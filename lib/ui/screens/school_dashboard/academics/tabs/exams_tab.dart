import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../database/daos/exams_grades_dao.dart' show ExamWithPapers;
import '../../../../../database/tables/enums.dart';
import '../../../../../models/school_context.dart';
import '../exam_detail_page.dart';

/// Exams tab — shows all exams for a specific stream within a grade, with
/// local in-memory filters for exam type and personalized status.
///
/// Each exam card shows the type badge, date range, teacher name, paper count,
/// and optional personalized / grade-wide labels.
///
/// Tapping a card navigates to `ExamDetailPage` (Task 13 — placeholder until
/// that widget exists).
class ExamsTab extends StatefulWidget {
  const ExamsTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final dynamic curriculumType;
  final SchoolContext schoolContext;

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab>
    with AutomaticKeepAliveClientMixin {
  late final AcademicsDao _dao;
  late Stream<List<ExamWithPapers>> _stream;

  // ── Filter state ───────────────────────────────────────────────────────────

  /// null = All types
  ExamType? _typeFilter;

  /// null = All, true = Personalized only, false = Standard only
  bool? _personalizedFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = AcademicsDao(db);
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant ExamsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() => _stream = _buildStream());
    }
  }

  Stream<List<ExamWithPapers>> _buildStream() {
    return _dao.watchExamsForGradeStream(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      streamCode: widget.streamCode,
    );
  }

  List<ExamWithPapers> _applyFilters(List<ExamWithPapers> items) {
    return items.where((ep) {
      if (_typeFilter != null && ep.exam.type != _typeFilter) return false;
      if (_personalizedFilter != null &&
          ep.exam.personalized != _personalizedFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<ExamWithPapers>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final allItems = snapshot.data ?? [];
        final filtered = _applyFilters(allItems);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Filter rows ──────────────────────────────────────────────
            _buildFilterSection(cs),

            // ── Divider ──────────────────────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: 2),
              color: cs.outline.withValues(alpha: 0.05),
            ),

            // ── List / empty ─────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(cs, allItems.isEmpty)
                  : _buildList(cs, filtered),
            ),
          ],
        );
      },
    );
  }

  // ── Filter section ─────────────────────────────────────────────────────────

  Widget _buildFilterSection(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ExamFilterChip(
                  label: 'All',
                  selected: _typeFilter == null,
                  cs: cs,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Exam',
                  selected: _typeFilter == ExamType.exam,
                  cs: cs,
                  onTap: () => setState(() => _typeFilter = ExamType.exam),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Assignment',
                  selected: _typeFilter == ExamType.assignment,
                  cs: cs,
                  onTap: () =>
                      setState(() => _typeFilter = ExamType.assignment),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Assessment',
                  selected: _typeFilter == ExamType.assessment,
                  cs: cs,
                  onTap: () =>
                      setState(() => _typeFilter = ExamType.assessment),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Personalized filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ExamFilterChip(
                  label: 'All',
                  selected: _personalizedFilter == null,
                  cs: cs,
                  onTap: () => setState(() => _personalizedFilter = null),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Personalized',
                  selected: _personalizedFilter == true,
                  cs: cs,
                  onTap: () => setState(() => _personalizedFilter = true),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Standard',
                  selected: _personalizedFilter == false,
                  cs: cs,
                  onTap: () => setState(() => _personalizedFilter = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty(ColorScheme cs, bool isGloballyEmpty) {
    final String message;
    final IconData icon;

    if (isGloballyEmpty) {
      message = 'No exams for ${widget.streamName}';
      icon = Icons.quiz_outlined;
    } else {
      // Filters are active but yielded zero results.
      final typeLabel = _typeFilter != null
          ? _examTypeLabel(_typeFilter!)
          : null;
      final personLabel = _personalizedFilter == true
          ? 'personalized'
          : _personalizedFilter == false
          ? 'standard'
          : null;

      final parts = <String>[
        if (typeLabel != null) typeLabel.toLowerCase(),
        if (personLabel != null) personLabel,
      ];
      message = parts.isEmpty
          ? 'No exams found'
          : 'No ${parts.join(' ')} exams found';
      icon = Icons.filter_list_off_rounded;
    }

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
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isGloballyEmpty ? 'No exams this term' : 'No matching exams',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exam list ──────────────────────────────────────────────────────────────

  Widget _buildList(ColorScheme cs, List<ExamWithPapers> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: items.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(cs, items.length);
        return _buildExamCard(cs, items[index - 1]);
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$count exam${count == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ── Exam card ──────────────────────────────────────────────────────────────

  Widget _buildExamCard(ColorScheme cs, ExamWithPapers ep) {
    final exam = ep.exam;
    final isDark = cs.brightness == Brightness.dark;
    final typeColor = _examTypeColor(exam.type, cs);
    final typeLabel = _examTypeLabel(exam.type);

    final startDate = DateTime.fromMillisecondsSinceEpoch(
      exam.start * 86400 * 1000,
    );
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      exam.end * 86400 * 1000,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onExamTap(ep),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top: type badge + personalized badge + grade-wide ────
                Row(
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),

                    if (exam.personalized) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: cs.outline.withValues(
                              alpha: isDark ? 0.15 : 0.12,
                            ),
                          ),
                        ),
                        child: Text(
                          'Personalized',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: exam.stream == null
                            ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        border: exam.stream != null
                            ? Border.all(
                                color: cs.outline.withValues(
                                  alpha: isDark ? 0.15 : 0.12,
                                ),
                              )
                            : null,
                      ),
                      child: Text(
                        exam.stream == null ? 'All Streams' : widget.streamName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: exam.stream == null
                              ? cs.primary
                              : cs.onSurfaceVariant.withValues(alpha: 0.6),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Date range ───────────────────────────────────────────
                Text(
                  '${_fmtDate(startDate)} – ${_fmtDate(endDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                // ── Teacher name ─────────────────────────────────────────
                Text(
                  'Created by ${ep.teacher.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Paper count badge ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${ep.papers.length} paper${ep.papers.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onExamTap(ExamWithPapers ep) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamDetailPage(
          exam: ep,
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          grade: widget.grade,
          streamCode: widget.streamCode,
          streamName: widget.streamName,
          curriculumType: widget.curriculumType,
          schoolContext: widget.schoolContext,
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _ExamFilterChip extends StatelessWidget {
  const _ExamFilterChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _examTypeLabel(ExamType type) => switch (type) {
  ExamType.exam => 'Exam',
  ExamType.assignment => 'Assignment',
  ExamType.assessment => 'Assessment',
};

Color _examTypeColor(ExamType type, ColorScheme cs) => switch (type) {
  ExamType.exam => cs.primary,
  ExamType.assignment => const Color(0xFFF59E0B),
  ExamType.assessment => const Color(0xFF4CAF50),
};

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

const _months = [
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
