import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../models/paper_generation.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';

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
  // ignore: unused_field
  List<PaperQuestion> _generatedQuestions =
      []; // filled by Step 1 → used by Task 13
  // ignore: unused_field
  PaperPdf? _paperPdf; // filled by Step 2 → used by Task 14
  bool _isGenerating = false;

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
    super.dispose();
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

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'Generate Paper',
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
        1 => _buildReviewStep(cs),
        2 => _buildFinalizeStep(cs),
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
                separatorBuilder: (_, _i) =>
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

  // ───────────────── Step 1: Review (placeholder) ─────────────────

  Widget _buildReviewStep(ColorScheme cs) {
    return Center(
      child: Text(
        'Step 2 — Review & Edit (coming soon)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ───────────────── Step 2: Finalize (placeholder) ─────────────────

  Widget _buildFinalizeStep(ColorScheme cs) {
    return Center(
      child: Text(
        'Step 3 — Finalize (coming soon)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
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
