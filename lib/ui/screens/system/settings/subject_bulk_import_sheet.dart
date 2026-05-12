import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../client.dart';
import '../../../../models/question.dart';
import '../../../../models/result.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubjectBulkImportSheet — upload/paste JSON to bulk-import questions at the
// subject level. The JSON includes topic info so the server can resolve or
// create topics automatically.
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet / dialog for bulk-importing questions from a JSON file or
/// pasted JSON content at the subject level.
///
/// Launched via [showEduSheet]. Self-contained per BUG-010 convention —
/// provides its own [EduSheet] wrapper (background, handle, title, keyboard
/// padding).
class SubjectBulkImportSheet extends StatefulWidget {
  const SubjectBulkImportSheet({
    super.key,
    required this.subjectName,
    required this.subjectId,
    required this.curriculum,
    this.onImported,
  });

  final String subjectName;
  final int subjectId;
  final CurriculumType curriculum;

  /// Called after a successful (or partial-success) import so the caller can
  /// refresh its question list.
  final VoidCallback? onImported;

  @override
  State<SubjectBulkImportSheet> createState() => _SubjectBulkImportSheetState();
}

class _SubjectBulkImportSheetState extends State<SubjectBulkImportSheet> {
  final _jsonCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Validation state ─────────────────────────────────────────────────────
  bool _validated = false;
  int _validQuestionCount = 0;
  List<String> _validationErrors = [];

  // ── Import state ─────────────────────────────────────────────────────────
  bool _importing = false;
  BulkImportResult? _importResult;
  String? _importError;

  // ── File picker state ────────────────────────────────────────────────────
  bool _pickingFile = false;

  String get _curriculumLabel =>
      widget.curriculum == CurriculumType.eightFourFour ? '8-4-4' : 'CBC';

  @override
  void dispose() {
    _jsonCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── File picker ──────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        developer.log(
          'Picked system-wide question import file: '
          'path=${result.files.single.path} '
          'subject=${widget.subjectName} '
          'subjectId=${widget.subjectId} '
          'curriculum=${widget.curriculum.name} '
          'school=none',
          name: 'SubjectBulkImportSheet',
        );
        _jsonCtrl.text = content;
        // Reset validation state
        setState(() {
          _validated = false;
          _validQuestionCount = 0;
          _validationErrors = [];
          _importResult = null;
          _importError = null;
        });
      }
    } catch (_) {
      // Silently ignore picker cancellation / platform errors.
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
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

      // ── Subject ──────────────────────────────────────────────────
      final dynamic subject = parsed['subject'];
      if (subject == null || subject is! String || subject.trim().isEmpty) {
        errors.add('Missing or empty "subject" field.');
      }

      // ── Curriculum ───────────────────────────────────────────────
      final dynamic curriculum = parsed['curriculum'];
      if (curriculum == null || curriculum is! String) {
        errors.add('Missing "curriculum" field (expected "844" or "cbc").');
      } else if (curriculum != '844' && curriculum != 'cbc') {
        errors.add('"curriculum" must be "844" or "cbc".');
      }

      // ── Grade ────────────────────────────────────────────────────
      final dynamic grade = parsed['grade'];
      if (grade == null) {
        errors.add('Missing "grade" field.');
      } else if (grade is int) {
        if (grade <= 0) errors.add('"grade" must be a positive integer.');
      } else if (grade is double) {
        if (grade.toInt() <= 0) {
          errors.add('"grade" must be a positive integer.');
        }
      } else {
        errors.add('"grade" must be an integer.');
      }

      // ── Topic ────────────────────────────────────────────────────
      final dynamic topic = parsed['topic'];
      if (topic == null || topic is! String || topic.trim().isEmpty) {
        errors.add('Missing or empty "topic" field.');
      }

      // ── Questions array ──────────────────────────────────────────
      final dynamic questions = parsed['questions'];
      if (questions == null || questions is! List || questions.isEmpty) {
        errors.add('"questions" array is missing or empty.');
        setState(() {
          _validated = false;
          _validQuestionCount = 0;
          _validationErrors = errors;
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

        // body (was "text" — backward compat: try "body" first, fall back to "text")
        final rawBody = q['body'] ?? q['text'];
        if (rawBody == null || rawBody is! String || rawBody.trim().isEmpty) {
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

        // example_answer — optional, no validation needed (can be null/missing)

        // images — optional, can be null/missing/empty
        final dynamic images = q['images'];
        if (images != null && images is! List) {
          errors.add('$prefix: "images" must be an array if provided.');
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
    });
  }

  // ── Import ───────────────────────────────────────────────────────────────

  Future<void> _import() async {
    if (!_validated) return;

    final jsonContent = _jsonCtrl.text.trim();
    final diagnosticLabel =
        'subject="${widget.subjectName}" '
        'subjectId=${widget.subjectId} '
        'curriculum=${widget.curriculum.name}';

    developer.log(
      'Starting system-wide question import: '
      '$diagnosticLabel school=none jsonLength=${jsonContent.length}',
      name: 'SubjectBulkImportSheet',
    );

    setState(() {
      _importing = true;
      _importError = null;
      _importResult = null;
    });

    final result = await questionBankService.bulkImport(
      jsonContent: jsonContent,
      accessToken: accessToken,
      diagnosticLabel: diagnosticLabel,
    );

    if (!mounted) return;

    switch (result) {
      case Ok<BulkImportResult, GrpcError>(:final value):
        developer.log(
          'System-wide question import completed: '
          '$diagnosticLabel school=none '
          'created=${value.createdCount} errors=${value.errors.length}',
          name: 'SubjectBulkImportSheet',
        );
        setState(() {
          _importing = false;
          _importResult = value;
        });
        if (value.createdCount > 0) {
          widget.onImported?.call();
        }
      case Err<BulkImportResult, GrpcError>(:final error):
        final exactMessage = (error.message != null && error.message!.trim().isNotEmpty)
            ? error.message!.trim()
            : 'gRPC error ${error.code}';
        developer.log(
          'System-wide question import failed: '
          '$diagnosticLabel school=none '
          'grpcCode=${error.code} grpcMessage=$exactMessage',
          name: 'SubjectBulkImportSheet',
          error: error,
          stackTrace: StackTrace.current,
        );
        setState(() {
          _importing = false;
          _importError = 'Import failed: $exactMessage';
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
      title: 'Bulk Import',
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
              '${widget.subjectName} · $_curriculumLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),

            // ── Description ──────────────────────────────────────────
            Text(
              'Paste or upload a JSON object containing "subject", '
              '"curriculum", "grade", "topic", and a "questions" array. '
              'The server will resolve or create the topic automatically.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),

            // ── File picker button ───────────────────────────────────
            _FilePickerChip(
              onTap: _pickingFile ? null : _pickFile,
              cs: cs,
              isDark: isDark,
              loading: _pickingFile,
            ),
            const SizedBox(height: 8),

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
// File picker chip — "Load from file" button
// ─────────────────────────────────────────────────────────────────────────────

class _FilePickerChip extends StatelessWidget {
  const _FilePickerChip({
    required this.onTap,
    required this.cs,
    required this.isDark,
    this.loading = false,
  });

  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool isDark;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final fgColor = enabled
        ? cs.onSurfaceVariant
        : cs.onSurfaceVariant.withValues(alpha: 0.35);
    final borderCol = AppTheme.borderColor(isDark, cs);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
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
                  Icon(Icons.upload_file_rounded, size: 14, color: fgColor),
                const SizedBox(width: 6),
                Text(
                  'Load from file',
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
              '  "subject": "Biology",\n'
              '  "curriculum": "844",\n'
              '  "grade": 4,\n'
              '  "topic": "Introduction to Biology",\n'
              '  "questions": [\n'
              '    {\n'
              '      "text": "Question text...",\n'
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
    required this.cs,
    required this.isDark,
  });

  final bool validated;
  final int questionCount;
  final List<String> errors;
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
