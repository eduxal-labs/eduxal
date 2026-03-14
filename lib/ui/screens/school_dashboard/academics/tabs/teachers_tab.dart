import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/subjects_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../models/curriculum_levels.dart';
import '../../../../../models/school_context.dart';
import '../../../../widgets/user_avatar.dart';

/// Teachers tab — shows class teacher (active + history) and subject-teacher
/// assignments for a specific stream within a grade.
///
/// Three sections:
/// 1. **Active Class Teacher** — prominent card with primary-tinted border.
/// 2. **Past Class Teachers** — collapsible list (default collapsed).
/// 3. **Subject Teachers** — list of subject-teacher rows.
class TeachersTab extends StatefulWidget {
  const TeachersTab({
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
  State<TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<TeachersTab>
    with AutomaticKeepAliveClientMixin {
  late final SubjectsDao _dao;

  late Stream<({ClassTeacher classTeacher, UsersData user})?> _activeCtStream;
  late Stream<List<({ClassTeacher classTeacher, UsersData user})>>
  _historyStream;
  late Stream<List<({SubjectTeacher subject, UsersData teacher})>>
  _subjectsStream;

  bool _historyExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = SubjectsDao(db);
    _buildStreams();
  }

  @override
  void didUpdateWidget(covariant TeachersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() {
        _buildStreams();
        _historyExpanded = false;
      });
    }
  }

  void _buildStreams() {
    _activeCtStream = _dao.watchActiveClassTeacher(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    _historyStream = _dao.watchClassTeacherHistory(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    _subjectsStream = _dao.watchSubjectsForClass(
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Section 1: Active class teacher ──────────────────────────────
        _buildActiveClassTeacherSection(cs),

        const SizedBox(height: 20),

        // ── Section 2: Past class teachers ───────────────────────────────
        _buildPastClassTeachersSection(cs),

        const SizedBox(height: 20),

        // ── Section 3: Subject teachers ──────────────────────────────────
        _buildSubjectTeachersSection(cs),
      ],
    );
  }

  // ── Section 1: Active Class Teacher ────────────────────────────────────────

  Widget _buildActiveClassTeacherSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionHeader(cs, 'Class Teacher'),
        const SizedBox(height: 8),
        StreamBuilder<({ClassTeacher classTeacher, UsersData user})?>(
          stream: _activeCtStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildLoading(cs);
            }

            final active = snapshot.data;

            if (active == null) {
              return _buildEmptyPlaceholder(
                cs,
                Icons.person_outline_rounded,
                'No class teacher assigned',
              );
            }

            return _buildActiveClassTeacherCard(cs, active);
          },
        ),
      ],
    );
  }

  Widget _buildActiveClassTeacherCard(
    ColorScheme cs,
    ({ClassTeacher classTeacher, UsersData user}) active,
  ) {
    final startLabel = _formatDaysDate(active.classTeacher.start);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          UserAvatar(userId: active.user.id, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active.user.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Class Teacher',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Since $startLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 2: Past Class Teachers ─────────────────────────────────────────

  Widget _buildPastClassTeachersSection(ColorScheme cs) {
    return StreamBuilder<List<({ClassTeacher classTeacher, UsersData user})>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allEntries = snapshot.data ?? [];
        // Filter to only past class teachers (end IS NOT NULL).
        final pastEntries = allEntries
            .where((e) => e.classTeacher.end != null)
            .toList();

        if (pastEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header with chevron toggle ─────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _historyExpanded = !_historyExpanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Previous Class Teachers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _historyExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Collapsible content ────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in pastEntries)
                    _buildPastClassTeacherCard(cs, entry),
                ],
              ),
              crossFadeState: _historyExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPastClassTeacherCard(
    ColorScheme cs,
    ({ClassTeacher classTeacher, UsersData user}) entry,
  ) {
    final startLabel = _formatDaysDate(entry.classTeacher.start);
    final endLabel = entry.classTeacher.end != null
        ? _formatDaysDate(entry.classTeacher.end!)
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(userId: entry.user.id, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.user.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$startLabel — $endLabel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 3: Subject Teachers ────────────────────────────────────────────

  Widget _buildSubjectTeachersSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<({SubjectTeacher subject, UsersData teacher})>>(
          stream: _subjectsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSectionHeader(cs, 'Subject Teachers'),
                  const SizedBox(height: 8),
                  _buildLoading(cs),
                ],
              );
            }

            final entries = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header with count badge ──────────────────────────────
                Row(
                  children: [
                    _buildSectionHeader(cs, 'Subject Teachers'),
                    if (entries.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildCountBadge(cs, entries.length),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                if (entries.isEmpty)
                  _buildEmptyPlaceholder(
                    cs,
                    Icons.menu_book_outlined,
                    'No subjects assigned to ${widget.streamName}',
                  )
                else
                  for (final entry in entries)
                    _buildSubjectTeacherCard(cs, entry),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubjectTeacherCard(
    ColorScheme cs,
    ({SubjectTeacher subject, UsersData teacher}) entry,
  ) {
    final label = subjectLabel(widget.curriculumType, entry.subject.subject);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Subject name
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 12),

            // Teacher avatar + name
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(userId: entry.teacher.id, radius: 14),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    entry.teacher.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
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
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(ColorScheme cs, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildCountBadge(ColorScheme cs, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(ColorScheme cs, IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date formatting ─────────────────────────────────────────────────────────

/// Converts days since epoch to a readable date string (e.g. "12 Jan 2024").
String _formatDaysDate(int daysSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

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
