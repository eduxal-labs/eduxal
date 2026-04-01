import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../models/question.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import 'create_question_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuestionsListPage — full-page question browser for a topic
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page screen showing all questions for a topic with pagination.
///
/// Fetches questions from [questionBankService.listQuestions] and stores
/// them in local state. Supports create, edit, delete, and inline expansion
/// to view full question details (rubric, example answer, images).
class QuestionsListPage extends StatefulWidget {
  const QuestionsListPage({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.subjectName,
    required this.grade,
    required this.canEdit,
    required this.canDelete,
    required this.canCreate,
  });

  final int topicId;
  final String topicName;
  final String subjectName;
  final int grade;
  final bool canEdit;
  final bool canDelete;
  final bool canCreate;

  @override
  State<QuestionsListPage> createState() => _QuestionsListPageState();
}

class _QuestionsListPageState extends State<QuestionsListPage> {
  List<Question> _questions = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQuestions(reset: true);
  }

  Future<void> _fetchQuestions({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final offset = reset ? 0 : _questions.length;
    final result = await questionBankService.listQuestions(
      topicId: widget.topicId,
      offset: offset,
      limit: 50,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(value: final v):
        setState(() {
          if (reset) {
            _questions = v.$1;
          } else {
            _questions = [..._questions, ...v.$1];
          }
          _total = v.$2;
          _loading = false;
          _loadingMore = false;
          _error = null;
        });
      case Err(error: final e):
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = e.message ?? 'Failed to load questions.';
        });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _questions.length >= _total) return;
    setState(() => _loadingMore = true);
    await _fetchQuestions();
  }

  void _onQuestionCreated() {
    _fetchQuestions(reset: true);
  }

  void _openCreateSheet() {
    showEduSheet(
      context: context,
      maxWidth: 520,
      builder: (_) => CreateQuestionSheet(
        topicId: widget.topicId,
        topicName: widget.topicName,
        subjectName: widget.subjectName,
        grade: widget.grade,
        onCreated: _onQuestionCreated,
      ),
    );
  }

  void _openEditSheet(Question question) {
    showEduSheet(
      context: context,
      maxWidth: 520,
      builder: (_) => _EditQuestionSheet(
        question: question,
        onUpdated: () => _fetchQuestions(reset: true),
      ),
    );
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Question',
      message:
          'Are you sure you want to delete this question? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final result = await questionBankService.deleteQuestion(
      id: question.id,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        setState(() {
          _questions.removeWhere((q) => q.id == question.id);
          _total = (_total - 1).clamp(0, _total);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err(error: final e):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to delete question.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.modalBg(isDark, cs) : cs.surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.modalBg(isDark, cs) : cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${widget.subjectName} › ${widget.topicName}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
        ),
        titleSpacing: 0,
        actions: [
          if (widget.canCreate)
            IconButton(
              icon: Icon(Icons.add_rounded, size: 22, color: cs.primary),
              tooltip: 'Add question',
              onPressed: _openCreateSheet,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(cs, isDark, isDesktop),
    );
  }

  Widget _buildBody(ColorScheme cs, bool isDark, bool isDesktop) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: cs.primary.withValues(alpha: 0.5),
        ),
      );
    }

    if (_error != null && _questions.isEmpty) {
      return _ErrorState(
        message: _error!,
        onRetry: () => _fetchQuestions(reset: true),
        cs: cs,
      );
    }

    if (_questions.isEmpty) {
      return _EmptyState(cs: cs, isDark: isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _questions.length + (_questions.length < _total ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _questions.length) {
          return _LoadMoreButton(
            loading: _loadingMore,
            remaining: _total - _questions.length,
            onTap: _loadMore,
            cs: cs,
            isDark: isDark,
          );
        }

        final question = _questions[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0) AppTheme.tableRowDivider(isDark, cs),
            _QuestionRow(
              question: question,
              index: index,
              canEdit: widget.canEdit,
              canDelete: widget.canDelete,
              isDesktop: isDesktop,
              cs: cs,
              isDark: isDark,
              onEdit: () => _openEditSheet(question),
              onDelete: () => _deleteQuestion(question),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuestionRow — single question row with expansion
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionRow extends StatefulWidget {
  const _QuestionRow({
    required this.question,
    required this.index,
    required this.canEdit,
    required this.canDelete,
    required this.isDesktop,
    required this.cs,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  final Question question;
  final int index;
  final bool canEdit;
  final bool canDelete;
  final bool isDesktop;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_QuestionRow> createState() => _QuestionRowState();
}

class _QuestionRowState extends State<_QuestionRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _hovered = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.25).animate(_expandAnim);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    });
  }

  void _showMobileActions() {
    final cs = widget.cs;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EduSheet(
        title: 'Question Actions',
        onClose: () => Navigator.of(ctx).pop(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.canEdit)
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: cs.onSurface,
                  ),
                  title: Text(
                    'Edit question',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onEdit();
                  },
                ),
              if (widget.canDelete)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: cs.error,
                  ),
                  title: Text(
                    'Delete question',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.error,
                    ),
                  ),
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onDelete();
                  },
                ),
              SizedBox(height: MediaQuery.viewPaddingOf(ctx).bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final q = widget.question;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Collapsed row ────────────────────────────────────────────────
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: _toggle,
            hoverColor: cs.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Expand chevron
                  RotationTransition(
                    turns: _rotateAnim,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _expanded
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Question number
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(
                        alpha: isDark ? 0.25 : 0.50,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Question text
                  Expanded(
                    child: Text(
                      q.text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurface.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Marks badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(
                        alpha: isDark ? 0.30 : 0.60,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    ),
                    child: Text(
                      '${q.marks} mk${q.marks == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                  // Rubric count badge
                  if (q.rubric.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(
                          alpha: isDark ? 0.25 : 0.50,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        '${q.rubric.length} cr',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onTertiaryContainer.withValues(alpha: 0.80),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Actions
                  if (widget.isDesktop)
                    AnimatedOpacity(
                      opacity: _hovered || _expanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 120),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.canEdit)
                            _TinyAction(
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit',
                              onTap: widget.onEdit,
                              cs: cs,
                            ),
                          if (widget.canDelete) ...[
                            const SizedBox(width: 2),
                            _TinyAction(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Delete',
                              onTap: widget.onDelete,
                              cs: cs,
                              isDestructive: true,
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (widget.canEdit || widget.canDelete)
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: _showMobileActions,
                    ),
                ],
              ),
            ),
          ),
        ),
        // ── Expanded detail ──────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: _QuestionExpandedContent(question: q, cs: cs, isDark: isDark),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuestionExpandedContent — full question details
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionExpandedContent extends StatelessWidget {
  const _QuestionExpandedContent({
    required this.question,
    required this.cs,
    required this.isDark,
  });

  final Question question;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 50, right: 16, bottom: 8, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.10 : 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Full question text ──────────────────────────────────────
          _SectionLabel(label: 'Question', cs: cs),
          const SizedBox(height: 4),
          Text(
            question.text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: cs.onSurface.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),

          // ── Rubric ─────────────────────────────────────────────────
          if (question.rubric.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel(label: 'Rubric Criteria', cs: cs),
            const SizedBox(height: 6),
            ...question.rubric.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.criterion,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurface.withValues(alpha: 0.75),
                          height: 1.4,
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
                        color: cs.primaryContainer.withValues(
                          alpha: isDark ? 0.25 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        '${r.marks} mk${r.marks == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Example answer ─────────────────────────────────────────
          if (question.exampleAnswer != null &&
              question.exampleAnswer!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel(label: 'Example Answer', cs: cs),
            const SizedBox(height: 4),
            Text(
              question.exampleAnswer!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.70),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // ── Images ─────────────────────────────────────────────────
          if (question.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel(label: 'Images', cs: cs),
            const SizedBox(height: 6),
            ...question.images.map(
              (img) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        img.filename,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(
                          alpha: isDark ? 0.25 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        _imageContextLabel(img.context),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSecondaryContainer.withValues(
                            alpha: 0.70,
                          ),
                        ),
                      ),
                    ),
                    if (img.caption != null && img.caption!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          img.caption!,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _imageContextLabel(ImageContext ctx) => switch (ctx) {
    ImageContext.question => 'Question',
    ImageContext.rubric => 'Rubric',
    ImageContext.exampleAnswer => 'Example',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionLabel
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        letterSpacing: 0.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TinyAction — small icon button (matches subjects_section.dart pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _TinyAction extends StatefulWidget {
  const _TinyAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.cs,
    this.isDestructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDestructive;

  @override
  State<_TinyAction> createState() => _TinyActionState();
}

class _TinyActionState extends State<_TinyAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final color = widget.isDestructive
        ? cs.error.withValues(alpha: _hovered ? 0.85 : 0.45)
        : cs.onSurfaceVariant.withValues(alpha: _hovered ? 0.70 : 0.35);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(widget.icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            'No questions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add questions manually or import from JSON.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorState
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.cs,
  });

  final String message;
  final VoidCallback onRetry;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: cs.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadMoreButton
// ─────────────────────────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.loading,
    required this.remaining,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final bool loading;
  final int remaining;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.primary.withValues(alpha: 0.5),
                ),
              )
            : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                ),
                child: Text(
                  'Load more ($remaining remaining)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.primary.withValues(alpha: 0.70),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EditQuestionSheet — pre-filled question edit form
// ─────────────────────────────────────────────────────────────────────────────

/// Edit variant of the question form. Pre-fills all fields from [question]
/// and calls [questionBankService.updateQuestion] on submit.
///
/// Self-contained per BUG-010 — provides its own EduSheet wrapper with
/// handle, title, background, and keyboard padding.
class _EditQuestionSheet extends StatefulWidget {
  const _EditQuestionSheet({required this.question, required this.onUpdated});

  final Question question;
  final VoidCallback onUpdated;

  @override
  State<_EditQuestionSheet> createState() => _EditQuestionSheetState();
}

class _EditQuestionSheetState extends State<_EditQuestionSheet> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _marksCtrl;
  late final TextEditingController _exampleAnswerCtrl;

  final List<_RubricEntry> _rubric = [];
  final List<_ImageEntry> _images = [];

  bool _submitting = false;
  String? _textError;
  String? _marksError;
  String? _rubricError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _textCtrl = TextEditingController(text: q.text);
    _marksCtrl = TextEditingController(text: '${q.marks}');
    _exampleAnswerCtrl = TextEditingController(text: q.exampleAnswer ?? '');

    for (final r in q.rubric) {
      _rubric.add(
        _RubricEntry(
          criterionCtrl: TextEditingController(text: r.criterion),
          marksCtrl: TextEditingController(text: '${r.marks}'),
        ),
      );
    }

    for (final img in q.images) {
      _images.add(
        _ImageEntry(
          filenameCtrl: TextEditingController(text: img.filename),
          captionCtrl: TextEditingController(text: img.caption ?? ''),
          descriptionCtrl: TextEditingController(text: img.description),
          context: img.context,
        ),
      );
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _marksCtrl.dispose();
    _exampleAnswerCtrl.dispose();
    for (final r in _rubric) {
      r.criterionCtrl.dispose();
      r.marksCtrl.dispose();
    }
    for (final img in _images) {
      img.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    String? textErr;
    String? marksErr;
    String? rubricErr;

    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      textErr = 'Question text is required.';
      valid = false;
    }

    final marks = int.tryParse(_marksCtrl.text.trim());
    if (marks == null || marks <= 0) {
      marksErr = 'Enter a valid positive number.';
      valid = false;
    }

    if (_rubric.isNotEmpty) {
      int rubricSum = 0;
      for (final r in _rubric) {
        if (r.criterionCtrl.text.trim().isEmpty) {
          rubricErr = 'All criteria must have text.';
          valid = false;
          break;
        }
        final rm = int.tryParse(r.marksCtrl.text.trim());
        if (rm == null || rm <= 0) {
          rubricErr = 'All criteria must have valid marks (> 0).';
          valid = false;
          break;
        }
        rubricSum += rm;
      }
      if (rubricErr == null && marks != null && rubricSum != marks) {
        rubricErr =
            'Rubric marks ($rubricSum) must equal total marks ($marks).';
        valid = false;
      }
    }

    setState(() {
      _textError = textErr;
      _marksError = marksErr;
      _rubricError = rubricErr;
    });
    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final marks = int.parse(_marksCtrl.text.trim());

    final rubric = _rubric
        .map(
          (r) => RubricCriterion(
            criterion: r.criterionCtrl.text.trim(),
            marks: int.parse(r.marksCtrl.text.trim()),
          ),
        )
        .toList();

    final exampleAnswer = _exampleAnswerCtrl.text.trim().isNotEmpty
        ? _exampleAnswerCtrl.text.trim()
        : null;

    final images = _images
        .where((img) => img.filenameCtrl.text.trim().isNotEmpty)
        .map(
          (img) => QuestionImage(
            context: img.context,
            filename: img.filenameCtrl.text.trim(),
            caption: img.captionCtrl.text.trim().isNotEmpty
                ? img.captionCtrl.text.trim()
                : null,
            description: img.descriptionCtrl.text.trim(),
          ),
        )
        .toList();

    final result = await questionBankService.updateQuestion(
      id: widget.question.id,
      text: _textCtrl.text.trim(),
      marks: marks,
      rubric: rubric,
      exampleAnswer: exampleAnswer,
      images: images,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        widget.onUpdated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err(error: final e):
        setState(() {
          _submitting = false;
          _submitError = e.message ?? 'Failed to update question.';
        });
    }
  }

  void _addRubricRow() {
    setState(() {
      _rubric.add(
        _RubricEntry(
          criterionCtrl: TextEditingController(),
          marksCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _removeRubricRow(int index) {
    setState(() {
      final entry = _rubric.removeAt(index);
      entry.criterionCtrl.dispose();
      entry.marksCtrl.dispose();
    });
  }

  void _addImageRow() {
    setState(() {
      _images.add(
        _ImageEntry(
          filenameCtrl: TextEditingController(),
          captionCtrl: TextEditingController(),
          descriptionCtrl: TextEditingController(),
          context: ImageContext.question,
        ),
      );
    });
  }

  void _removeImageRow(int index) {
    setState(() {
      final entry = _images.removeAt(index);
      entry.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return EduSheet(
      title: 'Edit Question',
      onClose: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 4,
          bottom: 16 + viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Submit error banner ──────────────────────────────────
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],

            // ── Question text ────────────────────────────────────────
            Text(
              'Question text',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              minLines: 2,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: cs.onSurface,
              ),
              decoration: _fieldDecoration(
                cs: cs,
                isDark: isDark,
                hint: 'Enter the question…',
                errorText: _textError,
              ),
            ),
            const SizedBox(height: 14),

            // ── Total marks ──────────────────────────────────────────
            Text(
              'Total marks',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _marksCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurface,
                ),
                decoration: _fieldDecoration(
                  cs: cs,
                  isDark: isDark,
                  hint: 'e.g. 10',
                  errorText: _marksError,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Rubric section ───────────────────────────────────────
            Row(
              children: [
                Text(
                  'Rubric criteria',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _addRubricRow,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: cs.primary.withValues(alpha: 0.60),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add criterion',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: cs.primary.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_rubricError != null) ...[
              const SizedBox(height: 4),
              Text(
                _rubricError!,
                style: TextStyle(fontSize: 11.5, color: cs.error),
              ),
            ],
            if (_rubric.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(_rubric.length, (i) {
                final entry = _rubric[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.criterionCtrl,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurface,
                          ),
                          decoration: _compactDecoration(
                            cs: cs,
                            isDark: isDark,
                            hint: 'Criterion',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: entry.marksCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurface,
                          ),
                          decoration: _compactDecoration(
                            cs: cs,
                            isDark: isDark,
                            hint: 'Mks',
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeRubricRow(i),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: cs.error.withValues(alpha: 0.50),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 14),

            // ── Example answer ───────────────────────────────────────
            Text(
              'Example answer (optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _exampleAnswerCtrl,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: cs.onSurface,
              ),
              decoration: _fieldDecoration(
                cs: cs,
                isDark: isDark,
                hint: 'Expected answer…',
              ),
            ),
            const SizedBox(height: 14),

            // ── Images section ───────────────────────────────────────
            Row(
              children: [
                Text(
                  'Images (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _addImageRow,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: cs.primary.withValues(alpha: 0.60),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add image',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: cs.primary.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(_images.length, (i) {
                final entry = _images[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.nestedBg(
                        isDark,
                        cs,
                      ).withValues(alpha: isDark ? 1.0 : 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(
                          alpha: isDark ? 0.10 : 0.15,
                        ),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.filenameCtrl,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: cs.onSurface,
                                ),
                                decoration: _compactDecoration(
                                  cs: cs,
                                  isDark: isDark,
                                  hint: 'Filename',
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            DropdownButton<ImageContext>(
                              value: entry.context,
                              isDense: true,
                              underline: const SizedBox.shrink(),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                              items: ImageContext.values
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(_imageCtxLabel(c)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => entry.context = v);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeImageRow(i),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: cs.error.withValues(alpha: 0.50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: entry.captionCtrl,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurface,
                          ),
                          decoration: _compactDecoration(
                            cs: cs,
                            isDark: isDark,
                            hint: 'Caption (optional)',
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: entry.descriptionCtrl,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurface,
                          ),
                          decoration: _compactDecoration(
                            cs: cs,
                            isDark: isDark,
                            hint: 'Alt-text description',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),

            // ── Submit button ────────────────────────────────────────
            SizedBox(
              height: 40,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Decoration helpers ─────────────────────────────────────────────────

  InputDecoration _fieldDecoration({
    required ColorScheme cs,
    required bool isDark,
    required String hint,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: cs.onSurface.withValues(alpha: 0.30),
      ),
      errorText: errorText,
      errorStyle: TextStyle(fontSize: 11.5, color: cs.error),
      filled: true,
      fillColor: AppTheme.nestedBg(
        isDark,
        cs,
      ).withValues(alpha: isDark ? 1.0 : 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.20),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.20),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.error, width: 0.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.error, width: 1),
      ),
    );
  }

  InputDecoration _compactDecoration({
    required ColorScheme cs,
    required bool isDark,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: cs.onSurface.withValues(alpha: 0.25),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.18),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.18),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        borderSide: BorderSide(color: cs.primary, width: 1),
      ),
    );
  }

  static String _imageCtxLabel(ImageContext ctx) => switch (ctx) {
    ImageContext.question => 'Question',
    ImageContext.rubric => 'Rubric',
    ImageContext.exampleAnswer => 'Example',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper data classes for _EditQuestionSheet
// ─────────────────────────────────────────────────────────────────────────────

class _RubricEntry {
  final TextEditingController criterionCtrl;
  final TextEditingController marksCtrl;
  _RubricEntry({required this.criterionCtrl, required this.marksCtrl});
}

class _ImageEntry {
  final TextEditingController filenameCtrl;
  final TextEditingController captionCtrl;
  final TextEditingController descriptionCtrl;
  ImageContext context;

  _ImageEntry({
    required this.filenameCtrl,
    required this.captionCtrl,
    required this.descriptionCtrl,
    required this.context,
  });

  void dispose() {
    filenameCtrl.dispose();
    captionCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorBanner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.cs,
    required this.isDark,
  });

  final String message;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: isDark ? 0.25 : 0.60),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: cs.error.withValues(alpha: 0.70),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
