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
import '../../../../models/curriculum_levels.dart';
import '../../../../models/result.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
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
    required this.curriculumType,
    required this.schoolContext,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

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

  Paper get _paper => widget.paper;
  Exam get _exam => widget.exam.exam;

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
    final isDark = cs.brightness == Brightness.dark;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.5,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2332) : cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Select Invigilator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(
                child: ListView.builder(
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
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: cs.primary,
                            )
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
                          changes: PapersCompanion(
                            invigilator: Value(t.user.id),
                            updated: Value(now),
                          ),
                          accountId: accountId,
                        );
                      },
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

  Future<void> _loadStudents() async {
    final list = await _dao.getEnrolledStudents(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
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
    final subjLabel = subjectLabel(widget.curriculumType, _paper.subject);
    final paperNum = _paper.paper != null ? ' Paper ${_paper.paper}' : '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop =
                      constraints.maxWidth >= AppTheme.kMobileBreakpoint;

                  return ListView(
                    padding: isDesktop
                        ? const EdgeInsets.fromLTRB(16, 4, 16, 32)
                        : const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      // ── Paper Info Card ──────────────────────────────────
                      _PaperInfoCard(
                        paper: currentPaper,
                        exam: widget.exam,
                        curriculumType: widget.curriculumType,
                        cs: cs,
                        canEdit: _canManage,
                        onEditInvigilator: () =>
                            _showInvigilatorPicker(context, currentPaper),
                      ),

                      const SizedBox(height: 12),

                      // ── Status Advance ──────────────────────────────────
                      _PaperActionBar(
                        paper: currentPaper,
                        schoolId: widget.schoolId,
                        exam: _exam,
                        dao: _dao,
                        canManage: _canManage,
                        cs: cs,
                        onDeleted: () => Navigator.of(context).pop(),
                      ),

                      const SizedBox(height: 16),

                      // ── Analytics (when marked) ─────────────────────────
                      if (currentPaper.status == PaperStatus.marked) ...[
                        _AnalyticsSection(
                          gradeRows: gradeRows,
                          totalStudents: _students.length,
                          cs: cs,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Grade Entry Section ─────────────────────────────
                      _SectionLabel(label: 'Grades', cs: cs),
                      const SizedBox(height: 8),

                      if (_students.isEmpty)
                        _buildEmpty(cs, 'No students enrolled')
                      else if (isDesktop)
                        _GradeSpreadsheet(
                          students: _students,
                          gradeMap: gradeMap,
                          paper: currentPaper,
                          exam: _exam,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          canGrade: _canManage,
                          cs: cs,
                        )
                      else
                        _GradeList(
                          students: _students,
                          gradeMap: gradeMap,
                          paper: currentPaper,
                          exam: _exam,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          canGrade: _canManage,
                          cs: cs,
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Paper Info Card
// ═════════════════════════════════════════════════════════════════════════════

class _PaperInfoCard extends StatelessWidget {
  const _PaperInfoCard({
    required this.paper,
    required this.exam,
    required this.curriculumType,
    required this.cs,
    required this.canEdit,
    this.onEditInvigilator,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final CurriculumType curriculumType;
  final ColorScheme cs;
  final bool canEdit;
  final VoidCallback? onEditInvigilator;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final subjLabel = subjectLabel(curriculumType, paper.subject);
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        child: isMobile
            ? _buildMobileLayout(cs, isDark, subjLabel, startDt, endDt)
            : _buildDesktopLayout(cs, isDark, subjLabel, startDt, endDt),
      ),
    );
  }

  Widget _buildDesktopLayout(
    ColorScheme cs,
    bool isDark,
    String subjLabel,
    DateTime startDt,
    DateTime endDt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Subject + paper number row ──
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
            _PaperStatusChip(status: paper.status, cs: cs),
          ],
        ),

        const SizedBox(height: 10),

        // ── Scheduled time ──
        Row(
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              '${_fmtDate(startDt)} · ${_fmtTime(startDt)} – ${_fmtTime(endDt)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // ── Invigilator ──
        GestureDetector(
          onTap: (canEdit && paper.status == PaperStatus.pending)
              ? onEditInvigilator
              : null,
          child: Row(
            children: [
              UserAvatar(userId: exam.teacher.id, radius: 10),
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
              if (canEdit && paper.status == PaperStatus.pending)
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Exam type badge ──
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ],
    );
  }

  Widget _buildMobileLayout(
    ColorScheme cs,
    bool isDark,
    String subjLabel,
    DateTime startDt,
    DateTime endDt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Subject header + status chip inline ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                subjLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Paper number badge + status chip
            if (paper.paper != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                ),
                child: Text(
                  'P${paper.paper}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            _PaperStatusChip(status: paper.status, cs: cs),
          ],
        ),

        const SizedBox(height: 10),

        // ── Scheduled time ──
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
                '${_fmtDate(startDt)} · ${_fmtTime(startDt)} – ${_fmtTime(endDt)}',
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

        // ── Invigilator ──
        GestureDetector(
          onTap: (canEdit && paper.status == PaperStatus.pending)
              ? onEditInvigilator
              : null,
          child: Row(
            children: [
              UserAvatar(userId: exam.teacher.id, radius: 10),
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
              if (canEdit && paper.status == PaperStatus.pending)
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Exam type badge ──
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Paper Status Row + Advance Button
// ═════════════════════════════════════════════════════════════════════════════

class _PaperActionBar extends StatefulWidget {
  const _PaperActionBar({
    required this.paper,
    required this.schoolId,
    required this.exam,
    required this.dao,
    required this.canManage,
    required this.cs,
    this.onDeleted,
  });

  final Paper paper;
  final String schoolId;
  final Exam exam;
  final ExamsGradesDao dao;
  final bool canManage;
  final ColorScheme cs;
  final VoidCallback? onDeleted;

  @override
  State<_PaperActionBar> createState() => _PaperActionBarState();
}

class _PaperActionBarState extends State<_PaperActionBar>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _showCheck = false;
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _deletePaper(BuildContext context) async {
    final cs = widget.cs;
    final subjLabel = widget.paper.paper != null
        ? 'Paper ${widget.paper.paper}'
        : 'Paper';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        ),
        title: const Text(
          'Delete Paper?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        content: Text(
          'This will permanently remove $subjLabel.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    try {
      await widget.dao.deletePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        accountId: accountId,
      );
      widget.onDeleted?.call();
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
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.updatePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        changes: PapersCompanion(status: Value(next), updated: Value(now)),
        accountId: accountId,
      );
      // Brief checkmark confirmation for the "Start" button only
      if (widget.paper.status == PaperStatus.pending && mounted) {
        setState(() => _showCheck = true);
        _checkCtrl.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => _showCheck = false);
        _checkCtrl.reset();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PaperStatus? _nextStatus(PaperStatus s) => switch (s) {
    PaperStatus.pending => PaperStatus.progress,
    PaperStatus.progress => PaperStatus.done,
    PaperStatus.done => PaperStatus.marked,
    PaperStatus.marked => null,
  };

  ({Color color, IconData icon, String label})? _buttonConfig(PaperStatus s) =>
      switch (s) {
        PaperStatus.pending => (
          color: const Color(0xFF42A5F5),
          icon: Icons.play_arrow_rounded,
          label: 'Start',
        ),
        PaperStatus.progress => (
          color: const Color(0xFFFFA726),
          icon: Icons.check_circle_outline_rounded,
          label: 'Done',
        ),
        PaperStatus.done => (
          color: const Color(0xFF66BB6A),
          icon: Icons.grading_rounded,
          label: 'Grade',
        ),
        PaperStatus.marked => null,
      };

  @override
  Widget build(BuildContext context) {
    final cfg = _buttonConfig(widget.paper.status);
    final isPending = widget.paper.status == PaperStatus.pending;

    return Row(
      children: [
        // Delete button — only in pending state
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
                  color: widget.cs.error.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        _PaperStatusChip(status: widget.paper.status, cs: widget.cs),
        const SizedBox(width: 8),
        Text(
          _statusDescription(widget.paper.status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: widget.cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        if (widget.canManage && cfg != null)
          GestureDetector(
            onTap: _busy ? null : _advance,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: MediaQuery.sizeOf(context).width < 600 ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: cfg.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : _showCheck
                  ? ScaleTransition(
                      scale: _checkScale,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cfg.icon, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          cfg.label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  String _statusDescription(PaperStatus s) => switch (s) {
    PaperStatus.pending => 'Not yet started',
    PaperStatus.progress => 'Exam in progress',
    PaperStatus.done => 'Exam completed, awaiting grading',
    PaperStatus.marked => 'Fully graded',
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// Analytics Section (visible when paper is Marked)
// ═════════════════════════════════════════════════════════════════════════════

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({
    required this.gradeRows,
    required this.totalStudents,
    required this.cs,
  });

  final List<GradeRow> gradeRows;
  final int totalStudents;
  final ColorScheme cs;

  // Distribution buckets aligned to the task-specified grade bands.
  static const _buckets = [
    (label: '0–49', color: Color(0xFFEF5350)), // cs.error equivalent
    (label: '50–59', color: Colors.orange),
    (label: '60–69', color: Colors.amber),
    (label: '70–79', color: Colors.lightGreen),
    (label: '80–89', color: Colors.green),
    (label: '90–100', color: Color(0xFF2E7D32)),
  ];

  PaperAnalytics _compute() {
    final emptyDist = <String, int>{for (final b in _buckets) b.label: 0};

    if (gradeRows.isEmpty) {
      return PaperAnalytics(
        totalStudents: totalStudents,
        gradedStudents: 0,
        averageScore: 0,
        averagePercent: 0,
        distribution: emptyDist,
      );
    }

    double totalScore = 0;
    double totalPercent = 0;
    final dist = <String, int>{for (final b in _buckets) b.label: 0};

    // Only count students with a real (non-zero) score as graded.
    final actuallyGraded = gradeRows.where((r) => r.grade.score > 0).toList();

    for (final row in actuallyGraded) {
      final pct = row.grade.total > 0
          ? (row.grade.score / row.grade.total) * 100
          : 0.0;
      totalScore += row.grade.score;
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

    return PaperAnalytics(
      totalStudents: totalStudents,
      gradedStudents: actuallyGraded.length,
      averageScore: actuallyGraded.isEmpty
          ? 0
          : totalScore / actuallyGraded.length,
      averagePercent: actuallyGraded.isEmpty
          ? 0
          : totalPercent / actuallyGraded.length,
      distribution: dist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final analytics = _compute();
    final gradedPct = totalStudents > 0
        ? analytics.gradedStudents / totalStudents
        : 0.0;
    final avgPct = analytics.averagePercent;

    // Average colour: red below 50, orange 50-60, amber 60-70,
    // lightGreen 70-80, green 80-90, dark-green 90+.
    final avgColor = avgPct < 50
        ? const Color(0xFFEF5350)
        : avgPct < 60
        ? Colors.orange
        : avgPct < 70
        ? Colors.amber
        : avgPct < 80
        ? Colors.lightGreen
        : avgPct < 90
        ? Colors.green
        : const Color(0xFF2E7D32);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 560;

          // ── Stats summary panel ───────────────────────────────────────────
          final statsPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Graded progress bar row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: SizedBox(
                            height: 4,
                            child: LinearProgressIndicator(
                              value: gradedPct,
                              backgroundColor: isDark
                                  ? const Color(0xFF2A3848)
                                  : cs.outlineVariant.withValues(alpha: 0.25),
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${analytics.gradedStudents}/${analytics.totalStudents} graded',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Class average big number
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${avgPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: avgColor,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'class average',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          // ── Distribution bar chart ────────────────────────────────────────
          final distPanel = _CompactBarChart(
            distribution: analytics.distribution,
            buckets: _buckets,
            cs: cs,
            isDark: isDark,
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: statsPanel),
                const SizedBox(width: 24),
                distPanel,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [statsPanel, const SizedBox(height: 14), distPanel],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact vertical bar chart — no fl_chart dependency
// ─────────────────────────────────────────────────────────────────────────────

class _CompactBarChart extends StatelessWidget {
  const _CompactBarChart({
    required this.distribution,
    required this.buckets,
    required this.cs,
    required this.isDark,
  });

  final Map<String, int> distribution;
  final List<({String label, Color color})> buckets;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final values = [for (final b in buckets) distribution[b.label] ?? 0];
    final maxVal = values.fold(0, math.max);
    // Bar height area: 48px. Each bar is 24px wide.
    const barAreaHeight = 48.0;
    const barWidth = 22.0;

    return SizedBox(
      width: buckets.length * (barWidth + 4) - 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribution',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < buckets.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                SizedBox(
                  width: barWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Count label above bar
                      SizedBox(
                        height: 14,
                        child: Center(
                          child: Text(
                            values[i] > 0 ? '${values[i]}' : '',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Bar itself
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        child: Container(
                          width: barWidth,
                          height: maxVal <= 0
                              ? 4
                              : math.max(4, barAreaHeight * values[i] / maxVal),
                          color: buckets[i].color.withValues(
                            alpha: isDark ? 0.75 : 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Range labels row
          Row(
            children: [
              for (int i = 0; i < buckets.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                SizedBox(
                  width: barWidth,
                  child: Text(
                    _shortLabel(buckets[i].label),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Shorten labels: "0–49" → "F", "50–59" → "C", etc.
  String _shortLabel(String label) => switch (label) {
    '0–49' => 'F',
    '50–59' => 'C',
    '60–69' => 'B',
    '70–79' => 'A-',
    '80–89' => 'A',
    '90–100' => 'A+',
    _ => label,
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// Grade Spreadsheet — Desktop (≥ 600px)
// ═════════════════════════════════════════════════════════════════════════════

class _GradeSpreadsheet extends StatefulWidget {
  const _GradeSpreadsheet({
    required this.students,
    required this.gradeMap,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    required this.canGrade,
    required this.cs,
  });

  final List<StudentsData> students;
  final Map<int, Grade> gradeMap;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final bool canGrade;
  final ColorScheme cs;

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

  Future<void> _runAiMarking() async {
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

    // Phase 2 — progress bar fill over 2 seconds
    _progressCtrl.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.assigning);

    // Phase 3 — assign grades with staggered row flash
    final rng = math.Random();
    int marked = 0;
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
        }
      } catch (_) {
        // skip failed rows — don't abort the whole batch
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Wave flash — staggered 30ms per row for a satisfying top-to-bottom effect
    _triggerWaveFlash(gradedAdms);

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.done);

    // Phase 4 — show completion label for 2 seconds then reset
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnswerSubmissionSheet(
        student: student,
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        existingPaths: List.from(_submissions[adm] ?? []),
        onUpdated: (paths) {
          if (mounted) setState(() => _submissions[adm] = paths);
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

    final showAiButton =
        (widget.paper.status == PaperStatus.done ||
            widget.paper.status == PaperStatus.marked) &&
        widget.canGrade;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── AI Mark All button (desktop — appears in header row) ──────────
        if (showAiButton) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _AiMarkButton(
              hasSubmissions: _hasSubmissions,
              submissionCount: _submissionCount,
              isMarking: _aiMarking,
              phase: _aiPhase,
              markedCount: _aiMarkedCount,
              shimmerCtrl: _shimmerCtrl,
              progressCtrl: _progressCtrl,
              onTap: _runAiMarking,
              cs: cs,
            ),
          ),
          const SizedBox(height: 8),
        ],
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
              const SizedBox(width: 48),
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
                  setState(() => _drafts[adm] = v);
                },
                onSave: () => _saveRow(adm, _controllers[adm]!.text),
                onSubmitted: (_) {
                  _saveRow(adm, _controllers[adm]!.text);
                  _focusNext(i);
                },
                onSubmitTap: _aiMarking
                    ? () {}
                    : () => _openSubmissionSheet(context, student),
                onGradeButtonTap: () {
                  final fn = _focusNodes[adm]!;
                  if (fn.hasFocus) {
                    _saveRow(adm, _controllers[adm]!.text);
                  } else {
                    fn.requestFocus();
                    _controllers[adm]!.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controllers[adm]!.text.length,
                    );
                  }
                },
                onQuickGradeTap: _aiMarking ? () {} : () => _quickGrade(adm),
                isQuickGrading: _quickGrading[adm] ?? false,
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

// ─────────────────────────────────────────────────────────────────────────────
// AI Mark Button — shared between desktop spreadsheet and mobile list
// ─────────────────────────────────────────────────────────────────────────────

class _AiMarkButton extends StatelessWidget {
  const _AiMarkButton({
    required this.hasSubmissions,
    required this.submissionCount,
    required this.isMarking,
    required this.phase,
    required this.markedCount,
    required this.shimmerCtrl,
    required this.progressCtrl,
    required this.onTap,
    required this.cs,
    this.fullWidth = false,
  });

  final bool hasSubmissions;
  final int submissionCount;
  final bool isMarking;
  final _AiPhase phase;
  final int markedCount;
  final AnimationController shimmerCtrl;
  final AnimationController progressCtrl;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isIdle = phase == _AiPhase.idle;
    final isDone = phase == _AiPhase.done;
    final isAnalyzing = phase == _AiPhase.analyzing;
    final isAssigning = phase == _AiPhase.assigning;

    final String label;
    if (isDone) {
      label = 'Marked $markedCount papers';
    } else if (isAnalyzing) {
      label = 'Analyzing papers…';
    } else if (isAssigning) {
      label = 'Marking…';
    } else {
      label = 'Mark with AI';
    }

    final IconData icon = isDone ? Icons.check : Icons.auto_awesome;

    Widget buttonContent = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: fullWidth
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );

    // Shimmer mask during analyzing phase
    if (isAnalyzing) {
      buttonContent = AnimatedBuilder(
        animation: shimmerCtrl,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              final shimmerPos = shimmerCtrl.value * 2 - 0.5;
              return LinearGradient(
                begin: Alignment(shimmerPos - 1, 0),
                end: Alignment(shimmerPos + 1, 0),
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white,
                  Colors.white.withValues(alpha: 0.35),
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: buttonContent,
      );
    }

    final disabled = !hasSubmissions && isIdle;

    Widget button = Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Tooltip(
        message: disabled ? 'Submit student answer papers first' : '',
        child: GestureDetector(
          onTap: (disabled || isMarking) ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: buttonContent,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: fullWidth
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        // Progress bar (phases: analyzing + assigning)
        if (isMarking && !isDone) ...[
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: progressCtrl,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: progressCtrl.isAnimating
                      ? progressCtrl.value
                      : (isAssigning ? null : 0.0),
                  minHeight: 2,
                  backgroundColor: const Color(
                    0xFF6366F1,
                  ).withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                ),
              );
            },
          ),
        ],
        // Submission count subtitle
        const SizedBox(height: 4),
        Text(
          hasSubmissions
              ? '$submissionCount ${submissionCount == 1 ? 'paper' : 'papers'} submitted'
              : 'No papers submitted',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          textAlign: fullWidth ? TextAlign.center : TextAlign.right,
        ),
      ],
    );
  }
}

class _SpreadsheetRow extends StatefulWidget {
  const _SpreadsheetRow({
    required this.student,
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
    required this.onGradeButtonTap,
    required this.onQuickGradeTap,
    required this.isQuickGrading,
  });

  final StudentsData student;
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
  final VoidCallback onGradeButtonTap;
  final VoidCallback onQuickGradeTap;
  final bool isQuickGrading;

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
    final showGradeButton =
        widget.canGrade &&
        (widget.paperStatus == PaperStatus.done ||
            widget.paperStatus == PaperStatus.marked);
    final showSubmit =
        widget.paperStatus == PaperStatus.done ||
        widget.paperStatus == PaperStatus.marked;

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
            // Name + submission badge
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
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
                  if (widget.submissionCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 10,
                            color: AppTheme.brandGreen,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.submissionCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.brandGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
            // Pencil "Grade" icon button — only when paper is done/marked
            if (showGradeButton)
              Tooltip(
                message: widget.focusNode.hasFocus
                    ? 'Save grade'
                    : 'Edit grade',
                child: InkWell(
                  onTap: widget.onGradeButtonTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 22),
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
            // Quick-grade AI button (visible when submissions exist)
            if (showSubmit && widget.submissionCount > 0) ...[
              GestureDetector(
                onTap: (widget.isQuickGrading || !widget.canGrade)
                    ? null
                    : widget.onQuickGradeTap,
                child: Tooltip(
                  message: 'Quick-grade with AI',
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: widget.isQuickGrading
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF6366F1),
                            ),
                          )
                        : const Icon(
                            Icons.auto_fix_high,
                            size: 15,
                            color: Color(0xFF6366F1),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Submit answers button (visible when paper is Done)
            if (showSubmit)
              GestureDetector(
                onTap: widget.onSubmitTap,
                child: Tooltip(
                  message: widget.submissionCount > 0
                      ? '${widget.submissionCount} page(s) submitted'
                      : 'Submit answer sheets',
                  child: widget.submissionCount > 0
                      ? Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.brandGreen,
                        )
                      : Icon(
                          Icons.upload_file_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
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
    required this.students,
    required this.gradeMap,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    required this.canGrade,
    required this.cs,
  });

  final List<StudentsData> students;
  final Map<int, Grade> gradeMap;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final bool canGrade;
  final ColorScheme cs;

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
    }
  }

  Future<void> _runAiMarking() async {
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

    // Phase 2 — progress bar fill over 2 seconds
    _progressCtrl.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.assigning);

    // Phase 3 — assign grades with staggered row flash
    final rng = math.Random();
    int marked = 0;
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
        }
      } catch (_) {
        // skip failed rows — don't abort the whole batch
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Wave flash — staggered 30ms per row for a satisfying top-to-bottom effect
    _triggerWaveFlash(gradedAdms);

    if (!mounted) return;
    setState(() => _aiPhase = _AiPhase.done);

    // Phase 4 — show completion label for 2 seconds then reset
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnswerSubmissionSheet(
        student: student,
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        existingPaths: List.from(_submissions[adm] ?? []),
        onUpdated: (paths) {
          if (mounted) setState(() => _submissions[adm] = paths);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final adm = student.adm;
    final subCount = (_submissions[adm] ?? []).length;
    final showSubmit =
        widget.paper.status == PaperStatus.done ||
        widget.paper.status == PaperStatus.marked;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18222E) : cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Student name header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Adm: $adm',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.2),
              ),
              // Action: Submit Answer Sheets (only when done/marked)
              if (showSubmit)
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
              // Action: Quick Grade with AI (only when submissions exist)
              if (showSubmit && subCount > 0)
                _ActionSheetRow(
                  icon: Icons.auto_fix_high,
                  label: 'Quick Grade with AI',
                  cs: cs,
                  isDark: isDark,
                  onTap:
                      (_quickGrading[adm] == true ||
                          _aiMarking ||
                          !widget.canGrade)
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _quickGrade(adm);
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
              // Action: View Submissions (only when submissions exist)
              if (subCount > 0)
                _ActionSheetRow(
                  icon: Icons.photo_library_outlined,
                  label: 'View Submissions ($subCount)',
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openSubmissionSheet(context, student);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final showSubmit =
        widget.paper.status == PaperStatus.done ||
        widget.paper.status == PaperStatus.marked;
    final showAiButton = showSubmit && widget.canGrade;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── AI Mark All button (mobile — full-width card above list) ──────
        if (showAiButton) ...[
          _AiMarkButton(
            hasSubmissions: _hasSubmissions,
            submissionCount: _submissionCount,
            isMarking: _aiMarking,
            phase: _aiPhase,
            markedCount: _aiMarkedCount,
            shimmerCtrl: _shimmerCtrl,
            progressCtrl: _progressCtrl,
            onTap: _runAiMarking,
            cs: cs,
            fullWidth: true,
          ),
          const SizedBox(height: 10),
        ],
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
                        // Name + ADM column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      student.name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (subCount > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandGreen.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '$subCount',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.brandGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
