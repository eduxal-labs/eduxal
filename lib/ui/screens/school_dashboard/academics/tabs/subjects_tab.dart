import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../models/grade_analytics.dart';
import '../../../../../models/school_context.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';

/// Subjects tab — shows all subject-teacher assignments for a specific stream
/// within a grade. Each card displays the subject name, assigned teacher,
/// mastery comparison bars (stream vs grade average), and a delta indicator.
class SubjectsTab extends StatefulWidget {
  const SubjectsTab({
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
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  @override
  State<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<SubjectsTab>
    with AutomaticKeepAliveClientMixin {
  late final AcademicsDao _dao;
  late Stream<List<SubjectTeacherEntry>> _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = AcademicsDao(db);
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant SubjectsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() => _stream = _buildStream());
    }
  }

  Stream<List<SubjectTeacherEntry>> _buildStream() {
    return _dao.watchSubjectsForGrade(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<SubjectTeacherEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return _buildEmpty(cs);
        }

        return _buildList(cs, entries);
      },
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

  Widget _buildEmpty(ColorScheme cs) {
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
                Icons.menu_book_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No subjects assigned',
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
              'No subjects have been assigned to ${widget.streamName}',
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

  // ── Subject list ───────────────────────────────────────────────────────────

  Widget _buildList(ColorScheme cs, List<SubjectTeacherEntry> entries) {
    final isDark = cs.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _buildHeader(cs, entries.length),
        ),
        AppTheme.tableRowDivider(isDark, cs),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: entries.length * 2 - 1,
            itemBuilder: (context, index) {
              if (index.isOdd) {
                return AppTheme.tableRowDivider(isDark, cs);
              }
              return _buildSubjectRow(cs, entries[index ~/ 2], isDark);
            },
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, int count) {
    return Text(
      '$count subject${count == 1 ? '' : 's'}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  // ── Subject row ────────────────────────────────────────────────────────────

  Widget _buildSubjectRow(
    ColorScheme cs,
    SubjectTeacherEntry entry,
    bool isDark,
  ) {
    return _SubjectRow(
      entry: entry,
      curriculumType: widget.curriculumType,
      cs: cs,
      isDark: isDark,
    );
  }
}

// ─── Flat subject row with hover ──────────────────────────────────────────────

class _SubjectRow extends StatefulWidget {
  const _SubjectRow({
    required this.entry,
    required this.curriculumType,
    required this.cs,
    required this.isDark,
  });

  final SubjectTeacherEntry entry;
  final CurriculumType curriculumType;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_SubjectRow> createState() => _SubjectRowState();
}

class _SubjectRowState extends State<_SubjectRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final entry = widget.entry;
    final label = entry.subjectName;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered
            ? cs.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Subject name + teacher ─────────────────────────────────
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(userId: entry.teacher.id, radius: 10),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            entry.teacher.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.65,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Mastery bars (compact) ─────────────────────────────────
              Expanded(
                flex: 3,
                child: _MasterySection(
                  streamAvg: entry.streamMasteryAverage,
                  gradeAvg: entry.gradeMasteryAverage,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mastery bars + delta indicator ──────────────────────────────────────────

class _MasterySection extends StatelessWidget {
  const _MasterySection({
    required this.streamAvg,
    required this.gradeAvg,
    required this.cs,
    required this.isDark,
  });

  final double? streamAvg;
  final double? gradeAvg;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (streamAvg == null && gradeAvg == null) {
      return Text(
        'No mastery data',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Stream average bar ─────────────────────────────────────────
        _MasteryBar(
          label: 'Stream Avg',
          value: streamAvg,
          cs: cs,
          isDark: isDark,
        ),

        const SizedBox(height: 6),

        // ── Grade average bar ──────────────────────────────────────────
        _MasteryBar(
          label: 'Grade Avg',
          value: gradeAvg,
          cs: cs,
          isDark: isDark,
        ),

        // ── Delta indicator ────────────────────────────────────────────
        if (streamAvg != null && gradeAvg != null) ...[
          const SizedBox(height: 8),
          _buildDelta(streamAvg!, gradeAvg!),
        ],
      ],
    );
  }

  Widget _buildDelta(double stream, double grade) {
    final delta = stream - grade;
    if (delta.abs() < 0.05) {
      return Text(
        'Same as grade average',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      );
    }

    final isPositive = delta > 0;
    final color = isPositive
        ? const Color(0xFF4CAF50)
        : const Color(0xFFF44336);
    final sign = isPositive ? '+' : '';
    final icon = isPositive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '$sign${delta.toStringAsFixed(1)}% vs grade',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Individual mastery bar ──────────────────────────────────────────────────

class _MasteryBar extends StatelessWidget {
  const _MasteryBar({
    required this.label,
    required this.value,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final double? value;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final percent = value ?? 0.0;
    final barColor = value != null ? _percentColor(percent) : null;
    final displayLabel = value != null ? '${value!.toStringAsFixed(1)}%' : '—';

    return Row(
      children: [
        // Label
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),

        // Bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: value != null ? (percent / 100).clamp(0.0, 1.0) : 0.0,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.6 : 0.8,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  barColor ?? cs.surfaceContainerHighest,
                ),
                minHeight: 6,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Percentage label
        SizedBox(
          width: 42,
          child: Text(
            displayLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: barColor ?? cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }

  static Color _percentColor(double p) {
    if (p >= 70) return const Color(0xFF4CAF50);
    if (p >= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }
}
