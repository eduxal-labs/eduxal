import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../models/event.dart' show PaperGenerationPhase;
import '../../../../models/paper.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';
import 'paper_preview_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StudentPapersListPage
//
// Shows per-student paper generation status for a finalized exam paper.
// Polls GetStudentPapersStatus every 3 seconds while generation is in
// progress. Once complete or failed, polling stops.
//
// Reached from PaperDetailPage or EventDetailPage after triggering
// finalizeStudentPapers(). Receives a server-side paperId string and a
// human-readable paper name.
// ─────────────────────────────────────────────────────────────────────────────

class StudentPapersListPage extends StatefulWidget {
  const StudentPapersListPage({
    super.key,
    required this.paperId,
    required this.paperName,
  });

  final String paperId;
  final String paperName;

  @override
  State<StudentPapersListPage> createState() => _StudentPapersListPageState();
}

class _StudentPapersListPageState extends State<StudentPapersListPage> {
  StudentPapersStatus? _status;
  bool _loading = true;
  Timer? _pollTimer;

  /// Admission numbers → student rows fetched from the local DB.
  /// Populated after each successful poll so rows show real names.
  Map<String, StudentsData> _studentCache = {};

  Set<String> _selectedStudentIds = {};
  bool _multiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Polling
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    final result = await paperService.getStudentPapersStatus(
      paperId: widget.paperId,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Best-effort: load student names from local DB by adm number.
        // We do NOT have schoolId here, so we query without a school filter.
        // In practice all students on a paper belong to one school, so adm
        // collisions across schools are negligible.
        await _refreshStudentCache(value.students);
        if (!mounted) return;

        setState(() {
          _status = value;
          _loading = false;
        });

        final done =
            value.phase == PaperGenerationPhase.complete ||
            value.phase == PaperGenerationPhase.failed;

        if (done) {
          _pollTimer?.cancel();
          _pollTimer = null;
        } else if (_pollTimer == null) {
          // Start the periodic timer only once, after the first response.
          _pollTimer = Timer.periodic(
            const Duration(seconds: 3),
            (_) => _poll(),
          );
        }

      case Err(:final error):
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load paper status: ${error.message}'),
            ),
          );
        }
    }
  }

  /// Queries the local [Students] table for any student whose [adm] matches
  /// one of the IDs returned by the server. Does not require schoolId — the
  /// adm is used as a proxy key since all students on one paper belong to the
  /// same school and adm numbers are unique within a school.
  Future<void> _refreshStudentCache(List<StudentPaperEntry> entries) async {
    final adms = entries
        .map((e) => int.tryParse(e.studentId))
        .whereType<int>()
        .toList();
    if (adms.isEmpty) return;

    try {
      final rows = await (db.select(
        db.students,
      )..where((t) => t.adm.isIn(adms))).get();

      final cache = <String, StudentsData>{};
      for (final row in rows) {
        cache[row.adm.toString()] = row;
      }

      if (mounted) {
        setState(() => _studentCache = cache);
      }
    } catch (_) {
      // Non-critical — fall back to ID-based display names.
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Print actions
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _printAll() async {
    for (final s in (_status?.students ?? []).where((s) => s.isReady)) {
      if (s.pdfUrl != null) {
        await launchUrl(
          Uri.parse(s.pdfUrl!),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }

  Future<void> _printSelected() async {
    for (final s in (_status?.students ?? []).where(
      (s) => s.isReady && _selectedStudentIds.contains(s.studentId),
    )) {
      if (s.pdfUrl != null) {
        await launchUrl(
          Uri.parse(s.pdfUrl!),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Multi-select
  // ───────────────────────────────────────────────────────────────────────────

  void _enterMultiSelect(String studentId) {
    setState(() {
      _multiSelectMode = true;
      _selectedStudentIds = {studentId};
    });
  }

  void _toggleSelection(String studentId) {
    setState(() {
      final updated = Set<String>.from(_selectedStudentIds);
      if (updated.contains(studentId)) {
        updated.remove(studentId);
        if (updated.isEmpty) _multiSelectMode = false;
      } else {
        updated.add(studentId);
      }
      _selectedStudentIds = updated;
    });
  }

  void _clearMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedStudentIds = {};
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final status = _status;
    final isGenerating =
        status != null && status.phase == PaperGenerationPhase.generating;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _multiSelectMode) _clearMultiSelect();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0E13) : cs.surface,
        appBar: _buildAppBar(cs, isDark),
        body: _buildBody(cs, isDark, status, isGenerating),
      ),
    );
  }

  AppBar _buildAppBar(ColorScheme cs, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF121A24) : cs.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, size: 24),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.paperName,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      actions: [
        if (_multiSelectMode) ...[
          TextButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: Text(
              'Print Selected (${_selectedStudentIds.length})',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            onPressed: _selectedStudentIds.isEmpty ? null : _printSelected,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cancel selection',
            onPressed: _clearMultiSelect,
          ),
        ] else
          TextButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: const Text(
              'Print All',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onPressed: _status == null ? null : _printAll,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(
    ColorScheme cs,
    bool isDark,
    StudentPapersStatus? status,
    bool isGenerating,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (status == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load paper status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _loading = true);
                  _poll();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (status.phase == PaperGenerationPhase.failed &&
        status.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(
                'Generation failed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'One or more student papers could not be generated.\nPlease try again.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (isGenerating) _buildProgressBanner(cs, isDark, status),
        Expanded(
          child: status.students.isEmpty
              ? _buildEmptyState(cs)
              : ListView.builder(
                  itemCount: status.students.length,
                  itemBuilder: (context, index) {
                    final entry = status.students[index];
                    final cachedStudent = _studentCache[entry.studentId];
                    return _StudentPaperRow(
                      key: ValueKey(entry.studentId),
                      entry: entry,
                      cachedStudent: cachedStudent,
                      paperId: widget.paperId,
                      isSelected: _selectedStudentIds.contains(entry.studentId),
                      multiSelectMode: _multiSelectMode,
                      onLongPress: () => _enterMultiSelect(entry.studentId),
                      onTap: _multiSelectMode
                          ? () => _toggleSelection(entry.studentId)
                          : null,
                      onRetry: () {
                        setState(() => _loading = true);
                        _poll();
                      },
                      cs: cs,
                      isDark: isDark,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProgressBanner(
    ColorScheme cs,
    bool isDark,
    StudentPapersStatus status,
  ) {
    final progress = status.total > 0 ? status.generated / status.total : null;

    return Container(
      color: AppTheme.nestedBg(isDark, cs),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  value: progress,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Generating papers… ${status.generated}/${status.total}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: AppTheme.borderColor(
              isDark,
              cs,
            ).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Text(
        'No students enrolled for this paper.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StudentPaperRow
//
// Single row in the student papers list. StatefulWidget so it can own its
// own hover / tap animation state independently of the parent list.
// ─────────────────────────────────────────────────────────────────────────────

class _StudentPaperRow extends StatefulWidget {
  const _StudentPaperRow({
    super.key,
    required this.entry,
    required this.cachedStudent,
    required this.paperId,
    required this.isSelected,
    required this.multiSelectMode,
    required this.cs,
    required this.isDark,
    this.onLongPress,
    this.onTap,
    this.onRetry,
  });

  final StudentPaperEntry entry;

  /// Optional student row from the local DB, used for display name + adm.
  /// Null when the student was not found locally (falls back to ID display).
  final StudentsData? cachedStudent;

  final String paperId;
  final bool isSelected;
  final bool multiSelectMode;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  @override
  State<_StudentPaperRow> createState() => _StudentPaperRowState();
}

class _StudentPaperRowState extends State<_StudentPaperRow> {
  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final cs = widget.cs;
    final isDark = widget.isDark;

    // Resolve display name — prefer local DB data, fall back to proto, then ID.
    final displayName = widget.cachedStudent?.name.isNotEmpty == true
        ? widget.cachedStudent!.name
        : e.studentName.isNotEmpty
        ? e.studentName
        : 'Student #${e.studentId}';

    // Admission number — prefer local DB (adm is the integer admission key).
    final admDisplay = widget.cachedStudent != null
        ? 'ADM ${widget.cachedStudent!.adm}'
        : e.admNo.isNotEmpty
        ? e.admNo
        : null;

    final initials = _initials(widget.cachedStudent?.name ?? e.studentName);

    final selectedBg = widget.isSelected
        ? cs.primaryContainer.withValues(alpha: 0.3)
        : Colors.transparent;

    return Material(
      color: selectedBg,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        hoverColor: cs.primary.withValues(alpha: 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // ── Leading: circle avatar with initials ──────────────────
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Title + subtitle ──────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (admDisplay != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            admDisplay,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Trailing: status badge + action icons ─────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(e, cs),
                      const SizedBox(width: 2),

                      // Preview paper button.
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        tooltip: 'Preview paper',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PaperPreviewPage(
                                paperId: widget.paperId,
                                studentId: e.studentId,
                              ),
                            ),
                          );
                        },
                      ),

                      // Retry button — only shown when this student failed.
                      if (e.isFailed)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: 'Retry generation',
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onRetry,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            AppTheme.tableRowDivider(isDark, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StudentPaperEntry e, ColorScheme cs) {
    if (e.isReady) {
      return _StatusChip(
        label: 'Ready',
        backgroundColor: Colors.green.withValues(alpha: 0.12),
        foregroundColor: Colors.green,
      );
    }

    if (e.isFailed) {
      return _StatusChip(
        label: 'Failed',
        backgroundColor: cs.errorContainer.withValues(alpha: 0.5),
        foregroundColor: cs.error,
      );
    }

    // Still generating for this student.
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 1.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusChip
//
// Compact, non-interactive status badge chip used in student paper rows.
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: foregroundColor,
        ),
      ),
    );
  }
}
