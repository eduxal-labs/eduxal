import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../cache/file_cache.dart';
import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../models/grade_analytics.dart';
import '../../../../../models/school_context.dart';
import '../student_grade_page.dart';

/// Students tab — shows all enrolled students for a specific stream within a
/// grade. Each row displays the student's avatar, name, admission number,
/// trajectory indicator, and overall average percentage badge.
///
/// Tapping a row navigates to `StudentGradePage`.
class StudentsTab extends StatefulWidget {
  const StudentsTab({
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
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab>
    with AutomaticKeepAliveClientMixin {
  late final AcademicsDao _dao;
  late Stream<List<GradeStudentRow>> _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = AcademicsDao(db);
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant StudentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() => _stream = _buildStream());
    }
  }

  Stream<List<GradeStudentRow>> _buildStream() {
    return _dao.watchStudentsForGrade(
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

    return StreamBuilder<List<GradeStudentRow>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return _buildEmpty(cs);
        }

        return _buildList(cs, rows);
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
                Icons.people_outline_rounded,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No students enrolled',
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
              'Use the + button to enroll students in ${widget.streamName}',
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

  // ── Student list ───────────────────────────────────────────────────────────

  Widget _buildList(ColorScheme cs, List<GradeStudentRow> rows) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(cs, rows.length);
        return _buildStudentItem(cs, rows[index - 1]);
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$count student${count == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ── Student row ────────────────────────────────────────────────────────────

  Widget _buildStudentItem(ColorScheme cs, GradeStudentRow row) {
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _onStudentTap(row),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // ── Avatar ─────────────────────────────────────────────────
                _StudentAvatar(
                  schoolId: widget.schoolId,
                  adm: row.student.adm,
                  cs: cs,
                ),

                const SizedBox(width: 12),

                // ── Name + ADM ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.student.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ADM: ${row.student.adm}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ── Trajectory icon ────────────────────────────────────────
                _TrajectoryIcon(trajectory: row.trajectory, cs: cs),

                const SizedBox(width: 8),

                // ── Average badge ──────────────────────────────────────────
                _AverageBadge(
                  percent: row.overallAverage,
                  cs: cs,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onStudentTap(GradeStudentRow row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentGradePage(
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          grade: widget.grade,
          streamCode: widget.streamCode,
          streamName: widget.streamName,
          studentAdm: row.student.adm,
          curriculumType: widget.curriculumType,
          schoolContext: widget.schoolContext,
        ),
      ),
    );
  }
}

// ─── Student Avatar (cached file-based) ──────────────────────────────────────

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({
    required this.schoolId,
    required this.adm,
    required this.cs,
  });

  final String schoolId;
  final int adm;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.studentImagePath(schoolId, adm)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: 18,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        return CircleAvatar(
          radius: 18,
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: 16,
            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        );
      },
    );
  }
}

// ─── Trajectory icon ─────────────────────────────────────────────────────────

class _TrajectoryIcon extends StatelessWidget {
  const _TrajectoryIcon({required this.trajectory, required this.cs});

  final Trajectory trajectory;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trajectory) {
      Trajectory.improving => (
        Icons.trending_up_rounded,
        const Color(0xFF4CAF50),
      ),
      Trajectory.declining => (
        Icons.trending_down_rounded,
        const Color(0xFFF44336),
      ),
      Trajectory.stable => (
        Icons.trending_flat_rounded,
        const Color(0xFFFFA726),
      ),
      Trajectory.insufficientData => (
        Icons.help_outline_rounded,
        cs.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    };

    return Icon(icon, size: 16, color: color);
  }
}

// ─── Average percentage badge ────────────────────────────────────────────────

class _AverageBadge extends StatelessWidget {
  const _AverageBadge({
    required this.percent,
    required this.cs,
    required this.isDark,
  });

  final double? percent;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = percent != null ? '${percent!.round()}%' : '—';
    final color = percent != null ? _percentColor(percent!) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: isDark ? 0.18 : 0.1)
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color ?? cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  static Color _percentColor(double p) {
    if (p >= 70) return const Color(0xFF4CAF50);
    if (p >= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }
}
