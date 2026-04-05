import 'dart:math' as math;

import 'package:flutter/material.dart' hide Action;

import '../../../../core/formatters.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/school_config.dart';

import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paper grouping helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<DateTime, List<Paper>> groupPapersByDate(List<Paper> papers) {
  final map = <DateTime, List<Paper>>{};
  for (final p in papers) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    final day = DateTime(dt.year, dt.month, dt.day);
    map.putIfAbsent(day, () => []).add(p);
  }
  // Sort papers within each day by start time
  for (final list in map.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return map;
}

List<DateTime> sortedPaperDates(Map<DateTime, List<Paper>> grouped) {
  final dates = grouped.keys.toList()..sort();
  return dates;
}

List<({String start, String end})> uniquePaperStartTimes(List<Paper> papers) {
  final seen = <String>{};
  final result = <({String start, String end})>[];
  final sorted = List<Paper>.from(papers)
    ..sort((a, b) => a.start.compareTo(b.start));
  for (final p in sorted) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    final endDt = DateTime.fromMillisecondsSinceEpoch(p.end.toInt() * 1000);
    final startStr = fmtTimeDt(startDt);
    if (!seen.contains(startStr)) {
      seen.add(startStr);
      result.add((start: startStr, end: fmtTimeDt(endDt)));
    }
  }
  return result;
}

List<Paper> papersAt(
  Map<DateTime, List<Paper>> grouped,
  DateTime date,
  String startTime,
) {
  final day = DateTime(date.year, date.month, date.day);
  final papers = grouped[day] ?? [];
  return papers.where((p) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    return fmtTimeDt(dt) == startTime;
  }).toList();
}

String fmtDayHeader(DateTime d) {
  final wd = kDayNames[d.weekday - 1];
  return '$wd, ${d.day} ${kMonthNames[d.month - 1]}';
}

String fmtDayColumn(DateTime d) {
  final wd = kDayNames[d.weekday - 1];
  return '$wd ${d.day}';
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionHeader + HeaderAction
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leadingAction,
  });
  final String title;
  final String subtitle;
  final HeaderAction? leadingAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          if (leadingAction != null) ...[
            IconButton(
              onPressed: leadingAction!.onTap,
              icon: Icon(leadingAction!.icon, size: 20),
              tooltip: leadingAction!.label,
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurface,
                minimumSize: const Size(36, 36),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClassChip, MetaBadge, StatusChip
// ─────────────────────────────────────────────────────────────────────────────

class ClassChip extends StatelessWidget {
  const ClassChip({super.key, required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class MetaBadge extends StatelessWidget {
  const MetaBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.cs,
  });
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.cs});
  final PaperStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaperStatus.pending => ('Pending', cs.onSurfaceVariant),
      PaperStatus.progress => ('In Progress', const Color(0xFFF59E0B)),
      PaperStatus.done => ('Done', cs.primary),
      PaperStatus.marked => ('Marked', AppTheme.brandGreen),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / no-data states
// ─────────────────────────────────────────────────────────────────────────────

class EmptyExamsState extends StatelessWidget {
  const EmptyExamsState({super.key, required this.canCreate});
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                Icons.assignment_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No exams this term',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              canCreate
                  ? 'Use the + button to create your first exam.'
                  : 'Exams created by teachers will appear here.',
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
}

class NoStudentsState extends StatelessWidget {
  const NoStudentsState({super.key, required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      child: Center(
        child: Text(
          'No students enrolled in this class.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class NoTermState extends StatelessWidget {
  const NoTermState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Select a term to view exams and grades.',
        style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class RestrictedAccessState extends StatelessWidget {
  const RestrictedAccessState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                Icons.lock_outline_rounded,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Not available',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Exam management is not available for your role.\n'
              'Your grades will appear in the Grades section.',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

String examGradeLabel(int grade, SchoolConfig config) {
  for (final c in config.curricula) {
    final labels = gradeLabelsFor(c.type);
    if (labels.containsKey(grade)) return labels[grade]!;
  }
  return 'Grade $grade';
}

String examStreamLabel(int grade, int streamCode, SchoolConfig config) {
  for (final c in config.curricula) {
    final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
    if (gc != null) {
      final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
      if (s != null) return s.name;
    }
  }
  return 'Stream $streamCode';
}

String typeLabel(ExamType type) => switch (type) {
  ExamType.exam => 'Exam',
  ExamType.assignment => 'Assignment',
  ExamType.assessment => 'Assessment',
};

Color paperStatusColor(PaperStatus status, ColorScheme cs) => switch (status) {
  PaperStatus.pending => cs.onSurfaceVariant.withValues(alpha: 0.3),
  PaperStatus.progress => const Color(0xFF42A5F5),
  PaperStatus.done => const Color(0xFFFFA726),
  PaperStatus.marked => const Color(0xFF66BB6A),
};

String paperStatusLabel(PaperStatus status) => switch (status) {
  PaperStatus.pending => 'Pending',
  PaperStatus.progress => 'In Progress',
  PaperStatus.done => 'Done',
  PaperStatus.marked => 'Marked',
};

Color typeColor(ExamType type, ColorScheme cs) => switch (type) {
  ExamType.exam => cs.primary,
  ExamType.assignment => const Color(0xFFF59E0B),
  ExamType.assessment => AppTheme.brandGreen,
};

Color examPctColor(double pct, ColorScheme cs) {
  if (pct >= 70) return AppTheme.brandGreen;
  if (pct >= 50) return const Color(0xFFF59E0B);
  return cs.error;
}

InputDecoration inputDeco(ColorScheme cs, {String? label}) {
  final isDark = cs.brightness == Brightness.dark;
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
    ),
    filled: true,
    fillColor: isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55),
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}

/// Generates a simple time-based unique id.
String generateId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rand = (math.Random().nextInt(0x7FFFFFFF));
  return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
}
