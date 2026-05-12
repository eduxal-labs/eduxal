import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';

import '../../../../client.dart';
import '../../../../models/question.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/stimulus_block.dart';
import '../../../widgets/tiptap_renderer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BulkImportSheet — paste JSON to bulk-import questions into a topic
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet / dialog for bulk-importing questions from pasted JSON content.
///
/// Launched via [showEduSheet]. Self-contained per BUG-010 convention —
/// provides its own [EduSheet] wrapper (background, handle, title, keyboard
/// padding).
class BulkImportSheet extends StatefulWidget {
  const BulkImportSheet({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.subjectName,
    required this.curriculum,
    required this.grade,
    this.onImported,
  });

  final int topicId;
  final String topicName;
  final String subjectName;
  final int curriculum;
  final int grade;

  /// Called after a successful (or partial-success) import so the caller can
  /// refresh its question list.
  final VoidCallback? onImported;

  @override
  State<BulkImportSheet> createState() => _BulkImportSheetState();
}

class _BulkImportSheetState extends State<BulkImportSheet> {
  final _jsonCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Validation state ─────────────────────────────────────────────────────
  bool _validated = false;
  int _validQuestionCount = 0;
  List<String> _validationErrors = [];
  List<Map<String, dynamic>> _parsedQuestions = [];

  // ── Import state ─────────────────────────────────────────────────────────
  bool _importing = false;
  BulkImportResult? _importResult;
  String? _importError;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────

  void _validate() {
    final text = _jsonCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _validated = false;
        _validQuestionCount = 0;
        _validationErrors = ['JSON content is empty.'];
      });
      return;
    }

    // Reset import state when re-validating.
    _importResult = null;
    _importError = null;

    final errors = <String>[];
    int count = 0;
    final parsedQs = <Map<String, dynamic>>[];

    try {
      final dynamic parsed = jsonDecode(text);
      if (parsed is! Map<String, dynamic>) {
        setState(() {
          _validated = false;
          _validQuestionCount = 0;
          _validationErrors = ['Root must be a JSON object.'];
        });
        return;
      }

      final dynamic questions = parsed['questions'];
      if (questions == null || questions is! List || questions.isEmpty) {
        setState(() {
          _validated = false;
          _validQuestionCount = 0;
          _validationErrors = ['"questions" array is missing or empty.'];
        });
        return;
      }

      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final prefix = 'Question ${i + 1}';

        if (q is! Map<String, dynamic>) {
          errors.add('$prefix: not a JSON object.');
          continue;
        }
        parsedQs.add(q);

        // body backward compat (new format: 'body'/'body_format'; old format: 'text')
        final body = q['body'] as String? ?? q['text'] as String? ?? '';
        // ignore: unused_local_variable
        final bodyFormat = q['body_format'] as String? ?? 'plain';

        // example_answer backward compat
        final rawEa = q['example_answer'];
        // ignore: unused_local_variable
        final exampleAnswerContent = rawEa is String
            ? rawEa
            : (rawEa as Map?)?['content'] as String? ?? '';

        // New fields (optional — do not reject if absent)
        final parts = (q['parts'] as List?)?.cast<Map<String, dynamic>>();
        // ignore: unused_local_variable
        final stimulus = q['stimulus'] as Map<String, dynamic>?;
        // ignore: unused_local_variable
        final qType = q['type'] as String? ?? 'definition';
        // ignore: unused_local_variable
        final difficulty = q['difficulty'] as int? ?? 3;

        if (body.trim().isEmpty) {
          errors.add('$prefix: missing or empty "body" (or "text").');
        }

        // marks
        final dynamic rawMarks = q['marks'];
        int? marks;
        if (rawMarks == null) {
          errors.add('$prefix: missing "marks".');
        } else if (rawMarks is int) {
          marks = rawMarks;
          if (marks <= 0) errors.add('$prefix: "marks" must be > 0.');
        } else if (rawMarks is double) {
          marks = rawMarks.toInt();
          if (marks <= 0) errors.add('$prefix: "marks" must be > 0.');
        } else {
          errors.add('$prefix: "marks" must be a number.');
        }

        // rubric
        final dynamic rubric = q['rubric'];
        if (rubric == null || rubric is! List || rubric.isEmpty) {
          errors.add('$prefix: missing or empty "rubric" array.');
        } else {
          int rubricSum = 0;
          for (var j = 0; j < rubric.length; j++) {
            final r = rubric[j];
            if (r is! Map<String, dynamic>) {
              errors.add('$prefix, rubric[${j + 1}]: not a JSON object.');
              continue;
            }
            final rawCriterion = r['criterion'] ?? r['criteria'];
            if (rawCriterion == null ||
                rawCriterion is! String ||
                rawCriterion.trim().isEmpty) {
              errors.add('$prefix, rubric[${j + 1}]: missing "criterion" (or "criteria").');
            }
            final dynamic rMarks = r['marks'];
            if (rMarks == null) {
              errors.add('$prefix, rubric[${j + 1}]: missing "marks".');
            } else if (rMarks is int) {
              rubricSum += rMarks;
            } else if (rMarks is double) {
              rubricSum += rMarks.toInt();
            } else {
              errors.add(
                '$prefix, rubric[${j + 1}]: "marks" must be a number.',
              );
            }
          }

          // Rubric marks must cover at least the question marks.
          if (marks != null && rubricSum < marks) {
            errors.add(
              '$prefix: rubric marks sum ($rubricSum) is less than question marks ($marks). Rubric must cover at least the question marks.',
            );
          }
        }

        // max_marks check
        final maxMarks = q['max_marks'] as int?;
        if (maxMarks != null && marks != null && maxMarks > marks) {
          errors.add(
            '$prefix: "max_marks" ($maxMarks) must be ≤ "marks" ($marks).',
          );
        }

        count++;
      }
    } on FormatException catch (e) {
      setState(() {
        _validated = false;
        _validQuestionCount = 0;
        _validationErrors = ['Invalid JSON: ${e.message}'];
      });
      return;
    }

    setState(() {
      _validationErrors = errors;
      _validQuestionCount = count;
      _validated = errors.isEmpty && count > 0;
      _parsedQuestions = errors.isEmpty && count > 0 ? parsedQs : [];
    });
  }

  // ── Import ───────────────────────────────────────────────────────────────

  Future<void> _import() async {
    if (!_validated) return;

    setState(() {
      _importing = true;
      _importError = null;
      _importResult = null;
    });

    final result = await questionBankService.bulkImport(
      jsonContent: _jsonCtrl.text.trim(),
      accessToken: accessToken,
      subjectName: widget.subjectName,
      curriculum: widget.curriculum,
      grade: widget.grade,
      topicName: widget.topicName,
    );

    if (!mounted) return;

    switch (result) {
      case Ok<BulkImportResult, GrpcError>(:final value):
        setState(() {
          _importing = false;
          _importResult = value;
        });
        if (value.createdCount > 0) {
          widget.onImported?.call();
        }
      case Err<BulkImportResult, GrpcError>(:final error):
        setState(() {
          _importing = false;
          _importError = error.message ?? 'Import failed (${error.code}).';
        });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Self-contained sheet — provides its own EduSheet wrapper (background,
    // handle, title, keyboard padding) per BUG-010 convention.
    return EduSheet(
      title: 'Bulk Import Questions',
      child: ListView(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          shrinkWrap: true,
          children: [
            // ── Subtitle ─────────────────────────────────────────────
            Text(
              '${widget.subjectName} · ${widget.topicName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),

            // ── Description ──────────────────────────────────────────
            Text(
              'Paste a JSON object with a "questions" array. Each question '
              'needs "text", "marks", and a "rubric" array.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),

            // ── JSON text field ──────────────────────────────────────
            _JsonTextField(
              controller: _jsonCtrl,
              cs: cs,
              isDark: isDark,
              onChanged: (_) {
                // Reset validation on edit.
                if (_validated || _validationErrors.isNotEmpty) {
                  setState(() {
                    _validated = false;
                    _validQuestionCount = 0;
                    _validationErrors = [];
                    _importResult = null;
                    _importError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // ── Action buttons row ───────────────────────────────────
            Row(
              children: [
                // Validate button
                _ActionChip(
                  label: 'Validate',
                  icon: Icons.check_circle_outline_rounded,
                  onTap: _jsonCtrl.text.trim().isNotEmpty ? _validate : null,
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                // Import button
                _ActionChip(
                  label: 'Import',
                  icon: Icons.upload_rounded,
                  onTap: _validated && !_importing ? _import : null,
                  cs: cs,
                  isDark: isDark,
                  isPrimary: true,
                  loading: _importing,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Validation results ───────────────────────────────────
            if (_validationErrors.isNotEmpty || _validated)
              _ValidationResults(
                validated: _validated,
                questionCount: _validQuestionCount,
                errors: _validationErrors,
                questions: _parsedQuestions,
                cs: cs,
                isDark: isDark,
              ),

            // ── Import error ─────────────────────────────────────────
            if (_importError != null) ...[
              const SizedBox(height: 8),
              _ErrorBanner(message: _importError!, cs: cs, isDark: isDark),
            ],

            // ── Import results ───────────────────────────────────────
            if (_importResult != null) ...[
              const SizedBox(height: 8),
              _ImportResults(result: _importResult!, cs: cs, isDark: isDark),
            ],
          ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON text field — monospace multiline input
// ─────────────────────────────────────────────────────────────────────────────

class _JsonTextField extends StatelessWidget {
  const _JsonTextField({
    required this.controller,
    required this.cs,
    required this.isDark,
    this.onChanged,
  });

  final TextEditingController controller;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: null,
        minLines: 10,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText:
              '{\n'
              '  "questions": [\n'
              '    {\n'
              '      "text": "State the meaning of ...",\n'
              '      "marks": 3,\n'
              '      "rubric": [\n'
              '        { "criterion": "...", "marks": 1 }\n'
              '      ]\n'
              '    }\n'
              '  ]\n'
              '}',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            height: 1.5,
          ),
          contentPadding: const EdgeInsets.all(12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action chip — Validate / Import button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.cs,
    required this.isDark,
    this.isPrimary = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool isDark;
  final bool isPrimary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final bgColor = isPrimary && enabled
        ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.1)
        : Colors.transparent;
    final fgColor = enabled
        ? (isPrimary ? cs.primary : cs.onSurfaceVariant)
        : cs.onSurfaceVariant.withValues(alpha: 0.35);
    final borderCol = isPrimary && enabled
        ? cs.primary.withValues(alpha: 0.3)
        : AppTheme.borderColor(isDark, cs);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            border: Border.all(color: borderCol, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: fgColor,
                  ),
                )
              else
                Icon(icon, size: 14, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fgColor,
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
// Validation results display
// ─────────────────────────────────────────────────────────────────────────────

class _ValidationResults extends StatelessWidget {
  const _ValidationResults({
    required this.validated,
    required this.questionCount,
    required this.errors,
    required this.questions,
    required this.cs,
    required this.isDark,
  });

  final bool validated;
  final int questionCount;
  final List<String> errors;
  final List<Map<String, dynamic>> questions;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final successColor = AppTheme.statusActive;
    final errorColor = cs.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: validated
              ? successColor.withValues(alpha: 0.3)
              : errorColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (validated)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: successColor),
                const SizedBox(width: 6),
                Text(
                  '$questionCount question${questionCount == 1 ? '' : 's'} found, all valid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: successColor,
                  ),
                ),
              ],
            ),
          if (errors.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: errorColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  '${errors.length} validation error${errors.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: errorColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: TextStyle(
                        fontSize: 11,
                        color: errorColor.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // ── Preview ──────────────────────────────────────────────────────
          if (validated && questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 10),
            Text(
              'Preview',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...questions.asMap().entries.map(
              (entry) => _QuestionPreviewCard(
                index: entry.key,
                q: entry.value,
                cs: cs,
                isDark: isDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question preview card — rich rendering for validated questions
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionPreviewCard extends StatelessWidget {
  const _QuestionPreviewCard({
    required this.index,
    required this.q,
    required this.cs,
    required this.isDark,
  });

  final int index;
  final Map<String, dynamic> q;
  final ColorScheme cs;
  final bool isDark;

  Color _typeColor(String qType) => switch (qType) {
    'definition' => Colors.blue.shade100,
    'calculation' => Colors.orange.shade100,
    'structured' => Colors.purple.shade100,
    'experiment' => Colors.green.shade100,
    'diagram' => Colors.teal.shade100,
    _ => Colors.grey.shade200,
  };

  Color _typeTextColor(String qType) => switch (qType) {
    'definition' => Colors.blue.shade800,
    'calculation' => Colors.orange.shade800,
    'structured' => Colors.purple.shade800,
    'experiment' => Colors.green.shade800,
    'diagram' => Colors.teal.shade800,
    _ => Colors.grey.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final body = q['body'] as String? ?? q['text'] as String? ?? '';
    final bodyFormat = q['body_format'] as String? ?? 'plain';
    final stimulus = q['stimulus'] as Map<String, dynamic>?;
    final qType = q['type'] as String? ?? 'definition';
    final difficulty = (q['difficulty'] as int? ?? 3).clamp(0, 5);
    final marks = q['marks'] as int? ?? 0;
    final parts =
        (q['parts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.overlayBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: type badge + difficulty + marks badge ─────────
          Row(
            children: [
              // Question number
              Text(
                '${index + 1}.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor(qType),
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                ),
                child: Text(
                  qType,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _typeTextColor(qType),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Difficulty stars
              Text(
                List.filled(difficulty, '★').join(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber.shade700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              // Marks badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                ),
                child: Text(
                  '$marks mark${marks == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Stimulus ──────────────────────────────────────────────
          if (stimulus != null) StimulusBlock(stimulus: stimulus),

          // ── Body ──────────────────────────────────────────────────
          renderBody(
            body,
            bodyFormat,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
              height: 1.4,
            ),
          ),

          // ── Parts ─────────────────────────────────────────────────
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...parts.map((part) {
              final label = part['label'] as String? ?? '';
              final partBody = part['body'] as String? ?? '';
              final partBodyFormat = part['body_format'] as String? ?? 'plain';
              final partMarks = part['marks'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 1),
                        child: Text(
                          '($label)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Expanded(
                      child: renderBody(
                        partBody,
                        partBodyFormat,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$partMarks mk',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import results display
// ─────────────────────────────────────────────────────────────────────────────

class _ImportResults extends StatelessWidget {
  const _ImportResults({
    required this.result,
    required this.cs,
    required this.isDark,
  });

  final BulkImportResult result;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasErrors = result.errors.isNotEmpty;
    final successColor = AppTheme.statusActive;
    final created = result.createdCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: hasErrors
              ? cs.error.withValues(alpha: 0.3)
              : successColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Success line ──────────────────────────────────────────
          Row(
            children: [
              Icon(
                hasErrors
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                size: 14,
                color: hasErrors
                    ? cs.error.withValues(alpha: 0.7)
                    : successColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasErrors
                      ? '$created created, ${result.errors.length} error${result.errors.length == 1 ? '' : 's'}:'
                      : '✓ $created question${created == 1 ? '' : 's'} created',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: hasErrors ? cs.onSurface : successColor,
                  ),
                ),
              ),
            ],
          ),

          // ── Error list ───────────────────────────────────────────
          if (hasErrors) ...[
            const SizedBox(height: 8),
            ...result.errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.error.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Question ${e.index + 1}: ${e.message}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner — full-width red error strip
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
