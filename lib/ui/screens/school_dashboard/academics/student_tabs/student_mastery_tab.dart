import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/exams_grades_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../models/curriculum_levels.dart';
import '../../../../widgets/edu_sheet.dart';

/// Mastery tab for the Student Grade Page — shows the student's topic-level
/// mastery per subject with tappable subject cards that open a detail sheet.
///
/// Each subject card displays the subject name, overall mastery percentage
/// (average of all topics), and a thin color-coded progress bar. Tapping a
/// card opens a modal bottom sheet with the per-topic breakdown.
class StudentMasteryTab extends StatefulWidget {
  const StudentMasteryTab({
    super.key,
    required this.schoolId,
    required this.studentAdm,
    required this.grade,
    required this.curriculumType,
  });

  final String schoolId;
  final int studentAdm;
  final int grade;
  final CurriculumType curriculumType;

  @override
  State<StudentMasteryTab> createState() => _StudentMasteryTabState();
}

class _StudentMasteryTabState extends State<StudentMasteryTab>
    with AutomaticKeepAliveClientMixin {
  late final ExamsGradesDao _examsGradesDao;
  late Stream<List<MasteryData>> _masteryStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _examsGradesDao = ExamsGradesDao(db);
    _buildStream();
  }

  @override
  void didUpdateWidget(covariant StudentMasteryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.studentAdm != widget.studentAdm ||
        oldWidget.grade != widget.grade) {
      _buildStream();
      setState(() {});
    }
  }

  void _buildStream() {
    _masteryStream = _examsGradesDao.watchMasteryForStudent(
      schoolId: widget.schoolId,
      studentAdm: widget.studentAdm,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<MasteryData>>(
      stream: _masteryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          );
        }

        final allMastery = snapshot.data ?? [];

        // Filter to current grade.
        final mastery = allMastery;

        if (mastery.isEmpty) {
          return _buildEmptyState(cs);
        }

        // Group by subject → list of topic scores.
        final bySubject = <int, List<MasteryData>>{};
        for (final m in mastery) {
          bySubject.putIfAbsent(m.subject, () => []).add(m);
        }

        // Sort by subject index.
        final sortedSubjects = bySubject.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: sortedSubjects.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${sortedSubjects.length} subject${sortedSubjects.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              );
            }

            final subjectIndex = sortedSubjects[index - 1];
            final topics = bySubject[subjectIndex]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SubjectCard(
                cs: cs,
                isDark: isDark,
                subjectIndex: subjectIndex,
                topics: topics,
                curriculumType: widget.curriculumType,
                onTap: () =>
                    _showTopicSheet(context, cs, isDark, subjectIndex, topics),
              ),
            );
          },
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(ColorScheme cs) {
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
                Icons.psychology_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No mastery data',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Topic mastery will appear here once assessments are graded',
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

  // ── Topic detail sheet ─────────────────────────────────────────────────────

  void _showTopicSheet(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    int subjectIndex,
    List<MasteryData> topics,
  ) {
    showEduSheet(
      context: context,
      builder: (ctx) => _TopicDetailSheet(
        cs: cs,
        isDark: isDark,
        subjectIndex: subjectIndex,
        topics: topics,
        curriculumType: widget.curriculumType,
      ),
    );
  }
}

// ─── Subject Card ────────────────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.cs,
    required this.isDark,
    required this.subjectIndex,
    required this.topics,
    required this.curriculumType,
    required this.onTap,
  });

  final ColorScheme cs;
  final bool isDark;
  final int subjectIndex;
  final List<MasteryData> topics;
  final CurriculumType curriculumType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avg =
        topics.map((t) => t.score).reduce((a, b) => a + b) / topics.length;
    final pct = avg * 100; // scores are 0.0–1.0
    final color = _masteryColor(pct);
    final label = subjectLabel(curriculumType, subjectIndex);

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Subject name + percentage ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${pct.round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Mastery bar ────────────────────────────────────────────
              _ThinProgressBar(
                percent: avg.clamp(0.0, 1.0),
                color: color,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                height: 4,
              ),

              const SizedBox(height: 6),

              // ── Topics count + chevron hint ────────────────────────────
              Row(
                children: [
                  Text(
                    '${topics.length} topic${topics.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Topic Detail Bottom Sheet (Mobile) ──────────────────────────────────────

class _TopicDetailSheet extends StatelessWidget {
  const _TopicDetailSheet({
    required this.cs,
    required this.isDark,
    required this.subjectIndex,
    required this.topics,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final int subjectIndex;
  final List<MasteryData> topics;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    final sortedTopics = List<MasteryData>.from(topics)
      ..sort((a, b) => a.topic.compareTo(b.topic));
    final avg =
        topics.map((t) => t.score).reduce((a, b) => a + b) / topics.length;
    final pct = avg * 100;
    final color = _masteryColor(pct);
    final label = subjectLabel(curriculumType, subjectIndex);

    // Compute max height: ~60% of screen, but at least enough for header + a
    // few rows and at most 85%.
    final maxFraction = (0.25 + (sortedTopics.length * 0.06)).clamp(0.35, 0.85);

    return DraggableScrollableSheet(
      initialChildSize: maxFraction.clamp(0.35, 0.7),
      minChildSize: 0.25,
      maxChildSize: maxFraction,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerLow : cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${pct.round()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ThinProgressBar(
                      percent: avg.clamp(0.0, 1.0),
                      color: color,
                      backgroundColor: cs.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      height: 4,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sortedTopics.length} topic${sortedTopics.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ────────────────────────────────────────────────
              Container(
                height: 1,
                color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
              ),

              // ── Topic list ─────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  itemCount: sortedTopics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    return _TopicRow(
                      cs: cs,
                      isDark: isDark,
                      topic: sortedTopics[index],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Topic Row ───────────────────────────────────────────────────────────────

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.cs,
    required this.isDark,
    required this.topic,
  });

  final ColorScheme cs;
  final bool isDark;
  final MasteryData topic;

  @override
  Widget build(BuildContext context) {
    final pct = topic.score * 100;
    final color = _masteryColor(pct);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // ── Topic index label ──────────────────────────────────────────
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              '${topic.topic}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Label + bar ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Topic ${topic.topic}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                _ThinProgressBar(
                  percent: topic.score.clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: cs.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  height: 3,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Percentage ─────────────────────────────────────────────────
          SizedBox(
            width: 38,
            child: Text(
              '${pct.round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thin Progress Bar ───────────────────────────────────────────────────────

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.percent,
    required this.color,
    required this.backgroundColor,
    this.height = 3,
  });

  /// 0.0 – 1.0
  final double percent;
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: backgroundColor),
            FractionallySizedBox(
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mastery Color Helper ────────────────────────────────────────────────────

Color _masteryColor(double p) {
  if (p >= 80) return const Color(0xFF4CAF50);
  if (p >= 60) return const Color(0xFFFFC107);
  if (p >= 40) return const Color(0xFFFF9800);
  return const Color(0xFFF44336);
}
