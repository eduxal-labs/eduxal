import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../models/question.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateQuestionSheet — single question creation form
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet / desktop dialog for creating a single question under a topic.
///
/// Launched via [showEduSheet]. Self-contained per BUG-010/BUG-016 — wraps
/// content in [EduSheet] for mobile background, drag handle, title row, and
/// keyboard padding. On desktop [showEduSheet] provides the outer dialog chrome.
class CreateQuestionSheet extends StatefulWidget {
  const CreateQuestionSheet({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.subjectName,
    required this.grade,
    this.onCreated,
  });

  final int topicId;
  final String topicName;
  final String subjectName;
  final int grade;

  /// Called after a question is successfully created (before pop).
  final VoidCallback? onCreated;

  @override
  State<CreateQuestionSheet> createState() => _CreateQuestionSheetState();
}

class _CreateQuestionSheetState extends State<CreateQuestionSheet> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _textCtrl = TextEditingController();
  final _marksCtrl = TextEditingController();
  final _exampleAnswerCtrl = TextEditingController();

  // ── Dynamic lists ────────────────────────────────────────────────────────
  final List<_RubricEntry> _rubric = [];
  final List<_ImageEntry> _images = [];

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _showExampleAnswer = false;
  bool _showImages = false;
  bool _submitting = false;

  // ── Errors ───────────────────────────────────────────────────────────────
  String? _textError;
  String? _marksError;
  String? _rubricError;
  String? _submitError;

  // ── Lifecycle ────────────────────────────────────────────────────────────

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

  // ── Rubric list management ───────────────────────────────────────────────

  void _addRubricRow() {
    setState(() {
      _rubric.add(_RubricEntry());
      _rubricError = null;
    });
  }

  void _removeRubricRow(int index) {
    final entry = _rubric.removeAt(index);
    entry.criterionCtrl.dispose();
    entry.marksCtrl.dispose();
    setState(() => _rubricError = null);
  }

  // ── Image list management ────────────────────────────────────────────────

  void _addImageRow() {
    setState(() => _images.add(_ImageEntry()));
  }

  void _removeImageRow(int index) {
    final entry = _images.removeAt(index);
    entry.dispose();
    setState(() {});
  }

  // ── Validation ───────────────────────────────────────────────────────────

  bool _validate() {
    bool valid = true;
    String? textErr;
    String? marksErr;
    String? rubricErr;

    // Question text
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      textErr = 'Question text is required.';
      valid = false;
    }

    // Marks
    final marks = int.tryParse(_marksCtrl.text.trim());
    if (marks == null || marks <= 0) {
      marksErr = 'Enter a valid positive number.';
      valid = false;
    }

    // Rubric
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

  // ── Submit ───────────────────────────────────────────────────────────────

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

    final exampleAnswer =
        _showExampleAnswer && _exampleAnswerCtrl.text.trim().isNotEmpty
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

    final result = await questionBankService.createQuestion(
      topicId: widget.topicId,
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
        widget.onCreated?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question created'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err(error: final e):
        setState(() {
          _submitting = false;
          _submitError = e.message ?? 'Failed to create question.';
        });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return EduSheet(
      title: 'New Question',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Context subtitle + save button ───────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.subjectName} · Grade ${widget.grade}'
                    ' · ${widget.topicName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  _SmallIconButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Create question',
                    onTap: _submit,
                    cs: cs,
                    isPrimary: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Submit error ─────────────────────────────────────────
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],

            // ── Question text ────────────────────────────────────────
            EduFormField(
              controller: _textCtrl,
              label: 'Question text',
              hint: 'Enter the question text...',
              error: _textError,
              maxLines: 10,
              minLines: 3,
            ),
            const SizedBox(height: 14),

            // ── Total marks ──────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: EduFormField(
                    controller: _marksCtrl,
                    label: 'Total marks',
                    hint: 'e.g. 10',
                    error: _marksError,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Rubric criteria ──────────────────────────────────────
            _buildRubricSection(cs, isDark),
            const SizedBox(height: 14),

            // ── Example answer (collapsible) ─────────────────────────
            _buildExampleAnswerSection(cs, isDark),
            const SizedBox(height: 14),

            // ── Image references (collapsible) ───────────────────────
            _buildImagesSection(cs, isDark),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Rubric section
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRubricSection(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
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

        // Rubric error
        if (_rubricError != null) ...[
          _ErrorBanner(message: _rubricError!, cs: cs, isDark: isDark),
          const SizedBox(height: 8),
        ],

        // Rows
        for (int i = 0; i < _rubric.length; i++) ...[
          if (i > 0) AppTheme.tableRowDivider(isDark, cs),
          _buildRubricRow(i, cs, isDark),
        ],

        // Add criterion button
        const SizedBox(height: 6),
        _AddRowButton(
          label: 'Add criterion',
          onTap: _addRubricRow,
          cs: cs,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildRubricRow(int index, ColorScheme cs, bool isDark) {
    final entry = _rubric[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Criterion text
          Expanded(
            child: TextField(
              controller: entry.criterionCtrl,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: _compactDecoration(
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: _compactDecoration(
                hint: 'Marks',
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Remove button (28×28)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _TinyIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove',
              onTap: () => _removeRubricRow(index),
              color: cs.error.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Example answer section (collapsible)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildExampleAnswerSection(ColorScheme cs, bool isDark) {
    if (!_showExampleAnswer) {
      return _ExpandLink(
        icon: Icons.add_rounded,
        label: 'Add example answer',
        onTap: () => setState(() => _showExampleAnswer = true),
        cs: cs,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with collapse button
        Row(
          children: [
            Text(
              'EXAMPLE ANSWER',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(optional)',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.40),
              ),
            ),
            const Spacer(),
            _TinyIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Remove example answer',
              onTap: () {
                _exampleAnswerCtrl.clear();
                setState(() => _showExampleAnswer = false);
              },
              color: cs.onSurfaceVariant.withValues(alpha: 0.50),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _exampleAnswerCtrl,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          maxLines: null,
          minLines: 2,
          decoration: _fieldDecoration(
            hint: 'Enter the example answer...',
            cs: cs,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Image references section (collapsible)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildImagesSection(ColorScheme cs, bool isDark) {
    if (!_showImages) {
      return _ExpandLink(
        icon: Icons.image_outlined,
        label: 'Add image references',
        onTap: () => setState(() => _showImages = true),
        cs: cs,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with collapse button
        Row(
          children: [
            Text(
              'IMAGE REFERENCES',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const Spacer(),
            _TinyIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close images section',
              onTap: () {
                for (final img in _images) {
                  img.dispose();
                }
                setState(() {
                  _images.clear();
                  _showImages = false;
                });
              },
              color: cs.onSurfaceVariant.withValues(alpha: 0.50),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Image rows
        for (int i = 0; i < _images.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 4),
            AppTheme.tableRowDivider(isDark, cs),
            const SizedBox(height: 4),
          ],
          _buildImageRow(i, cs, isDark),
        ],

        // Add image button
        const SizedBox(height: 6),
        _AddRowButton(
          label: 'Add image',
          onTap: _addImageRow,
          cs: cs,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildImageRow(int index, ColorScheme cs, bool isDark) {
    final entry = _images[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Context dropdown + remove button
          Row(
            children: [
              // Context dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2A3A)
                      : cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: isDark
                      ? Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                          width: 0.5,
                        )
                      : null,
                ),
                child: DropdownButton<ImageContext>(
                  value: entry.context,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                  dropdownColor: AppTheme.overlayBg(isDark, cs),
                  items: ImageContext.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(_imageContextLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => entry.context = v);
                  },
                ),
              ),
              const Spacer(),
              _TinyIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remove image',
                onTap: () => _removeImageRow(index),
                color: cs.error.withValues(alpha: 0.60),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Filename
          TextField(
            controller: entry.filenameCtrl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: _compactDecoration(
              hint: 'Filename',
              cs: cs,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 6),
          // Caption (optional)
          TextField(
            controller: entry.captionCtrl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: _compactDecoration(
              hint: 'Caption (optional)',
              cs: cs,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 6),
          // Description
          TextField(
            controller: entry.descriptionCtrl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            maxLines: null,
            minLines: 2,
            decoration: _compactDecoration(
              hint: 'Description',
              cs: cs,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared decoration helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Compact input decoration for inline fields (rubric rows, image fields).
  InputDecoration _compactDecoration({
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

  /// Standard field decoration (matches EduFormField styling) for standalone
  /// TextFields that don't use EduFormField (e.g. example answer where the
  /// section header is managed externally).
  InputDecoration _fieldDecoration({
    required String hint,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: isDark
            ? BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: isDark
            ? BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _imageContextLabel(ImageContext ctx) => switch (ctx) {
    ImageContext.question => 'Question',
    ImageContext.rubric => 'Rubric',
    ImageContext.exampleAnswer => 'Example Answer',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data holders
// ─────────────────────────────────────────────────────────────────────────────

class _RubricEntry {
  final criterionCtrl = TextEditingController();
  final marksCtrl = TextEditingController();
}

class _ImageEntry {
  final filenameCtrl = TextEditingController();
  final captionCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  ImageContext context = ImageContext.question;

  void dispose() {
    filenameCtrl.dispose();
    captionCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared private widgets (local to this file)
// ─────────────────────────────────────────────────────────────────────────────

/// 28×28 green check icon button — same pattern as subjects_section.dart.
class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.cs,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isPrimary
            ? cs.primary
            : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.4),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              icon,
              size: 15,
              color: isPrimary ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny 28×28 icon button used for row-level actions (delete, close).
class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16, color: color),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: tooltip,
      splashRadius: 14,
    );
  }
}

/// Error banner — same pattern as subjects_section.dart `_ErrorBanner`.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.error.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: cs.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.error.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed-border-style "Add X" button used for rubric + image rows.
class _AddRowButton extends StatefulWidget {
  const _AddRowButton({
    required this.label,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_AddRowButton> createState() => _AddRowButtonState();
}

class _AddRowButtonState extends State<_AddRowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.primary.withValues(alpha: 0.04)
                : Colors.transparent,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.30),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 14,
                color: cs.primary.withValues(alpha: 0.60),
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.primary.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline link to expand a collapsed section ("Add example answer", etc.).
class _ExpandLink extends StatelessWidget {
  const _ExpandLink({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: cs.primary.withValues(alpha: 0.60)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.primary.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
