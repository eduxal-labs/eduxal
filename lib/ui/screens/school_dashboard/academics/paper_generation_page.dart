import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../models/paper_generation.dart';
import '../../../../models/question.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';
import 'paper_pdf_viewer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paper Generation Page
//
// Multi-step wizard for AI paper generation:
//   Step 0 — Topic mark allocation (this task)
//   Step 1 — Review & edit generated questions (Task 13)
//   Step 2 — Finalize (Task 14)
// ─────────────────────────────────────────────────────────────────────────────

class PaperGenerationPage extends StatefulWidget {
  const PaperGenerationPage({
    super.key,
    required this.schoolId,
    required this.examId,
    required this.subjectId,
    this.paperId,
    required this.grade,
    this.stream,
    required this.subjectName,
    required this.examName,
  });

  final String schoolId;
  final String examId;
  final int subjectId;
  final int? paperId;
  final int grade;
  final int? stream;
  final String subjectName;
  final String examName;

  @override
  State<PaperGenerationPage> createState() => _PaperGenerationPageState();
}

class _PaperGenerationPageState extends State<PaperGenerationPage> {
  int _currentStep = 0; // 0=allocate, 1=review, 2=finalize
  int _totalMarks = 80;
  List<TopicAllocation> _allocations = [];
  List<PaperQuestion> _generatedQuestions = [];
  PaperPdf? _paperPdf;
  bool _isGenerating = false;
  bool _isFinalizing = false;

  /// Track paperQuestionId → topicId for regeneration.
  /// Built when generating paper from allocations.
  final Map<String, int> _questionTopics = {};

  /// Index of the question currently in inline-edit mode, or -1 if none.
  int _editingIndex = -1;

  /// Index of the question currently being regenerated, or -1 if none.
  int _regeneratingIndex = -1;

  // ── Edit mode controllers ──
  final TextEditingController _editTextCtrl = TextEditingController();
  final TextEditingController _editMarksCtrl = TextEditingController();
  final List<_InlineRubricEntry> _editRubric = [];

  bool _isSavingEdit = false;

  late final TextEditingController _totalMarksController;
  final List<TextEditingController> _markControllers = [];

  @override
  void initState() {
    super.initState();
    _totalMarksController = TextEditingController(text: '$_totalMarks');
  }

  @override
  void dispose() {
    _totalMarksController.dispose();
    for (final c in _markControllers) {
      c.dispose();
    }
    _editTextCtrl.dispose();
    _editMarksCtrl.dispose();
    _disposeEditRubric();
    super.dispose();
  }

  void _disposeEditRubric() {
    for (final r in _editRubric) {
      r.criterionCtrl.dispose();
      r.marksCtrl.dispose();
    }
    _editRubric.clear();
  }

  // ───────────────────────── Computed ─────────────────────────

  int get _allocatedSum {
    int sum = 0;
    for (final a in _allocations) {
      sum += a.marks;
    }
    return sum;
  }

  Color _allocationColor(ColorScheme cs) {
    final sum = _allocatedSum;
    if (sum == _totalMarks && _totalMarks > 0) return const Color(0xFF4CAF50);
    if (sum > _totalMarks) return const Color(0xFFF44336);
    return const Color(0xFFFFA726);
  }

  bool get _canGenerate =>
      _allocatedSum == _totalMarks && _totalMarks > 0 && !_isGenerating;

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _generate() async {
    if (!_canGenerate) return;

    final nonZero = _allocations.where((a) => a.marks > 0).toList();
    if (nonZero.isEmpty) return;

    setState(() => _isGenerating = true);

    final result = await questionBankService.generatePaper(
      school: widget.schoolId,
      exam: widget.examId,
      subject: widget.subjectId,
      paper: widget.paperId,
      grade: widget.grade,
      stream: widget.stream,
      totalMarks: _totalMarks,
      allocations: nonZero,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(value: final questions):
        // Build the question → topic map.
        // Heuristic: distribute questions across allocations proportionally.
        // Each allocation specifies marks for a topic — questions are ordered
        // and we assign them to topics based on cumulative marks.
        _questionTopics.clear();
        _buildQuestionTopicMap(questions, nonZero);
        setState(() {
          _generatedQuestions = questions;
          _currentStep = 1;
          _isGenerating = false;
        });
      case Err(error: final e):
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Failed to generate paper'),
              behavior: SnackBarBehavior.floating,
            ),
          );
    }
  }

  /// Build a mapping from paperQuestionId → topicId.
  /// Uses cumulative marks to assign questions to topics.
  void _buildQuestionTopicMap(
    List<PaperQuestion> questions,
    List<TopicAllocation> allocations,
  ) {
    if (allocations.isEmpty || questions.isEmpty) return;

    // Build cumulative mark boundaries per topic
    final boundaries = <({int topicId, int cumulativeMarks})>[];
    int cumulative = 0;
    for (final a in allocations) {
      cumulative += a.marks;
      boundaries.add((topicId: a.topicId, cumulativeMarks: cumulative));
    }

    // Sort questions by order
    final sorted = List<PaperQuestion>.from(questions)
      ..sort((a, b) => a.order.compareTo(b.order));

    int runningMarks = 0;
    int boundaryIndex = 0;
    for (final q in sorted) {
      runningMarks += q.marks;
      // Advance boundary when we've exceeded the current topic's cumulative
      while (boundaryIndex < boundaries.length - 1 &&
          runningMarks > boundaries[boundaryIndex].cumulativeMarks) {
        boundaryIndex++;
      }
      _questionTopics[q.id] = boundaries[boundaryIndex].topicId;
    }
  }

  int _findTopicForQuestion(PaperQuestion question) {
    return _questionTopics[question.id] ?? 0;
  }

  // ─────────────────── Regenerate ────────────────────────────

  Future<void> _regenerateQuestion(int index) async {
    if (_regeneratingIndex != -1) return;
    final question = _generatedQuestions[index];

    setState(() => _regeneratingIndex = index);

    final result = await questionBankService.regenerateQuestion(
      school: widget.schoolId,
      exam: widget.examId,
      subject: widget.subjectId,
      paper: widget.paperId,
      grade: widget.grade,
      position: question.order,
      topicId: _findTopicForQuestion(question),
      marks: question.marks,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(value: final newQuestion):
        setState(() {
          // Preserve the topic mapping for the new question
          final topicId = _questionTopics.remove(question.id);
          if (topicId != null) {
            _questionTopics[newQuestion.id] = topicId;
          }
          _generatedQuestions[index] = newQuestion;
          _regeneratingIndex = -1;
        });
      case Err(error: final e):
        setState(() => _regeneratingIndex = -1);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(e.message ?? 'Failed to regenerate question'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
    }
  }

  // ─────────────────── Inline Edit ───────────────────────────

  void _startEditing(int index) {
    final question = _generatedQuestions[index];
    _disposeEditRubric();

    _editTextCtrl.text = question.text;
    _editMarksCtrl.text = '${question.marks}';

    for (final c in question.rubric) {
      _editRubric.add(
        _InlineRubricEntry()
          ..criterionCtrl.text = c.criterion
          ..marksCtrl.text = '${c.marks}',
      );
    }

    setState(() {
      _editingIndex = index;
      _isSavingEdit = false;
    });
  }

  void _cancelEditing() {
    _disposeEditRubric();
    setState(() {
      _editingIndex = -1;
      _isSavingEdit = false;
    });
  }

  void _addEditRubricRow() {
    setState(() {
      _editRubric.add(_InlineRubricEntry());
    });
  }

  void _removeEditRubricRow(int index) {
    final entry = _editRubric.removeAt(index);
    entry.criterionCtrl.dispose();
    entry.marksCtrl.dispose();
    setState(() {});
  }

  Future<void> _saveEdit(int index) async {
    if (_isSavingEdit) return;
    final question = _generatedQuestions[index];

    final text = _editTextCtrl.text.trim();
    if (text.isEmpty) return;

    final marks = int.tryParse(_editMarksCtrl.text.trim()) ?? question.marks;

    final rubric = <RubricCriterion>[];
    for (final r in _editRubric) {
      final criterion = r.criterionCtrl.text.trim();
      final rMarks = int.tryParse(r.marksCtrl.text.trim()) ?? 0;
      if (criterion.isNotEmpty) {
        rubric.add(RubricCriterion(criterion: criterion, marks: rMarks));
      }
    }

    setState(() => _isSavingEdit = true);

    final result = await questionBankService.editPaperQuestion(
      questionId: question.questionId,
      text: text,
      marks: marks,
      rubric: rubric,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(value: final editedQuestion):
        // Reconstruct PaperQuestion from the returned Question,
        // preserving the original order/position.
        final updated = PaperQuestion(
          id: editedQuestion.id.toString(),
          questionId: editedQuestion.id,
          text: editedQuestion.text,
          marks: editedQuestion.marks,
          rubric: editedQuestion.rubric,
          images: editedQuestion.images,
          order: question.order,
        );
        // Preserve topic mapping
        final topicId = _questionTopics.remove(question.id);
        if (topicId != null) {
          _questionTopics[updated.id] = topicId;
        }
        _disposeEditRubric();
        setState(() {
          _generatedQuestions[index] = updated;
          _editingIndex = -1;
          _isSavingEdit = false;
        });
      case Err(error: final e):
        setState(() => _isSavingEdit = false);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(e.message ?? 'Failed to save changes'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
    }
  }

  // ─────────────────────── Sync allocations from topics ───────────────────

  void _syncAllocations(List<Topic> topics) {
    // Build a map of existing allocations by topicId for preservation
    final existing = <int, int>{};
    for (final a in _allocations) {
      existing[a.topicId] = a.marks;
    }

    // Dispose old controllers that are excess
    while (_markControllers.length > topics.length) {
      _markControllers.removeLast().dispose();
    }

    final newAllocations = <TopicAllocation>[];
    for (int i = 0; i < topics.length; i++) {
      final t = topics[i];
      final marks = existing[t.id] ?? 0;
      newAllocations.add(
        TopicAllocation(topicId: t.id, topicName: t.name, marks: marks),
      );

      if (i < _markControllers.length) {
        // Update existing controller text only if value changed
        final currentText = _markControllers[i].text;
        final expectedText = marks == 0 ? '' : '$marks';
        if (currentText != expectedText) {
          _markControllers[i].text = expectedText;
        }
      } else {
        _markControllers.add(
          TextEditingController(text: marks == 0 ? '' : '$marks'),
        );
      }
    }

    _allocations = newAllocations;
  }

  // ─────────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String title;
    switch (_currentStep) {
      case 0:
        title = 'Generate Paper';
      case 1:
        title = 'Review Questions';
      case 2:
        title = 'Finalize';
      default:
        title = 'Generate Paper';
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
            } else if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.of(context).pop();
            }
          },
          tooltip: _currentStep > 0 ? 'Previous step' : 'Back',
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StepDots(current: _currentStep, total: 3, cs: cs),
          ),
        ],
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: switch (_currentStep) {
        0 => _buildAllocationStep(cs, isDark),
        1 => _buildReviewStep(cs, isDark),
        2 => _buildFinalizeStep(cs, isDark),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ───────────────── Step 0: Topic Allocation ─────────────────

  Widget _buildAllocationStep(ColorScheme cs, bool isDark) {
    return Column(
      children: [
        // ── Subject & Exam context ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.subjectName} · ${widget.examName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // ── Total marks input ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Text(
                'Total marks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                height: 40,
                child: TextField(
                  controller: _totalMarksController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor(isDark, cs),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor(isDark, cs),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                  enabled: !_isGenerating,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed >= 0) {
                      setState(() => _totalMarks = parsed);
                    } else if (v.isEmpty) {
                      setState(() => _totalMarks = 0);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Topic list ──
        Expanded(
          child: StreamBuilder<List<Topic>>(
            stream: catalogDao.watchTopicsBySubjectAndGrade(
              subjectId: widget.subjectId,
              grade: widget.grade,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final topics = snapshot.data ?? [];

              if (topics.isEmpty) {
                return _buildEmptyTopics(cs);
              }

              // Sync allocations + controllers with latest topic list
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final needsSync =
                    _allocations.length != topics.length ||
                    topics.any(
                      (t) => !_allocations.any((a) => a.topicId == t.id),
                    );
                if (needsSync) {
                  setState(() => _syncAllocations(topics));
                } else if (_allocations.isEmpty && topics.isNotEmpty) {
                  setState(() => _syncAllocations(topics));
                }
              });

              // First render — sync immediately
              if (_allocations.length != topics.length) {
                _syncAllocations(topics);
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allocations.length,
                separatorBuilder: (_, i) =>
                    AppTheme.tableRowDivider(isDark, cs),
                itemBuilder: (context, index) {
                  if (index >= _allocations.length ||
                      index >= _markControllers.length) {
                    return const SizedBox.shrink();
                  }
                  final alloc = _allocations[index];
                  return _TopicRow(
                    allocation: alloc,
                    controller: _markControllers[index],
                    cs: cs,
                    isDark: isDark,
                    enabled: !_isGenerating,
                    onChanged: (value) {
                      setState(() {
                        alloc.marks = value;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),

        // ── Sticky footer ──
        _AllocationFooter(
          allocated: _allocatedSum,
          total: _totalMarks,
          color: _allocationColor(cs),
          canGenerate: _canGenerate,
          isGenerating: _isGenerating,
          cs: cs,
          isDark: isDark,
          onGenerate: _generate,
        ),
      ],
    );
  }

  Widget _buildEmptyTopics(ColorScheme cs) {
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
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              child: Icon(
                Icons.topic_outlined,
                size: 28,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No topics found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add topics for this subject and grade to generate a paper',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── Step 1: Review Questions ─────────────────

  Widget _buildReviewStep(ColorScheme cs, bool isDark) {
    if (_generatedQuestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 48,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No questions generated',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Go back and generate questions first',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ── Context header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.subjectName} · ${widget.examName} · ${_generatedQuestions.length} question${_generatedQuestions.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // ── Question list ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _generatedQuestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final question = _generatedQuestions[index];
              final isEditing = _editingIndex == index;
              final isRegenerating = _regeneratingIndex == index;

              if (isRegenerating) {
                return _buildRegeneratingCard(cs, isDark);
              }

              if (isEditing) {
                return _buildEditCard(index, question, cs, isDark);
              }

              return _buildQuestionCard(index, question, cs, isDark);
            },
          ),
        ),

        // ── Finalize footer ──
        _ReviewFooter(
          questionCount: _generatedQuestions.length,
          cs: cs,
          isDark: isDark,
          onFinalize: _generatedQuestions.isNotEmpty
              ? () => setState(() => _currentStep = 2)
              : null,
        ),
      ],
    );
  }

  // ── Question card (display mode) ──

  Widget _buildQuestionCard(
    int index,
    PaperQuestion question,
    ColorScheme cs,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2536) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: order + marks + actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                // Question number
                Text(
                  'Q${question.order}.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                // Marks pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  ),
                  child: Text(
                    '${question.marks} mk${question.marks == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                // Edit button
                _MiniIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onTap: () => _startEditing(index),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                // Regenerate button
                _MiniIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Regenerate',
                  onTap: () => _regenerateQuestion(index),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),

          // ── Question text ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              question.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: cs.onSurface,
                height: 1.45,
              ),
            ),
          ),

          // ── Rubric (collapsible) ──
          if (question.rubric.isNotEmpty)
            _CollapsibleRubric(rubric: question.rubric, cs: cs, isDark: isDark),

          // ── Images ──
          if (question.images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: question.images.map((img) {
                  return _ImageBadge(
                    filename: img.filename,
                    context: img.context,
                    cs: cs,
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Regenerating shimmer card ──

  Widget _buildRegeneratingCard(ColorScheme cs, bool isDark) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2536) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Regenerating…',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit card (inline edit mode) ──

  Widget _buildEditCard(
    int index,
    PaperQuestion question,
    ColorScheme cs,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2536) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: order label + save/cancel ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                Text(
                  'Q${question.order}. — Editing',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
                const Spacer(),
                // Save
                _MiniIconButton(
                  icon: Icons.check_rounded,
                  tooltip: 'Save',
                  onTap: _isSavingEdit ? null : () => _saveEdit(index),
                  color: const Color(0xFF4CAF50),
                ),
                // Cancel
                _MiniIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  onTap: _isSavingEdit ? null : _cancelEditing,
                  color: cs.error.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),

          // ── Saving indicator ──
          if (_isSavingEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: cs.primary,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
              ),
            ),

          // ── Question text field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _editTextCtrl,
              maxLines: null,
              minLines: 2,
              enabled: !_isSavingEdit,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                height: 1.45,
              ),
              decoration: _editFieldDecoration(
                hint: 'Question text',
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),

          // ── Marks field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Text(
                  'Marks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  height: 34,
                  child: TextField(
                    controller: _editMarksCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    textAlign: TextAlign.center,
                    enabled: !_isSavingEdit,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: _editFieldDecoration(
                      hint: '0',
                      cs: cs,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Rubric criteria ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RUBRIC CRITERIA',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 6),

                for (int i = 0; i < _editRubric.length; i++) ...[
                  if (i > 0) AppTheme.tableRowDivider(isDark, cs),
                  _buildEditRubricRow(i, cs, isDark),
                ],

                const SizedBox(height: 6),

                // Add criterion
                GestureDetector(
                  onTap: _isSavingEdit ? null : _addEditRubricRow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(
                          alpha: isDark ? 0.2 : 0.15,
                        ),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: cs.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add criterion',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEditRubricRow(int index, ColorScheme cs, bool isDark) {
    final entry = _editRubric[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Criterion text
          Expanded(
            child: TextField(
              controller: entry.criterionCtrl,
              enabled: !_isSavingEdit,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: _editFieldDecoration(
                hint: 'Criterion description',
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Marks
          SizedBox(
            width: 60,
            child: TextField(
              controller: entry.marksCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              enabled: !_isSavingEdit,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: _editFieldDecoration(
                hint: 'Mks',
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Remove button
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _MiniIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove',
              onTap: _isSavingEdit ? null : () => _removeEditRubricRow(index),
              color: cs.error.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _editFieldDecoration({
    required String hint,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.40),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: isDark
            ? BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: isDark
            ? BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: cs.primary, width: 1),
      ),
    );
  }

  // ───────────────── Step 2: Finalize ─────────────────

  Future<void> _finalize() async {
    if (_isFinalizing) return;
    setState(() => _isFinalizing = true);

    final result = await questionBankService.finalizePaper(
      school: widget.schoolId,
      exam: widget.examId,
      subject: widget.subjectId,
      paper: widget.paperId,
      grade: widget.grade,
      stream: widget.stream,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        setState(() {
          _paperPdf = value;
          _isFinalizing = false;
        });
      case Err(:final error):
        setState(() => _isFinalizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to finalize paper: ${error.message}')),
        );
    }
  }

  Widget _buildFinalizeStep(ColorScheme cs, bool isDark) {
    final totalMarks = _generatedQuestions.fold<int>(
      0,
      (sum, q) => sum + q.marks,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // ── Subject & Exam context ──
              Text(
                '${widget.subjectName} · ${widget.examName}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),

              // ── Stats row ──
              Row(
                children: [
                  _summaryChip(
                    label: 'Questions',
                    value: '${_generatedQuestions.length}',
                    cs: cs,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _summaryChip(
                    label: 'Total Marks',
                    value: '$totalMarks',
                    cs: cs,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Question list header ──
              Text(
                'Questions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),

              // ── Compact question list (data-table style) ──
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.borderColor(isDark, cs),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _generatedQuestions.length; i++) ...[
                      if (i > 0) AppTheme.tableRowDivider(isDark, cs),
                      _buildQuestionRow(i, _generatedQuestions[i], cs, isDark),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── PDF result area (visible after finalization) ──
              if (_paperPdf != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.08 : 0.05),
                    border: Border.all(
                      color: Colors.green.withValues(
                        alpha: isDark ? 0.25 : 0.2,
                      ),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paper generated successfully!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Download / Print PDF button
                      SizedBox(
                        width: double.infinity,
                        child: _FinalizeActionButton(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Download / Print PDF',
                          color: cs.primary,
                          textColor: cs.onPrimary,
                          onTap: () => downloadAndOpenPdf(
                            school: widget.schoolId,
                            exam: widget.examId,
                            subject: widget.subjectId,
                            paper: widget.paperId,
                            grade: widget.grade,
                            stream: widget.stream,
                            accessToken: accessToken,
                            context: context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Done button
                      SizedBox(
                        width: double.infinity,
                        child: _FinalizeActionButton(
                          icon: Icons.done_all_rounded,
                          label: 'Done',
                          color: isDark
                              ? cs.surfaceContainerHighest
                              : cs.surfaceContainerHigh,
                          textColor: cs.onSurface,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Finalize button footer (hidden once PDF is generated) ──
        if (_paperPdf == null)
          _FinalizeFooter(
            cs: cs,
            isDark: isDark,
            isFinalizing: _isFinalizing,
            onFinalize: _generatedQuestions.isNotEmpty ? _finalize : null,
          ),
      ],
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionRow(
    int index,
    PaperQuestion question,
    ColorScheme cs,
    bool isDark,
  ) {
    final truncated = question.text.length > 60
        ? '${question.text.substring(0, 60)}…'
        : question.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              'Q${question.order}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              truncated,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${question.marks}m',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline rubric entry (edit mode)
// ─────────────────────────────────────────────────────────────────────────────

class _InlineRubricEntry {
  final criterionCtrl = TextEditingController();
  final marksCtrl = TextEditingController();
}

// ─────────────────────────────────────────────────────────────────────────────
// Finalize footer (animated button)
// ─────────────────────────────────────────────────────────────────────────────

class _FinalizeFooter extends StatefulWidget {
  const _FinalizeFooter({
    required this.cs,
    required this.isDark,
    required this.isFinalizing,
    required this.onFinalize,
  });

  final ColorScheme cs;
  final bool isDark;
  final bool isFinalizing;
  final VoidCallback? onFinalize;

  @override
  State<_FinalizeFooter> createState() => _FinalizeFooterState();
}

class _FinalizeFooterState extends State<_FinalizeFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _scaleCtrl.reverse();
  void _handleTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _handleTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final enabled = widget.onFinalize != null && !widget.isFinalizing;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTapDown: enabled ? _handleTapDown : null,
          onTapUp: enabled ? _handleTapUp : null,
          onTapCancel: enabled ? _handleTapCancel : null,
          onTap: enabled ? widget.onFinalize : null,
          child: AnimatedBuilder(
            animation: _scaleCtrl,
            builder: (context, child) {
              return Transform.scale(scale: _scaleCtrl.value, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: enabled
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              alignment: Alignment.center,
              child: widget.isFinalizing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: enabled
                              ? cs.onPrimary
                              : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Finalize & Generate PDF',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: enabled
                                ? cs.onPrimary
                                : cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Finalize action button (download / done)
// ─────────────────────────────────────────────────────────────────────────────

class _FinalizeActionButton extends StatefulWidget {
  const _FinalizeActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_FinalizeActionButton> createState() => _FinalizeActionButtonState();
}

class _FinalizeActionButtonState extends State<_FinalizeActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp: (_) => _scaleCtrl.forward(),
      onTapCancel: () => _scaleCtrl.forward(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) {
          return Transform.scale(scale: _scaleCtrl.value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.textColor),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.textColor,
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
// Mini icon button (28×28)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: 16,
        color: onTap != null ? color : color.withValues(alpha: 0.3),
      ),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: tooltip,
      splashRadius: 14,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsible rubric section
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsibleRubric extends StatefulWidget {
  const _CollapsibleRubric({
    required this.rubric,
    required this.cs,
    required this.isDark,
  });

  final List<RubricCriterion> rubric;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_CollapsibleRubric> createState() => _CollapsibleRubricState();
}

class _CollapsibleRubricState extends State<_CollapsibleRubric> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'Rubric (${widget.rubric.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Criteria list
          if (_expanded) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151E2B)
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.15 : 0.1,
                  ),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < widget.rubric.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.rubric[i].criterion,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: cs.onSurface.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(
                                alpha: isDark ? 0.10 : 0.07,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kChipRadius,
                              ),
                            ),
                            child: Text(
                              '${widget.rubric[i].marks}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: cs.primary.withValues(alpha: 0.8),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image badge
// ─────────────────────────────────────────────────────────────────────────────

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({
    required this.filename,
    required this.context,
    required this.cs,
    required this.isDark,
  });

  final String filename;
  final ImageContext context;
  final ColorScheme cs;
  final bool isDark;

  String get _contextLabel => switch (context) {
    ImageContext.question => 'Question',
    ImageContext.rubric => 'Rubric',
    ImageContext.exampleAnswer => 'Answer',
  };

  @override
  Widget build(BuildContext context_) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: isDark ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            filename,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              _contextLabel,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review footer with Finalize button
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewFooter extends StatefulWidget {
  const _ReviewFooter({
    required this.questionCount,
    required this.cs,
    required this.isDark,
    required this.onFinalize,
  });

  final int questionCount;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onFinalize;

  @override
  State<_ReviewFooter> createState() => _ReviewFooterState();
}

class _ReviewFooterState extends State<_ReviewFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _scaleCtrl.reverse();
  void _handleTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _handleTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final enabled = widget.onFinalize != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${widget.questionCount} question${widget.questionCount == 1 ? '' : 's'} ready',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            GestureDetector(
              onTapDown: enabled ? _handleTapDown : null,
              onTapUp: enabled ? _handleTapUp : null,
              onTapCancel: enabled ? _handleTapCancel : null,
              onTap: widget.onFinalize,
              child: AnimatedBuilder(
                animation: _scaleCtrl,
                builder: (context, child) {
                  return Transform.scale(scale: _scaleCtrl.value, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: enabled
                            ? cs.onPrimary
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Finalize',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: enabled
                              ? cs.onPrimary
                              : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator dots
// ─────────────────────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.current,
    required this.total,
    required this.cs,
  });

  final int current;
  final int total;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return Padding(
          padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 8 : 6,
            height: isActive ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? cs.primary
                  : isPast
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic row
// ─────────────────────────────────────────────────────────────────────────────

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.allocation,
    required this.controller,
    required this.cs,
    required this.isDark,
    required this.enabled,
    required this.onChanged,
  });

  final TopicAllocation allocation;
  final TextEditingController controller;
  final ColorScheme cs;
  final bool isDark;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              allocation.topicName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            height: 34,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                hintText: '0',
                hintStyle: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  borderSide: BorderSide(
                    color: AppTheme.borderColor(isDark, cs),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  borderSide: BorderSide(
                    color: AppTheme.borderColor(isDark, cs),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
              enabled: enabled,
              onChanged: (v) {
                final parsed = int.tryParse(v);
                onChanged(parsed ?? 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky footer with allocation summary + generate button
// ─────────────────────────────────────────────────────────────────────────────

class _AllocationFooter extends StatefulWidget {
  const _AllocationFooter({
    required this.allocated,
    required this.total,
    required this.color,
    required this.canGenerate,
    required this.isGenerating,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
  });

  final int allocated;
  final int total;
  final Color color;
  final bool canGenerate;
  final bool isGenerating;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onGenerate;

  @override
  State<_AllocationFooter> createState() => _AllocationFooterState();
}

class _AllocationFooterState extends State<_AllocationFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _scaleCtrl.reverse();
  void _handleTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _handleTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ── Allocation summary ──
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'Allocated: '),
                    TextSpan(
                      text: '${widget.allocated}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: widget.color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: ' / ${widget.total}',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Generate button ──
            GestureDetector(
              onTapDown: widget.canGenerate ? _handleTapDown : null,
              onTapUp: widget.canGenerate ? _handleTapUp : null,
              onTapCancel: widget.canGenerate ? _handleTapCancel : null,
              onTap: widget.canGenerate ? widget.onGenerate : null,
              child: AnimatedBuilder(
                animation: _scaleCtrl,
                builder: (context, child) {
                  return Transform.scale(scale: _scaleCtrl.value, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: widget.canGenerate
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  child: widget.isGenerating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: widget.canGenerate
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Generate',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: widget.canGenerate
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          ],
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
