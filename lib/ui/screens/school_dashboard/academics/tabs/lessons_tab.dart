import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../cache/file_cache.dart';
import '../../../../theme/app_theme.dart';
import '../../../../../database/database.dart';
import '../../../../../database/daos/timetable_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';

import '../../../../../models/school_context.dart';

/// Lessons tab — displays a chronological log of all lessons recorded for a
/// specific stream within a grade. Lessons are grouped by date (most recent
/// first) and can be filtered by subject via a chip row.
///
/// **Data source:** [TimetableDao.watchClassTermLessons] — returns
/// `Stream<List<LessonEntry>>` where each entry pairs a [Lesson] row with
/// the teacher's [UsersData].
class LessonsTab extends StatefulWidget {
  const LessonsTab({
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
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab>
    with AutomaticKeepAliveClientMixin {
  late final TimetableDao _dao;
  late Stream<List<LessonEntry>> _stream;

  /// `null` means "All" — no filter applied.
  int? _selectedSubject;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = TimetableDao(db);
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant LessonsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      _selectedSubject = null;
      setState(() => _stream = _buildStream());
    }
  }

  Stream<List<LessonEntry>> _buildStream() {
    return _dao.watchClassTermLessons(
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

    return StreamBuilder<List<LessonEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final all = snapshot.data ?? [];

        if (all.isEmpty) {
          return _buildEmpty(cs);
        }

        // Collect distinct subjects for filter chips.
        // Build a map of subject ID → name from the entries.
        final subjectNames = <int, String>{};
        for (final e in all) {
          subjectNames.putIfAbsent(e.lesson.subject, () => e.subjectName);
        }
        final sortedSubjects = subjectNames.keys.toList()..sort();

        // Apply subject filter.
        final filtered = _selectedSubject == null
            ? all
            : all.where((e) => e.lesson.subject == _selectedSubject).toList();

        // Compute summary stats from the filtered list.
        final lessonCount = filtered.length;
        final distinctSubjects = <int>{};
        final distinctTeachers = <String>{};
        for (final e in filtered) {
          distinctSubjects.add(e.lesson.subject);
          distinctTeachers.add(e.teacher.id);
        }

        // Group by date (descending — already sorted by DAO).
        final grouped = <int, List<LessonEntry>>{};
        for (final e in filtered) {
          (grouped[e.lesson.date] ??= []).add(e);
        }
        final sortedDates = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary row ──────────────────────────────────────────────
            _SummaryRow(
              lessonCount: lessonCount,
              subjectCount: distinctSubjects.length,
              teacherCount: distinctTeachers.length,
              cs: cs,
            ),

            // ── Subject filter chips ─────────────────────────────────────
            _SubjectFilterRow(
              subjects: sortedSubjects,
              selectedSubject: _selectedSubject,
              subjectNames: subjectNames,
              cs: cs,
              onSelected: (subject) {
                setState(() => _selectedSubject = subject);
              },
            ),

            // ── Divider ──────────────────────────────────────────────────
            Container(height: 1, color: cs.outline.withValues(alpha: 0.06)),

            // ── Grouped lesson list ──────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildFilterEmpty(cs, subjectNames)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _itemCount(sortedDates, grouped),
                      itemBuilder: (context, index) {
                        return _buildItem(index, sortedDates, grouped, cs);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── Item count & builder (date headers + lesson rows) ──────────────────────

  int _itemCount(List<int> dates, Map<int, List<LessonEntry>> grouped) {
    int count = 0;
    for (final d in dates) {
      count += 1; // date header
      count += grouped[d]!.length; // lesson rows
    }
    return count;
  }

  Widget _buildItem(
    int index,
    List<int> dates,
    Map<int, List<LessonEntry>> grouped,
    ColorScheme cs,
  ) {
    int running = 0;
    for (final d in dates) {
      final entries = grouped[d]!;
      if (index == running) {
        // Date header
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DateHeader(date: d, cs: cs),
        );
      }
      running += 1;
      if (index < running + entries.length) {
        final entryIndex = index - running;
        final entry = entries[entryIndex];
        return _LessonRow(
          entry: entry,
          curriculumType: widget.curriculumType,
          schoolId: widget.schoolId,
          cs: cs,
        );
      }
      running += entries.length;
    }
    return const SizedBox.shrink();
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
              'No lessons recorded',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'No lessons recorded for ${widget.streamName}',
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

  /// Empty state when the filter produces zero results.
  Widget _buildFilterEmpty(ColorScheme cs, Map<int, String> subjectNames) {
    final label = _selectedSubject != null
        ? (subjectNames[_selectedSubject!] ?? 'Subject $_selectedSubject')
        : 'this subject';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No lessons for $label',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUMMARY ROW
// ═════════════════════════════════════════════════════════════════════════════

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.lessonCount,
    required this.subjectCount,
    required this.teacherCount,
    required this.cs,
  });

  final int lessonCount;
  final int subjectCount;
  final int teacherCount;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.menu_book_outlined,
            value: '$lessonCount',
            label: lessonCount == 1 ? 'lesson' : 'lessons',
            cs: cs,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.subject_outlined,
            value: '$subjectCount',
            label: subjectCount == 1 ? 'subject' : 'subjects',
            cs: cs,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.person_outline,
            value: '$teacherCount',
            label: teacherCount == 1 ? 'teacher' : 'teachers',
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final String value;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outline.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUBJECT FILTER CHIPS
// ═════════════════════════════════════════════════════════════════════════════

class _SubjectFilterRow extends StatelessWidget {
  const _SubjectFilterRow({
    required this.subjects,
    required this.selectedSubject,
    required this.subjectNames,
    required this.cs,
    required this.onSelected,
  });

  final List<int> subjects;
  final int? selectedSubject;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        itemCount: subjects.length + 1, // +1 for "All"
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterChip(
              label: 'All',
              selected: selectedSubject == null,
              cs: cs,
              onTap: () => onSelected(null),
            );
          }
          final code = subjects[index - 1];
          return _FilterChip(
            label: subjectNames[code] ?? 'Subject $code',
            selected: selectedSubject == code,
            cs: cs,
            onTap: () => onSelected(code),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
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

// ═════════════════════════════════════════════════════════════════════════════
// DATE HEADER
// ═════════════════════════════════════════════════════════════════════════════

const _weekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Converts days-since-epoch to a formatted date string.
String _formatDate(int daysSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  final weekDay = _weekDays[dt.weekday - 1];
  final month = _months[dt.month - 1];
  return '$weekDay, ${dt.day} $month ${dt.year}';
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.cs});

  final int date;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          // ── Calendar icon + date label ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? cs.primary.withValues(alpha: 0.08)
                  : cs.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              border: Border.all(
                color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.10),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 11,
                  color: cs.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Decorative line extending to the right ──────────────────
          Expanded(
            child: Container(
              height: 0.5,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LESSON ROW
// ═════════════════════════════════════════════════════════════════════════════

/// Subtle subject color based on subject code.
Color _subjectColor(int subject) {
  const palette = [
    Color(0xFF42A5F5), // blue
    Color(0xFF66BB6A), // green
    Color(0xFFAB47BC), // purple
    Color(0xFFEF5350), // red
    Color(0xFFFFA726), // orange
    Color(0xFF26A69A), // teal
    Color(0xFF5C6BC0), // indigo
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF78909C), // blue grey
  ];
  return palette[subject % palette.length];
}

class _LessonRow extends StatefulWidget {
  const _LessonRow({
    required this.entry,
    required this.curriculumType,
    required this.schoolId,
    required this.cs,
  });

  final LessonEntry entry;
  final CurriculumType curriculumType;
  final String schoolId;
  final ColorScheme cs;

  @override
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final entry = widget.entry;
    final subjectName = entry.subjectName;
    final teacherName = entry.teacher.name;
    final color = _subjectColor(entry.lesson.subject);

    final idleBg = isDark
        ? color.withValues(alpha: 0.06)
        : color.withValues(alpha: 0.03);
    final hoverBg = isDark
        ? color.withValues(alpha: 0.12)
        : color.withValues(alpha: 0.07);
    final pressBg = isDark
        ? color.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.11);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () {
              // TODO: navigate to lesson detail
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _isPressed
                    ? pressBg
                    : _isHovered
                        ? hoverBg
                        : idleBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? color.withValues(alpha: isDark ? 0.35 : 0.25)
                      : cs.outline.withValues(alpha: isDark ? 0.10 : 0.08),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Animated left accent bar ───────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 4 : 3,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: _isHovered || _isPressed ? 1.0 : 0.65,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Row content ────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              // ── Subject name + teacher ─────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      subjectName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 11,
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.35),
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            teacherName,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w400,
                                              color: cs.onSurfaceVariant
                                                  .withValues(alpha: 0.55),
                                              height: 1.2,
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
                              const SizedBox(width: 8),

                              // ── Teacher avatar ─────────────────────────
                              _TeacherAvatar(
                                userId: entry.teacher.id,
                                name: teacherName,
                                cs: cs,
                              ),

                              const SizedBox(width: 4),

                              // ── Animated chevron ───────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(
                                  _isHovered ? 0.15 : 0.0,
                                  0,
                                ),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isHovered ? 0.8 : 0.35,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _isHovered
                                        ? color
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER AVATAR
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherAvatar extends StatelessWidget {
  const _TeacherAvatar({
    required this.userId,
    required this.name,
    required this.cs,
  });

  final String userId;
  final String name;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final relativePath = FileCache.profilePath(userId);

    return FutureBuilder<File?>(
      future: FileCache.get(relativePath),
      builder: (context, snap) {
        final file = snap.data;
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cs.outline.withValues(alpha: 0.06)),
            image: file != null
                ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                : null,
          ),
          child: file != null
              ? null
              : Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Returns up to 2-character initials from a full name.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
}
