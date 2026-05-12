import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/grade_analytics.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import 'paper_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subject Detail Page
//
// Shows a single subject's assignments and assessments for a specific class
// (grade + stream).  Includes a compact mastery header, tab-based paper lists,
// and a FAB for creating new papers (owner / assigned teacher only).
// ─────────────────────────────────────────────────────────────────────────────

class SubjectDetailPage extends StatefulWidget {
  const SubjectDetailPage({
    super.key,
    required this.schoolContext,
    required this.subjectEntry,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
  });

  final SchoolContext schoolContext;
  final SubjectTeacherEntry subjectEntry;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final CurriculumType curriculumType;

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage>
    with TickerProviderStateMixin {
  // ── Tab controllers ──────────────────────────────────────────────────────
  late final TabController _tabCtrl;

  // ── Entrance animation ───────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // ── FAB animation ────────────────────────────────────────────────────────
  late final AnimationController _fabCtrl;
  late final Animation<double> _fabScale;

  // ── DAO ──────────────────────────────────────────────────────────────────
  late final ExamsGradesDao _dao;

  // ── Permission state ─────────────────────────────────────────────────────
  bool _canCreate = false;
  StreamSubscription? _teacherSub;

  // ── Subject name lookup ──────────────────────────────────────────────────
  final Map<int, String> _subjectNames = {};

  bool get _isOwner =>
      widget.schoolContext.currentEntry.value is OwnerEntry;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));
    _entranceCtrl.forward();

    _tabCtrl = TabController(length: 2, vsync: this);

    final canCreate = _isOwner;
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: canCreate ? 1.0 : 0.0,
    );
    _fabScale = CurvedAnimation(
      parent: _fabCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _dao = ExamsGradesDao(db);

    // Populate subject name map.
    _subjectNames[widget.subjectEntry.subject.subject] =
        widget.subjectEntry.subjectName;

    // Teacher permission: watch assigned subjects.
    final entry = widget.schoolContext.currentEntry.value;
    if (entry is TeacherEntry) {
      _teacherSub = MembersDao(db)
          .watchTeacherSubjectsForTerm(
            widget.schoolId,
            entry.teacher.user,
            year: widget.year,
            term: widget.term,
          )
          .listen(_updateTeacherPermission);
    }
  }

  void _updateTeacherPermission(List<SubjectTeacher> subjects) {
    if (!mounted) return;
    final assigned = subjects.any(
      (st) =>
          st.grade == widget.grade &&
          st.stream == widget.streamCode &&
          st.subject == widget.subjectEntry.subject.subject,
    );
    if (assigned != _canCreate) {
      setState(() => _canCreate = assigned);
      if (assigned) {
        _fabCtrl.forward();
      } else {
        _fabCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _tabCtrl.dispose();
    _fabCtrl.dispose();
    _teacherSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final entry = widget.subjectEntry;
    final canCreate = _isOwner || _canCreate;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.subjectName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            Text(
              '${widget.streamName} · Grade ${widget.grade}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMasteryHeader(entry, cs, isDark),
              Container(
                color: cs.surface,
                child: EduTabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    EduTab(label: 'Assignments'),
                    EduTab(label: 'Assessments'),
                  ],
                  isScrollable: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                ),
              ),
              Container(
                height: 1,
                color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildPapersTab(cs, isDark, ExamType.assignment),
                    _buildPapersTab(cs, isDark, ExamType.assessment),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(canCreate, cs, isDark),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mastery header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMasteryHeader(
      SubjectTeacherEntry entry, ColorScheme cs, bool isDark) {
    final color = _subjectColor(entry.subject.subject);
    final hasData =
        entry.streamMasteryAverage != null || entry.gradeMasteryAverage != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          side: BorderSide(
            color: cs.outline.withValues(alpha: isDark ? 0.10 : 0.06),
            width: 0.5,
          ),
        ),
        color: isDark
            ? color.withValues(alpha: 0.06)
            : color.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    'Class Mastery',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (!hasData) ...[
                const SizedBox(height: 10),
                Text(
                  'No mastery data yet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                _MasteryBar(
                  label: 'Stream Avg',
                  value: entry.streamMasteryAverage,
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _MasteryBar(
                  label: 'Grade Avg',
                  value: entry.gradeMasteryAverage,
                  cs: cs,
                  isDark: isDark,
                ),
                if (entry.streamMasteryAverage != null &&
                    entry.gradeMasteryAverage != null) ...[
                  const SizedBox(height: 6),
                  _buildDelta(
                      entry.streamMasteryAverage!, entry.gradeMasteryAverage!,
                      cs),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Papers tab content
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPapersTab(ColorScheme cs, bool isDark, ExamType type) {
    final schoolId = widget.schoolId;
    final grade = widget.grade;
    final stream = widget.streamCode;
    final subject = widget.subjectEntry.subject.subject;

    return StreamBuilder<List<PaperWithExamInfo>>(
      stream: _dao.watchPapersForSubjectClass(
        schoolId: schoolId,
        grade: grade,
        stream: stream,
        subject: subject,
        examType: type.index,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: cs.primary),
          );
        }

        final papers = snapshot.data ?? [];

        if (papers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(
                        alpha: isDark ? 0.5 : 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    type == ExamType.assignment
                        ? Icons.assignment_outlined
                        : Icons.quiz_outlined,
                    size: 24,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  type == ExamType.assignment
                      ? 'No assignments'
                      : 'No assessments',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type == ExamType.assignment
                      ? 'Assignments for this subject will appear here.'
                      : 'Assessments for this subject will appear here.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color:
                        cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: papers.length,
          itemBuilder: (context, index) =>
              _buildPaperCard(cs, isDark, papers[index]),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Paper card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPaperCard(
      ColorScheme cs, bool isDark, PaperWithExamInfo entry) {
    final paper = entry.paper;
    final exam = entry.exam;
    final teacher = entry.teacher;
    final color = _subjectColor(widget.subjectEntry.subject.subject);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaperDetailPage(
                paper: paper,
                exam: (exam: exam, papers: [paper], teacher: teacher),
                schoolId: widget.schoolId,
                year: widget.year,
                term: widget.term,
                grade: widget.grade,
                curriculumType: widget.curriculumType,
                schoolContext: widget.schoolContext,
                subjectNames: _subjectNames,
                streamNames: {widget.streamCode: widget.streamName},
              ),
            ),
          );
        },
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            side: BorderSide(
              color: cs.outline.withValues(alpha: isDark ? 0.10 : 0.06),
              width: 0.5,
            ),
          ),
          color: cs.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Left accent strip.
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                // Content.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusBadge(status: paper.status, cs: cs, isDark: isDark),
                          const SizedBox(width: 8),
                          Text(
                            _fmtDate(paper.start.toInt()),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          if (paper.topic != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '#${paper.topic}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Average score for marked papers.
                if (paper.status == PaperStatus.marked)
                  _AverageChip(
                    schoolId: widget.schoolId,
                    examId: exam.id,
                    subject: paper.subject,
                    paperNum: paper.paper,
                    dao: _dao,
                    cs: cs,
                    isDark: isDark,
                  ),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFab(bool canCreate, ColorScheme cs, bool isDark) {
    return ScaleTransition(
      scale: _fabScale,
      alignment: Alignment.center,
      child: FloatingActionButton.small(
        heroTag: 'fab_subject_detail',
        onPressed: canCreate
            ? () => _showCreateSheet(context, cs, isDark)
            : null,
        tooltip: 'Create',
        elevation: 4,
        highlightElevation: 6,
        backgroundColor:
            canCreate ? cs.primary : cs.surfaceContainerHighest,
        foregroundColor: canCreate
            ? cs.onPrimary
            : cs.onSurfaceVariant.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add_rounded, size: 20),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Create sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showCreateSheet(BuildContext context, ColorScheme cs, bool isDark) {
    showEduSheet(
      context: context,
      title: '${widget.subjectEntry.subjectName} · ${widget.streamName}',
      builder: (ctx) => _CreatePaperSheet(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
        streamCode: widget.streamCode,
        streamName: widget.streamName,
        subjectId: widget.subjectEntry.subject.subject,
        subjectName: widget.subjectEntry.subjectName,
        curriculumType: widget.curriculumType,
        schoolContext: widget.schoolContext,
        dao: _dao,
        onCreated: (paper, exam, teacher) {
          // Pop the sheet, then push the new paper's detail page.
          Navigator.of(ctx).pop();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaperDetailPage(
                paper: paper,
                exam: (exam: exam, papers: [paper], teacher: teacher),
                schoolId: widget.schoolId,
                year: widget.year,
                term: widget.term,
                grade: widget.grade,
                curriculumType: widget.curriculumType,
                schoolContext: widget.schoolContext,
                subjectNames: _subjectNames,
                streamNames: {widget.streamCode: widget.streamName},
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _fmtDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  static String _statusLabel(PaperStatus s) => switch (s) {
        PaperStatus.pending => 'Pending',
        PaperStatus.progress => 'In Progress',
        PaperStatus.done => 'Done',
        PaperStatus.marked => 'Marked',
      };

  static Color _statusColor(PaperStatus s) => switch (s) {
        PaperStatus.pending => const Color(0xFF78909C),
        PaperStatus.progress => const Color(0xFF42A5F5),
        PaperStatus.done => const Color(0xFFFFA726),
        PaperStatus.marked => const Color(0xFF66BB6A),
      };

  Widget _buildDelta(double stream, double grade, ColorScheme cs) {
    final delta = stream - grade;
    if (delta.abs() < 0.05) {
      return Text('Same as grade average',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45)));
    }
    final positive = delta > 0;
    final c = positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final sign = positive ? '+' : '';
    final icon = positive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 3),
      Text('$sign${delta.toStringAsFixed(1)}% vs grade',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: c)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

Color _subjectColor(int subject) {
  const palette = [
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];
  return palette[subject % palette.length];
}

/// A colored status pill.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.cs,
    required this.isDark,
  });

  final PaperStatus status;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = _SubjectDetailPageState._statusLabel(status);
    final color = _SubjectDetailPageState._statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

/// Compact mastery progress bar.
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

  static Color _pcColor(double percent) {
    if (percent >= 70) return const Color(0xFF4CAF50);
    if (percent >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final percent = value ?? 0.0;
    final barColor = value != null ? _pcColor(percent) : null;
    final display = value != null ? '${value!.toStringAsFixed(1)}%' : '—';
    return Row(children: [
      SizedBox(
        width: 68,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55))),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: value != null ? (percent / 100).clamp(0.0, 1.0) : 0.0,
              backgroundColor: cs.surfaceContainerHighest
                  .withValues(alpha: isDark ? 0.6 : 0.8),
              valueColor: AlwaysStoppedAnimation<Color>(
                  barColor ?? cs.surfaceContainerHighest),
              minHeight: 6,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 42,
        child: Text(display,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    barColor ?? cs.onSurfaceVariant.withValues(alpha: 0.35))),
      ),
    ]);
  }
}

/// Average score chip for marked papers.  Loads analytics lazily.
class _AverageChip extends StatelessWidget {
  const _AverageChip({
    required this.schoolId,
    required this.examId,
    required this.subject,
    required this.paperNum,
    required this.dao,
    required this.cs,
    required this.isDark,
  });

  final String schoolId;
  final String examId;
  final int subject;
  final int? paperNum;
  final ExamsGradesDao dao;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaperAnalytics>(
      future: dao.computePaperAnalytics(
        schoolId: schoolId,
        examId: examId,
        subject: subject,
        paper: paperNum,
        totalEnrolled: 0,
      ),
      builder: (context, snapshot) {
        final analytics = snapshot.data;
        final avg = analytics?.averagePercent;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF66BB6A).withValues(
                alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            avg != null ? 'Avg ${avg.toStringAsFixed(0)}%' : '—',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF66BB6A),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Paper Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePaperSheet extends StatefulWidget {
  const _CreatePaperSheet({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.subjectId,
    required this.subjectName,
    required this.curriculumType,
    required this.schoolContext,
    required this.dao,
    required this.onCreated,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final int subjectId;
  final String subjectName;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;
  final ExamsGradesDao dao;
  final void Function(Paper paper, Exam exam, UsersData teacher) onCreated;

  @override
  State<_CreatePaperSheet> createState() => _CreatePaperSheetState();
}

class _CreatePaperSheetState extends State<_CreatePaperSheet> {
  int _step = 0;
  ExamType? _pickedType;

  final _nameCtrl = TextEditingController();
  final _marksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final Set<int> _selectedTopicIds = {};
  bool _creating = false;
  String? _error;

  late final int _currentGrade;
  late final List<MapEntry<int, String>> _allowedGrades;
  late int _selectedGrade;

  @override
  void initState() {
    super.initState();
    _currentGrade = widget.grade;
    _selectedGrade = _currentGrade;
    _allowedGrades = _computeAllowedGrades();
  }

  List<MapEntry<int, String>> _computeAllowedGrades() {
    final labels = gradeLabelsFor(widget.curriculumType);
    final entries = labels.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final curIsForm = _currentGrade >= 41;
    return entries.where((e) {
      final g = e.key;
      final gIsForm = g >= 41;
      // Disallow cross-band: Form students only see Form grades, Standard
      // students only see Standard grades.
      if (curIsForm != gIsForm) return false;
      // Only grades up to (and including) the current grade.
      return g <= _currentGrade;
    }).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18222E) : cs.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF2A3848)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: _step == 0
            ? _buildTypePicker(cs, isDark)
            : _buildConfigForm(cs, isDark),
      ),
    );
  }

  // ── Step 0: pick type ───────────────────────────────────────────────────

  Widget _buildTypePicker(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sheet handle
          Center(
            child: Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Paper',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose the type of paper to create.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 17,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _SheetDivider(isDark: isDark, cs: cs),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              children: [
                _TypeTile(
                  icon: Icons.assignment_outlined,
                  label: 'New Assignment',
                  subtitle: 'Multiple topics — students complete over a period',
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _pickedType = ExamType.assignment;
                      _nameCtrl.text = 'Assignment: ${widget.subjectName}';
                      _step = 1;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _TypeTile(
                  icon: Icons.quiz_outlined,
                  label: 'New Assessment',
                  subtitle: 'Single topic — focused short test',
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _pickedType = ExamType.assessment;
                      _nameCtrl.text = 'Assessment: ${widget.subjectName}';
                      _step = 1;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Grade selector ──────────────────────────────────────────────────────

  Widget _buildGradeSelector(
    ColorScheme cs,
    bool isDark,
    StateSetter setModalState,
    bool isAssessment,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _allowedGrades.map((e) {
          final isSelected = e.key == _selectedGrade;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              onSelected: (sel) {
                if (!sel) return;
                setModalState(() {
                  _selectedGrade = e.key;
                  if (isAssessment) _selectedTopicIds.clear();
                });
              },
              selectedColor:
                  cs.primary.withValues(alpha: isDark ? 0.25 : 0.12),
              checkmarkColor: cs.primary,
              side: BorderSide(
                color: isSelected
                    ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.25)
                    : cs.outlineVariant.withValues(
                        alpha: isDark ? 0.2 : 0.3),
                width: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Step 1: configure ───────────────────────────────────────────────────

  Widget _buildConfigForm(ColorScheme cs, bool isDark) {
    final isAssessment = _pickedType == ExamType.assessment;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: 17,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                      tooltip: 'Back',
                      onPressed: () => setState(() {
                        _step = 0;
                        _error = null;
                      }),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(34, 34),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAssessment ? 'New Assessment' : 'New Assignment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.subjectName} · ${widget.streamName}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.65),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 17,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                      tooltip: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(34, 34),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _SheetDivider(isDark: isDark, cs: cs),
              ),
              // Form body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name
                    _SheetFieldLabel(label: 'Name', cs: cs),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _nameCtrl,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: isAssessment
                            ? 'e.g. End of Topic Assessment'
                            : 'e.g. Holiday Assignment',
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest
                                .withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          borderSide: BorderSide(
                            color: cs.outlineVariant
                                .withValues(alpha: isDark ? 0.2 : 0.3),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grade selector
                    if (_allowedGrades.length > 1) ...[
                      _SheetFieldLabel(label: 'Grade', cs: cs),
                      const SizedBox(height: 5),
                      _buildGradeSelector(cs, isDark, setModalState,
                          isAssessment),
                      const SizedBox(height: 12),
                    ],

                    // Topic picker
                    _SheetFieldLabel(
                      label: isAssessment ? 'Topic' : 'Topics',
                      cs: cs,
                    ),
                    if (isAssessment)
                      Text(
                        'Select exactly one topic',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 2),
                      Text(
                        'Selections persist across grade tabs',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      if (_selectedTopicIds.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_selectedTopicIds.length} topic${_selectedTopicIds.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: cs.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 5),
                    StreamBuilder<List<Topic>>(
                      stream: catalogDao.watchTopicsBySubjectAndGrade(
                        subjectId: widget.subjectId,
                        grade: _selectedGrade,
                      ),
                      builder: (context, snapshot) {
                        final topics = snapshot.data ?? [];
                        if (topics.isEmpty) {
                          final gradeLabel = _allowedGrades
                              .firstWhere((e) => e.key == _selectedGrade,
                                  orElse: () =>
                                      MapEntry(_selectedGrade, 'Grade $_selectedGrade'))
                              .value;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.kCardRadius,
                              ),
                              border: Border.all(
                                color: cs.outlineVariant
                                    .withValues(alpha: isDark ? 0.2 : 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'No topics for $gradeLabel.',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: topics.map((t) {
                            final selected =
                                _selectedTopicIds.contains(t.id);
                            return FilterChip(
                              selected: selected,
                              label: Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              onSelected: (sel) {
                                setModalState(() {
                                  if (isAssessment) {
                                    _selectedTopicIds.clear();
                                    if (sel) _selectedTopicIds.add(t.id);
                                  } else {
                                    if (sel) {
                                      _selectedTopicIds.add(t.id);
                                    } else {
                                      _selectedTopicIds.remove(t.id);
                                    }
                                  }
                                });
                              },
                              selectedColor: cs.primary.withValues(
                                alpha: isDark ? 0.25 : 0.12,
                              ),
                              checkmarkColor: cs.primary,
                              side: BorderSide(
                                color: selected
                                    ? cs.primary.withValues(
                                        alpha: isDark ? 0.35 : 0.25)
                                    : cs.outlineVariant.withValues(
                                        alpha: isDark ? 0.2 : 0.3),
                                width: 0.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Total marks
                    _SheetFieldLabel(label: 'Total Marks', cs: cs),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _marksCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 100',
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest
                                .withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          borderSide: BorderSide(
                            color: cs.outlineVariant
                                .withValues(alpha: isDark ? 0.2 : 0.3),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date
                    _SheetFieldLabel(label: 'Date', cs: cs),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => _date = picked);
                        }
                      },
                      borderRadius:
                          BorderRadius.circular(AppTheme.kCardRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.kCardRadius),
                          border: Border.all(
                            color: cs.outlineVariant
                                .withValues(alpha: isDark ? 0.2 : 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Error banner
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _SheetErrorBanner(
                        message: _error!,
                        cs: cs,
                        isDark: isDark,
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Footer
              _SheetDivider(isDark: isDark, cs: cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    const Spacer(),
                    GestureDetector(
                      onTap:
                          _creating ? null : () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _creating
                                ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                                : cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SheetConfirmButton(
                      saving: _creating,
                      onTap: _creating ? null : () => _doCreate(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _doCreate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    final marksText = _marksCtrl.text.trim();
    final totalMarks = int.tryParse(marksText);
    if (totalMarks == null || totalMarks <= 0) {
      setState(() => _error = 'Please enter a valid total marks value.');
      return;
    }
    if (_selectedTopicIds.isEmpty) {
      setState(() => _error = 'Please select at least one topic.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final accountId = cache.currentUser?.user.id ?? '';
      final examId = _generateId();
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final startMs = _date.millisecondsSinceEpoch;
      final endMs =
          _date.add(const Duration(hours: 2)).millisecondsSinceEpoch;
      final startDays = startMs ~/ (86400 * 1000);
      final endDays = endMs ~/ (86400 * 1000);

      final exam = ExamsCompanion(
        id: Value(examId),
        school: Value(widget.schoolId),
        name: Value(name),
        year: Value(widget.year),
        term: Value(widget.term),
        type: Value(_pickedType!),
        start: Value(startDays),
        end: Value(endDays),
        teacher: Value(accountId),
        personalized: const Value(false),
        created: Value(now),
        updated: Value(now),
      );

      final paperRow = PapersCompanion(
        school: Value(widget.schoolId),
        exam: Value(examId),
        subject: Value(widget.subjectId),
        topic: Value(
            _selectedTopicIds.length == 1 ? _selectedTopicIds.first : null),
        invigilator: const Value.absent(),
        start: Value(BigInt.from(startMs)),
        end: Value(BigInt.from(endMs)),
        grade: Value(widget.grade),
        stream: Value(widget.streamCode),
        timeAllowedMinutes: const Value.absent(),
        customInstructions: const Value.absent(),
        status: const Value(PaperStatus.pending),
        created: Value(now),
        updated: Value(now),
      );

      await widget.dao.createExamWithPapers(
        exam: exam,
        paperRows: [paperRow],
        accountId: accountId,
      );

      final paperId = '${widget.schoolId}|$examId|${widget.subjectId}||'
          '${widget.grade}|${widget.streamCode}';
      final token = accessToken;

      if (_pickedType == ExamType.assessment) {
        await paperService.generateAssessment(
            paperId: paperId, accessToken: token);
      } else {
        await paperService.generateAssignment(
            paperId: paperId, accessToken: token);
      }

      final papers = await widget.dao.getPapersForSubjectClass(
        schoolId: widget.schoolId,
        grade: widget.grade,
        stream: widget.streamCode,
        subject: widget.subjectId,
        examType: _pickedType!.index,
      );
      final created = papers.firstWhere(
        (p) => p.paper.exam == examId,
        orElse: () => (
          paper: Paper(
            school: widget.schoolId,
            exam: examId,
            subject: widget.subjectId,
            topic: _selectedTopicIds.length == 1
                ? _selectedTopicIds.first
                : null,
            paper: null,
            invigilator: '',
            start: BigInt.from(startMs),
            end: BigInt.from(endMs),
            status: PaperStatus.pending,
            grade: widget.grade,
            stream: widget.streamCode,
            timeAllowedMinutes: null,
            customInstructions: null,
            created: now,
            updated: now,
          ),
          exam: Exam(
            id: examId,
            school: widget.schoolId,
            name: name,
            year: widget.year,
            term: widget.term,
            personalized: false,
            type: _pickedType!,
            start: startDays,
            end: endDays,
            teacher: accountId,
            created: now,
            updated: now,
          ),
          teacher: UsersData(
            id: accountId,
            phone: '',
            name: 'Unknown',
            email: null,
            level: UserLevel.normal,
            status: UserStatus.active,
            created: BigInt.zero,
            updated: BigInt.zero,
          ),
        ),
      );

      if (!mounted) return;
      widget.onCreated(created.paper, created.exam, created.teacher);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = 'Failed to create: $e';
      });
    }
  }

  String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${widget.schoolId}_${widget.subjectId}_$ts';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet helper widgets (matching create_term_modal.dart style)
// ─────────────────────────────────────────────────────────────────────────────

class _SheetFieldLabel extends StatelessWidget {
  const _SheetFieldLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider({required this.isDark, required this.cs});
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.45),
    );
  }
}

class _SheetErrorBanner extends StatelessWidget {
  const _SheetErrorBanner({
    required this.message,
    required this.cs,
    required this.isDark,
  });
  final String message;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: cs.error.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: cs.error.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.error.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetConfirmButton extends StatelessWidget {
  const _SheetConfirmButton({required this.saving, required this.onTap});
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const green = AppTheme.brandGreen;
    final effectiveColor = saving ? green.withValues(alpha: 0.5) : green;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: saving
            ? []
            : [
                BoxShadow(
                  color: green.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor:
              WidgetStateProperty.all(Colors.white.withValues(alpha: 0.08)),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: saving
                  ? SizedBox(
                      key: const ValueKey('spin'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    )
                  : const Icon(
                      key: ValueKey('check'),
                      Icons.check,
                      size: 17,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type picker tile
// ─────────────────────────────────────────────────────────────────────────────

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.12),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
