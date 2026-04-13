import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../client.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../services/import_file_parser.dart';
import '../../../../services/question_bank.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MultiFileImportSheet — pick multiple JSON files, validate, import
// sequentially with image upload, and show per-file results.
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet / dialog for bulk-importing questions from multiple JSON files
/// at the subject level. Each file contains a topic's worth of questions with
/// optional image references.
///
/// Launched via [showEduSheet]. Self-contained per BUG-010 convention —
/// provides its own [EduSheet] wrapper (background, handle, title, keyboard
/// padding).
class MultiFileImportSheet extends StatefulWidget {
  const MultiFileImportSheet({
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
  /// refresh its question list / topic counts.
  final VoidCallback? onImported;

  @override
  State<MultiFileImportSheet> createState() => _MultiFileImportSheetState();
}

class _MultiFileImportSheetState extends State<MultiFileImportSheet> {
  // ── File selection ─────────────────────────────────────────────────────
  bool _pickingFiles = false;
  List<ParsedImportFile> _parsedFiles = [];

  // ── Import execution ───────────────────────────────────────────────────
  bool _importing = false;
  int _currentFileIndex = -1; // -1 = not started
  String _currentPhase = ''; // "importing" | "uploading"
  String _currentDetail = ''; // Human-readable progress detail
  double _currentProgress = 0.0; // 0.0–1.0 within current file

  // ── Results ────────────────────────────────────────────────────────────
  List<FileImportResult> _results = [];
  bool _completed = false;
  String? _fatalError; // non-recoverable error (e.g. auth)

  String get _curriculumLabel =>
      widget.curriculum == CurriculumType.eightFourFour ? '8-4-4' : 'CBC';

  int get _validCount => _parsedFiles.where((f) => f.isValid).length;
  int get _invalidCount => _parsedFiles.where((f) => !f.isValid).length;
  int get _totalImages => _parsedFiles.fold(0, (s, f) => s + f.totalImageRefs);
  int get _totalMissing =>
      _parsedFiles.fold(0, (s, f) => s + f.missingImages.length);

  // ── File picker ────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    setState(() => _pickingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.isNotEmpty) {
        final parsed = <ParsedImportFile>[];
        for (final pf in result.files) {
          if (pf.path == null) continue;
          final file = File(pf.path!);
          final content = await file.readAsString();
          parsed.add(parseImportFile(pf.path!, content));
        }
        // Sort by topic name for readability.
        parsed.sort((a, b) => a.topic.compareTo(b.topic));
        setState(() {
          _parsedFiles = parsed;
          _results = [];
          _completed = false;
          _fatalError = null;
        });
      }
    } catch (_) {
      // Silently ignore picker cancellation.
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  // ── Import execution ───────────────────────────────────────────────────

  Future<void> _importAll() async {
    final validFiles = _parsedFiles.where((f) => f.isValid).toList();
    if (validFiles.isEmpty) return;

    setState(() {
      _importing = true;
      _results = [];
      _completed = false;
      _fatalError = null;
    });

    final qbService = client.questionBank;
    final token = accessToken;

    for (var i = 0; i < validFiles.length; i++) {
      if (!_importing) break; // cancelled

      setState(() {
        _currentFileIndex = i;
        _currentPhase = 'importing';
        _currentDetail = 'Preparing…';
        _currentProgress = 0.0;
      });

      final result = await qbService.importFileWithImages(
        parsed: validFiles[i],
        accessToken: token,
        onProgress: (phase, detail, progress) {
          if (mounted) {
            setState(() {
              _currentPhase = phase;
              _currentDetail = detail;
              _currentProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _results.add(result);
        });
      }
    }

    if (mounted) {
      setState(() {
        _importing = false;
        _completed = true;
        _currentFileIndex = -1;
      });
      // Notify parent to refresh topic counts.
      if (_results.any((r) => r.questionsCreated > 0)) {
        widget.onImported?.call();
      }
    }
  }

  void _cancelImport() {
    setState(() => _importing = false);
  }

  void _clearFiles() {
    setState(() {
      _parsedFiles = [];
      _results = [];
      _completed = false;
      _fatalError = null;
      _currentFileIndex = -1;
    });
  }

  void _done() {
    Navigator.of(context).pop();
  }

  // ── Helpers for mapping parsed files to import status ───────────────────

  /// Returns the status of a parsed file during/after import.
  /// -1 = pending, 0 = in progress, 1 = done, 2 = failed, 3 = skipped (invalid)
  int _fileStatus(int parsedIndex) {
    final file = _parsedFiles[parsedIndex];
    if (!file.isValid) return 3; // invalid — skipped

    if (_completed || (!_importing && _results.isNotEmpty)) {
      // Finished — check results.
      final validIndex = _validIndexOf(parsedIndex);
      if (validIndex < _results.length) {
        return _results[validIndex].isFullSuccess ? 1 : 2;
      }
      return -1; // was cancelled before reaching this file
    }

    if (!_importing) return -1; // not started

    final validIndex = _validIndexOf(parsedIndex);
    if (validIndex < 0) return 3;
    if (validIndex < _currentFileIndex) {
      // Already processed.
      if (validIndex < _results.length) {
        return _results[validIndex].isFullSuccess ? 1 : 2;
      }
      return 1;
    }
    if (validIndex == _currentFileIndex) return 0; // in progress
    return -1; // pending
  }

  /// Maps a parsedFiles index to its position within the valid-only sublist.
  int _validIndexOf(int parsedIndex) {
    int vi = -1;
    for (var i = 0; i <= parsedIndex; i++) {
      if (_parsedFiles[i].isValid) vi++;
    }
    return vi;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return EduSheet(
      title: 'Bulk Import Questions',
      child: Flexible(
        child: ListView(
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

            if (_completed) ..._buildResultsPhase(cs, isDark),
            if (!_completed) ..._buildSelectionPhase(cs, isDark),
          ],
        ),
      ),
    );
  }

  // ── Phase A / B — file selection + import progress ─────────────────────

  List<Widget> _buildSelectionPhase(ColorScheme cs, bool isDark) {
    return [
      // ── Description ──────────────────────────────────────────────
      if (_parsedFiles.isEmpty && !_importing)
        Text(
          'Select one or more JSON files to import. Each file should '
          'contain a "subject", "curriculum", "grade", "topic", and '
          'a "questions" array. Images referenced in questions will be '
          'verified and uploaded automatically.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),

      if (_parsedFiles.isEmpty && !_importing) const SizedBox(height: 12),

      // ── File picker button ───────────────────────────────────────
      if (!_importing)
        _FilePickerChip(
          onTap: _pickingFiles ? null : _pickFiles,
          cs: cs,
          isDark: isDark,
          loading: _pickingFiles,
        ),

      // ── Import progress header ───────────────────────────────────
      if (_importing && _currentFileIndex >= 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'File ${_currentFileIndex + 1} of $_validCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
        ),

      if (_parsedFiles.isNotEmpty) const SizedBox(height: 12),

      // ── File list ────────────────────────────────────────────────
      if (_parsedFiles.isNotEmpty) ...[
        Container(
          decoration: BoxDecoration(
            color: AppTheme.nestedBg(isDark, cs),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            border: Border.all(
              color: AppTheme.borderColor(isDark, cs),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _parsedFiles.length; i++) ...[
                  if (i > 0) AppTheme.tableRowDivider(isDark, cs),
                  _FileValidationTile(
                    parsed: _parsedFiles[i],
                    status: _fileStatus(i),
                    currentPhase: _currentPhase,
                    currentDetail: _currentDetail,
                    currentProgress: _currentProgress,
                    cs: cs,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],

      // ── Summary row ──────────────────────────────────────────────
      if (_parsedFiles.isNotEmpty && !_importing)
        _SummaryRow(
          validCount: _validCount,
          invalidCount: _invalidCount,
          totalImages: _totalImages,
          missingImages: _totalMissing,
          cs: cs,
          isDark: isDark,
        ),

      if (_parsedFiles.isNotEmpty) const SizedBox(height: 12),

      // ── Fatal error ──────────────────────────────────────────────
      if (_fatalError != null) ...[
        _ErrorBanner(message: _fatalError!, cs: cs, isDark: isDark),
        const SizedBox(height: 8),
      ],

      // ── Action buttons ───────────────────────────────────────────
      if (_parsedFiles.isNotEmpty)
        Row(
          children: [
            if (!_importing) ...[
              _ActionChip(
                label: 'Import All',
                icon: Icons.upload_rounded,
                onTap: _validCount > 0 ? _importAll : null,
                cs: cs,
                isDark: isDark,
                isPrimary: true,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                label: 'Clear',
                icon: Icons.clear_rounded,
                onTap: _clearFiles,
                cs: cs,
                isDark: isDark,
              ),
            ],
            if (_importing)
              _ActionChip(
                label: 'Cancel',
                icon: Icons.stop_rounded,
                onTap: _cancelImport,
                cs: cs,
                isDark: isDark,
              ),
          ],
        ),
    ];
  }

  // ── Phase C — results ──────────────────────────────────────────────────

  List<Widget> _buildResultsPhase(ColorScheme cs, bool isDark) {
    final totalCreated = _results.fold(0, (s, r) => s + r.questionsCreated);
    final totalImagesUploaded = _results.fold(
      0,
      (s, r) => s + r.imagesUploaded,
    );
    final totalErrors = _results.fold(
      0,
      (s, r) => s + r.questionsErrored + r.imagesFailed,
    );
    final hasErrors = totalErrors > 0;

    final successColor = AppTheme.statusActive;

    return [
      // ── Header ───────────────────────────────────────────────────
      Row(
        children: [
          Icon(
            hasErrors
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            size: 16,
            color: hasErrors ? Colors.amber.shade700 : successColor,
          ),
          const SizedBox(width: 8),
          Text(
            hasErrors ? 'Import Complete with Errors' : 'Import Complete',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // ── Aggregate stats ──────────────────────────────────────────
      Text(
        _buildAggregateStats(totalCreated, totalImagesUploaded, totalErrors),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      const SizedBox(height: 12),

      // ── Per-file results ─────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _results.length; i++) ...[
                if (i > 0) AppTheme.tableRowDivider(isDark, cs),
                _FileResultTile(result: _results[i], cs: cs, isDark: isDark),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // ── Done button ──────────────────────────────────────────────
      _ActionChip(
        label: 'Done',
        icon: Icons.check_rounded,
        onTap: _done,
        cs: cs,
        isDark: isDark,
        isPrimary: true,
      ),
    ];
  }

  String _buildAggregateStats(int created, int images, int errors) {
    final parts = <String>[];
    parts.add('$created question${created == 1 ? '' : 's'} created');
    if (images > 0) {
      parts.add('$images image${images == 1 ? '' : 's'} uploaded');
    }
    if (errors > 0) {
      parts.add('$errors error${errors == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilePickerChip — "Select JSON files" button
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
                  Icon(Icons.folder_open_outlined, size: 14, color: fgColor),
                const SizedBox(width: 6),
                Text(
                  'Select JSON files',
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
// _ActionChip — compact action button with loading state
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
// _FileValidationTile — shows one parsed file with status indicators
// ─────────────────────────────────────────────────────────────────────────────

class _FileValidationTile extends StatelessWidget {
  const _FileValidationTile({
    required this.parsed,
    required this.status,
    required this.currentPhase,
    required this.currentDetail,
    required this.currentProgress,
    required this.cs,
    required this.isDark,
  });

  final ParsedImportFile parsed;

  /// -1=pending, 0=in progress, 1=done, 2=failed, 3=skipped (invalid)
  final int status;
  final String currentPhase;
  final String currentDetail;
  final double currentProgress;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final successColor = AppTheme.statusActive;
    final errorColor = cs.error;
    final amberColor = Colors.amber.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: status icon + filename + question count badge ──
          Row(
            children: [
              _statusIcon(successColor, errorColor, amberColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parsed.fileName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _QuestionCountBadge(
                count: parsed.questionCount,
                cs: cs,
                isDark: isDark,
              ),
            ],
          ),

          // ── Row 2: topic name ────────────────────────────────────
          if (parsed.topic.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                parsed.topic,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ── Row 3: image status ──────────────────────────────────
          if (parsed.hasImages)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                parsed.hasMissingImages
                    ? '${parsed.totalImageRefs} images (${parsed.missingImages.length} missing)'
                    : '${parsed.totalImageRefs} images (all found)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: parsed.hasMissingImages ? amberColor : successColor,
                ),
              ),
            ),

          // ── Validation errors ────────────────────────────────────
          if (parsed.validationErrors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final err in parsed.validationErrors.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $err',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: errorColor.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (parsed.validationErrors.length > 3)
                    Text(
                      '…and ${parsed.validationErrors.length - 3} more',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: errorColor.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),

          // ── Progress indicator (in-progress status) ──────────────
          if (status == 0) ...[
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Text(
                currentDetail,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: cs.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4, right: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: currentProgress,
                  minHeight: 3,
                  backgroundColor: cs.primary.withValues(
                    alpha: isDark ? 0.1 : 0.08,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    cs.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon(Color success, Color error, Color amber) {
    switch (status) {
      case 0: // in progress
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.primary),
        );
      case 1: // done
        return Icon(Icons.check_circle_rounded, size: 14, color: success);
      case 2: // failed
        return Icon(Icons.error_outline_rounded, size: 14, color: error);
      case 3: // skipped (invalid)
        return Icon(
          Icons.cancel_outlined,
          size: 14,
          color: error.withValues(alpha: 0.6),
        );
      default: // pending
        return Icon(
          Icons.radio_button_unchecked_rounded,
          size: 14,
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuestionCountBadge — small pill with question count
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCountBadge extends StatelessWidget {
  const _QuestionCountBadge({
    required this.count,
    required this.cs,
    required this.isDark,
  });

  final int count;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        '$count Q',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.primary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SummaryRow — aggregate file/image counts
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.validCount,
    required this.invalidCount,
    required this.totalImages,
    required this.missingImages,
    required this.cs,
    required this.isDark,
  });

  final int validCount;
  final int invalidCount;
  final int totalImages;
  final int missingImages;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    parts.add('$validCount valid file${validCount == 1 ? '' : 's'}');
    if (invalidCount > 0) {
      parts.add('$invalidCount invalid');
    }
    if (totalImages > 0) {
      final imgStr = '$totalImages image${totalImages == 1 ? '' : 's'}';
      if (missingImages > 0) {
        parts.add('$imgStr ($missingImages missing)');
      } else {
        parts.add(imgStr);
      }
    }

    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FileResultTile — expandable per-file import result
// ─────────────────────────────────────────────────────────────────────────────

class _FileResultTile extends StatefulWidget {
  const _FileResultTile({
    required this.result,
    required this.cs,
    required this.isDark,
  });

  final FileImportResult result;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_FileResultTile> createState() => _FileResultTileState();
}

class _FileResultTileState extends State<_FileResultTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final cs = widget.cs;
    final successColor = AppTheme.statusActive;
    final hasErrors = r.questionsErrored > 0 || r.imagesFailed > 0;
    final statusColor = hasErrors ? Colors.amber.shade700 : successColor;

    return InkWell(
      onTap: r.errors.isNotEmpty
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: icon + filename + expand arrow ──────────────
            Row(
              children: [
                Icon(
                  hasErrors
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (r.errors.isNotEmpty)
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),

            // ── Row 2: topic ───────────────────────────────────────
            if (r.topic.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 22, top: 2),
                child: Text(
                  r.topic,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Row 3: stats summary ───────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                _resultSummary(r),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: statusColor,
                ),
              ),
            ),

            // ── Expanded error list ────────────────────────────────
            if (_expanded && r.errors.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final err in r.errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '•  ',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.error.withValues(alpha: 0.6),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                err,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resultSummary(FileImportResult r) {
    final parts = <String>[];
    parts.add('${r.questionsCreated} created');
    if (r.questionsErrored > 0) {
      parts.add(
        '${r.questionsErrored} error${r.questionsErrored == 1 ? '' : 's'}',
      );
    }
    if (r.imagesUploaded > 0) {
      parts.add(
        '${r.imagesUploaded} image${r.imagesUploaded == 1 ? '' : 's'} uploaded',
      );
    }
    if (r.imagesFailed > 0) {
      parts.add('${r.imagesFailed} failed');
    }
    if (r.imagesSkipped > 0) {
      parts.add('${r.imagesSkipped} skipped');
    }
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorBanner — inline error message
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
