import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';

import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Create Assessment Page
//
// Single-page form that:
//   1. Collects assessment name, topic, total marks, and date.
//   2. Calls PaperService.createPaper (eventId = '', type = 0).
//   3. Calls PaperService.generateAssessment with the returned paperId.
//   4. On success: navigates to StudentPapersListPage (TODO Task F1).
// ─────────────────────────────────────────────────────────────────────────────

class CreateAssessmentPage extends StatefulWidget {
  const CreateAssessmentPage({
    super.key,
    required this.schoolId,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    this.stream,
  });

  final String schoolId;
  final int subjectId;
  final String subjectName;
  final int grade;
  final int? stream;

  @override
  State<CreateAssessmentPage> createState() => _CreateAssessmentPageState();
}

class _CreateAssessmentPageState extends State<CreateAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '40');

  int? _selectedTopicId;
  DateTime? _selectedDate;

  List<({int id, String name})> _topics = [];
  bool _topicsLoading = true;
  bool _submitting = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadTopics() async {
    try {
      final rows = await catalogDao
          .watchTopicsBySubjectAndGrade(
            subjectId: widget.subjectId,
            grade: widget.grade,
          )
          .first;
      if (!mounted) return;
      setState(() {
        _topics = rows.map((t) => (id: t.id, name: t.name)).toList();
        _topicsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _topicsLoading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDate == null) {
      _showSnackBar('Please select an assessment date.');
      return;
    }

    setState(() => _submitting = true);

    // ── Step 1: Create paper ────────────────────────────────────────────────
    final createResult = await paperService.createPaper(
      school: widget.schoolId,
      eventId: '',
      subject: widget.subjectId,
      grade: widget.grade,
      stream: widget.stream ?? 0,
      type: 0,
      name: _nameCtrl.text.trim(),
      totalMarks: int.parse(_marksCtrl.text.trim()),
      durationMinutes: 60,
      date: _selectedDate!,
      topicWeights: const [],
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (createResult) {
      case Err(:final error):
        _showSnackBar(
          'Failed to create paper: ${error.message ?? error.toString()}',
        );
        setState(() => _submitting = false);
        return;

      case Ok(:final value):
        final paperId = value;

        // ── Step 2: Trigger assessment generation ───────────────────────────
        final genResult = await paperService.generateAssessment(
          paperId: paperId,
          accessToken: accessToken,
        );

        if (!mounted) return;

        switch (genResult) {
          case Err(:final error):
            _showSnackBar(
              'Generation failed: ${error.message ?? error.toString()}',
            );
            setState(() => _submitting = false);

          case Ok(:final value):
            setState(() => _submitting = false);
            if (value) {
              // TODO(Task F1): Replace stub with:
              //   Navigator.push(context, MaterialPageRoute(
              //     builder: (_) => StudentPapersListPage(
              //       paperId: paperId,
              //       paperName: _nameCtrl.text.trim(),
              //     ),
              //   ));
              _showSnackBar('Papers are being generated…');
              if (mounted) Navigator.pop(context);
            } else {
              _showSnackBar('Server rejected the generation request.');
            }
        }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 13))),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0E13)
          : cs.surfaceContainerLowest,
      appBar: _buildAppBar(cs, isDark),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _buildFormCard(cs, isDark),
            const SizedBox(height: 24),
            _SubmitButton(
              submitting: _submitting,
              onTap: _submitting ? null : _submit,
              cs: cs,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF121A24) : cs.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 48,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, size: 24),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create Assessment',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          Text(
            widget.subjectName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: AppTheme.borderColor(isDark, cs),
        ),
      ),
    );
  }

  Widget _buildFormCard(ColorScheme cs, bool isDark) {
    return _Card(
      cs: cs,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name ──────────────────────────────────────────────────────────
          _FieldLabel(label: 'Assessment Name', cs: cs),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: _fieldDeco(
              hint: 'e.g. Form 2A Chemistry CAT 1',
              cs: cs,
              isDark: isDark,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Assessment name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // ── Topic ─────────────────────────────────────────────────────────
          _FieldLabel(label: 'Topic', cs: cs),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _selectedTopicId,
            decoration: _fieldDeco(
              hint: _topicsLoading
                  ? 'Loading topics…'
                  : _topics.isEmpty
                  ? 'No topics available'
                  : 'Select a topic',
              cs: cs,
              isDark: isDark,
            ),
            dropdownColor: isDark ? const Color(0xFF1A2435) : cs.surface,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            items: _topics
                .map(
                  (t) => DropdownMenuItem<int>(
                    value: t.id,
                    child: Text(
                      t.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: _topicsLoading || _topics.isEmpty
                ? null
                : (v) => setState(() => _selectedTopicId = v),
            validator: (v) {
              if (v == null) return 'Please select a topic';
              return null;
            },
          ),

          const SizedBox(height: 16),

          // ── Total marks ───────────────────────────────────────────────────
          _FieldLabel(label: 'Total Marks', cs: cs),
          const SizedBox(height: 6),
          TextFormField(
            controller: _marksCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: _fieldDeco(hint: 'e.g. 40', cs: cs, isDark: isDark),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Total marks is required';
              }
              final n = int.tryParse(v.trim());
              if (n == null || n <= 0) {
                return 'Enter a positive integer';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // ── Date ──────────────────────────────────────────────────────────
          _FieldLabel(label: 'Assessment Date', cs: cs),
          const SizedBox(height: 6),
          _DateTile(
            selectedDate: _selectedDate,
            cs: cs,
            isDark: isDark,
            onTap: _pickDate,
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco({
    required String hint,
    required ColorScheme cs,
    required bool isDark,
  }) {
    final fillColor = isDark
        ? const Color(0xFF1A2435)
        : cs.surfaceContainerHighest;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      borderSide: BorderSide(color: AppTheme.borderColor(isDark, cs)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: fillColor,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date tile — tappable row that opens a date picker
// ─────────────────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.selectedDate,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final DateTime? selectedDate;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  String get _label {
    if (selectedDate == null) return 'Tap to select a date';
    final d = selectedDate!;
    final months = [
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    final fillColor = isDark
        ? const Color(0xFF1A2435)
        : cs.surfaceContainerHighest;
    final borderColor = AppTheme.borderColor(isDark, cs);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: hasDate
                  ? cs.primary.withValues(alpha: 0.85)
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasDate ? FontWeight.w400 : FontWeight.w300,
                color: hasDate
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit button with animated press + loading state
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({
    required this.submitting,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final bool submitting;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.reverse();
  void _onTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _onTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final disabled = widget.onTap == null;

    return GestureDetector(
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: disabled ? cs.primary.withValues(alpha: 0.4) : cs.primary,
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          ),
          alignment: Alignment.center,
          child: widget.submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      cs.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: cs.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generate Papers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onPrimary,
                        letterSpacing: 0.2,
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
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.cs, required this.isDark, required this.child});

  final ColorScheme cs;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121A24) : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
        letterSpacing: 0.2,
      ),
    );
  }
}
