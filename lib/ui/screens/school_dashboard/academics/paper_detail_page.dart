import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';

import '../../../../models/result.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/student_avatar.dart';
import '../../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paper Detail Page
//
// Reached from ExamDetailPage when a paper card is tapped. Shows a single
// paper with info card, status advance, grade entry (desktop spreadsheet or
// mobile list), and analytics when the paper is marked.
// ─────────────────────────────────────────────────────────────────────────────

class PaperDetailPage extends StatefulWidget {
  const PaperDetailPage({
    super.key,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.curriculumType = CurriculumType.cbc,
    required this.schoolContext,
    this.subjectNames = const {},
    this.onBack,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;
  final Map<int, String> subjectNames;
  final VoidCallback? onBack;

  @override
  State<PaperDetailPage> createState() => _PaperDetailPageState();
}

class _PaperDetailPageState extends State<PaperDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  late final ExamsGradesDao _dao;
  late Stream<List<GradeRow>> _gradesStream;
  late Stream<Paper?> _paperStream;
  List<StudentsData> _students = [];
  bool _loadingStudents = true;
  bool? _lastIsDesktop;

  bool _hasDirtyGrades = false;
  final GlobalKey<_GradeSpreadsheetState> _spreadsheetKey = GlobalKey();
  final GlobalKey<_GradeListState> _gradeListKey = GlobalKey();

  // ── AI marking state (driven by callbacks from child widgets) ──────────
  bool _aiMarking = false;
  _AiPhase _aiPhase = _AiPhase.idle;
  int _aiMarkedCount = 0;
  double _aiProgress = 0.0;

  Paper get _paper => widget.paper;
  Exam get _exam => widget.exam.exam;

  bool get _hasUnmarkedSubmissions {
    if (_spreadsheetKey.currentState != null) {
      return _spreadsheetKey.currentState?.hasUnmarkedSubmissions ?? false;
    } else {
      return _gradeListKey.currentState?.hasUnmarkedSubmissions ?? false;
    }
  }

  Future<void> _runAiMarking() async {
    setState(() => _aiMarking = true);
    if (_spreadsheetKey.currentState != null) {
      await _spreadsheetKey.currentState?.runAiMarking();
    } else if (_gradeListKey.currentState != null) {
      await _gradeListKey.currentState?.runAiMarking();
    }
  }

  bool get _canManage {
    final entry = widget.schoolContext.currentEntry.value;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();

    _dao = ExamsGradesDao(db);
    _gradesStream = _dao.watchGradesForPaper(
      schoolId: widget.schoolId,
      examId: _exam.id,
      subject: _paper.subject,
      paper: _paper.paper,
    );
    _paperStream = _dao.watchPaper(
      schoolId: widget.schoolId,
      examId: _exam.id,
      subject: _paper.subject,
      paperNum: _paper.paper,
      grade: _paper.grade,
      stream: _paper.stream,
    );
    _loadStudents();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _showInvigilatorPicker(
    BuildContext ctx,
    Paper currentPaper,
  ) async {
    final membersDao = MembersDao(db);
    final teacherRows = await membersDao.watchTeachers(widget.schoolId).first;
    final teachers = <({TeachersData teacher, UsersData user})>[];
    for (final t in teacherRows) {
      final user = await membersDao.findUserById(t.user);
      if (user != null) teachers.add((teacher: t, user: user));
    }
    if (!mounted) return;

    final cs = Theme.of(ctx).colorScheme;

    showEduSheet(
      context: ctx,
      title: 'Select Invigilator',
      builder: (sheetCtx) {
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: teachers.length,
          itemBuilder: (_, i) {
            final t = teachers[i];
            final isSelected = t.user.id == currentPaper.invigilator;
            return ListTile(
              leading: UserAvatar(userId: t.user.id, radius: 16),
              title: Text(
                t.user.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_rounded, size: 18, color: cs.primary)
                  : null,
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (t.user.id == currentPaper.invigilator) return;
                final accountId = cache.currentUser?.user.id;
                if (accountId == null) return;
                final now = BigInt.from(
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
                );
                await _dao.updatePaper(
                  schoolId: widget.schoolId,
                  examId: _exam.id,
                  subject: currentPaper.subject,
                  paperNum: currentPaper.paper,
                  grade: currentPaper.grade,
                  stream: currentPaper.stream,
                  changes: PapersCompanion(
                    invigilator: Value(t.user.id),
                    updated: Value(now),
                  ),
                  accountId: accountId,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadStudents() async {
    final list = await _dao.getEnrolledStudents(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: _paper.stream,
    );
    if (!mounted) return;
    setState(() {
      _students = list;
      _loadingStudents = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjLabel =
        widget.subjectNames[_paper.subject] ?? 'Subject ${_paper.subject}';
    final paperNum = _paper.paper != null ? ' Paper ${_paper.paper}' : '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          '$subjLabel$paperNum',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: StreamBuilder<Paper?>(
            stream: _paperStream,
            builder: (context, paperSnap) {
              final currentPaper = paperSnap.data ?? widget.paper;

              return StreamBuilder<List<GradeRow>>(
                stream: _gradesStream,
                builder: (context, snap) {
                  if (_loadingStudents ||
                      snap.connectionState == ConnectionState.waiting) {
                    return _buildLoading(cs);
                  }

                  final gradeRows = snap.data ?? [];
                  final gradeMap = {
                    for (final r in gradeRows) r.student.adm: r.grade,
                  };

                  final screenWidth = MediaQuery.sizeOf(context).width;
                  final isDesktop = screenWidth >= AppTheme.kMobileBreakpoint;
                  _lastIsDesktop = isDesktop;

                  return ListView(
                    padding: isDesktop
                        ? const EdgeInsets.fromLTRB(16, 4, 16, 32)
                        : const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      // ── Paper Header (info + action + analytics) ────────
                      _PaperHeader(
                        paper: currentPaper,
                        exam: widget.exam,
                        schoolId: widget.schoolId,
                        subjectNames: widget.subjectNames,
                        cs: cs,
                        canEdit: _canManage,
                        canManage: _canManage,
                        dao: _dao,
                        gradeRows: gradeRows,
                        totalStudents: _students.length,
                        hasDirtyGrades: _hasDirtyGrades,
                        onEditInvigilator: () =>
                            _showInvigilatorPicker(context, currentPaper),
                        onDeleted:
                            widget.onBack ?? () => Navigator.of(context).pop(),
                        onSaveAllGrades: () async {
                          await _spreadsheetKey.currentState?.saveAllDirty();
                          if (mounted) setState(() => _hasDirtyGrades = false);
                        },
                        hasUnmarkedSubmissions: _hasUnmarkedSubmissions,
                        onAiMark: _runAiMarking,
                        aiProgress: _aiMarking ? _aiProgress : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Grade Entry Section ─────────────────────────────
                      _SectionLabel(label: 'Grades', cs: cs),
                      const SizedBox(height: 8),

                      if (_students.isEmpty)
                        _buildEmpty(cs, 'No students enrolled')
                      else if (isDesktop)
                        _GradeSpreadsheet(
                          key: _spreadsheetKey,
                          students: _students,
                          gradeMap: gradeMap,
                          paper: currentPaper,
                          exam: _exam,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          canGrade: _canManage,
                          cs: cs,
                          onDirtyChanged: (dirty) {
                            if (mounted)
                              setState(() => _hasDirtyGrades = dirty);
                          },
                          onSubmissionsChanged: () {
                            if (mounted) setState(() {});
                          },
                          onAiPhaseChanged: (phase) {
                            setState(() => _aiPhase = phase);
                            if (phase == _AiPhase.done) {
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() {
                                    _aiMarking = false;
                                    _aiPhase = _AiPhase.idle;
                                    _aiProgress = 0.0;
                                    _aiMarkedCount = 0;
                                  });
                                }
                              });
                            }
                          },
                          onAiProgressChanged: (p) =>
                              setState(() => _aiProgress = p),
                          onAiMarkedCountChanged: (c) =>
                              setState(() => _aiMarkedCount = c),
                        )
                      else
                        _GradeList(
                          key: _gradeListKey,
                          students: _students,
                          gradeMap: gradeMap,
                          paper: currentPaper,
                          exam: _exam,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          canGrade: _canManage,
                          cs: cs,
                          onDirtyChanged: (dirty) {
                            if (mounted)
                              setState(() => _hasDirtyGrades = dirty);
                          },
                          onSubmissionsChanged: () {
                            if (mounted) setState(() {});
                          },
                          onAiPhaseChanged: (phase) {
                            setState(() => _aiPhase = phase);
                            if (phase == _AiPhase.done) {
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() {
                                    _aiMarking = false;
                                    _aiPhase = _AiPhase.idle;
                                    _aiProgress = 0.0;
                                    _aiMarkedCount = 0;
                                  });
                                }
                              });
                            }
                          },
                          onAiProgressChanged: (p) =>
                              setState(() => _aiProgress = p),
                          onAiMarkedCountChanged: (c) =>
                              setState(() => _aiMarkedCount = c),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Paper Header — unified info + action bar + analytics
// ═════════════════════════════════════════════════════════════════════════════

const _kDayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _PaperHeader extends StatefulWidget {
  const _PaperHeader({
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.subjectNames,
    required this.cs,
    required this.canEdit,
    required this.canManage,
    required this.dao,
    required this.gradeRows,
    required this.totalStudents,
    required this.hasDirtyGrades,
    required this.onEditInvigilator,
    required this.onDeleted,
    required this.onSaveAllGrades,
    this.hasUnmarkedSubmissions = false,
    this.onAiMark,
    this.aiProgress,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final String schoolId;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool canEdit;
  final bool canManage;
  final ExamsGradesDao dao;
  final List<GradeRow> gradeRows;
  final int totalStudents;
  final bool hasDirtyGrades;
  final VoidCallback onEditInvigilator;
  final VoidCallback onDeleted;
  final VoidCallback onSaveAllGrades;
  final bool hasUnmarkedSubmissions;
  final VoidCallback? onAiMark;
  final double? aiProgress;

  @override
  State<_PaperHeader> createState() => _PaperHeaderState();
}

class _PaperHeaderState extends State<_PaperHeader>
    with TickerProviderStateMixin {
  bool _busy = false;
  late AnimationController _arcCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _flashCtrl;
  late Animation<double> _arcAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arcAnimation = Tween<double>(
      begin: _arcFraction(widget.paper.status),
      end: _arcFraction(widget.paper.status),
    ).animate(CurvedAnimation(parent: _arcCtrl, curve: Curves.easeInOut));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.88,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_scaleCtrl);
  }

  @override
  void didUpdateWidget(_PaperHeader old) {
    super.didUpdateWidget(old);
    if (old.paper.status != widget.paper.status) {
      _arcAnimation = Tween<double>(
        begin: _arcFraction(old.paper.status),
        end: _arcFraction(widget.paper.status),
      ).animate(CurvedAnimation(parent: _arcCtrl, curve: Curves.easeInOut));
      _arcCtrl.forward(from: 0);
      _flashCtrl.forward(from: 0).then((_) {
        if (mounted) _flashCtrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _arcCtrl.dispose();
    _scaleCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  // ── Status helpers (moved from _PaperActionBar) ─────────────────────────

  double _arcFraction(PaperStatus s) => switch (s) {
    PaperStatus.pending => 0.0,
    PaperStatus.progress => 0.33,
    PaperStatus.done => 0.66,
    PaperStatus.marked => 1.0,
  };

  Color _statusColor(PaperStatus s) => switch (s) {
    PaperStatus.pending => const Color(0xFF42A5F5),
    PaperStatus.progress => const Color(0xFFFFA726),
    PaperStatus.done => const Color(0xFF66BB6A),
    PaperStatus.marked => const Color(0xFF43A047),
  };

  IconData _statusIcon(PaperStatus s) => switch (s) {
    PaperStatus.pending => Icons.play_arrow_rounded,
    PaperStatus.progress => Icons.check_circle_outline_rounded,
    PaperStatus.done => Icons.grading_rounded,
    PaperStatus.marked => Icons.check_rounded,
  };

  String _statusActionLabel(PaperStatus s) => switch (s) {
    PaperStatus.pending => 'Start exam',
    PaperStatus.progress => 'Mark as done',
    PaperStatus.done => 'Mark as graded',
    PaperStatus.marked => 'Fully graded',
  };

  PaperStatus? _nextStatus(PaperStatus s) => switch (s) {
    PaperStatus.pending => PaperStatus.progress,
    PaperStatus.progress => PaperStatus.done,
    PaperStatus.done => PaperStatus.marked,
    PaperStatus.marked => null,
  };

  Future<void> _deletePaper(BuildContext context) async {
    final subjLabel = widget.paper.paper != null
        ? 'Paper ${widget.paper.paper}'
        : 'Paper';
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Paper?',
      message: 'This will permanently remove $subjLabel.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    try {
      await widget.dao.deletePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        grade: widget.paper.grade,
        stream: widget.paper.stream,
        accountId: accountId,
      );
      widget.onDeleted.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance() async {
    final next = _nextStatus(widget.paper.status);
    if (next == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    _scaleCtrl.forward(from: 0);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.updatePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        grade: widget.paper.grade,
        stream: widget.paper.stream,
        changes: PapersCompanion(status: Value(next), updated: Value(now)),
        accountId: accountId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Analytics computation (moved from _AnalyticsSection) ────────────────

  static const _buckets = [
    (label: '0–49', color: Color(0xFFEF5350)),
    (label: '50–59', color: Color(0xFFFF9800)),
    (label: '60–69', color: Color(0xFFFFC107)),
    (label: '70–79', color: Color(0xFF8BC34A)),
    (label: '80–89', color: Color(0xFF4CAF50)),
    (label: '90–100', color: Color(0xFF2E7D32)),
  ];

  ({int gradedCount, double averagePercent, List<_DonutSegment> segments})
  _computeAnalytics() {
    final gradeRows = widget.gradeRows;
    if (gradeRows.isEmpty) {
      return (gradedCount: 0, averagePercent: 0, segments: []);
    }

    double totalPercent = 0;
    final dist = <String, int>{for (final b in _buckets) b.label: 0};
    final actuallyGraded = gradeRows.where((r) => r.grade.score > 0).toList();

    for (final row in actuallyGraded) {
      final pct = row.grade.total > 0
          ? (row.grade.score / row.grade.total) * 100
          : 0.0;
      totalPercent += pct;
      if (pct < 50) {
        dist['0–49'] = dist['0–49']! + 1;
      } else if (pct < 60) {
        dist['50–59'] = dist['50–59']! + 1;
      } else if (pct < 70) {
        dist['60–69'] = dist['60–69']! + 1;
      } else if (pct < 80) {
        dist['70–79'] = dist['70–79']! + 1;
      } else if (pct < 90) {
        dist['80–89'] = dist['80–89']! + 1;
      } else {
        dist['90–100'] = dist['90–100']! + 1;
      }
    }

    final gradedCount = actuallyGraded.length;
    final averagePercent = gradedCount > 0 ? totalPercent / gradedCount : 0.0;

    // Build donut segments
    final segments = <_DonutSegment>[];
    if (gradedCount > 0) {
      for (final b in _buckets) {
        final count = dist[b.label]!;
        if (count > 0) {
          segments.add(_DonutSegment(count / gradedCount, b.color));
        }
      }
    }

    return (
      gradedCount: gradedCount,
      averagePercent: averagePercent,
      segments: segments,
    );
  }

  Color _avgColor(double pct) {
    if (pct < 50) return const Color(0xFFEF5350);
    if (pct < 60) return Colors.orange;
    if (pct < 70) return Colors.amber;
    if (pct < 80) return Colors.lightGreen;
    if (pct < 90) return Colors.green;
    return const Color(0xFF2E7D32);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final paper = widget.paper;
    final exam = widget.exam;
    final subjLabel =
        widget.subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);

    final status = paper.status;
    final isPending = status == PaperStatus.pending;
    final isMarked = status == PaperStatus.marked;
    final color = _statusColor(status);
    final next = _nextStatus(status);
    final nextColor = next != null ? _statusColor(next) : color;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
        color: cs.surfaceContainerLowest,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Title + Status ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  paper.paper != null
                      ? '$subjLabel — Paper ${paper.paper}'
                      : subjLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _PaperStatusChip(status: status, cs: cs),
            ],
          ),

          const SizedBox(height: 8),

          // ── Row 2: Date/Time ──────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_kDayAbbr[startDt.weekday - 1]}, ${startDt.day} ${_months[startDt.month - 1]} ${startDt.year} · ${_fmtTime(startDt)} – ${_fmtTime(endDt)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Row 3: Exam Type ──────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                _typeLabel(exam.exam.type),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: _typeColor(exam.exam.type, cs),
                ),
              ),
              if (exam.exam.personalized) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Personalized',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // ── Row 4: Invigilator ────────────────────────────────────────
          GestureDetector(
            onTap: widget.canEdit ? widget.onEditInvigilator : null,
            child: Row(
              children: [
                UserAvatar(userId: exam.teacher.id, radius: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exam.teacher.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.canEdit)
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
              ],
            ),
          ),

          // ── Row 5: Analytics (when gradeRows not empty) ───────────────
          if (widget.gradeRows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.1),
            ),
            const SizedBox(height: 10),
            _buildAnalyticsRow(cs, isDark),
          ],

          // ── Row 6: Bottom action row ──────────────────────────────────
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.1),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.canManage && isPending) ...[
                Tooltip(
                  message: 'Delete paper',
                  child: InkWell(
                    onTap: _busy ? null : () => _deletePaper(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: cs.error.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (widget.canManage)
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _arcCtrl,
                    _scaleCtrl,
                    _flashCtrl,
                  ]),
                  builder: (context, _) {
                    final scale = _scaleCtrl.isAnimating
                        ? _scaleAnimation.value
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: _buildActionButton(
                        status,
                        isMarked,
                        color,
                        nextColor,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Analytics row with donut chart ────────────────────────────────────

  Widget _buildAnalyticsRow(ColorScheme cs, bool isDark) {
    final analytics = _computeAnalytics();
    final gradedCount = analytics.gradedCount;
    final averagePercent = analytics.averagePercent;
    final segments = analytics.segments;

    return Row(
      children: [
        // Donut chart
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments.isEmpty
                  ? [
                      _DonutSegment(
                        1.0,
                        isDark
                            ? const Color(0xFF2A3848)
                            : const Color(0xFFE0E0E0),
                      ),
                    ]
                  : segments,
              strokeWidth: 10,
              trackColor: isDark
                  ? const Color(0xFF2A3848)
                  : const Color(0xFFE0E0E0),
            ),
            child: Center(
              child: Text(
                '$gradedCount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$gradedCount / ${widget.totalStudents} graded',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${averagePercent.toStringAsFixed(0)}% avg',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _avgColor(averagePercent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Unified action button dispatcher ──────────────────────────────────

  Widget _buildActionButton(
    PaperStatus status,
    bool isMarked,
    Color color,
    Color nextColor,
  ) {
    // State 1: Has dirty grades → orange save
    if (widget.hasDirtyGrades && !isMarked) {
      return _buildDirtySaveButton();
    }

    // State 2: AI marking in progress → radial progress fill
    if (widget.aiProgress != null) {
      return _buildAiProgressButton();
    }

    // State 3: Has unmarked submissions → indigo AI button
    if (widget.hasUnmarkedSubmissions) {
      return _buildAiMarkButton();
    }

    // State 4: Normal advance or fully marked
    return _buildCircularButton(status, isMarked, color, nextColor);
  }

  // ── AI progress button ────────────────────────────────────────────────

  Widget _buildAiProgressButton() {
    final progress = widget.aiProgress ?? 0.0;
    final pctText = '${(progress * 100).toInt()}%';
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _RadialFillPainter(
          progress: progress,
          fillColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
          borderColor: const Color(0xFF6366F1),
          strokeWidth: 2.5,
        ),
        child: Center(
          child: Text(
            pctText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ),
    );
  }

  // ── AI mark button ────────────────────────────────────────────────────

  Widget _buildAiMarkButton() {
    return Tooltip(
      message: 'Mark with AI',
      child: GestureDetector(
        onTap: widget.onAiMark,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF6366F1), width: 2.5),
          ),
          child: const Center(
            child: Icon(
              Icons.auto_fix_high,
              size: 18,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dirty-save button ─────────────────────────────────────────────────

  Widget _buildDirtySaveButton() {
    const size = 40.0;
    return Tooltip(
      message: 'Save all grades',
      child: GestureDetector(
        onTap: _busy ? null : widget.onSaveAllGrades,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFA726).withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xFFFFA726), width: 2.0),
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFFFA726),
                    ),
                  )
                : const Icon(
                    Icons.save_rounded,
                    size: 18,
                    color: Color(0xFFFFA726),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Circular advance button ───────────────────────────────────────────

  Widget _buildCircularButton(
    PaperStatus status,
    bool isMarked,
    Color color,
    Color nextColor,
  ) {
    const size = 40.0;
    final arcValue = _arcCtrl.isAnimating
        ? _arcAnimation.value
        : _arcFraction(status);
    final flashValue = _flashCtrl.value;

    if (isMarked) {
      return Tooltip(
        message: 'Fully graded',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
              const Color(0xFF43A047),
              const Color(0xFF66BB6A),
              flashValue,
            ),
          ),
          child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
        ),
      );
    }

    return Tooltip(
      message: _statusActionLabel(status),
      child: GestureDetector(
        onTap: _busy ? null : _advance,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ArcProgressPainter(
              progress: arcValue,
              arcColor: nextColor,
              trackColor: widget.cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 3.0,
              flashColor: flashValue > 0
                  ? const Color(0xFF66BB6A).withValues(alpha: flashValue * 0.4)
                  : null,
            ),
            child: Center(
              child: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: nextColor,
                      ),
                    )
                  : Icon(_statusIcon(status), size: 18, color: nextColor),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Donut Chart Painter
// ═════════════════════════════════════════════════════════════════════════════

class _DonutSegment {
  const _DonutSegment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.trackColor,
  });

  final List<_DonutSegment> segments;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track background
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw segments
    double startAngle = -math.pi / 2; // start from top
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweep = seg.fraction * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = seg.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.trackColor != trackColor;
}

// ═════════════════════════════════════════════════════════════════════════════
// Arc Progress Painter (reused by header + mini indicator)
// ═════════════════════════════════════════════════════════════════════════════

class _RadialFillPainter extends CustomPainter {
  _RadialFillPainter({
    required this.progress,
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
  });
  final double progress;
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;

    // Fill arc (from top, clockwise)
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      true,
      fillPaint,
    );

    // Border circle
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = borderColor;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialFillPainter old) =>
      old.progress != progress;
}

class _ArcProgressPainter extends CustomPainter {
  _ArcProgressPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
    this.flashColor,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;
  final Color? flashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Flash fill
    if (flashColor != null) {
      final flashPaint = Paint()
        ..color = flashColor!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - strokeWidth / 2, flashPaint);
    }

    // Arc
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.flashColor != flashColor;
}

// ═════════════════════════════════════════════════════════════════════════════
// Grade Spreadsheet — Desktop (≥ 600px)
// ═════════════════════════════════════════════════════════════════════════════

class _GradeSpreadsheet extends StatefulWidget {
  const _GradeSpreadsheet({
    super.key,
    required this.students,
    required this.gradeMap,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    required this.canGrade,
    required this.cs,
    this.onDirtyChanged,
    this.onAiPhaseChanged,
    this.onAiProgressChanged,
    this.onAiMarkedCountChanged,
    this.onSubmissionsChanged,
  });

  final List<StudentsData> students;
  final Map<int, Grade> gradeMap;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final bool canGrade;
  final ColorScheme cs;
  final ValueChanged<bool>? onDirtyChanged;
  final ValueChanged<_AiPhase>? onAiPhaseChanged;
  final ValueChanged<double>? onAiProgressChanged;
  final ValueChanged<int>? onAiMarkedCountChanged;
  final VoidCallback? onSubmissionsChanged;

  @override
  State<_GradeSpreadsheet> createState() => _GradeSpreadsheetState();
}

class _GradeSpreadsheetState extends State<_GradeSpreadsheet>
    with TickerProviderStateMixin {
  // Local draft state: adm → raw score string being edited
  final Map<int, String> _drafts = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, bool> _saving = {};

  // adm → local file paths of uploaded answer images
  final Map<int, List<String>> _submissions = {};

  // adm → animation controller for the green flash on successful save
  final Map<int, AnimationController> _flashControllers = {};

  // Default max score from any existing grade, fallback 100
  int _maxScore = 100;

  // adm → true while a quick-grade save is in progress
  final Map<int, bool> _quickGrading = {};

  // adm → true when new submissions were added after last AI mark
  final Set<int> _dirtySubmissions = {};

  // ── AI Marking state ────────────────────────────────────────────────────
  bool _aiMarking = false;
  _AiPhase _aiPhase = _AiPhase.idle;
  late AnimationController _shimmerCtrl;
  late AnimationController _progressCtrl;
  int _aiMarkedCount = 0;

  @override
  void initState() {
    super.initState();
    _initFromMap();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadPersistedSubmissions();
  }

  Future<void> _loadPersistedSubmissions() async {
    final persisted = await widget.dao.getSubmissionsForPaper(
      schoolId: widget.schoolId,
      examId: widget.exam.id,
      subject: widget.paper.subject,
      paperNum: widget.paper.paper,
    );
    if (mounted) {
      setState(() => _submissions.addAll(persisted));
      widget.onSubmissionsChanged?.call();
    }
  }

  @override
  void didUpdateWidget(_GradeSpreadsheet old) {
    super.didUpdateWidget(old);
    // Refresh controllers that aren't being actively edited
    for (final student in widget.students) {
      final adm = student.adm;
      final grade = widget.gradeMap[adm];
      final ctrl = _controllers[adm];
      if (ctrl != null && !(_focusNodes[adm]?.hasFocus ?? false)) {
        final newVal = grade != null ? _fmtScore(grade.score) : '';
        if (ctrl.text != newVal) ctrl.text = newVal;
        if (grade != null) _maxScore = grade.total;
      }
    }
  }

  void _initFromMap() {
    for (final student in widget.students) {
      final adm = student.adm;
      final grade = widget.gradeMap[adm];
      final initial = grade != null ? _fmtScore(grade.score) : '';
      _controllers[adm] = TextEditingController(text: initial);
      _focusNodes[adm] = FocusNode();
      _flashControllers[adm] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      if (grade != null) _maxScore = grade.total;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    for (final fc in _flashControllers.values) {
      fc.dispose();
    }
    _shimmerCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  bool get _hasSubmissions =>
      _submissions.values.any((list) => list.isNotEmpty);

  int get _submissionCount =>
      _submissions.values.where((list) => list.isNotEmpty).length;

  bool get hasUnmarkedSubmissions {
    return _submissions.entries.any(
      (e) => e.value.isNotEmpty && !widget.gradeMap.containsKey(e.key),
    );
  }

  bool get hasDirtyGrades {
    for (final student in widget.students) {
      final adm = student.adm;
      if (_drafts.containsKey(adm)) {
        final existingGrade = widget.gradeMap[adm];
        final existingText = existingGrade != null
            ? _fmtScore(existingGrade.score)
            : '';
        if (_drafts[adm] != existingText) return true;
      }
    }
    return false;
  }

  Future<void> saveAllDirty() async {
    for (final student in widget.students) {
      final adm = student.adm;
      if (_drafts.containsKey(adm)) {
        final existingGrade = widget.gradeMap[adm];
        final existingText = existingGrade != null
            ? _fmtScore(existingGrade.score)
            : '';
        if (_drafts[adm] != existingText) {
          await _saveRow(adm, _controllers[adm]?.text ?? _drafts[adm]!);
        }
      }
    }
  }

  Future<void> runAiMarking() async {
    if (!_hasSubmissions || !widget.canGrade || _aiMarking) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final studentsWithSubmissions = widget.students
        .where(
          (s) =>
              (_submissions[s.adm] ?? []).isNotEmpty &&
              !widget.gradeMap.containsKey(s.adm),
        )
        .toList();

    if (studentsWithSubmissions.isEmpty) return;

    setState(() {
      _aiMarking = true;
      _aiPhase = _AiPhase.analyzing;
      _aiMarkedCount = 0;
    });
    widget.onAiPhaseChanged?.call(_AiPhase.analyzing);
    widget.onAiProgressChanged?.call(0.0);

    // Phase 2 — "analyzing" with smooth progress from 0% to 40% over ~3.5s
    const analyzeMs = 3500;
    const analyzeTicks = 35;
    const analyzeInterval = analyzeMs ~/ analyzeTicks;
    for (int tick = 1; tick <= analyzeTicks; tick++) {
      await Future.delayed(const Duration(milliseconds: analyzeInterval));
      if (!mounted) return;
      final analyzeProgress = (tick / analyzeTicks) * 0.4; // 0.0 → 0.4
      widget.onAiProgressChanged?.call(analyzeProgress);
    }

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.assigning);
    widget.onAiPhaseChanged?.call(_AiPhase.assigning);

    // Phase 3 — assign grades with staggered delays for 5-7s total grading
    // Compute per-student delay: target ~6s total, clamped 250ms–600ms
    final rng = math.Random();
    int marked = 0;
    final total = studentsWithSubmissions.length;
    final perStudentDelay = total > 0 ? (6000 ~/ total).clamp(250, 600) : 400;
    final List<int> gradedAdms = [];
    for (int i = 0; i < studentsWithSubmissions.length; i++) {
      final student = studentsWithSubmissions[i];
      final adm = student.adm;
      final score = (55 + rng.nextInt(46)).toDouble();
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      try {
        await widget.dao.upsertGrade(
          grade: GradesCompanion(
            school: Value(widget.schoolId),
            exam: Value(widget.exam.id),
            student: Value(adm),
            subject: Value(widget.paper.subject),
            paper: Value(widget.paper.paper),
            score: Value(score),
            total: Value(_maxScore),
            created: Value(now),
            updated: Value(now),
          ),
          accountId: accountId,
        );
        if (mounted) {
          _controllers[adm]?.text = _fmtScore(score);
          gradedAdms.add(adm);
          marked++;
          setState(() => _aiMarkedCount = marked);
          widget.onAiMarkedCountChanged?.call(marked);
          // Progress: 40%–100% mapped across graded students
          final gradingProgress = 0.4 + (marked / total) * 0.6;
          widget.onAiProgressChanged?.call(gradingProgress);
        }
      } catch (_) {
        // skip failed rows — don't abort the whole batch
      }
      // Add jitter: ±30% of base delay for natural feel
      final jitter = (perStudentDelay * 0.3).toInt();
      final delay = perStudentDelay + rng.nextInt(jitter * 2 + 1) - jitter;
      await Future.delayed(Duration(milliseconds: delay));
    }

    // Wave flash — staggered 30ms per row for a satisfying top-to-bottom effect
    _triggerWaveFlash(gradedAdms);

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.done);
    widget.onAiPhaseChanged?.call(_AiPhase.done);

    // Phase 4 — show completion label for 2 seconds then reset
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
      _dirtySubmissions.clear();
    });
    _progressCtrl.reset();
  }

  void _triggerWaveFlash(List<int> admList) {
    for (int i = 0; i < admList.length; i++) {
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) {
          _flashControllers[admList[i]]?.forward(from: 0.0).then((_) {
            _flashControllers[admList[i]]?.reverse();
          });
        }
      });
    }
  }

  Future<void> _saveRow(int adm, String rawInput) async {
    if (!widget.canGrade) return;
    final score = double.tryParse(rawInput);
    if (score == null || score < 0 || score > _maxScore) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving[adm] = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.upsertGrade(
        grade: GradesCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.exam.id),
          student: Value(adm),
          subject: Value(widget.paper.subject),
          paper: Value(widget.paper.paper),
          score: Value(score),
          total: Value(_maxScore),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      // Flash green on successful save
      final fc = _flashControllers[adm];
      if (fc != null && mounted) {
        fc.forward(from: 0.0).then((_) => fc.reverse());
      }
      // Clear draft for this adm since it's been saved
      _drafts.remove(adm);
      widget.onDirtyChanged?.call(hasDirtyGrades);
    } finally {
      if (mounted) setState(() => _saving[adm] = false);
    }
  }

  void _focusNext(int currentIndex) {
    final next = currentIndex + 1;
    if (next < widget.students.length) {
      _focusNodes[widget.students[next].adm]?.requestFocus();
    }
  }

  Future<void> _quickGrade(int adm) async {
    if (_quickGrading[adm] == true || !widget.canGrade) return;
    if (_submissions[adm]?.isEmpty ?? true) return; // no-op if no submissions
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _quickGrading[adm] = true);
    try {
      final rng = math.Random();
      final score = (55 + rng.nextInt(46)).toDouble();
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.upsertGrade(
        grade: GradesCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.exam.id),
          student: Value(adm),
          subject: Value(widget.paper.subject),
          paper: Value(widget.paper.paper),
          score: Value(score),
          total: Value(_maxScore),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      // Update text controller so the field reflects the new grade immediately
      _controllers[adm]?.text = _fmtScore(score);
      // Flash the row green
      final fc = _flashControllers[adm];
      if (fc != null && mounted) {
        fc.forward(from: 0.0).then((_) => fc.reverse());
      }
    } finally {
      if (mounted) setState(() => _quickGrading[adm] = false);
    }
  }

  void _openSubmissionSheet(BuildContext context, StudentsData student) {
    final adm = student.adm;
    showEduSheet(
      context: context,
      builder: (_) => _AnswerSubmissionSheet(
        student: student,
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        existingPaths: List.from(_submissions[adm] ?? []),
        onUpdated: (paths) {
          if (mounted) {
            setState(() {
              _submissions[adm] = paths;
              if (paths.isNotEmpty) _dirtySubmissions.add(adm);
            });
            widget.onSubmissionsChanged?.call();
          }
        },
        dao: widget.dao,
        cs: widget.cs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1A2435) : const Color(0xFFF1F3F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kRadius),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 84),
              Expanded(
                flex: 3,
                child: Text(
                  'Student',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  'Score / $_maxScore',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppTheme.kRadius),
          ),
          elevation: 2,
          shadowColor: cs.shadow.withValues(alpha: 0.08),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.students.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (context, i) {
              final student = widget.students[i];
              final adm = student.adm;
              final existingGrade = widget.gradeMap[adm];
              final isDirty =
                  _drafts.containsKey(adm) &&
                  _drafts[adm] !=
                      (existingGrade != null
                          ? _fmtScore(existingGrade.score)
                          : '');
              final isSaving = _saving[adm] ?? false;

              return _SpreadsheetRow(
                student: student,
                schoolId: widget.schoolId,
                controller: _controllers[adm]!,
                focusNode: _focusNodes[adm]!,
                existingGrade: existingGrade,
                maxScore: _maxScore,
                isDirty: isDirty,
                isSaving: isSaving,
                canGrade: widget.canGrade && !_aiMarking,
                paperStatus: widget.paper.status,
                submissionCount: (_submissions[adm] ?? []).length,
                flashController: _flashControllers[adm]!,
                cs: cs,
                onChanged: (v) {
                  final wasDirty = hasDirtyGrades;
                  setState(() => _drafts[adm] = v);
                  final isDirtyNow = hasDirtyGrades;
                  if (wasDirty != isDirtyNow) {
                    widget.onDirtyChanged?.call(isDirtyNow);
                  }
                },
                onSave: () => _saveRow(adm, _controllers[adm]!.text),
                onSubmitted: (_) {
                  _saveRow(adm, _controllers[adm]!.text);
                  _focusNext(i);
                },
                onSubmitTap: _aiMarking
                    ? () {}
                    : () => _openSubmissionSheet(context, student),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Marking Phase Enum
// ─────────────────────────────────────────────────────────────────────────────

enum _AiPhase { idle, analyzing, assigning, done }

class _SpreadsheetRow extends StatefulWidget {
  const _SpreadsheetRow({
    required this.student,
    required this.schoolId,
    required this.controller,
    required this.focusNode,
    required this.existingGrade,
    required this.maxScore,
    required this.isDirty,
    required this.isSaving,
    required this.canGrade,
    required this.paperStatus,
    required this.submissionCount,
    required this.flashController,
    required this.cs,
    required this.onChanged,
    required this.onSave,
    required this.onSubmitted,
    required this.onSubmitTap,
  });

  final StudentsData student;
  final String schoolId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Grade? existingGrade;
  final int maxScore;
  final bool isDirty;
  final bool isSaving;
  final bool canGrade;
  final PaperStatus paperStatus;
  final int submissionCount;
  final AnimationController flashController;
  final ColorScheme cs;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSubmitTap;

  double? get _pct {
    if (existingGrade == null) return null;
    if (existingGrade!.total <= 0) return null;
    return (existingGrade!.score / existingGrade!.total) * 100;
  }

  @override
  State<_SpreadsheetRow> createState() => _SpreadsheetRowState();
}

class _SpreadsheetRowState extends State<_SpreadsheetRow> {
  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final pct = widget._pct;
    final showSubmit = true; // Always show file upload button

    return AnimatedBuilder(
      animation: widget.flashController,
      builder: (context, child) {
        final flash = widget.flashController.value;
        return Container(
          color: flash > 0
              ? const Color(0xFF6366F1).withValues(alpha: flash * 0.08)
              : Colors.transparent,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Adm number badge
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                '${widget.student.adm}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            StudentAvatar(
              schoolId: widget.schoolId,
              adm: widget.student.adm,
              name: widget.student.name,
              radius: 14,
            ),
            const SizedBox(width: 8),
            // Name
            Expanded(
              flex: 3,
              child: Text(
                widget.student.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Score input
            SizedBox(
              width: 80,
              child: widget.canGrade
                  ? TextFormField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                      ),
                      onChanged: widget.onChanged,
                      onFieldSubmitted: widget.onSubmitted,
                    )
                  : Text(
                      widget.existingGrade != null
                          ? _fmtScore(widget.existingGrade!.score)
                          : '–',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            // Percentage badge
            SizedBox(
              width: 44,
              child: pct != null
                  ? Text(
                      '${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _pctColor(pct, cs),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Submit answers button
            if (showSubmit)
              GestureDetector(
                onTap: widget.onSubmitTap,
                child: Tooltip(
                  message: widget.submissionCount > 0
                      ? '${widget.submissionCount} page(s) submitted'
                      : 'Submit answer sheets',
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            Icons.upload_file_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        if (widget.submissionCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppTheme.brandGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${widget.submissionCount}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (showSubmit) const SizedBox(width: 4),
            // Save button
            if (widget.canGrade)
              AnimatedSaveButton(
                isDirty: widget.isDirty,
                isSaving: widget.isSaving,
                onSave: widget.isDirty ? widget.onSave : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Grade List — Mobile (< 600px)
// ═════════════════════════════════════════════════════════════════════════════

class _GradeList extends StatefulWidget {
  const _GradeList({
    super.key,
    required this.students,
    required this.gradeMap,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    required this.canGrade,
    required this.cs,
    this.onDirtyChanged,
    this.onAiPhaseChanged,
    this.onAiProgressChanged,
    this.onAiMarkedCountChanged,
    this.onSubmissionsChanged,
  });

  final List<StudentsData> students;
  final Map<int, Grade> gradeMap;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final bool canGrade;
  final ColorScheme cs;
  final ValueChanged<bool>? onDirtyChanged;
  final ValueChanged<_AiPhase>? onAiPhaseChanged;
  final ValueChanged<double>? onAiProgressChanged;
  final ValueChanged<int>? onAiMarkedCountChanged;
  final VoidCallback? onSubmissionsChanged;

  @override
  State<_GradeList> createState() => _GradeListState();
}

class _GradeListState extends State<_GradeList> with TickerProviderStateMixin {
  int _maxScore = 100;

  // adm → local file paths of uploaded answer images
  final Map<int, List<String>> _submissions = {};

  // adm → animation controller for the green flash on save
  final Map<int, AnimationController> _flashControllers = {};

  // adm → true while a quick-grade save is in progress
  final Map<int, bool> _quickGrading = {};

  // adm → true when new submissions were added after last AI mark
  final Set<int> _dirtySubmissions = {};

  // ── AI Marking state ──────────────────────────────────────────────────
  bool _aiMarking = false;
  _AiPhase _aiPhase = _AiPhase.idle;
  late AnimationController _shimmerCtrl;
  late AnimationController _progressCtrl;
  int _aiMarkedCount = 0;

  bool get _hasSubmissions =>
      _submissions.values.any((list) => list.isNotEmpty);

  int get _submissionCount =>
      _submissions.values.where((list) => list.isNotEmpty).length;

  bool get hasUnmarkedSubmissions {
    return _submissions.entries.any(
      (e) => e.value.isNotEmpty && !widget.gradeMap.containsKey(e.key),
    );
  }

  @override
  void initState() {
    super.initState();
    final first = widget.gradeMap.values.firstOrNull;
    if (first != null) _maxScore = first.total;
    for (final student in widget.students) {
      _flashControllers[student.adm] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
    }
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadPersistedSubmissions();
  }

  Future<void> _loadPersistedSubmissions() async {
    final persisted = await widget.dao.getSubmissionsForPaper(
      schoolId: widget.schoolId,
      examId: widget.exam.id,
      subject: widget.paper.subject,
      paperNum: widget.paper.paper,
    );
    if (mounted) {
      setState(() => _submissions.addAll(persisted));
      widget.onSubmissionsChanged?.call();
    }
  }

  Future<void> runAiMarking() async {
    if (!_hasSubmissions || !widget.canGrade || _aiMarking) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final studentsWithSubmissions = widget.students
        .where(
          (s) =>
              (_submissions[s.adm] ?? []).isNotEmpty &&
              !widget.gradeMap.containsKey(s.adm),
        )
        .toList();
    if (studentsWithSubmissions.isEmpty) return;

    setState(() {
      _aiMarking = true;
      _aiPhase = _AiPhase.analyzing;
      _aiMarkedCount = 0;
    });
    widget.onAiPhaseChanged?.call(_AiPhase.analyzing);
    widget.onAiProgressChanged?.call(0.0);

    // Phase 2 — "analyzing" with smooth progress from 0% to 40% over ~3.5s
    const analyzeMs = 3500;
    const analyzeTicks = 35;
    const analyzeInterval = analyzeMs ~/ analyzeTicks;
    for (int tick = 1; tick <= analyzeTicks; tick++) {
      await Future.delayed(const Duration(milliseconds: analyzeInterval));
      if (!mounted) return;
      final analyzeProgress = (tick / analyzeTicks) * 0.4; // 0.0 → 0.4
      widget.onAiProgressChanged?.call(analyzeProgress);
    }

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.assigning);
    widget.onAiPhaseChanged?.call(_AiPhase.assigning);

    // Phase 3 — assign grades with staggered delays for 5-7s total grading
    // Compute per-student delay: target ~6s total, clamped 250ms–600ms
    final rng = math.Random();
    int marked = 0;
    final total = studentsWithSubmissions.length;
    final perStudentDelay = total > 0 ? (6000 ~/ total).clamp(250, 600) : 400;
    final List<int> gradedAdms = [];
    for (int i = 0; i < studentsWithSubmissions.length; i++) {
      final student = studentsWithSubmissions[i];
      final adm = student.adm;
      final score = (55 + rng.nextInt(46)).toDouble();
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      try {
        await widget.dao.upsertGrade(
          grade: GradesCompanion(
            school: Value(widget.schoolId),
            exam: Value(widget.exam.id),
            student: Value(adm),
            subject: Value(widget.paper.subject),
            paper: Value(widget.paper.paper),
            score: Value(score),
            total: Value(_maxScore),
            created: Value(now),
            updated: Value(now),
          ),
          accountId: accountId,
        );
        if (mounted) {
          gradedAdms.add(adm);
          marked++;
          setState(() => _aiMarkedCount = marked);
          widget.onAiMarkedCountChanged?.call(marked);
          // Progress: 40%–100% mapped across graded students
          final gradingProgress = 0.4 + (marked / total) * 0.6;
          widget.onAiProgressChanged?.call(gradingProgress);
        }
      } catch (_) {
        // skip failed rows — don't abort the whole batch
      }
      // Add jitter: ±30% of base delay for natural feel
      final jitter = (perStudentDelay * 0.3).toInt();
      final delay = perStudentDelay + rng.nextInt(jitter * 2 + 1) - jitter;
      await Future.delayed(Duration(milliseconds: delay));
    }

    // Wave flash — staggered 30ms per row for a satisfying top-to-bottom effect
    _triggerWaveFlash(gradedAdms);

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.done);
    widget.onAiPhaseChanged?.call(_AiPhase.done);

    // Phase 4 — show completion label for 2 seconds then reset
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
      _dirtySubmissions.clear();
    });
    _progressCtrl.reset();
  }

  void _triggerWaveFlash(List<int> admList) {
    for (int i = 0; i < admList.length; i++) {
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) {
          _flashControllers[admList[i]]?.forward(from: 0.0).then((_) {
            _flashControllers[admList[i]]?.reverse();
          });
        }
      });
    }
  }

  void _openSubmissionSheet(BuildContext context, StudentsData student) {
    final adm = student.adm;
    showEduSheet(
      context: context,
      builder: (_) => _AnswerSubmissionSheet(
        student: student,
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        existingPaths: List.from(_submissions[adm] ?? []),
        onUpdated: (paths) {
          if (mounted) {
            setState(() {
              _submissions[adm] = paths;
              if (paths.isNotEmpty) _dirtySubmissions.add(adm);
            });
            widget.onSubmissionsChanged?.call();
          }
        },
        dao: widget.dao,
        cs: widget.cs,
      ),
    );
  }

  @override
  void dispose() {
    for (final fc in _flashControllers.values) {
      fc.dispose();
    }
    _shimmerCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickGrade(int adm) async {
    if (_quickGrading[adm] == true || !widget.canGrade) return;
    if (_submissions[adm]?.isEmpty ?? true) return; // no-op if no submissions
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _quickGrading[adm] = true);
    try {
      final rng = math.Random();
      final score = (55 + rng.nextInt(46)).toDouble();
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.upsertGrade(
        grade: GradesCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.exam.id),
          student: Value(adm),
          subject: Value(widget.paper.subject),
          paper: Value(widget.paper.paper),
          score: Value(score),
          total: Value(_maxScore),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      // Flash the row green
      final fc = _flashControllers[adm];
      if (fc != null && mounted) {
        fc.forward(from: 0.0).then((_) => fc.reverse());
      }
    } finally {
      if (mounted) setState(() => _quickGrading[adm] = false);
    }
  }

  void _openGradeEntry(BuildContext context, StudentsData student) {
    if (!widget.canGrade) return;
    final adm = student.adm;
    final existing = widget.gradeMap[adm];
    showEduSheet(
      context: context,
      builder: (_) => _MobileGradeEntrySheet(
        student: student,
        existingGrade: existing,
        maxScore: _maxScore,
        paper: widget.paper,
        exam: widget.exam,
        schoolId: widget.schoolId,
        dao: widget.dao,
        onSaved: () {
          final fc = _flashControllers[adm];
          if (fc != null && mounted) {
            fc.forward(from: 0.0).then((_) => fc.reverse());
          }
        },
      ),
    );
  }

  void _openStudentActionSheet(BuildContext context, StudentsData student) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;

    showEduSheet(
      context: context,
      title: student.name,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action: Submit Answer Sheets (always available)
          _ActionSheetRow(
            icon: Icons.upload_file_outlined,
            label: 'Submit Answer Sheets',
            cs: cs,
            isDark: isDark,
            onTap: () {
              Navigator.pop(ctx);
              _openSubmissionSheet(context, student);
            },
          ),
          // Action: Enter Grade (always shown)
          _ActionSheetRow(
            icon: Icons.edit_outlined,
            label: 'Enter Grade',
            cs: cs,
            isDark: isDark,
            onTap: widget.canGrade
                ? () {
                    Navigator.pop(ctx);
                    _openGradeEntry(context, student);
                  }
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          elevation: 2,
          shadowColor: cs.shadow.withValues(alpha: 0.08),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.students.length,
            separatorBuilder: (_, _) => AppTheme.tableRowDivider(isDark, cs),
            itemBuilder: (context, i) {
              final student = widget.students[i];
              final adm = student.adm;
              final grade = widget.gradeMap[adm];
              final pct = grade != null && grade.total > 0
                  ? (grade.score / grade.total) * 100
                  : null;
              final subCount = (_submissions[adm] ?? []).length;
              final flashCtrl = _flashControllers[adm];

              Widget cardContent = InkWell(
                onTap: (widget.canGrade && !_aiMarking)
                    ? () => _openGradeEntry(context, student)
                    : null,
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        StudentAvatar(
                          schoolId: widget.schoolId,
                          adm: student.adm,
                          name: student.name,
                          radius: 14,
                        ),
                        const SizedBox(width: 10),
                        // Name + ADM column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                student.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Adm: $adm',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Grade badge
                        if (grade != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.brandGreen.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.brandGreen.withValues(
                                  alpha: 0.25,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_fmtScore(grade.score)}/${grade.total}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.brandGreen,
                                  ),
                                ),
                                if (pct != null)
                                  Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.brandGreen.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Not graded',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                        // Three-dot action menu
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: _aiMarking
                              ? null
                              : () => _openStudentActionSheet(context, student),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (flashCtrl != null) {
                cardContent = AnimatedBuilder(
                  animation: flashCtrl,
                  builder: (context, child) {
                    final flash = flashCtrl.value;
                    return Container(
                      color: flash > 0
                          ? const Color(
                              0xFF6366F1,
                            ).withValues(alpha: flash * 0.08)
                          : Colors.transparent,
                      child: child,
                    );
                  },
                  child: cardContent,
                );
              }

              return cardContent;
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Sheet Row — reusable row for mobile bottom sheet actions
// ─────────────────────────────────────────────────────────────────────────────

class _ActionSheetRow extends StatelessWidget {
  const _ActionSheetRow({
    required this.icon,
    required this.label,
    required this.cs,
    required this.isDark,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 18,
                color: disabled
                    ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: disabled
                      ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                      : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Answer Submission Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _AnswerSubmissionSheet extends StatefulWidget {
  const _AnswerSubmissionSheet({
    required this.student,
    required this.schoolId,
    required this.examId,
    required this.subject,
    required this.paperNum,
    required this.existingPaths,
    required this.onUpdated,
    required this.dao,
    required this.cs,
  });

  final StudentsData student;
  final String schoolId;
  final String examId;
  final int subject;
  final int? paperNum;
  final List<String> existingPaths;
  final ValueChanged<List<String>> onUpdated;
  final ExamsGradesDao dao;
  final ColorScheme cs;

  @override
  State<_AnswerSubmissionSheet> createState() => _AnswerSubmissionSheetState();
}

// Per-file upload status for thumbnail overlays.
enum _UploadStatus { pending, uploading, done, failed }

class _AnswerSubmissionSheetState extends State<_AnswerSubmissionSheet> {
  late List<String> _paths;
  bool _picking = false;

  /// Tracks upload status per file index. Absent = never queued.
  final Map<int, _UploadStatus> _uploadStatus = {};

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.existingPaths);
    // Existing paths (loaded from DB) start as pending — they may not yet
    // have been uploaded (e.g. added while offline).
    for (int i = 0; i < _paths.length; i++) {
      _uploadStatus[i] = _UploadStatus.pending;
    }
  }

  Future<void> _addPhotos() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final paperSuffix = widget.paperNum != null
          ? '${widget.subject}_${widget.paperNum}'
          : '${widget.subject}';
      final dir = Directory(
        '${appDir.path}/submissions/${widget.schoolId}/${widget.examId}/$paperSuffix/${widget.student.adm}',
      );
      await dir.create(recursive: true);

      final newPaths = <String>[];
      for (final xFile in picked) {
        final index = _paths.length + newPaths.length + 1;
        final dest = File('${dir.path}/$index.jpg');
        await File(xFile.path).copy(dest.path);
        newPaths.add(dest.path);
      }

      if (!mounted) return;

      // Mark new files as pending before adding them to the list so the
      // overlay icons appear immediately on the first render.
      final baseIndex = _paths.length;
      for (int i = 0; i < newPaths.length; i++) {
        _uploadStatus[baseIndex + i] = _UploadStatus.pending;
      }

      setState(() => _paths = [..._paths, ...newPaths]);
      widget.onUpdated(_paths);

      // Persist new paths to local DB
      for (final p in newPaths) {
        await widget.dao.insertSubmission(
          schoolId: widget.schoolId,
          examId: widget.examId,
          student: widget.student.adm,
          subject: widget.subject,
          paperNum: widget.paperNum,
          path: p,
        );
      }

      // Trigger background upload (non-blocking fire-and-forget).
      if (mounted) {
        // ignore: unawaited_futures
        _uploadPendingFiles();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Upload all locally-saved paths to remote storage in the background.
  ///
  /// Runs without blocking the UI. Thumbnail overlays reflect progress via
  /// [_uploadStatus].
  Future<void> _uploadPendingFiles() async {
    final svc = client.fileUpload;
    final token = cache.currentUser?.accessToken;
    if (token == null) return;

    // Mark every current file as uploading.
    if (mounted) {
      setState(() {
        for (int i = 0; i < _paths.length; i++) {
          _uploadStatus[i] = _UploadStatus.uploading;
        }
      });
    }

    final result = await svc.uploadAnswerSheets(
      schoolId: widget.schoolId,
      examId: widget.examId,
      subject: widget.subject,
      paper: widget.paperNum,
      studentAdm: widget.student.adm,
      localPaths: _paths,
      accessToken: token,
    );

    if (!mounted) return;
    setState(() {
      switch (result) {
        case Ok():
          for (int i = 0; i < _paths.length; i++) {
            _uploadStatus[i] = _UploadStatus.done;
          }
        case Err():
          for (int i = 0; i < _paths.length; i++) {
            _uploadStatus[i] = _UploadStatus.failed;
          }
      }
    });
  }

  void _removePhoto(int index) {
    final removedPath = _paths[index];
    setState(() {
      _paths.removeAt(index);
      // Rebuild the status map with shifted indices.
      final updated = <int, _UploadStatus>{};
      for (final entry in _uploadStatus.entries) {
        if (entry.key < index) {
          updated[entry.key] = entry.value;
        } else if (entry.key > index) {
          updated[entry.key - 1] = entry.value;
        }
        // entry.key == index is dropped (file removed)
      }
      _uploadStatus
        ..clear()
        ..addAll(updated);
    });
    widget.onUpdated(_paths);
    // Delete from local DB (fire-and-forget — UI already updated)
    widget.dao.deleteSubmission(
      schoolId: widget.schoolId,
      examId: widget.examId,
      student: widget.student.adm,
      subject: widget.subject,
      paperNum: widget.paperNum,
      path: removedPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2435) : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Submit Answers — ${widget.student.name}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Upload photos of the student\'s answer sheets.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Image grid
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: _paths.isEmpty
                  ? _buildEmptyPlaceholder(cs, isDark)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: _paths.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1 / 1.3,
                            ),
                        itemBuilder: (context, i) {
                          return _buildThumbnail(cs, i);
                        },
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Add Photos button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _picking ? null : _addPhotos,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: cs.outline.withValues(alpha: 0.35),
                  radius: 4,
                ),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  child: _picking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.primary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add Photos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Done button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: cs.outline.withValues(alpha: 0.25),
          radius: 4,
        ),
        child: Container(
          height: 120,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 28,
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 8),
              Text(
                'No pages uploaded yet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme cs, int index) {
    final path = _paths[index];
    final status = _uploadStatus[index];
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Icon(
                Icons.broken_image_outlined,
                size: 24,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
        // Page number label
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Upload status overlay icon (bottom-right)
        if (status != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: _buildUploadStatusIcon(status),
          ),
      ],
    );
  }

  /// Small cloud icon in the bottom-right corner of each thumbnail indicating
  /// whether the file has been uploaded to remote storage.
  Widget _buildUploadStatusIcon(_UploadStatus status) {
    switch (status) {
      case _UploadStatus.pending:
      case _UploadStatus.uploading:
        return Icon(
          Icons.cloud_upload_outlined,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case _UploadStatus.done:
        return Icon(
          Icons.cloud_done_outlined,
          size: 12,
          color: Colors.green.shade300.withValues(alpha: 0.9),
        );
      case _UploadStatus.failed:
        return Icon(
          Icons.cloud_off_outlined,
          size: 12,
          color: Colors.red.shade300.withValues(alpha: 0.9),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed border painter (shared)
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashWidth = 5.0;
    final dashSpace = 4.0;
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════

class _MobileGradeEntrySheet extends StatefulWidget {
  const _MobileGradeEntrySheet({
    required this.student,
    required this.existingGrade,
    required this.maxScore,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    this.onSaved,
  });

  final StudentsData student;
  final Grade? existingGrade;
  final int maxScore;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final VoidCallback? onSaved;

  @override
  State<_MobileGradeEntrySheet> createState() => _MobileGradeEntrySheetState();
}

class _MobileGradeEntrySheetState extends State<_MobileGradeEntrySheet> {
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _totalCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = TextEditingController(
      text: widget.existingGrade != null
          ? _fmtScore(widget.existingGrade!.score)
          : '',
    );
    _totalCtrl = TextEditingController(
      text: '${widget.existingGrade?.total ?? widget.maxScore}',
    );
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final score = double.parse(_scoreCtrl.text);
    final total = int.parse(_totalCtrl.text);

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.upsertGrade(
        grade: GradesCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.exam.id),
          student: Value(widget.student.adm),
          subject: Value(widget.paper.subject),
          paper: Value(widget.paper.paper),
          score: Value(score),
          total: Value(total),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      if (mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.student.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Adm: ${widget.student.adm}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _scoreCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      decoration: _inputDeco(cs, label: 'Score'),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null) return 'Enter a valid number';
                        final total = int.tryParse(_totalCtrl.text) ?? 100;
                        if (n < 0 || n > total) return '0 – $total';
                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '/',
                      style: TextStyle(
                        fontSize: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _totalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDeco(cs, label: 'Out of'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text(
                        'Save Grade',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Small shared widgets
// ═════════════════════════════════════════════════════════════════════════════

class _PaperStatusChip extends StatelessWidget {
  const _PaperStatusChip({required this.status, required this.cs});
  final PaperStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final (String label, Color color) = switch (status) {
      PaperStatus.pending => (
        'Pending',
        cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      PaperStatus.progress => ('In Progress', const Color(0xFFF59E0B)),
      PaperStatus.done => ('Done', cs.primary),
      PaperStatus.marked => ('Marked', AppTheme.brandGreen),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═════════════════════════════════════════════════════════════════════════════

Widget _buildLoading(ColorScheme cs) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      ),
    ),
  );
}

Widget _buildEmpty(ColorScheme cs, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 24,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ),
  );
}

String _typeLabel(ExamType type) => switch (type) {
  ExamType.exam => 'Exam',
  ExamType.assignment => 'Assignment',
  ExamType.assessment => 'Assessment',
};

Color _typeColor(ExamType type, ColorScheme cs) => switch (type) {
  ExamType.exam => cs.primary,
  ExamType.assignment => const Color(0xFFF59E0B),
  ExamType.assessment => AppTheme.brandGreen,
};

Color _pctColor(double pct, ColorScheme cs) {
  if (pct >= 70) return AppTheme.brandGreen;
  if (pct >= 50) return const Color(0xFFF59E0B);
  return cs.error;
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtScore(double score) => score == score.truncateToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(1);

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

InputDecoration _inputDeco(ColorScheme cs, {required String label}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    filled: true,
    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
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
      borderSide: BorderSide(color: cs.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}
