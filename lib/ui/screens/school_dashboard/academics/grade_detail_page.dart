import 'package:flutter/material.dart';

import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';

/// Stub page for a single grade's detail view.
///
/// Shows the grade label as a header, a horizontal row of stream filter chips
/// (`All` + one per stream), and a placeholder body. The filter state is fully
/// wired so content can be plugged in beneath the chips later.
class GradeDetailPage extends StatefulWidget {
  const GradeDetailPage({
    super.key,
    required this.schoolContext,
    required this.curriculumType,
    required this.grade,
    required this.gradeLabel,
  });

  final SchoolContext schoolContext;
  final CurriculumType curriculumType;
  final GradeConfig grade;
  final String gradeLabel;

  @override
  State<GradeDetailPage> createState() => _GradeDetailPageState();
}

class _GradeDetailPageState extends State<GradeDetailPage> {
  /// `null` means "All" is selected — no stream filter applied.
  int? _selectedStreamCode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final streams = widget.grade.streams;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.gradeLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stream filter chips ─────────────────────────────────────────
          if (streams.isNotEmpty)
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _selectedStreamCode == null,
                      onTap: () => setState(() => _selectedStreamCode = null),
                    ),
                    for (final stream in streams) ...[
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: stream.name,
                        isSelected: _selectedStreamCode == stream.code,
                        onTap: () =>
                            setState(() => _selectedStreamCode = stream.code),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Divider ────────────────────────────────────────────────────
          Container(
            height: 1,
            color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
          ),

          // ── Content placeholder ────────────────────────────────────────
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.view_list_outlined,
                        size: 22,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Grade detail — coming soon',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _selectedStreamCode == null
                          ? 'Showing all streams'
                          : 'Filtered to ${_selectedStreamLabel()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _selectedStreamLabel() {
    if (_selectedStreamCode == null) return 'All';
    final match = widget.grade.streams
        .where((s) => s.code == _selectedStreamCode)
        .firstOrNull;
    return match?.name ?? 'Stream $_selectedStreamCode';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip — compact, solid element for the stream filter row
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.10)
          : isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
          : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.3)
                  : cs.outline.withValues(alpha: isDark ? 0.1 : 0.08),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.75),
              letterSpacing: 0.15,
            ),
          ),
        ),
      ),
    );
  }
}
