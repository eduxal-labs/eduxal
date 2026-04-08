import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../core/extensions.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';

import '../../../widgets/countdown_chip.dart';
import '../../../widgets/today_status_card.dart';
import '../../../widgets/quick_stat_row.dart';
import '../../../theme/app_theme.dart';
import '../school_dashboard_screen.dart';
import 'overview_shared.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class TeacherOverview extends StatelessWidget {
  const TeacherOverview({
    super.key,
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final TeacherEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final userId = entry.teacher.user;

    return RefreshIndicator(
      onRefresh: () async {
        sync.pushNow();
        await Future.delayed(const Duration(milliseconds: 800));
      },
      color: cs.primary,
      child: StaggeredList(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Next class countdown ─────────────────────────────────────────
          if (term != null &&
              userId.isNotEmpty &&
              termContext.isCurrentTermActive) ...[
            _TeacherNextClass(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              teacherUserId: userId,
            ),
            const SizedBox(height: 16),
          ],

          // ── Attendance marking status ────────────────────────────────────
          if (term != null &&
              userId.isNotEmpty &&
              termContext.isCurrentTermActive) ...[
            StreamBuilder<List<ClassAttendanceStatus>>(
              stream: AttendanceDao(db).watchTeacherClassAttendanceStatus(
                schoolId: schoolId,
                teacherId: userId,
                year: term.year,
                term: term.term,
                date: DateTime.now()
                    .toUtc()
                    .difference(DateTime.utc(1970, 1, 1))
                    .inDays,
              ),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty)
                  return const SizedBox.shrink();
                final classes = snap.data!;
                final allMarked = classes.every((c) => c.isMarked);
                final unmarkedCount = classes.where((c) => !c.isMarked).length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TodayStatusCard(
                    type: allMarked
                        ? TodayStatusType.positive
                        : TodayStatusType.warning,
                    icon: allMarked
                        ? Icons.check_circle_rounded
                        : Icons.edit_note_rounded,
                    title: allMarked
                        ? 'All classes marked'
                        : '$unmarkedCount class${unmarkedCount > 1 ? "es" : ""} not marked',
                    subtitle: classes
                        .map((c) {
                          final label = gradeLabel(c.grade);
                          return c.isMarked ? '$label ✓' : '$label ✗';
                        })
                        .join('  '),
                  ),
                );
              },
            ),
          ],

          // ── Today's schedule ─────────────────────────────────────────────
          if (term != null &&
              userId.isNotEmpty &&
              termContext.isCurrentTermActive) ...[
            SectionTitle(
              label: "Today's Schedule",
              cs: cs,
              onViewAll: () =>
                  DashboardNavigation.goToTab(context, 'Timetable'),
            ),
            const SizedBox(height: 8),
            _TeacherTodaySchedule(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              teacherUserId: userId,
            ),
            const SizedBox(height: 20),
          ],

          // ── My Classes ───────────────────────────────────────────────────
          if (term != null && userId.isNotEmpty) ...[
            SectionTitle(
              label: 'My Classes',
              cs: cs,
              onViewAll: () =>
                  DashboardNavigation.goToTab(context, 'My Classes'),
            ),
            const SizedBox(height: 8),
            _TeacherClassChips(schoolId: schoolId, userId: userId, term: term),
            const SizedBox(height: 20),
          ],

          // ── Quick stats ──────────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(label: 'Quick Stats', cs: cs),
            const SizedBox(height: 8),
            _TeacherQuickStats(
              schoolId: schoolId,
              term: term,
              entry: entry,
              userId: userId,
            ),
            const SizedBox(height: 20),
          ],

          // ── Upcoming Exams ───────────────────────────────────────────────
          if (term != null && userId.isNotEmpty) ...[
            SectionTitle(
              label: 'Upcoming Exams',
              cs: cs,
              onViewAll: () => DashboardNavigation.goToTab(context, 'Exams'),
            ),
            const SizedBox(height: 8),
            _TeacherUpcomingExams(
              schoolId: schoolId,
              userId: userId,
              term: term,
            ),
            const SizedBox(height: 20),
          ],

          // ── Recent announcements ─────────────────────────────────────────
          SectionTitle(
            label: 'Recent Announcements',
            cs: cs,
            onViewAll: () =>
                DashboardNavigation.goToTab(context, 'Announcements'),
          ),
          const SizedBox(height: 8),
          RecentAnnouncements(
            schoolId: schoolId,
            audienceBit: AudienceBits.teachers,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _TeacherNextClass extends StatefulWidget {
  const _TeacherNextClass({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.teacherUserId,
  });

  final String schoolId;
  final int year;
  final int term;
  final String teacherUserId;

  @override
  State<_TeacherNextClass> createState() => _TeacherNextClassState();
}

class _TeacherNextClassState extends State<_TeacherNextClass> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
  }

  @override
  void didUpdateWidget(covariant _TeacherNextClass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimetableData>>(
      stream: TimetableDao(db).watchTeacherTimetable(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        teacherUserId: widget.teacherUserId,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final allSlots = snap.data!;
        final todayDay = currentDayOfWeek();
        final now = DateTime.now();
        final nowSec = now.hour * 3600 + now.minute * 60 + now.second;

        final todaySlots =
            allSlots.where((s) => s.day == todayDay && s.end > nowSec).toList()
              ..sort((a, b) => a.start.compareTo(b.start));

        if (todaySlots.isEmpty) return const SizedBox.shrink();

        final nextSlot = todaySlots.firstWhere(
          (s) => s.start > nowSec,
          orElse: () => todaySlots.first,
        );

        final isInProgress = nextSlot.start <= nowSec && nextSlot.end > nowSec;

        return FutureBuilder<List<Subject>>(
          future: _subjectsFuture,
          builder: (context, subSnap) {
            final subjectMap = <int, String>{};
            for (final s in subSnap.data ?? []) {
              subjectMap[s.id] = s.name;
            }
            final subjectName = subjectMap[nextSlot.subject] ?? 'Class';

            if (isInProgress) {
              return TodayStatusCard(
                type: TodayStatusType.positive,
                icon: Icons.play_circle_rounded,
                title: '$subjectName in progress',
                subtitle:
                    '${fmtTime(nextSlot.start)} – ${fmtTime(nextSlot.end)}',
                trailing: CountdownChip(
                  label: 'Ends',
                  targetTime: todayAtSeconds(nextSlot.end),
                  icon: Icons.timer_outlined,
                  compact: true,
                ),
              );
            }

            return TodayStatusCard(
              type: TodayStatusType.neutral,
              icon: Icons.schedule_rounded,
              title: 'Next: $subjectName',
              subtitle: '${fmtTime(nextSlot.start)} – ${fmtTime(nextSlot.end)}',
              trailing: CountdownChip(
                label: 'Starts',
                targetTime: todayAtSeconds(nextSlot.start),
                icon: Icons.timer_outlined,
                compact: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _TeacherTodaySchedule extends StatefulWidget {
  const _TeacherTodaySchedule({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.teacherUserId,
  });

  final String schoolId;
  final int year;
  final int term;
  final String teacherUserId;

  @override
  State<_TeacherTodaySchedule> createState() => _TeacherTodayScheduleState();
}

class _TeacherTodayScheduleState extends State<_TeacherTodaySchedule> {
  late Future<List<Subject>> _subjectsFuture;
  late Future<List<SchoolStream>> _streamsFuture;
  Timer? _refreshTimer;
  bool _showAll = false;

  int get _nowSeconds {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _TeacherTodaySchedule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
        _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
        _showAll = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Filters out past lessons and sorts by proximity to now.
  List<TimetableData> _filterAndSort(List<TimetableData> slots) {
    final nowSec = _nowSeconds;
    // Remove lessons that have already ended.
    final active = slots.where((s) => s.end > nowSec).toList();
    // Sort by proximity to now (closest start first), break ties by grade.
    active.sort((a, b) {
      final diffA = (a.start - nowSec).abs();
      final diffB = (b.start - nowSec).abs();
      final cmp = diffA.compareTo(diffB);
      return cmp != 0 ? cmp : a.grade.compareTo(b.grade);
    });
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final timetableDao = TimetableDao(db);

    return StreamBuilder<List<TimetableData>>(
      stream: timetableDao.watchTeacherTimetable(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        teacherUserId: widget.teacherUserId,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingShimmer();
        }

        final allSlots = snap.data ?? [];
        final todayDay = currentDayOfWeek();
        final todaySlots = allSlots.where((s) => s.day == todayDay).toList();
        final activeSlots = _filterAndSort(todaySlots);

        // All lessons have passed for the day (but some were scheduled).
        if (activeSlots.isEmpty && todaySlots.isNotEmpty) {
          return const EmptyCard(
            icon: Icons.celebration_outlined,
            message: 'All done for today! 🎉',
          );
        }

        if (activeSlots.isEmpty) {
          return const EmptyCard(
            icon: Icons.event_available_outlined,
            message: 'No classes scheduled today',
          );
        }

        return FutureBuilder<List<Subject>>(
          future: _subjectsFuture,
          builder: (context, subSnap) {
            return FutureBuilder<List<SchoolStream>>(
              future: _streamsFuture,
              builder: (context, strSnap) {
                final subjectMap = <int, String>{};
                for (final s in subSnap.data ?? []) {
                  subjectMap[s.id] = s.name;
                }
                final streamMap = <(int, int), String>{};
                for (final s in strSnap.data ?? []) {
                  streamMap[(s.grade, s.stream)] = s.name;
                }

                return _TodayScheduleGrid(
                  slots: activeSlots,
                  subjectMap: subjectMap,
                  streamMap: streamMap,
                  showAll: _showAll,
                  onToggleShowAll: () => setState(() => _showAll = !_showAll),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Responsive grid for today's lessons ──────────────────────────────────────

class _TodayScheduleGrid extends StatelessWidget {
  const _TodayScheduleGrid({
    required this.slots,
    required this.subjectMap,
    required this.streamMap,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final List<TimetableData> slots;
  final Map<int, String> subjectMap;
  final Map<(int, int), String> streamMap;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 360 ? 2 : (width < 600 ? 3 : 4);
        final defaultVisible = columns * 2; // 2 rows
        final total = slots.length;
        final visibleCount = showAll ? total : total.clamp(0, defaultVisible);
        final hasMore = total > defaultVisible;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(visibleCount, (i) {
                final slot = slots[i];
                // Calculate card width to fill columns with spacing.
                final totalSpacing = 8.0 * (columns - 1);
                final cardWidth = (width - totalSpacing) / columns;

                return SizedBox(
                  width: cardWidth,
                  height: 72,
                  child: _TodayLessonCard(
                    slot: slot,
                    subjectName: subjectMap[slot.subject],
                    streamName: streamMap[(slot.grade, slot.stream)],
                  ),
                );
              }),
            ),
            if (hasMore && !showAll) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onToggleShowAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Show all ($total)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (hasMore && showAll) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onToggleShowAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Show less',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Single lesson card in the grid ───────────────────────────────────────────

class _TodayLessonCard extends StatelessWidget {
  const _TodayLessonCard({
    required this.slot,
    this.subjectName,
    this.streamName,
  });

  final TimetableData slot;
  final String? subjectName;
  final String? streamName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = subjectColor(slot.subject);
    final timeLabel = fmtTime(slot.start);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Left color stripe.
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.kCardRadius),
                bottomLeft: Radius.circular(AppTheme.kCardRadius),
              ),
            ),
          ),
          // Card content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: subject name + time badge.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subjectName ?? 'Subject ${slot.subject}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.kChipRadius,
                          ),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Bottom: grade + stream.
                  Text(
                    gradeStreamLabel(slot.grade, streamName: streamName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherQuickStats extends StatefulWidget {
  const _TeacherQuickStats({
    required this.schoolId,
    required this.term,
    required this.entry,
    required this.userId,
  });

  final String schoolId;
  final Term term;
  final TeacherEntry entry;
  final String userId;

  @override
  State<_TeacherQuickStats> createState() => _TeacherQuickStatsState();
}

class _TeacherQuickStatsState extends State<_TeacherQuickStats> {
  int _subjectCount = 0;
  int _classCount = 0;
  int _lessonsPerWeek = 0;
  int _papersCount = 0;
  Set<int> _teacherSubjectIds = {};
  List<ExamWithPapers> _allExams = [];

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    for (final s in _subs) s.cancel();
    _subs.clear();

    final membersDao = MembersDao(db);
    final timetableDao = TimetableDao(db);
    final examsDao = ExamsGradesDao(db);

    // 1. My Subjects — live count of subject assignments this term
    _subs.add(
      membersDao
          .watchTeacherSubjectsForTerm(
            widget.schoolId,
            widget.userId,
            year: widget.term.year,
            term: widget.term.term,
          )
          .listen((list) {
            if (!mounted) return;
            final ids = list.map((s) => s.subject).toSet();
            setState(() {
              _teacherSubjectIds = ids;
              _subjectCount = ids.length;
            });
            _recomputePapers();
          }),
    );

    // 2. My Classes — class_teacher assignments for this term
    _subs.add(
      membersDao
          .watchClassTeacherAssignments(widget.schoolId, widget.userId)
          .listen((list) {
            if (!mounted) return;
            final count = list
                .where(
                  (c) =>
                      c.year == widget.term.year && c.term == widget.term.term,
                )
                .length;
            setState(() => _classCount = count);
          }),
    );

    // 3. Lessons/Week — timetable entry count = weekly lesson slots
    _subs.add(
      timetableDao
          .watchTeacherTimetable(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
            teacherUserId: widget.userId,
          )
          .listen((list) {
            if (!mounted) return;
            setState(() => _lessonsPerWeek = list.length);
          }),
    );

    // 4. My Exams — papers count from exams where teacher is involved
    _subs.add(
      examsDao
          .watchExamsForTerm(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          )
          .listen((allExams) {
            if (!mounted) return;
            _allExams = allExams;
            _recomputePapers();
          }),
    );
  }

  void _recomputePapers() {
    int papers = 0;
    for (final e in _allExams) {
      if (e.teacher.id == widget.userId ||
          e.papers.any((p) => p.invigilator == widget.userId) ||
          e.papers.any((p) => _teacherSubjectIds.contains(p.subject))) {
        papers += e.papers.length;
      }
    }
    if (mounted) setState(() => _papersCount = papers);
  }

  @override
  void didUpdateWidget(covariant _TeacherQuickStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.userId != widget.userId ||
        oldWidget.term.year != widget.term.year ||
        oldWidget.term.term != widget.term.term) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuickStatRow(
      stats: [
        QuickStat(
          icon: Icons.menu_book_outlined,
          label: 'My Subjects',
          value: '$_subjectCount',
        ),
        QuickStat(
          icon: Icons.class_outlined,
          label: 'My Classes',
          value: '$_classCount',
        ),
        QuickStat(
          icon: Icons.calendar_view_week_rounded,
          label: 'Lessons/Week',
          value: '$_lessonsPerWeek',
        ),
        QuickStat(
          icon: Icons.assignment_outlined,
          label: 'My Exams',
          value: '$_papersCount',
        ),
      ],
    );
  }
}

// ── Teacher Class Chips ──────────────────────────────────────────────────────

class _TeacherClassChips extends StatefulWidget {
  const _TeacherClassChips({
    required this.schoolId,
    required this.userId,
    required this.term,
  });

  final String schoolId;
  final String userId;
  final Term term;

  @override
  State<_TeacherClassChips> createState() => _TeacherClassChipsState();
}

class _TeacherClassChipsState extends State<_TeacherClassChips> {
  late Future<List<SchoolStream>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }

  @override
  void didUpdateWidget(covariant _TeacherClassChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final membersDao = MembersDao(db);

    return StreamBuilder<List<ClassTeacher>>(
      stream: membersDao.watchClassTeacherAssignments(
        widget.schoolId,
        widget.userId,
      ),
      builder: (context, ctSnap) {
        if (ctSnap.connectionState == ConnectionState.waiting) {
          return const LoadingShimmer();
        }

        // Filter to current term + active (end == null) only
        final activeCt = (ctSnap.data ?? [])
            .where(
              (c) =>
                  c.year == widget.term.year &&
                  c.term == widget.term.term &&
                  c.end == null,
            )
            .toList();

        if (activeCt.isEmpty) {
          return EmptyCard(
            icon: Icons.school_outlined,
            message: 'No class teacher assignments this term',
          );
        }

        // Sort by grade, then stream
        activeCt.sort((a, b) {
          final g = a.grade.compareTo(b.grade);
          return g != 0 ? g : a.stream.compareTo(b.stream);
        });

        return FutureBuilder<List<SchoolStream>>(
          future: _streamsFuture,
          builder: (context, streamsSnap) {
            final streamNames = <(int, int), String>{};
            for (final s in streamsSnap.data ?? []) {
              streamNames[(s.grade, s.stream)] = s.name;
            }

            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: activeCt.map((ct) {
                final streamName = streamNames[(ct.grade, ct.stream)];
                final label = gradeStreamLabel(
                  ct.grade,
                  streamName: streamName,
                );

                return _buildClassChip(
                  label: label,
                  subtitle: 'Class Teacher',
                  isPrimary: true,
                  cs: cs,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildClassChip({
    required String label,
    required String subtitle,
    required bool isPrimary,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPrimary
              ? cs.primary.withValues(alpha: 0.2)
              : cs.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isPrimary ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: isPrimary
                  ? cs.primary.withValues(alpha: 0.6)
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Teacher Upcoming Exams ───────────────────────────────────────────────────

class _TeacherUpcomingExams extends StatefulWidget {
  const _TeacherUpcomingExams({
    required this.schoolId,
    required this.userId,
    required this.term,
  });

  final String schoolId;
  final String userId;
  final Term term;

  @override
  State<_TeacherUpcomingExams> createState() => _TeacherUpcomingExamsState();
}

class _TeacherUpcomingExamsState extends State<_TeacherUpcomingExams> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
  }

  @override
  void didUpdateWidget(covariant _TeacherUpcomingExams oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examsDao = ExamsGradesDao(db);
    final membersDao = MembersDao(db);
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Outer stream: teacher's subject assignments for this term — drives
    // the wider "teaches subject" filter (aligned with _TeacherQuickStats).
    return StreamBuilder<List<SubjectTeacher>>(
      stream: membersDao.watchTeacherSubjectsForTerm(
        widget.schoolId,
        widget.userId,
        year: widget.term.year,
        term: widget.term.term,
      ),
      builder: (context, subjectsSnap) {
        final teacherSubjects = subjectsSnap.data ?? [];
        final teacherSubjectIds = teacherSubjects.map((s) => s.subject).toSet();

        return StreamBuilder<List<ExamWithPapers>>(
          stream: examsDao.watchExamsForTerm(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                subjectsSnap.connectionState == ConnectionState.waiting) {
              return const LoadingShimmer();
            }

            final allExams = snap.data ?? [];

            // Collect future papers where this teacher is relevant:
            //  • teacher is the invigilator, OR
            //  • teacher teaches the paper's subject, OR
            //  • teacher created the exam
            final upcoming = <({Exam exam, Paper paper})>[];
            for (final e in allExams) {
              for (final p in e.papers) {
                if (p.start > nowSeconds &&
                    (p.invigilator == widget.userId ||
                        teacherSubjectIds.contains(p.subject) ||
                        e.teacher.id == widget.userId)) {
                  upcoming.add((exam: e.exam, paper: p));
                }
              }
            }

            // Sort by paper start ascending (soonest first)
            upcoming.sort((a, b) => a.paper.start.compareTo(b.paper.start));

            if (upcoming.isEmpty) {
              return EmptyCard(
                icon: Icons.assignment_outlined,
                message: 'No upcoming exams',
              );
            }

            final display = upcoming.take(3).toList();

            return FutureBuilder<List<Subject>>(
              future: _subjectsFuture,
              builder: (context, subSnap) {
                final subjectMap = <int, String>{};
                for (final s in subSnap.data ?? []) {
                  subjectMap[s.id] = s.name;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < display.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: cs.outline.withValues(alpha: 0.06),
                          ),
                        _buildExamRow(
                          examName: display[i].exam.name,
                          subjectName:
                              subjectMap[display[i].paper.subject] ??
                              'Subject ${display[i].paper.subject}',
                          paperStart: display[i].paper.start,
                          status: display[i].paper.status,
                          cs: cs,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExamRow({
    required String examName,
    required String subjectName,
    required BigInt paperStart,
    required PaperStatus status,
    required ColorScheme cs,
  }) {
    final (statusLabel, statusColor) = switch (status) {
      PaperStatus.pending => ('Pending', const Color(0xFFFFA726)),
      PaperStatus.progress => ('In Progress', const Color(0xFF42A5F5)),
      PaperStatus.done => ('Done', const Color(0xFF4CAF50)),
      PaperStatus.marked => ('Marked', const Color(0xFF7C4DFF)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$subjectName · ${fmtDateFromSeconds(paperStart)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
