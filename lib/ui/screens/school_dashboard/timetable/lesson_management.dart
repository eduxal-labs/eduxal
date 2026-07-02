import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/school_config.dart';
import '../../../../core/academic_utils.dart';
import '../../../theme/app_theme.dart';
import 'timetable_shared.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Generate Timetable — FAB
// ═════════════════════════════════════════════════════════════════════════════

class GenerateFab extends StatelessWidget {
  const GenerateFab({
    super.key,
    required this.onTap,
    required this.generating,
    required this.cs,
    this.heroTag,
  });

  final VoidCallback onTap;
  final bool generating;
  final ColorScheme cs;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: generating ? null : onTap,
      backgroundColor: AppTheme.brandGreen,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      tooltip: 'Configure rules & generate timetable',
      child: generating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_rounded, size: 20),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Generate Lessons — FAB, dialog, preview, substitution picker
// ═════════════════════════════════════════════════════════════════════════════

/// FAB shown when a timetable already exists — opens the lesson generation dialog.
class GenerateLessonsFab extends StatelessWidget {
  const GenerateLessonsFab({
    super.key,
    required this.onTap,
    required this.cs,
    this.heroTag,
  });

  final VoidCallback onTap;
  final ColorScheme cs;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onTap,
      backgroundColor: AppTheme.brandGreen,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      tooltip: 'Generate lessons from timetable',
      child: const Icon(Icons.auto_awesome_rounded, size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// An in-memory lesson generated from a timetable slot — not yet saved to DB.
class GeneratedLesson {
  GeneratedLesson({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.date,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int date;
  final int subjectId;
  final String subjectName;
  String teacherId;
  String teacherName;
  final int startTime;
  final int endTime;

  LessonsCompanion toCompanion() {
    final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    return LessonsCompanion(
      school: Value(schoolId),
      year: Value(year),
      term: Value(term),
      grade: Value(grade),
      stream: Value(stream),
      date: Value(date),
      subject: Value(subjectId),
      teacher: Value(teacherId),
      created: Value(nowMs),
      updated: Value(nowMs),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Shows the Generate Lessons dialog.
///
/// Desktop (≥ kMobileBreakpoint): centred [Dialog] with max width 480.
/// Mobile (< kMobileBreakpoint): modal bottom sheet (88 % height, top-rounded).
Future<void> showGenerateLessonsDialog(
  BuildContext context, {
  required String schoolId,
  required int year,
  required int term,
  required TimetableDao timetableDao,
  required SchoolConfig config,
}) {
  final isDesktop =
      MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
  if (isDesktop) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _GenerateLessonsDialog(
            schoolId: schoolId,
            year: year,
            term: term,
            timetableDao: timetableDao,
            config: config,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: _GenerateLessonsDialog(
          schoolId: schoolId,
          year: year,
          term: term,
          timetableDao: timetableDao,
          config: config,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _GenerateLessonsDialog extends StatefulWidget {
  const _GenerateLessonsDialog({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.timetableDao,
    required this.config,
  });

  final String schoolId;
  final int year;
  final int term;
  final TimetableDao timetableDao;
  final SchoolConfig config;

  @override
  State<_GenerateLessonsDialog> createState() => _GenerateLessonsDialogState();
}

class _GenerateLessonsDialogState extends State<_GenerateLessonsDialog> {
  // ── State ─────────────────────────────────────────────────────────────────

  int _step = 0; // 0 = scope picker, 1 = preview

  /// null = no selection, 0 = Today, 1 = This Week
  int? _selectedScope;

  bool _loading = false; // true while loading timetable from DB
  bool _saving = false; // true while writing to DB

  List<GeneratedLesson> _preview = [];

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Days since Unix epoch for a [DateTime].
  static int _epochDays(DateTime d) =>
      d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// Map Dart weekday (1=Mon … 7=Sun) to [DayOfWeek].
  static DayOfWeek _dartToDayOfWeek(int dartWeekday) {
    // Dart: Mon=1,Tue=2,...,Sat=6,Sun=7
    // DayOfWeek: sun=0,mon=1,...,sat=6
    return dartWeekday == 7 ? DayOfWeek.sunday : DayOfWeek.values[dartWeekday];
  }

  /// Returns (date: DateTime, dayOfWeek: DayOfWeek) pairs to generate.
  ///
  /// For scope 0 (Today): one entry — today.
  /// For scope 1 (This Week): Monday through Friday of the current calendar week.
  List<({DateTime date, DayOfWeek dow})> _datesForScope(int scope) {
    final now = DateTime.now();
    if (scope == 0) {
      return [
        (
          date: DateTime(now.year, now.month, now.day),
          dow: _dartToDayOfWeek(now.weekday),
        ),
      ];
    }
    // This week Mon–Fri
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(5, (i) {
      final d = monday.add(Duration(days: i));
      return (
        date: DateTime(d.year, d.month, d.day),
        dow: _dartToDayOfWeek(d.weekday),
      );
    });
  }

  Future<void> _generate() async {
    if (_selectedScope == null || _loading) return;
    setState(() => _loading = true);
    try {
      final datePairs = _datesForScope(_selectedScope!);
      final days = datePairs.map((p) => p.dow).toSet().toList();

      final entries = await widget.timetableDao.getTermTimetableForDays(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        days: days,
      );

      // Map timetable entries → GeneratedLesson per (date, slot)
      final generated = <GeneratedLesson>[];
      for (final pair in datePairs) {
        final dayEntries = entries
            .where((e) => e.slot.day == pair.dow)
            .toList();
        for (final e in dayEntries) {
          generated.add(
            GeneratedLesson(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: e.slot.grade,
              stream: e.slot.stream,
              date: _epochDays(pair.date),
              subjectId: e.slot.subject,
              subjectName: e.subjectName,
              teacherId: e.teacher.id,
              teacherName: e.teacher.name,
              startTime: e.slot.start,
              endTime: e.slot.end,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _preview = generated;
          _step = 1;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final account = cache.currentUser;
    if (account == null) return;
    setState(() => _saving = true);
    try {
      final companions = _preview.map((l) => l.toCompanion()).toList();
      await widget.timetableDao.saveLessons(
        lessonsList: companions,
        accountId: account.user.id,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${companions.length} lesson${companions.length == 1 ? '' : 's'} saved.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save lessons: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    final radius = isDesktop
        ? BorderRadius.circular(AppTheme.kModalRadius)
        : const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: radius,
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(cs, isDark, isDesktop),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderColor(isDark, cs),
            ),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _step == 0
                    ? _buildScopeStep(cs, isDark)
                    : _buildPreviewStep(cs, isDark),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderColor(isDark, cs),
            ),
            _buildFooter(cs, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark, bool isDesktop) {
    final title = _step == 0 ? 'Generate Lessons' : 'Preview Lessons';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          if (!isDesktop)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (_step == 1) ...[
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
          if (_step == 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.brandGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              ),
              child: Text(
                '${_preview.length} lesson${_preview.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.brandGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Scope Picker ───────────────────────────────────────────────────

  Widget _buildScopeStep(ColorScheme cs, bool isDark) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final friday = monday.add(const Duration(days: 4));

    String todayLabel() {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
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
      return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
    }

    String weekLabel() {
      const months = [
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
      final m1 = months[monday.month - 1];
      final m2 = months[friday.month - 1];
      if (monday.month == friday.month) {
        return '${monday.day} – ${friday.day} $m1';
      }
      return '${monday.day} $m1 – ${friday.day} $m2';
    }

    return SingleChildScrollView(
      key: const ValueKey('scope'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose how many lessons to generate',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ScopeOptionCard(
                  icon: Icons.today_rounded,
                  title: 'Today',
                  subtitle: todayLabel(),
                  selected: _selectedScope == 0,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedScope = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScopeOptionCard(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'This Week',
                  subtitle: weekLabel(),
                  selected: _selectedScope == 1,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedScope = 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Preview ────────────────────────────────────────────────────────

  Widget _buildPreviewStep(ColorScheme cs, bool isDark) {
    if (_preview.isEmpty) {
      return Padding(
        key: const ValueKey('preview_empty'),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 32,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedScope == 0
                  ? 'No timetable entries for today'
                  : 'No timetable entries for this week',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group preview lessons by date (epoch days)
    final grouped = <int, List<GeneratedLesson>>{};
    for (final l in _preview) {
      grouped.putIfAbsent(l.date, () => []).add(l);
    }
    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      key: const ValueKey('preview_list'),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: () {
        int count = 0;
        for (final date in dates) {
          count += 1 + grouped[date]!.length; // header + rows
        }
        return count;
      }(),
      itemBuilder: (context, index) {
        int cursor = 0;
        for (final date in dates) {
          if (index == cursor) {
            return _PreviewDateHeader(date: date, cs: cs);
          }
          cursor++;
          final dayLessons = grouped[date]!;
          for (int i = 0; i < dayLessons.length; i++) {
            if (index == cursor) {
              return _PreviewLessonItem(
                lesson: dayLessons[i],
                allLessons: _preview,
                cs: cs,
                isDark: isDark,
                timetableDao: widget.timetableDao,
                schoolId: widget.schoolId,
                year: widget.year,
                term: widget.term,
                config: widget.config,
                onChanged: () => setState(() {}),
              );
            }
            cursor++;
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, bool isDark) {
    if (_step == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.5),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: (_selectedScope == null || _loading)
                  ? null
                  : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Generate'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.brandGreen.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                minimumSize: const Size(0, 38),
              ),
            ),
          ],
        ),
      );
    }

    // Step 1 footer: Discard + Save
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface.withValues(alpha: 0.5),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: const Text('Discard'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: (_saving || _preview.isEmpty) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text(
              'Save ${_preview.length} lesson${_preview.length == 1 ? '' : 's'}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.brandGreen.withValues(
                alpha: 0.35,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              minimumSize: const Size(0, 38),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScopeOptionCard extends StatefulWidget {
  const _ScopeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_ScopeOptionCard> createState() => _ScopeOptionCardState();
}

class _ScopeOptionCardState extends State<_ScopeOptionCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg {
    if (widget.selected) {
      return widget.cs.primary.withValues(alpha: 0.08);
    }
    if (_pressed) return AppTheme.nestedBg(widget.isDark, widget.cs);
    if (_hovered) {
      return widget.cs.primary.withValues(alpha: 0.04);
    }
    return AppTheme.nestedBg(widget.isDark, widget.cs);
  }

  Color get _borderColor {
    if (widget.selected) return widget.cs.primary;
    if (_hovered) return widget.cs.primary.withValues(alpha: 0.4);
    return AppTheme.borderColor(widget.isDark, widget.cs);
  }

  double get _borderWidth => widget.selected ? 1.5 : 1.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: _borderColor, width: _borderWidth),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? widget.cs.primary.withValues(alpha: 0.12)
                        : AppTheme.borderColor(
                            widget.isDark,
                            widget.cs,
                          ).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: widget.selected
                        ? widget.cs.primary
                        : widget.cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.selected
                        ? widget.cs.primary
                        : widget.cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: widget.cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _PreviewDateHeader extends StatelessWidget {
  const _PreviewDateHeader({required this.date, required this.cs});

  final int date; // days since epoch
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        formatDateFromDays(date),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PreviewLessonItem extends StatelessWidget {
  const _PreviewLessonItem({
    required this.lesson,
    required this.allLessons,
    required this.cs,
    required this.isDark,
    required this.timetableDao,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.onChanged,
  });

  final GeneratedLesson lesson;
  final List<GeneratedLesson> allLessons;
  final ColorScheme cs;
  final bool isDark;
  final TimetableDao timetableDao;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final VoidCallback onChanged;

  String _gradeStreamLabel() {
    // Grade label
    String gradeLabel = 'Grade ${lesson.grade}';
    for (final cur in config.curricula) {
      final labels = gradeLabelsFor(cur.type);
      final l = labels[lesson.grade];
      if (l != null) {
        gradeLabel = l;
        break;
      }
    }
    // Stream label
    String streamLabel = '';
    outer:
    for (final cur in config.curricula) {
      for (final gc in cur.grades) {
        if (gc.grade == lesson.grade) {
          for (final s in gc.streams) {
            if (s.code == lesson.stream) {
              streamLabel = s.name;
              break outer;
            }
          }
        }
      }
    }
    return streamLabel.isNotEmpty ? '$gradeLabel · $streamLabel' : gradeLabel;
  }

  @override
  Widget build(BuildContext context) {
    final timeRange =
        '${fmtTimeSec(lesson.startTime)} – ${fmtTimeSec(lesson.endTime)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colour dot
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorForSubject(lesson.subjectId),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.teacherName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Grade/stream badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.nestedBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              _gradeStreamLabel(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Edit icon
          GestureDetector(
            onTap: () => _showSubstitutePickerDialog(
              context,
              lesson: lesson,
              allLessons: allLessons,
              timetableDao: timetableDao,
              schoolId: schoolId,
              year: year,
              term: term,
              cs: cs,
              isDark: isDark,
              onChanged: onChanged,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.edit_outlined,
                size: 15,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showSubstitutePickerDialog(
  BuildContext context, {
  required GeneratedLesson lesson,
  required List<GeneratedLesson> allLessons,
  required TimetableDao timetableDao,
  required String schoolId,
  required int year,
  required int term,
  required ColorScheme cs,
  required bool isDark,
  required VoidCallback onChanged,
}) async {
  final isDesktop =
      MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
  if (isDesktop) {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _SubstitutePickerDialog(
            lesson: lesson,
            allLessons: allLessons,
            timetableDao: timetableDao,
            schoolId: schoolId,
            year: year,
            term: term,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.70,
        ),
        child: _SubstitutePickerDialog(
          lesson: lesson,
          allLessons: allLessons,
          timetableDao: timetableDao,
          schoolId: schoolId,
          year: year,
          term: term,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SubstitutePickerDialog extends StatefulWidget {
  const _SubstitutePickerDialog({
    required this.lesson,
    required this.allLessons,
    required this.timetableDao,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.onChanged,
  });

  final GeneratedLesson lesson;
  final List<GeneratedLesson> allLessons;
  final TimetableDao timetableDao;
  final String schoolId;
  final int year;
  final int term;
  final VoidCallback onChanged;

  @override
  State<_SubstitutePickerDialog> createState() =>
      _SubstitutePickerDialogState();
}

class _SubstitutePickerDialogState extends State<_SubstitutePickerDialog> {
  bool _loading = true;

  /// (id, name, hasConflict)
  List<({String id, String name, bool hasConflict})> _candidates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Collect all teachers from the preview that teach this subject.
    final seen = <String>{};
    final candidates = <({String id, String name, bool hasConflict})>[];
    for (final l in widget.allLessons) {
      if (l.subjectId != widget.lesson.subjectId) continue;
      if (!seen.add(l.teacherId)) continue;
      final conflict = widget.allLessons.any(
        (other) =>
            other != widget.lesson &&
            other.teacherId == l.teacherId &&
            other.date == widget.lesson.date &&
            other.startTime < widget.lesson.endTime &&
            other.endTime > widget.lesson.startTime,
      );
      candidates.add((
        id: l.teacherId,
        name: l.teacherName,
        hasConflict: conflict,
      ));
    }
    if (mounted) {
      setState(() {
        _candidates = candidates;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    final radius = isDesktop
        ? BorderRadius.circular(AppTheme.kModalRadius)
        : const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: radius,
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Change Teacher',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.lesson.subjectName} · '
                    '${fmtTimeSec(widget.lesson.startTime)}–'
                    '${fmtTimeSec(widget.lesson.endTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderColor(isDark, cs),
            ),
            // Teacher list
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _candidates.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No other teachers assigned to this subject.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _candidates.length,
                      separatorBuilder: (_, _) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (_, i) {
                        final c = _candidates[i];
                        final isSelected = c.id == widget.lesson.teacherId;
                        return InkWell(
                          onTap: c.hasConflict
                              ? null
                              : () {
                                  widget.lesson.teacherId = c.id;
                                  widget.lesson.teacherName = c.name;
                                  widget.onChanged();
                                  Navigator.of(context).pop();
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.07)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Avatar initial
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? cs.primary.withValues(alpha: 0.15)
                                        : cs.surfaceContainerHighest.withValues(
                                            alpha: 0.5,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    c.name.isNotEmpty
                                        ? c.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? cs.primary
                                          : cs.onSurfaceVariant.withValues(
                                              alpha: 0.6,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: c.hasConflict
                                          ? cs.onSurface.withValues(alpha: 0.35)
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status badge
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.kChipRadius,
                                      ),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: cs.primary,
                                      ),
                                    ),
                                  )
                                else if (c.hasConflict)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.error.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.kChipRadius,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 11,
                                          color: cs.error.withValues(
                                            alpha: 0.75,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Conflict',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: cs.error.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandGreen.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.kChipRadius,
                                      ),
                                    ),
                                    child: Text(
                                      'Available',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.brandGreen.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OWNER — Lessons Tab  (Log · Teachers · Coverage)
// ═══════════════════════════════════════════════════════════════════════════

enum _LessonView { log, teachers, coverage }

class LessonsTab extends StatefulWidget {
  const LessonsTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.timetableDao,
    required this.config,
  });

  final String schoolId;
  final int year;
  final int term;
  final TimetableDao timetableDao;
  final SchoolConfig config;

  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  _LessonView _view = _LessonView.log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<LessonEntry>>(
      stream: widget.timetableDao.watchAllLessons(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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

        final lessons = snapshot.data ?? [];

        if (lessons.isEmpty) {
          return _LessonsEmptyState(cs: cs);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LessonStatsBar(lessons: lessons, cs: cs, isDark: isDark),
            _LessonViewSwitcher(
              view: _view,
              cs: cs,
              isDark: isDark,
              onChanged: (v) => setState(() => _view = v),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: switch (_view) {
                  _LessonView.log => _LessonLogView(
                    key: const ValueKey('log'),
                    lessons: lessons,
                    config: widget.config,
                    cs: cs,
                    isDark: isDark,
                  ),
                  _LessonView.teachers => _LessonTeachersView(
                    key: const ValueKey('teachers'),
                    lessons: lessons,
                    config: widget.config,
                    cs: cs,
                    isDark: isDark,
                  ),
                  _LessonView.coverage => _LessonCoverageView(
                    key: const ValueKey('coverage'),
                    lessons: lessons,
                    cs: cs,
                    isDark: isDark,
                  ),
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stats bar ────────────────────────────────────────────────────────────────

class _LessonStatsBar extends StatelessWidget {
  const _LessonStatsBar({
    required this.lessons,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final teacherCount = lessons.map((e) => e.teacher.id).toSet().length;
    final subjectCount = lessons.map((e) => e.lesson.subject).toSet().length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _LessonStatChip(
              value: '${lessons.length}',
              label: 'Lessons',
              cs: cs,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LessonStatChip(
              value: '$teacherCount',
              label: teacherCount == 1 ? 'Teacher' : 'Teachers',
              cs: cs,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LessonStatChip(
              value: '$subjectCount',
              label: subjectCount == 1 ? 'Subject' : 'Subjects',
              cs: cs,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonStatChip extends StatelessWidget {
  const _LessonStatChip({
    required this.value,
    required this.label,
    required this.cs,
    required this.isDark,
  });

  final String value;
  final String label;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── View switcher ─────────────────────────────────────────────────────────────

class _LessonViewSwitcher extends StatelessWidget {
  const _LessonViewSwitcher({
    required this.view,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final _LessonView view;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<_LessonView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _LessonViewChip(
            label: 'Log',
            selected: view == _LessonView.log,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(_LessonView.log),
          ),
          const SizedBox(width: 6),
          _LessonViewChip(
            label: 'Teachers',
            selected: view == _LessonView.teachers,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(_LessonView.teachers),
          ),
          const SizedBox(width: 6),
          _LessonViewChip(
            label: 'Coverage',
            selected: view == _LessonView.coverage,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(_LessonView.coverage),
          ),
        ],
      ),
    );
  }
}

class _LessonViewChip extends StatelessWidget {
  const _LessonViewChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.4)
                : AppTheme.borderColor(isDark, cs),
            width: selected ? 1.0 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ── Log view ──────────────────────────────────────────────────────────────────

class _LessonLogView extends StatelessWidget {
  const _LessonLogView({
    super.key,
    required this.lessons,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<LessonEntry>>{};
    for (final e in lessons) {
      grouped.putIfAbsent(e.lesson.date, () => []).add(e);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final items = <Widget>[];
    for (final date in dates) {
      final dayLessons = grouped[date]!;
      items.add(
        _LessonDayHeader(
          date: date,
          count: dayLessons.length,
          cs: cs,
          isDark: isDark,
        ),
      );
      for (int i = 0; i < dayLessons.length; i++) {
        items.add(
          _LessonLogRow(
            entry: dayLessons[i],
            config: config,
            cs: cs,
            isDark: isDark,
          ),
        );
        if (i < dayLessons.length - 1) {
          items.add(AppTheme.tableRowDivider(isDark, cs));
        }
      }
      items.add(const SizedBox(height: 8));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _LessonDayHeader extends StatelessWidget {
  const _LessonDayHeader({
    required this.date,
    required this.count,
    required this.cs,
    required this.isDark,
  });

  final int date;
  final int count;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            _lessonDayLabel(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.75),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.5,
              ),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonLogRow extends StatelessWidget {
  const _LessonLogRow({
    required this.entry,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final LessonEntry entry;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subjectColor = colorForSubject(entry.lesson.subject);
    final classLabel = _lessonClassLabel(
      entry.lesson.grade,
      entry.lesson.stream,
      config,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: subjectColor.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.subjectName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.teacher.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.55 : 0.5,
                ),
                borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              ),
              child: Text(
                classLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Teachers view ─────────────────────────────────────────────────────────────

class _LessonTeachersView extends StatefulWidget {
  const _LessonTeachersView({
    super.key,
    required this.lessons,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_LessonTeachersView> createState() => _LessonTeachersViewState();
}

class _LessonTeachersViewState extends State<_LessonTeachersView> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    final map = <String, ({String name, List<LessonEntry> lessons})>{};
    for (final e in widget.lessons) {
      final id = e.teacher.id;
      final existing = map[id];
      if (existing == null) {
        map[id] = (name: e.teacher.name, lessons: [e]);
      } else {
        existing.lessons.add(e);
      }
    }

    final teachers = map.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.lessons.length.compareTo(a.value.lessons.length);
        return cmp != 0 ? cmp : a.value.name.compareTo(b.value.name);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: teachers.length,
      itemBuilder: (context, i) {
        final tid = teachers[i].key;
        final tdata = teachers[i].value;
        final isExpanded = _expanded.contains(tid);

        final allSubjects = tdata.lessons
            .map((e) => e.subjectName)
            .toSet()
            .toList();
        final previewSubjects = allSubjects.take(3).join(', ');
        final extraCount = allSubjects.length - 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expanded.remove(tid);
                } else {
                  _expanded.add(tid);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tdata.name.isNotEmpty
                            ? tdata.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tdata.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            extraCount > 0
                                ? '$previewSubjects +$extraCount more'
                                : previewSubjects,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.5 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        '${tdata.lessons.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeInOut,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  color: AppTheme.nestedBg(isDark, cs),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: () {
                    final sorted = [...tdata.lessons]
                      ..sort((a, b) => b.lesson.date.compareTo(a.lesson.date));
                    final rows = <Widget>[];
                    for (int j = 0; j < sorted.length; j++) {
                      rows.add(
                        _TeacherLessonSubRow(
                          entry: sorted[j],
                          config: widget.config,
                          cs: cs,
                          isDark: isDark,
                        ),
                      );
                      if (j < sorted.length - 1) {
                        rows.add(AppTheme.tableRowDivider(isDark, cs));
                      }
                    }
                    return rows;
                  }(),
                ),
              ),
            ),
            AppTheme.tableRowDivider(isDark, cs),
          ],
        );
      },
    );
  }
}

class _TeacherLessonSubRow extends StatelessWidget {
  const _TeacherLessonSubRow({
    required this.entry,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final LessonEntry entry;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subjectColor = colorForSubject(entry.lesson.subject);
    final classLabel = _lessonClassLabel(
      entry.lesson.grade,
      entry.lesson.stream,
      config,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: subjectColor.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.subjectName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.35,
              ),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              classLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatDateFromDays(entry.lesson.date),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coverage view ─────────────────────────────────────────────────────────────

class _LessonCoverageView extends StatelessWidget {
  const _LessonCoverageView({
    super.key,
    required this.lessons,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final map = <int, ({String name, int count})>{};
    for (final e in lessons) {
      final id = e.lesson.subject;
      final existing = map[id];
      map[id] = (name: e.subjectName, count: (existing?.count ?? 0) + 1);
    }

    final subjects = map.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    final maxCount = subjects.isEmpty ? 1 : subjects.first.value.count;

    return ListView.separated(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: subjects.length,
      separatorBuilder: (_, _) => AppTheme.tableRowDivider(isDark, cs),
      itemBuilder: (context, i) {
        final subjectId = subjects[i].key;
        final data = subjects[i].value;
        final fraction = data.count / maxCount;
        final subjectColor = colorForSubject(subjectId);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: subjectColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 4,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: subjectColor.withValues(
                                  alpha: isDark ? 0.12 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              height: 4,
                              width: constraints.maxWidth * fraction,
                              decoration: BoxDecoration(
                                color: subjectColor.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${data.count}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.8),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                data.count == 1 ? 'lesson' : 'lessons',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _LessonsEmptyState extends StatelessWidget {
  const _LessonsEmptyState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Generate lessons from the Timetable tab',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats days-since-epoch to "Mon, 15 Jan".
String _lessonDayLabel(int daysSinceEpoch) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const months = [
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
  final d = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  // DateTime.weekday: 1=Mon … 7=Sun.  % 7 maps Sun→0, Mon→1 … Sat→6.
  return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]}';
}

/// Returns "Form 4 · Blue" or "Grade 3" etc., using config for label lookup.
String _lessonClassLabel(int grade, int stream, SchoolConfig config) {
  String gradeLabel = 'Grade $grade';
  String streamLabel = '';
  outer:
  for (final cur in config.curricula) {
    final labels = gradeLabelsFor(cur.type);
    if (labels.containsKey(grade)) gradeLabel = labels[grade]!;
    for (final gc in cur.grades) {
      if (gc.grade == grade) {
        for (final s in gc.streams) {
          if (s.code == stream) {
            streamLabel = s.name;
            break outer;
          }
        }
      }
    }
  }
  return streamLabel.isNotEmpty ? '$gradeLabel · $streamLabel' : gradeLabel;
}
