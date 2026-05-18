import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' hide Column;

import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../../../core/image_utils.dart';

import '../../../../cache/file_cache.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';

import '../../../../models/paper_generation.dart';
import '../../../../models/result.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../../services/authorization_service.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/student_avatar.dart';
import '../../../widgets/user_avatar.dart';
import '../../../widgets/marking_status_indicator.dart';
import 'paper_generation_page.dart';
import 'paper_pdf_viewer.dart';
import 'question_grades_sheet.dart';
import 'question_viewer_page.dart';

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
    this.streamNames = const {},
    this.serverPaperId,
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

  /// Maps streamCode → stream name for all streams in this paper's grade.
  /// Forwarded to [PaperGenerationPage] to populate the multi-stream copy picker.
  final Map<int, String> streamNames;

  /// Server-generated paper UUID (from papers_v2 / papers_v2.id).
  /// When non-null, used as the paper ID for all server RPC calls instead of
  /// the composite format. Required for assessments/assignments where the
  /// local exam ID differs from the server's paper ID.
  final String? serverPaperId;

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
  StreamSubscription<List<StudentsData>>? _studentsSub;
  bool? _lastIsDesktop;

  bool _hasDirtyGrades = false;
  final GlobalKey<_GradeSpreadsheetState> _spreadsheetKey = GlobalKey();
  final GlobalKey<_GradeListState> _gradeListKey = GlobalKey();

  // ── AI marking state (driven by callbacks from child widgets) ──────────
  bool _aiMarking = false;
  _AiPhase _aiPhase = _AiPhase.idle;
  int _aiMarkedCount = 0;
  double _aiProgress = 0.0;

  // ── Marking scheme state ────────────────────────────────────────────────

  // ── Generated paper PDF (populated when returning from PaperGenerationPage) ──
  PaperPdf? _paperPdf;

  // ── Teacher subject restriction (only for TeacherEntry) ─────────────────
  List<SubjectTeacher> _teacherSubjects = [];
  StreamSubscription? _teacherSubjectsSub;

  Map<int, List<String>> _childSubmissions = {};
  Set<int> _childDirtySubmissions = {};

  // ── Per-student paper state ──────────────────────────────────────────────
  bool _bulkPrinting = false;
  int _bulkGenerated = 0;
  int _bulkTotal = 0;
  bool _generatingPdfs = false;

  // ── Paper metadata cached from papers_v2 ─────────────────────────────────
  int? _paperTotalMarks;

  // ── Local PDF download state ────────────────────────────────────────────
  bool _teacherPdfLocal = false;
  final Set<int> _localStudentPdfs = {};
  final Set<int> _failedStudentPdfs = {};
  bool _downloadingPdfs = false;
  int _pdfDownloadCount = 0;
  int _pdfDownloadTotal = 0;

  bool get _allPdfsLocal =>
      _teacherPdfLocal &&
      _students.isNotEmpty &&
      _students.every((s) => _localStudentPdfs.contains(s.adm));

  Paper get _paper => widget.paper;
  Exam get _exam => widget.exam.exam;

  String get _paperId =>
      widget.serverPaperId ??
      '${widget.schoolId}|${_exam.id}|${_paper.subject}|'
          '${_paper.paper ?? ''}|${_paper.grade}|${_paper.stream ?? ''}';

  bool _computeHasUnmarked(Map<int, Grade> gradeMap) {
    final enrolledAdms = {for (final s in _students) s.adm};
    return _childSubmissions.entries.any(
      (e) =>
          e.value.isNotEmpty &&
          enrolledAdms.contains(e.key) &&
          (!gradeMap.containsKey(e.key) ||
              _childDirtySubmissions.contains(e.key)),
    );
  }

  Future<void> _runAiMarking() async {
    setState(() => _aiMarking = true);
    try {
      if (_spreadsheetKey.currentState != null) {
        await _spreadsheetKey.currentState?.runAiMarking();
      } else if (_gradeListKey.currentState != null) {
        await _gradeListKey.currentState?.runAiMarking();
      }
    } catch (e, st) {
      // Surface ANY exception — previously this was try/finally with no catch,
      // so exceptions propagated as unhandled Future errors with zero user
      // feedback (the button just silently reset to idle).
      print('[_runAiMarking] CAUGHT EXCEPTION: ${e.runtimeType}: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI marking error: $e')));
      }
    } finally {
      // Safety net: if the child exited without firing onAiPhaseChanged (e.g.
      // due to !mounted silent exits), reset the parent flag so the button
      // is never permanently stuck in loading state.
      if (mounted && _aiMarking) {
        setState(() => _aiMarking = false);
      }
    }
  }

  /// Whether the current user can progress the paper's status, delete, edit invigilator, or manage scheme.
  /// This is an exam-level management action — not subject-specific.
  bool get _canProgressStatus {
    final entry = widget.schoolContext.currentEntry.value;
    final perms = widget.schoolContext.permissions;
    // General permission check — any role with exams.update can progress status.
    if (perms.can(Resource.exams, Action.update)) return true;
    // Teacher-specific: can also progress if they created the exam, are the
    // invigilator, or teach this subject to this class.
    if (entry is TeacherEntry) {
      final userId = entry.teacher.user;
      if (_exam.teacher == userId) return true;
      if (_paper.invigilator == userId) return true;
      return _teacherSubjects.any(
        (st) =>
            st.grade == _paper.grade &&
            st.subject == _paper.subject &&
            (_paper.stream == null || st.stream == _paper.stream),
      );
    }
    return false;
  }

  /// Whether the current user can enter grades, submit answer sheets, or trigger AI marking.
  /// This IS subject-specific for teachers.
  bool get _canGradeContent {
    if (widget.schoolContext.currentEntry.value is OwnerEntry) return true;
    final perms = widget.schoolContext.permissions;
    if (perms.can(Resource.grades, Action.mark)) return true;
    // Teacher-specific fallback: can also grade if they created the exam, are
    // the invigilator, or teach this paper's subject to this class.
    final entry = widget.schoolContext.currentEntry.value;
    if (entry is TeacherEntry) {
      final userId = entry.teacher.user;
      if (_exam.teacher == userId) return true;
      if (_paper.invigilator == userId) return true;
      return _teacherSubjects.any(
        (st) =>
            st.grade == _paper.grade &&
            st.subject == _paper.subject &&
            (_paper.stream == null || st.stream == _paper.stream),
      );
    }
    return false;
  }



  Future<Directory> _schemeDirectory() async {
    final base = await FileCache.baseDir();
    final rel = FileCache.schemeDir(
      widget.schoolId,
      _exam.id,
      _paper.subject,
      _paper.paper ?? 0,
    );
    return Directory('$base/$rel');
  }

  /// Attempt to load the presigned PDF URL for this paper from the server.
  /// Called on init so returning users can view a previously-generated PDF
  /// without having to re-open the generation wizard.
  /// Silently ignores errors — not every paper has a finalized PDF yet.
  Future<void> _tryLoadExistingPdf() async {
    final token = accessToken;
    if (token.isEmpty) return;
    final result = await paperService.getPaperPdfUrl(
      paperId: _paperId,
      accessToken: token,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        setState(() => _paperPdf = value);
      case Err():
        // Paper not yet finalized — ignore silently.
        break;
    }
  }

  /// Load the paper's original totalMarks from the local papers_v2 table.
  Future<void> _loadPaperTotalMarks() async {
    final serverId = widget.serverPaperId;
    if (serverId == null) return;
    try {
      final row = await _dao.getPaperV2ById(serverId);
      if (row != null && mounted) {
        setState(() => _paperTotalMarks = row.totalMarks);
      }
    } catch (_) {}
  }

  /// Scan FileCache to determine which paper PDFs exist locally.
  /// Called on init and after downloads complete, so state persists across
  /// page reopens.
  Future<void> _checkLocalPdfState() async {
    final paperId = _paperId;
    final teacherPath = FileCache.teacherPaperPdfPath(widget.schoolId, paperId);
    final teacherFile = await FileCache.get(teacherPath);

    final localStudents = <int>{};
    for (final student in _students) {
      final path = FileCache.studentPaperPdfPath(
        widget.schoolId,
        paperId,
        student.adm,
      );
      if (await FileCache.get(path) != null) {
        localStudents.add(student.adm);
      }
    }

    if (!mounted) return;
    setState(() {
      _teacherPdfLocal = teacherFile != null;
      _localStudentPdfs
        ..clear()
        ..addAll(localStudents);
      _failedStudentPdfs.clear();
    });
  }

  // ── Per-student paper view ───────────────────────────────────────────────

  Future<void> _viewStudentPaper(StudentsData student) async {
    final token = accessToken;
    if (token.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Loading ${student.name} paper…'),
          ],
        ),
        duration: const Duration(minutes: 5),
      ),
    );

    try {
      final result = await paperService.getStudentPaperPdf(
        paperId: _paperId,
        studentId: student.adm.toString(),
        accessToken: token,
      );

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      switch (result) {
        case Ok(:final value):
          if (value.pdfUrl.isEmpty) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Paper not yet generated')),
            );
            return;
          }
          final bytes = await _downloadPdfBytes(value.pdfUrl);
          if (!mounted) return;
          if (bytes != null) {
            await Printing.layoutPdf(
              onLayout: (_) async => bytes,
              name:
                  '${student.name} - ${widget.subjectNames[_paper.subject] ?? 'Paper'}',
            );
          }
        case Err(:final error):
          messenger.showSnackBar(
            SnackBar(content: Text('Failed: ${error.message}')),
          );
      }
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// View a locally-cached student paper PDF in-app — no network required.
  Future<void> _viewStudentPaperLocal(StudentsData student) async {
    final paperId = _paperId;
    final localPath = FileCache.studentPaperPdfPath(
      widget.schoolId,
      paperId,
      student.adm,
    );

    final file = await FileCache.get(localPath);
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF not found locally')));
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaperPdfViewerPage(
          school: widget.schoolId,
          exam: _exam.id,
          subject: _paper.subject,
          paper: _paper.paper,
          grade: _paper.grade,
          stream: _paper.stream,
          accessToken: accessToken,
          title:
              '${student.name} - ${widget.subjectNames[_paper.subject] ?? 'Paper'}',
          localFilePath: file.path,
          serverPaperId: _paperId,
        ),
      ),
    );
  }

  // ── Generate PDFs (gear icon) ──────────────────────────────────────────

  Future<void> _generatePdfs() async {
    final token = accessToken;
    if (token.isEmpty || _generatingPdfs) return;

    setState(() => _generatingPdfs = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Generating PDFs…'),
          ],
        ),
        duration: Duration(minutes: 5),
      ),
    );

    try {
      // Step 1 — finalize the teacher/master paper PDF.
      final finalizeResult = await questionBankService.finalizePaper(
        paperId: _paperId,
        accessToken: token,
      );
      if (!mounted) return;
      if (finalizeResult case Err(:final error)) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Finalize failed: ${error.message}')),
        );
        return;
      }

      // Step 2 — resolve the storage key to a presigned URL.
      final urlResult = await paperService.getPaperPdfUrl(
        paperId: _paperId,
        accessToken: token,
      );
      if (!mounted) return;
      switch (urlResult) {
        case Ok(:final value):
          setState(() {
            _paperPdf = value;
            _teacherPdfLocal = false;
            _localStudentPdfs.clear();
            _failedStudentPdfs.clear();
          });
        case Err():
          break;
      }

      // Step 3 — trigger per-student PDF generation.
      final examType = widget.exam.exam.type;
      if (examType == ExamType.assessment) {
        await paperService.generateAssessment(
          paperId: _paperId,
          accessToken: token,
        );
      } else if (examType == ExamType.assignment) {
        await paperService.generateAssignment(
          paperId: _paperId,
          accessToken: token,
        );
      } else {
        // Default for exam-type papers — use generateAssessment.
        await paperService.generateAssessment(
          paperId: _paperId,
          accessToken: token,
        );
      }

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('PDFs generated'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text('Generation error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdfs = false);
    }
  }

  // ── Batch download all PDFs locally ──────────────────────────────────────

  Future<void> _downloadAllPdfs() async {
    final token = accessToken;
    if (token.isEmpty || _downloadingPdfs) return;

    setState(() {
      _downloadingPdfs = true;
      _pdfDownloadCount = 0;
      _pdfDownloadTotal = _students.length + 1; // +1 for teacher
      _failedStudentPdfs.clear();
    });

    final messenger = ScaffoldMessenger.of(context);
    final paperId = _paperId;

    try {
      // Step 1 — download teacher PDF if not already local.
      if (!_teacherPdfLocal) {
        final teacherPath = FileCache.teacherPaperPdfPath(
          widget.schoolId,
          paperId,
        );
        // Teacher PDF URL might already be in _paperPdf, or we resolve it afresh.
        final urlResult = await paperService.getPaperPdfUrl(
          paperId: paperId,
          accessToken: token,
        );
        if (!mounted) return;
        if (urlResult case Ok(:final value)) {
          final file = await FileCache.download(value.pdfUrl, teacherPath);
          if (!mounted) return;
          setState(() {
            if (file != null) _teacherPdfLocal = true;
            _pdfDownloadCount++;
          });
        }
      } else {
        setState(() => _pdfDownloadCount++);
      }

      // Step 2 — ensure per-student PDFs are generated on the server.
      // This is a no-op if already generated; callers may have skipped Phase 1.
      final examType = widget.exam.exam.type;
      if (examType == ExamType.assessment) {
        await paperService.generateAssessment(
          paperId: paperId,
          accessToken: token,
        );
      } else if (examType == ExamType.assignment) {
        await paperService.generateAssignment(
          paperId: paperId,
          accessToken: token,
        );
      } else {
        await paperService.generateAssessment(
          paperId: paperId,
          accessToken: token,
        );
      }

      // Step 3 — download each student PDF.
      for (final student in _students) {
        if (!mounted) return;
        final studentPath = FileCache.studentPaperPdfPath(
          widget.schoolId,
          paperId,
          student.adm,
        );

        // Skip already-downloaded students.
        if (_localStudentPdfs.contains(student.adm)) {
          setState(() => _pdfDownloadCount++);
          continue;
        }

        final pdfResult = await paperService.getStudentPaperPdf(
          paperId: paperId,
          studentId: student.adm.toString(),
          accessToken: token,
        );
        if (!mounted) return;

        if (pdfResult case Ok(:final value) when value.pdfUrl.isNotEmpty) {
          final file = await FileCache.download(value.pdfUrl, studentPath);
          if (!mounted) return;
          setState(() {
            if (file != null) {
              _localStudentPdfs.add(student.adm);
            } else {
              _failedStudentPdfs.add(student.adm);
            }
            _pdfDownloadCount++;
          });
        } else {
          setState(() {
            _failedStudentPdfs.add(student.adm);
            _pdfDownloadCount++;
          });
        }
      }

      if (!mounted) return;
      final failed = _failedStudentPdfs.length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failed > 0
                ? 'Downloaded ${_pdfDownloadCount - failed} PDFs ($failed failed)'
                : 'All PDFs downloaded',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Download error: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloadingPdfs = false);
    }
  }

  // ── Print all PDFs from local files ──────────────────────────────────────

  Future<void> _printAllLocalPdfs() async {
    if (_bulkPrinting) return;

    setState(() {
      _bulkPrinting = true;
      _bulkGenerated = 0;
      _bulkTotal = _students.length + 1; // +1 for teacher
    });

    final paperId = _paperId;
    final subjectLabel = widget.subjectNames[_paper.subject] ?? 'Paper';

    try {
      // Print teacher paper from local cache.
      final teacherPath = FileCache.teacherPaperPdfPath(
        widget.schoolId,
        paperId,
      );
      final teacherFile = await FileCache.get(teacherPath);
      if (teacherFile != null) {
        final bytes = await teacherFile.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: '$subjectLabel Teacher Copy',
        );
        setState(() => _bulkGenerated++);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Print each student paper from local cache.
      for (final student in _students) {
        if (!mounted) return;
        if (!_localStudentPdfs.contains(student.adm)) continue;

        final path = FileCache.studentPaperPdfPath(
          widget.schoolId,
          paperId,
          student.adm,
        );
        final file = await FileCache.get(path);
        if (file == null) continue;

        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: '${student.name} - $subjectLabel',
        );
        setState(() => _bulkGenerated++);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    } finally {
      if (mounted) setState(() => _bulkPrinting = false);
    }
  }

  // ── Deprecated — replaced by _downloadAllPdfs + _printAllLocalPdfs ──────

  Future<Uint8List?> _downloadPdfBytes(String url) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      return bytes;
    } catch (_) {
      return null;
    } finally {
      httpClient.close();
    }
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
    _subscribeStudents();
    _tryLoadExistingPdf();
    _loadPaperTotalMarks();

    // Subscribe to teacher subjects if the current entry is a teacher.
    final entry = widget.schoolContext.currentEntry.value;
    if (entry is TeacherEntry) {
      _teacherSubjectsSub = MembersDao(db)
          .watchTeacherSubjectsForTerm(
            widget.schoolId,
            entry.teacher.user,
            year: widget.year,
            term: widget.term,
          )
          .listen((subjects) {
            if (mounted) setState(() => _teacherSubjects = subjects);
          });
    }
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _teacherSubjectsSub?.cancel();
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

  void _subscribeStudents() {
    _studentsSub = _dao
        .watchEnrolledStudents(
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          grade: widget.grade,
          stream: _paper.stream,
        )
        .listen((list) {
          if (!mounted) return;
          final wasLoading = _loadingStudents;
          setState(() {
            _students = list;
            _loadingStudents = false;
          });
          if (wasLoading && list.isNotEmpty) {
            _checkLocalPdfState();
          }
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

                  final allGradeRows = snap.data ?? [];
                  // Filter grades to only students enrolled in this paper's
                  // grade/stream. The grades table has no stream column, so
                  // watchGradesForPaper returns grades across all streams.
                  final enrolledAdms = {for (final s in _students) s.adm};
                  final gradeRows = allGradeRows
                      .where((r) => enrolledAdms.contains(r.student.adm))
                      .toList();
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
                        streamNames: widget.streamNames,
                        cs: cs,
                        canEdit: _canProgressStatus,
                        canManage: _canProgressStatus,
                        canGrade: _canGradeContent,
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
                        hasUnmarkedSubmissions: _computeHasUnmarked(gradeMap),
                        onAiMark: _runAiMarking,
                        aiProgress: _aiMarking ? _aiProgress : null,
                        paperPdf: _paperPdf,
                        onPaperGenerated: (pdf) =>
                            setState(() => _paperPdf = pdf),
                        onPdfCleared: () => setState(() => _paperPdf = null),
                        bulkPrinting: _bulkPrinting,
                        bulkGenerated: _bulkGenerated,
                        bulkTotal: _bulkTotal,
                        generatingPdfs: _generatingPdfs,
                        onGeneratePdfs: _generatePdfs,
                        serverPaperId: widget.serverPaperId,
                        paperId: _paperId,
                        pdfsGenerated: _paperPdf != null || _teacherPdfLocal,
                        localPdfsReady: _allPdfsLocal,
                        downloadingPdfs: _downloadingPdfs,
                        pdfDownloadCount: _pdfDownloadCount,
                        pdfDownloadTotal: _pdfDownloadTotal,
                        onDownloadAllPdfs: _downloadAllPdfs,
                        onPrintAllLocal: _printAllLocalPdfs,
                        paperTotalMarks: _paperTotalMarks,
                      ),
                      const SizedBox(height: 16),

                      // ── Marking Status Indicator ────────────────────────
                      if (_aiPhase != _AiPhase.idle ||
                          widget.serverPaperId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MarkingStatusIndicator(
                            resolvedPaperId: _paperId,
                            onComplete: () {
                              if (mounted) {
                                setState(() {
                                  _aiMarking = false;
                                  _aiPhase = _AiPhase.idle;
                                  _aiProgress = 0.0;
                                  _aiMarkedCount = 0;
                                });
                              }
                            },
                            onRetry: _runAiMarking,
                          ),
                        ),

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
                          canGrade: _canGradeContent,
                          cs: cs,
                          initialDirtySubmissions: _childDirtySubmissions,
                          onDirtyChanged: (dirty) {
                            if (mounted)
                              setState(() => _hasDirtyGrades = dirty);
                          },
                          onSubmissionsChanged: () {
                            if (mounted) setState(() {});
                          },
                          onSubmissionsMapChanged: (map) {
                            if (mounted)
                              setState(() => _childSubmissions = map);
                          },
                          onDirtySubmissionsChanged: (dirty) {
                            if (mounted)
                              setState(() => _childDirtySubmissions = dirty);
                          },
                          onAiPhaseChanged: (phase) {
                            setState(() => _aiPhase = phase);
                            if (phase == _AiPhase.done) {
                              // Success path: hold "done" state for 2s for visual feedback, then reset.
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
                            } else if (phase == _AiPhase.idle) {
                              // Error/cancel path: reset immediately — no visual hold needed.
                              setState(() {
                                _aiMarking = false;
                                _aiProgress = 0.0;
                                _aiMarkedCount = 0;
                              });
                            }
                          },
                          onAiProgressChanged: (p) =>
                              setState(() => _aiProgress = p),
                          onAiMarkedCountChanged: (c) =>
                              setState(() => _aiMarkedCount = c),
                          localStudentPdfs: _localStudentPdfs,
                          onViewStudentPaperLocal: _viewStudentPaperLocal,
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
                          canGrade: _canGradeContent,
                          cs: cs,
                          initialDirtySubmissions: _childDirtySubmissions,
                          onViewStudentPaper: _viewStudentPaper,
                          localStudentPdfs: _localStudentPdfs,
                          onViewStudentPaperLocal: _viewStudentPaperLocal,
                          onDirtyChanged: (dirty) {
                            if (mounted)
                              setState(() => _hasDirtyGrades = dirty);
                          },
                          onSubmissionsChanged: () {
                            if (mounted) setState(() {});
                          },
                          onSubmissionsMapChanged: (map) {
                            if (mounted)
                              setState(() => _childSubmissions = map);
                          },
                          onDirtySubmissionsChanged: (dirty) {
                            if (mounted)
                              setState(() => _childDirtySubmissions = dirty);
                          },
                          onAiPhaseChanged: (phase) {
                            setState(() => _aiPhase = phase);
                            if (phase == _AiPhase.done) {
                              // Success path: hold "done" state for 2s for visual feedback, then reset.
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
                            } else if (phase == _AiPhase.idle) {
                              // Error/cancel path: reset immediately — no visual hold needed.
                              setState(() {
                                _aiMarking = false;
                                _aiProgress = 0.0;
                                _aiMarkedCount = 0;
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
    required this.streamNames,
    required this.cs,
    required this.canEdit,
    required this.canManage,
    required this.canGrade,
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
    this.paperPdf,
    this.onPaperGenerated,
    this.onPdfCleared,
    this.bulkPrinting = false,
    this.bulkGenerated = 0,
    this.bulkTotal = 0,
    this.generatingPdfs = false,
    this.onGeneratePdfs,
    this.serverPaperId,
    required this.paperId,
    this.pdfsGenerated = false,
    this.localPdfsReady = false,
    this.downloadingPdfs = false,
    this.pdfDownloadCount = 0,
    this.pdfDownloadTotal = 0,
    this.onDownloadAllPdfs,
    this.onPrintAllLocal,
    this.paperTotalMarks,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final String schoolId;
  final Map<int, String> subjectNames;
  final Map<int, String> streamNames;
  final ColorScheme cs;
  final bool canEdit;
  final bool canManage;
  final bool canGrade;
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
  final PaperPdf? paperPdf;
  final void Function(PaperPdf)? onPaperGenerated;
  final VoidCallback? onPdfCleared;
  final bool bulkPrinting;
  final int bulkGenerated;
  final int bulkTotal;
  final bool generatingPdfs;
  final VoidCallback? onGeneratePdfs;

  /// Server-generated paper UUID. When non-null, used for server RPC calls
  /// instead of the composite format.
  final String? serverPaperId;

  /// Composite paper ID (e.g. "school|exam|subject|paper|grade|stream"),
  /// used to resolve FileCache paths for offline PDF storage.
  final String paperId;

  /// True when the teacher paper PDF has been generated (Phase 1 complete).
  final bool pdfsGenerated;

  /// True when teacher + all student PDFs exist locally (Phase 3 ready).
  final bool localPdfsReady;

  /// True during batch download of all PDFs (Phase 2 in progress).
  final bool downloadingPdfs;

  final int pdfDownloadCount;
  final int pdfDownloadTotal;
  final VoidCallback? onDownloadAllPdfs;
  final VoidCallback? onPrintAllLocal;
  final int? paperTotalMarks;

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

  // ── Invigilator resolution ──────────────────────────────────────────────
  String? _invigilatorName;
  String _lastInvigilatorId = '';

  void _loadInvigilator() {
    final invId = widget.paper.invigilator;
    if (invId == _lastInvigilatorId) return;
    _lastInvigilatorId = invId;
    MembersDao(db).findUserById(invId).then((user) {
      if (!mounted) return;
      setState(() {
        _invigilatorName = user?.name;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadInvigilator();
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
    _loadInvigilator();
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
    final accessToken = cache.currentUser?.accessToken;
    if (accountId == null || accessToken == null) return;
    setState(() => _busy = true);
    try {
      String? actualServerId = widget.serverPaperId;
      if (actualServerId == null) {
        actualServerId = await widget.dao.getServerPaperId(
          schoolId: widget.schoolId,
          examId: widget.exam.exam.id,
          subject: widget.paper.subject,
          grade: widget.paper.grade,
          stream: widget.paper.stream,
        );
      }
      if (actualServerId != null) {
        final res = await paperService.deletePaper(
          paperId: actualServerId,
          accessToken: accessToken,
        );
        if (res case Err(:final error)) {
          if (mounted)
            showPermissionDenied(context, error.message ?? 'Permission denied');
          return;
        }
      }
      await widget.dao.deletePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        grade: widget.paper.grade,
        stream: widget.paper.stream,
        accountId: accountId,
        serverPaperId: actualServerId,
      );
      widget.onDeleted.call();
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showEditTimeSheet(BuildContext context) {
    final paper = widget.paper;
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);
    final durationMinutes = endDt.difference(startDt).inMinutes;

    showEduSheet(
      context: context,
      builder: (sheetCtx) => _EditTimeSheet(
        currentDate: startDt,
        currentStartTime: TimeOfDay.fromDateTime(startDt),
        currentDurationMinutes: durationMinutes < 1 ? 60 : durationMinutes,
        subjectName:
            widget.subjectNames[paper.subject] ?? 'Subject ${paper.subject}',
        onSave: (newDate, newStartTime, newDuration) async {
          final newStart = DateTime(
            newDate.year,
            newDate.month,
            newDate.day,
            newStartTime.hour,
            newStartTime.minute,
          );
          final newEnd = newStart.add(Duration(minutes: newDuration));
          final newDateDays = newDate.millisecondsSinceEpoch ~/ 86400000;

          final accountId = cache.currentUser?.user.id;
          if (accountId == null) return;

          setState(() => _busy = true);

          try {
            // Update server via RPC.
            final rpcPaperId =
                widget.serverPaperId ??
                '${widget.schoolId}|${widget.exam.exam.id}|'
                    '${paper.subject}|${paper.paper ?? ''}|'
                    '${paper.grade}|${paper.stream ?? ''}';
            await paperService.updatePaper(
              paperId: rpcPaperId,
              date: newDateDays,
              durationMinutes: newDuration,
              accessToken: accessToken,
            );

            // Update local DB.
            await widget.dao.updatePaperTimes(
              schoolId: widget.schoolId,
              examId: widget.exam.exam.id,
              subject: paper.subject,
              paperNum: paper.paper,
              grade: paper.grade,
              stream: paper.stream,
              start: newStart.millisecondsSinceEpoch ~/ 1000,
              end: newEnd.millisecondsSinceEpoch ~/ 1000,
              date: newDateDays,
              durationMinutes: newDuration,
              serverPaperId: rpcPaperId,
            );

            if (mounted) {
              Navigator.of(sheetCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paper time updated')),
              );
            }
          } on GrpcError catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server error: ${e.message}')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
            }
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
      ),
    );
  }

  Future<void> _advance() async {
    final paper = widget.paper;
    final next = _nextStatus(paper.status);
    if (next == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    debugPrint(
      '[_advance] Advancing paper: subject=${paper.subject}, '
      'paperNum=${paper.paper}, grade=${paper.grade}, '
      'stream=${paper.stream}, '
      'status=${paper.status} → $next, '
      'invigilator=${paper.invigilator}',
    );

    setState(() => _busy = true);
    _scaleCtrl.forward(from: 0);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final accessToken = cache.currentUser?.accessToken;
      if (accessToken != null) {
        String? actualServerId = widget.serverPaperId;
        if (actualServerId == null) {
          actualServerId = await widget.dao.getServerPaperId(
            schoolId: widget.schoolId,
            examId: widget.exam.exam.id,
            subject: paper.subject,
            grade: paper.grade,
            stream: paper.stream,
          );
        }
        if (actualServerId != null) {
          final v2StatusInt = switch (next) {
            PaperStatus.pending => 0,
            PaperStatus.progress => 4,
            PaperStatus.done => 5,
            PaperStatus.marked => 6,
          };
          final res = await paperService.forceSetPaperStatus(
            paperId: actualServerId,
            status: v2StatusInt,
            accessToken: accessToken,
          );
          if (res case Err(:final error)) {
            if (mounted)
              showPermissionDenied(
                context,
                error.message ?? 'Permission denied',
              );
            return;
          }
        }
      }

      await widget.dao.updatePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.exam.id,
        subject: paper.subject,
        paperNum: paper.paper,
        grade: paper.grade,
        stream: paper.stream,
        changes: PapersCompanion(status: Value(next), updated: Value(now)),
        accountId: accountId,
      );
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
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
    final isPending =
        status == PaperStatus.pending &&
        widget.paperPdf == null &&
        !widget.pdfsGenerated &&
        !widget.localPdfsReady;
    final isProgress = status == PaperStatus.progress;
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
                UserAvatar(userId: paper.invigilator, radius: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _invigilatorName ?? paper.invigilator,
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
              if (widget.canManage) ...[
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
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Edit Paper Time',
                  child: InkWell(
                    onTap: _busy ? null : () => _showEditTimeSheet(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: cs.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
              // ── Generate Paper (pending only) ─────────────────────────
              if (widget.canManage &&
                  isPending &&
                  widget.serverPaperId != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Generate Paper',
                  child: InkWell(
                    onTap: () async {
                      final pdf = await Navigator.push<PaperPdf?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaperGenerationPage(
                            schoolId: widget.schoolId,
                            examId: widget.exam.exam.id,
                            subjectId: widget.paper.subject,
                            paperId: widget.paper.paper,
                            grade: widget.paper.grade,
                            stream: widget.paper.stream,
                            subjectName:
                                widget.subjectNames[widget.paper.subject] ??
                                'Subject ${widget.paper.subject}',
                            examName: widget.exam.exam.name,
                            allStreamsForGrade: widget.streamNames.entries
                                .map((e) => (code: e.key, name: e.value))
                                .toList(),
                            serverPaperId: widget.serverPaperId!,
                            paperTotalMarks: widget.paperTotalMarks,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      if (pdf != null) {
                        widget.onPaperGenerated?.call(pdf);
                      } else {
                        // Teacher may have cleared questions — refresh PDF state.
                        widget.onPdfCleared?.call();
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: cs.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
              // ── View / Print Paper (prefers local file when cached) ──
              if (widget.paperPdf != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'View / Print Paper',
                  child: InkWell(
                    onTap: () async {
                      // Check for local copy first.
                      final localPath = FileCache.teacherPaperPdfPath(
                        widget.schoolId,
                        widget.paperId,
                      );
                      final localFile = await FileCache.get(localPath);

                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaperPdfViewerPage(
                            school: widget.schoolId,
                            exam: widget.exam.exam.id,
                            subject: widget.paper.subject,
                            paper: widget.paper.paper,
                            grade: widget.paper.grade,
                            stream: widget.paper.stream,
                            accessToken: accessToken,
                            title:
                                '${widget.subjectNames[widget.paper.subject] ?? 'Paper'}'
                                '${widget.paper.paper != null ? ' Paper ${widget.paper.paper}' : ''}',
                            localFilePath: localFile?.path,
                            serverPaperId: widget.serverPaperId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 18,
                        color: cs.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
              // ── View Marking Scheme (available after AI paper generation) ────
                // ── 3-Phase Button: Generate → Download → Print ────────────
              if (!isPending && widget.canManage) ...[
                const SizedBox(width: 4),
                // Phase 1: Generate PDFs on server
                if (!widget.pdfsGenerated) ...[
                  Tooltip(
                    message: 'Generate Student PDFs',
                    child: InkWell(
                      onTap: widget.generatingPdfs
                          ? null
                          : widget.onGeneratePdfs,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: widget.generatingPdfs
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: cs.primary.withValues(alpha: 0.7),
                                ),
                              )
                            : Icon(
                                Icons.auto_fix_high_rounded,
                                size: 18,
                                color: cs.primary.withValues(alpha: 0.7),
                              ),
                      ),
                    ),
                  ),
                ]
                // Phase 2: Download all PDFs locally
                else if (!widget.localPdfsReady &&
                    widget.onDownloadAllPdfs != null) ...[
                  Tooltip(
                    message: 'Download All PDFs',
                    child: InkWell(
                      onTap: widget.downloadingPdfs
                          ? null
                          : widget.onDownloadAllPdfs,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: widget.downloadingPdfs
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: cs.primary.withValues(alpha: 0.7),
                                ),
                              )
                            : Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: cs.primary.withValues(alpha: 0.7),
                              ),
                      ),
                    ),
                  ),
                  if (widget.downloadingPdfs && widget.pdfDownloadTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${widget.pdfDownloadCount}/${widget.pdfDownloadTotal}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ]
                // Phase 3: Print all from local files
                else if (widget.localPdfsReady &&
                    widget.onPrintAllLocal != null) ...[
                  Tooltip(
                    message: 'Print All Student Papers',
                    child: InkWell(
                      onTap: widget.bulkPrinting
                          ? null
                          : widget.onPrintAllLocal,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: widget.bulkPrinting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: cs.primary.withValues(alpha: 0.7),
                                ),
                              )
                            : Icon(
                                Icons.print_rounded,
                                size: 18,
                                color: cs.primary.withValues(alpha: 0.7),
                              ),
                      ),
                    ),
                  ),
                  if (widget.bulkPrinting && widget.bulkTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${widget.bulkGenerated}/${widget.bulkTotal}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ],
              // ── View Questions (when paper has generated questions) ────────
              if (!isPending) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'View Questions',
                  child: InkWell(
                    onTap: () {
                      final paperId =
                          widget.serverPaperId ??
                          '${widget.schoolId}|${widget.exam.exam.id}|'
                              '${widget.paper.subject}|${widget.paper.paper ?? ''}|'
                              '${widget.paper.grade}|${widget.paper.stream ?? ''}';
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuestionViewerPage(
                            paperId: paperId,
                            title:
                                '${widget.subjectNames[widget.paper.subject] ?? 'Paper'} Questions',
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.quiz_rounded,
                        size: 18,
                        color: cs.primary.withValues(alpha: 0.7),
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

    // State 3: Has unmarked submissions and scheme exists → indigo AI button
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
    this.onSubmissionsMapChanged,
    this.onDirtySubmissionsChanged,
    this.initialDirtySubmissions = const {},
    this.localStudentPdfs = const {},
    this.onViewStudentPaperLocal,
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
  final ValueChanged<Map<int, List<String>>>? onSubmissionsMapChanged;
  final ValueChanged<Set<int>>? onDirtySubmissionsChanged;
  final Set<int> initialDirtySubmissions;
  final Set<int> localStudentPdfs;
  final void Function(StudentsData)? onViewStudentPaperLocal;

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
    _dirtySubmissions.addAll(widget.initialDirtySubmissions);
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
      widget.onSubmissionsMapChanged?.call(Map.from(_submissions));
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
      (e) =>
          e.value.isNotEmpty &&
          (!widget.gradeMap.containsKey(e.key) ||
              _dirtySubmissions.contains(e.key)),
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

  void _resetAi() {
    if (!mounted) return;
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
      _aiMarkedCount = 0;
    });
    widget.onAiPhaseChanged?.call(_AiPhase.idle);
    widget.onAiProgressChanged?.call(0.0);
    _progressCtrl.reset();
  }

  Future<void> runAiMarking() async {
    if (!_hasSubmissions || !widget.canGrade || _aiMarking) return;
    final token = cache.currentUser?.accessToken;
    if (token == null) return;



    // ── Diagnostic: log full state before filtering ──────────────────────
    print('[AI-REMARK-SPREAD] === runAiMarking START ===');
    print('[AI-REMARK-SPREAD] dirtySubmissions=$_dirtySubmissions');
    for (final entry in _submissions.entries) {
      final adm = entry.key;
      final paths = entry.value;
      final hasGrade = widget.gradeMap.containsKey(adm);
      final isDirty = _dirtySubmissions.contains(adm);
      print(
        '[AI-REMARK-SPREAD] adm=$adm pathCount=${paths.length} '
        'hasGrade=$hasGrade isDirty=$isDirty paths=$paths',
      );
      // Log each file's existence and size
      for (int i = 0; i < paths.length; i++) {
        final f = File(paths[i]);
        final exists = f.existsSync();
        final size = exists ? f.lengthSync() : -1;
        print(
          '[AI-REMARK-SPREAD]   page[$i] exists=$exists size=$size '
          'path=${paths[i]}',
        );
      }
    }

    final studentsWithSubmissions = widget.students.where((s) {
      final paths = _submissions[s.adm] ?? [];
      if (paths.isEmpty) return false;
      // Include if: no grade yet, OR submissions were modified since last mark
      final included =
          !widget.gradeMap.containsKey(s.adm) ||
          _dirtySubmissions.contains(s.adm);
      if (!included) {
        print(
          '[AI-REMARK-SPREAD] SKIPPING adm=${s.adm} — '
          'hasGrade=${widget.gradeMap.containsKey(s.adm)} '
          'isDirty=${_dirtySubmissions.contains(s.adm)}',
        );
      }
      return included;
    }).toList();
    print(
      '[AI-REMARK-SPREAD] selected ${studentsWithSubmissions.length} students '
      'for remarking: ${studentsWithSubmissions.map((s) => s.adm).toList()}',
    );
    if (studentsWithSubmissions.isEmpty) return;

    setState(() {
      _aiMarking = true;
      _aiPhase = _AiPhase.analyzing;
      _aiMarkedCount = 0;
    });
    widget.onAiPhaseChanged?.call(_AiPhase.analyzing);
    widget.onAiProgressChanged?.call(0.0);

    // ── Phase 1: Request upload URLs ──────────────────────────────────────
    final studentSheetCounts = <int, int>{};
    for (final s in studentsWithSubmissions) {
      studentSheetCounts[s.adm] = (_submissions[s.adm] ?? []).length;
    }

    // Resolve the server UUID paper ID; fall back to composite format only
    // when the paper hasn't been synced to the server yet.
    final resolvedPaperId =
        await widget.dao.getServerPaperId(
          schoolId: widget.schoolId,
          examId: widget.exam.id,
          subject: widget.paper.subject,
          grade: widget.paper.grade,
          stream: widget.paper.stream,
        ) ??
        '${widget.schoolId}|${widget.exam.id}|${widget.paper.subject}|'
        '${widget.paper.paper ?? ''}|${widget.paper.grade}|${widget.paper.stream ?? ''}';
    final urlResult = await client.aiMarking.requestUploadUrls(
      paperId: resolvedPaperId,
      studentSheetCounts: studentSheetCounts,
      accessToken: token,
    );

    if (!mounted) return;
    switch (urlResult) {
      case Err(:final error):
        _resetAi();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get upload URLs: ${error.message}'),
          ),
        );
        return;
      case Ok():
        break;
    }
    final urlResponse = (urlResult as Ok).value;
      // ── Phase 3: Upload student answer sheets (25% → 50%) ────────────────
      int uploaded = 0;
      final totalFiles = studentSheetCounts.values.fold(0, (a, b) => a + b);
    final studentKeys = <int, List<String>>{};
    for (final studentUrl in urlResponse.studentUrls) {
      final adm = studentUrl.adm;
      final paths = _submissions[adm] ?? [];
      print(
        '[AI-UPLOAD-SPREAD] student=$adm pathCount=${paths.length} '
        'urlCount=${studentUrl.urls.length} paths=$paths',
      );
      final keys = <String>[];
      for (int i = 0; i < studentUrl.urls.length && i < paths.length; i++) {
        // Verify file exists and log size for diagnostics
        final fileToUpload = File(paths[i]);
        final exists = await fileToUpload.exists();
        final size = exists ? await fileToUpload.length() : -1;
        print(
          '[AI-UPLOAD-SPREAD] student=$adm page=$i '
          'path=${paths[i]} exists=$exists size=$size',
        );
        if (!exists) {
          print(
            '[AI-UPLOAD-SPREAD] WARNING: file missing at ${paths[i]} — '
            'skipping upload. Submissions may be stale.',
          );
          continue;
        }
        final ok = await client.aiMarking.uploadFile(
          studentUrl.urls[i].url,
          paths[i],
        );
        if (!ok) {
          if (mounted) {
            _resetAi();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload answer sheet for student $adm'),
              ),
            );
          } else {
            // Widget unmounted — notify parent so it can reset its _aiMarking flag.
            widget.onAiPhaseChanged?.call(_AiPhase.idle);
            widget.onAiProgressChanged?.call(0.0);
          }
          return;
        }
        keys.add(studentUrl.urls[i].key);
        uploaded++;
        if (mounted) {
          widget.onAiProgressChanged?.call((uploaded / totalFiles) * 0.8);
        }
      }
      studentKeys[adm] = keys;
    }

    // ── Phase 4: Trigger AI marking (80% → 100%) ──────────────────────────
    if (!mounted) {
      // Widget unmounted — notify parent before bailing out.
      widget.onAiPhaseChanged?.call(_AiPhase.idle);
      widget.onAiProgressChanged?.call(0.0);
      return;
    }
    setState(() => _aiPhase = _AiPhase.assigning);
    widget.onAiPhaseChanged?.call(_AiPhase.assigning);
    widget.onAiProgressChanged?.call(0.8);

    print(
      '[SPREADSHEET] calling markPaper — paperId=$resolvedPaperId totalMarks=$_maxScore',
    );
    final markResult = await client.aiMarking.markPaper(
      paperId: resolvedPaperId,
      totalMarks: _maxScore,
      studentKeys: studentKeys,
      accessToken: token,
    );
    print('[SPREADSHEET] markPaper returned: $markResult');

    if (!mounted) return;
    switch (markResult) {
      case Err(:final error):
        _resetAi();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI marking failed: ${error.message}')),
        );
        return;
      case Ok(:final value):
        if (!value.accepted) {
          _resetAi();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value.message.isNotEmpty
                    ? value.message
                    : 'AI marking was rejected',
              ),
            ),
          );
          return;
        }
    }

    // ── Phase 5: Marking queued — hand off to MarkingStatusIndicator ───────
    // Don't reset _aiPhase to done/idle here — the MarkingStatusIndicator
    // watches the marking_queue table via sync and shows real-time progress.
    // Its onComplete callback will reset _aiMarking and _aiPhase when the
    // server finishes marking (phase=5). Resetting here would hide the
    // indicator before the sync delivers the marking_queue row.

    // Write a local placeholder so the indicator shows "Queued for marking..."
    // immediately, before the server sync delivers the authoritative row.
    widget.dao.insertMarkingQueuePlaceholder(paperId: resolvedPaperId);

    widget.onAiProgressChanged?.call(1.0);
    _dirtySubmissions.clear();
    widget.onDirtySubmissionsChanged?.call(Set.from(_dirtySubmissions));
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
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
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
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
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
            widget.onSubmissionsMapChanged?.call(Map.from(_submissions));
            widget.onDirtySubmissionsChanged?.call(Set.from(_dirtySubmissions));
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
                canGrade:
                    widget.canGrade &&
                    !_aiMarking &&
                    widget.paper.status.index >= PaperStatus.done.index,
                paperStatus: widget.paper.status,
                submissionCount: (_submissions[adm] ?? []).length,
                isDirtySubmission: _dirtySubmissions.contains(adm),
                flashController: _flashControllers[adm]!,
                cs: cs,
                isPdfLocal: widget.localStudentPdfs.contains(adm),
                onViewPdf: widget.onViewStudentPaperLocal != null
                    ? () => widget.onViewStudentPaperLocal!(student)
                    : null,
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
                onSubmitTap:
                    (_aiMarking ||
                        widget.paper.status.index < PaperStatus.done.index)
                    ? null
                    : () => _openSubmissionSheet(context, student),
                onBreakdownTap:
                    (existingGrade != null &&
                        widget.paper.status == PaperStatus.marked)
                    ? () => showEduSheet(
                        context: context,
                        builder: (_) => QuestionGradesSheet(
                          school: widget.schoolId,
                          exam: widget.exam.id,
                          student: student.adm,
                          subject: widget.paper.subject,
                          paper: widget.paper.paper,
                          grade: widget.paper.grade,
                          stream: widget.paper.stream,
                          studentName: student.name,
                          overallScore: existingGrade.score,
                          totalMarks: existingGrade.total,
                        ),
                      )
                    : null,
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
    required this.isDirtySubmission,
    required this.flashController,
    required this.cs,
    required this.onChanged,
    required this.onSave,
    required this.onSubmitted,
    required this.onSubmitTap,
    this.onBreakdownTap,
    this.isPdfLocal = false,
    this.onViewPdf,
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
  final bool isDirtySubmission;
  final AnimationController flashController;
  final ColorScheme cs;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onSubmitTap;
  final VoidCallback? onBreakdownTap;
  final bool isPdfLocal;
  final VoidCallback? onViewPdf;

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
            // View marking breakdown button (visible when graded + marked)
            if (widget.onBreakdownTap != null) ...[
              GestureDetector(
                onTap: widget.onBreakdownTap,
                child: const Tooltip(
                  message: 'View marking breakdown',
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Icon(
                        Icons.analytics_outlined,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Submit answers button
            if (showSubmit)
              GestureDetector(
                onTap: widget.onSubmitTap,
                child: Tooltip(
                  message: widget.onSubmitTap == null
                      ? 'Paper must be done before submitting'
                      : widget.submissionCount > 0
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
                            color: widget.onSubmitTap == null
                                ? cs.onSurface.withValues(alpha: 0.2)
                                : cs.onSurfaceVariant.withValues(alpha: 0.4),
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
                        if (widget.isDirtySubmission &&
                            widget.existingGrade != null)
                          Positioned(
                            left: -1,
                            bottom: -1,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (showSubmit) const SizedBox(width: 4),
            // Per-student PDF view button
            if (widget.isPdfLocal && widget.onViewPdf != null) ...[
              Tooltip(
                message: 'View ${widget.student.name} paper',
                child: InkWell(
                  onTap: widget.onViewPdf,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 16,
                      color: AppTheme.brandGreen.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
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
    this.onSubmissionsMapChanged,
    this.onDirtySubmissionsChanged,
    this.initialDirtySubmissions = const {},
    this.onViewStudentPaper,
    this.localStudentPdfs = const {},
    this.onViewStudentPaperLocal,
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
  final ValueChanged<Map<int, List<String>>>? onSubmissionsMapChanged;
  final ValueChanged<Set<int>>? onDirtySubmissionsChanged;
  final Set<int> initialDirtySubmissions;
  final void Function(StudentsData)? onViewStudentPaper;

  /// Set of student adm values whose paper PDFs have been downloaded locally.
  final Set<int> localStudentPdfs;

  /// Called when a locally-cached student PDF should be viewed in-app.
  final void Function(StudentsData)? onViewStudentPaperLocal;

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
      (e) =>
          e.value.isNotEmpty &&
          (!widget.gradeMap.containsKey(e.key) ||
              _dirtySubmissions.contains(e.key)),
    );
  }

  @override
  void initState() {
    super.initState();
    _dirtySubmissions.addAll(widget.initialDirtySubmissions);
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
      widget.onSubmissionsMapChanged?.call(Map.from(_submissions));
    }
  }

  void _resetAi() {
    if (!mounted) return;
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
      _aiMarkedCount = 0;
    });
    widget.onAiPhaseChanged?.call(_AiPhase.idle);
    widget.onAiProgressChanged?.call(0.0);
    _progressCtrl.reset();
  }

  Future<void> runAiMarking() async {
    if (!_hasSubmissions || !widget.canGrade || _aiMarking) return;
    final token = cache.currentUser?.accessToken;
    if (token == null) return;



    // ── Diagnostic: log full state before filtering ──────────────────────
    print('[AI-REMARK-LIST] === runAiMarking START ===');
    print('[AI-REMARK-LIST] dirtySubmissions=$_dirtySubmissions');
    for (final entry in _submissions.entries) {
      final adm = entry.key;
      final paths = entry.value;
      final hasGrade = widget.gradeMap.containsKey(adm);
      final isDirty = _dirtySubmissions.contains(adm);
      print(
        '[AI-REMARK-LIST] adm=$adm pathCount=${paths.length} '
        'hasGrade=$hasGrade isDirty=$isDirty paths=$paths',
      );
      // Log each file's existence and size
      for (int i = 0; i < paths.length; i++) {
        final f = File(paths[i]);
        final exists = f.existsSync();
        final size = exists ? f.lengthSync() : -1;
        print(
          '[AI-REMARK-LIST]   page[$i] exists=$exists size=$size '
          'path=${paths[i]}',
        );
      }
    }

    final studentsWithSubmissions = widget.students.where((s) {
      final paths = _submissions[s.adm] ?? [];
      if (paths.isEmpty) return false;
      // Include if: no grade yet, OR submissions were modified since last mark
      final included =
          !widget.gradeMap.containsKey(s.adm) ||
          _dirtySubmissions.contains(s.adm);
      if (!included) {
        print(
          '[AI-REMARK-LIST] SKIPPING adm=${s.adm} — '
          'hasGrade=${widget.gradeMap.containsKey(s.adm)} '
          'isDirty=${_dirtySubmissions.contains(s.adm)}',
        );
      }
      return included;
    }).toList();
    print(
      '[AI-REMARK-LIST] selected ${studentsWithSubmissions.length} students '
      'for remarking: ${studentsWithSubmissions.map((s) => s.adm).toList()}',
    );
    if (studentsWithSubmissions.isEmpty) return;

    setState(() {
      _aiMarking = true;
      _aiPhase = _AiPhase.analyzing;
      _aiMarkedCount = 0;
    });
    widget.onAiPhaseChanged?.call(_AiPhase.analyzing);
    widget.onAiProgressChanged?.call(0.0);

    // ── Phase 1: Request upload URLs ──────────────────────────────────────
    final studentSheetCounts = <int, int>{};
    for (final s in studentsWithSubmissions) {
      studentSheetCounts[s.adm] = (_submissions[s.adm] ?? []).length;
    }

    // Resolve the server UUID paper ID; fall back to composite format only
    // when the paper hasn't been synced to the server yet.
    final resolvedPaperId =
        await widget.dao.getServerPaperId(
          schoolId: widget.schoolId,
          examId: widget.exam.id,
          subject: widget.paper.subject,
          grade: widget.paper.grade,
          stream: widget.paper.stream,
        ) ??
        '${widget.schoolId}|${widget.exam.id}|${widget.paper.subject}|'
        '${widget.paper.paper ?? ''}|${widget.paper.grade}|${widget.paper.stream ?? ''}';
    final urlResult = await client.aiMarking.requestUploadUrls(
      paperId: resolvedPaperId,
      studentSheetCounts: studentSheetCounts,
      accessToken: token,
    );

    if (!mounted) return;
    switch (urlResult) {
      case Err(:final error):
        _resetAi();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get upload URLs: ${error.message}'),
          ),
        );
        return;
      case Ok():
        break;
    }
    final urlResponse = (urlResult as Ok).value;
      // ── Phase 3: Upload student answer sheets (25% → 50%) ────────────────
      int uploaded = 0;
      final totalFiles = studentSheetCounts.values.fold(0, (a, b) => a + b);
    final studentKeys = <int, List<String>>{};
    for (final studentUrl in urlResponse.studentUrls) {
      final adm = studentUrl.adm;
      final paths = _submissions[adm] ?? [];
      print(
        '[AI-UPLOAD-LIST] student=$adm pathCount=${paths.length} '
        'urlCount=${studentUrl.urls.length} paths=$paths',
      );
      final keys = <String>[];
      for (int i = 0; i < studentUrl.urls.length && i < paths.length; i++) {
        // Verify file exists and log size for diagnostics
        final fileToUpload = File(paths[i]);
        final exists = await fileToUpload.exists();
        final size = exists ? await fileToUpload.length() : -1;
        print(
          '[AI-UPLOAD-LIST] student=$adm page=$i '
          'path=${paths[i]} exists=$exists size=$size',
        );
        if (!exists) {
          print(
            '[AI-UPLOAD-LIST] WARNING: file missing at ${paths[i]} — '
            'skipping upload. Submissions may be stale.',
          );
          continue;
        }
        final ok = await client.aiMarking.uploadFile(
          studentUrl.urls[i].url,
          paths[i],
        );
        if (!ok) {
          if (mounted) {
            _resetAi();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload answer sheet for student $adm'),
              ),
            );
          } else {
            // Widget unmounted — notify parent so it can reset its _aiMarking flag.
            widget.onAiPhaseChanged?.call(_AiPhase.idle);
            widget.onAiProgressChanged?.call(0.0);
          }
          return;
        }
        keys.add(studentUrl.urls[i].key);
        uploaded++;
        if (mounted) {
          widget.onAiProgressChanged?.call((uploaded / totalFiles) * 0.8);
        }
      }
      studentKeys[adm] = keys;
    }

    // ── Phase 4: Trigger AI marking (80% → 100%) ──────────────────────────
    if (!mounted) {
      // Widget unmounted — notify parent before bailing out.
      widget.onAiPhaseChanged?.call(_AiPhase.idle);
      widget.onAiProgressChanged?.call(0.0);
      return;
    }
    setState(() => _aiPhase = _AiPhase.assigning);
    widget.onAiPhaseChanged?.call(_AiPhase.assigning);
    widget.onAiProgressChanged?.call(0.8);

    print(
      '[GRADELIST] calling markPaper — paperId=$resolvedPaperId totalMarks=$_maxScore',
    );
    final markResult = await client.aiMarking.markPaper(
      paperId: resolvedPaperId,
      totalMarks: _maxScore,
      studentKeys: studentKeys,
      accessToken: token,
    );
    print('[GRADELIST] markPaper returned: $markResult');

    if (!mounted) return;
    switch (markResult) {
      case Err(:final error):
        _resetAi();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI marking failed: ${error.message}')),
        );
        return;
      case Ok(:final value):
        if (!value.accepted) {
          _resetAi();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value.message.isNotEmpty
                    ? value.message
                    : 'AI marking was rejected',
              ),
            ),
          );
          return;
        }
    }

    // ── Phase 5: Marking queued — hand off to MarkingStatusIndicator ───────
    // Don't reset _aiPhase to done/idle here — the MarkingStatusIndicator
    // watches the marking_queue table via sync and shows real-time progress.
    // Its onComplete callback will reset _aiMarking and _aiPhase when the
    // server finishes marking (phase=5). Resetting here would hide the
    // indicator before the sync delivers the marking_queue row.

    // Write a local placeholder so the indicator shows "Queued for marking..."
    // immediately, before the server sync delivers the authoritative row.
    widget.dao.insertMarkingQueuePlaceholder(paperId: resolvedPaperId);

    widget.onAiProgressChanged?.call(1.0);
    _dirtySubmissions.clear();
    widget.onDirtySubmissionsChanged?.call(Set.from(_dirtySubmissions));
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
            widget.onSubmissionsMapChanged?.call(Map.from(_submissions));
            widget.onDirtySubmissionsChanged?.call(Set.from(_dirtySubmissions));
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
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
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
      title: student.name,
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

    // If paper is not yet done, show informative message instead of action sheet
    if (widget.paper.status.index < PaperStatus.done.index) {
      final statusLabel = widget.paper.status == PaperStatus.pending
          ? 'pending'
          : 'in progress';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'This paper is still $statusLabel. Answer sheets and grading will be available once the paper is marked as done.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      return;
    }

    showEduSheet(
      context: context,
      builder: (ctx) => EduSheet(
        title: student.name,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action: Submit Answer Sheets (gated by paper status)
              _ActionSheetRow(
                icon: Icons.upload_file_outlined,
                label: 'Submit Answer Sheets',
                cs: cs,
                isDark: isDark,
                onTap: widget.paper.status.index >= PaperStatus.done.index
                    ? () {
                        Navigator.pop(ctx);
                        _openSubmissionSheet(context, student);
                      }
                    : null,
              ),
              // Action: Enter Grade (gated by canGrade + paper status)
              _ActionSheetRow(
                icon: Icons.edit_outlined,
                label: 'Enter Grade',
                cs: cs,
                isDark: isDark,
                onTap:
                    (widget.canGrade &&
                        widget.paper.status.index >= PaperStatus.done.index)
                    ? () {
                        Navigator.pop(ctx);
                        _openGradeEntry(context, student);
                      }
                    : null,
              ),
              // Action: Marking Breakdown (gated by grade + marked status)
              if (widget.gradeMap[student.adm] != null &&
                  widget.paper.status == PaperStatus.marked)
                _ActionSheetRow(
                  icon: Icons.analytics_outlined,
                  label: 'Marking breakdown',
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    final grade = widget.gradeMap[student.adm]!;
                    showEduSheet(
                      context: context,
                      builder: (_) => QuestionGradesSheet(
                        school: widget.schoolId,
                        exam: widget.exam.id,
                        student: student.adm,
                        subject: widget.paper.subject,
                        paper: widget.paper.paper,
                        grade: widget.paper.grade,
                        stream: widget.paper.stream,
                        studentName: student.name,
                        overallScore: grade.score,
                        totalMarks: grade.total,
                      ),
                    );
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
                onTap: !_aiMarking
                    ? () => _openStudentActionSheet(context, student)
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
                                if (pct != null)
                                  Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.brandGreen,
                                    ),
                                  ),
                                Text(
                                  '${_fmtScore(grade.score)}/${grade.total}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.brandGreen.withValues(
                                      alpha: 0.7,
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
                        // ── Per-student PDF icon (only when cached locally) ──
                        if (widget.localStudentPdfs.contains(student.adm) &&
                            widget.onViewStudentPaperLocal != null) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'View ${student.name} paper',
                            child: InkWell(
                              onTap: () =>
                                  widget.onViewStudentPaperLocal!(student),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 16,
                                  color: AppTheme.brandGreen.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
  bool _removing = false;
  bool _saving = false;

  /// True when the user has added or removed photos since opening the sheet.
  bool _hasChanges = false;

  /// Tracks upload status per file index. Absent = never queued.
  final Map<int, _UploadStatus> _uploadStatus = {};

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.existingPaths);
    print(
      '[ANSWER-SHEET] initState — student=${widget.student.adm} '
      'existingPaths(${_paths.length}): $_paths',
    );
    // Existing paths (loaded from DB) start as pending — they may not yet
    // have been uploaded (e.g. added while offline).
    for (int i = 0; i < _paths.length; i++) {
      _uploadStatus[i] = _UploadStatus.pending;
    }
  }

  Future<void> _savePickedFiles(List<XFile> picked) async {
    if (picked.isEmpty) return;

    final base = await FileCache.baseDir();
    final rel = FileCache.answerDir(
      widget.schoolId,
      widget.examId,
      widget.subject,
      widget.paperNum ?? 0,
      widget.student.adm,
    );
    final dir = Directory('$base/$rel');
    await dir.create(recursive: true);

    final newPaths = <String>[];
    for (final xFile in picked) {
      final index = _paths.length + newPaths.length; // 0-indexed
      final dest = File('${dir.path}/$index.jpg');
      await ImageUtils.compressAndSave(xFile.path, dest.path);
      final destSize = await dest.length();
      print(
        '[ANSWER-SHEET] saved page $index — '
        'src=${xFile.path} → '
        'dest=${dest.path} ($destSize bytes)',
      );
      newPaths.add(dest.path);
    }

    if (!mounted) return;

    // Mark new files as pending before adding them to the list so the
    // overlay icons appear immediately on the first render.
    final baseIndex = _paths.length;
    for (int i = 0; i < newPaths.length; i++) {
      _uploadStatus[baseIndex + i] = _UploadStatus.pending;
    }

    setState(() {
      _paths = [..._paths, ...newPaths];
      _hasChanges = true;
    });
    print(
      '[ANSWER-SHEET] _savePickedFiles done — '
      'total paths(${_paths.length}): $_paths',
    );
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

    // Log sync action so the server broadcasts the new pages to other devices.
    final accountId = cache.currentUser?.user.id;
    if (accountId != null) {
      await widget.dao.logUploadAnswerSheet(
        schoolId: widget.schoolId,
        examId: widget.examId,
        student: widget.student.adm,
        subject: widget.subject,
        paper: widget.paperNum,
        count: _paths.length,
        accountId: accountId,
      );
      // Delete local answer_pages so getSubmissionsForPaper won't return
      // stale rows before the server sync completes.
      await widget.dao.deleteAnswerPagesLocally(
        schoolId: widget.schoolId,
        examId: widget.examId,
        student: widget.student.adm,
        subject: widget.subject,
        paperNum: widget.paperNum,
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: false,
      );
      if (pictures == null || pictures.isEmpty) return;
      final xFiles = pictures.map((p) => XFile(p)).toList();
      await _savePickedFiles(xFiles);
    } catch (e) {
      debugPrint(
        '[AnswerSheet] scanner unavailable, falling back to camera: $e',
      );
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1500,
        maxHeight: 1500,
        imageQuality: 80,
      );
      if (picked != null) await _savePickedFiles([picked]);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addPhotos() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        maxWidth: 1500,
        maxHeight: 1500,
        imageQuality: 85,
      );
      await _savePickedFiles(picked);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Upload all locally-saved paths to remote storage in the background.
  ///
  /// Runs without blocking the UI. Thumbnail overlays reflect progress via
  /// [_uploadStatus].
  Future<void> _uploadPendingFiles() async {
    // Upload is deferred to the AI marking flow (Task C5).
    // Files are persisted locally and will be uploaded when AI marking runs.
    // Leave status as pending — don't mislead the user with a "done" icon.
    // The pending icon accurately reflects that files are saved locally
    // but not yet uploaded to the server.
  }

  /// Persists changes and closes the sheet.
  ///
  /// Deletes local [AnswerPages] rows for this student so that
  /// [getSubmissionsForPaper] (which merges answer_pages + paperSubmissions)
  /// won't resurrect deleted images before the server sync round-trip
  /// completes. The sync actions already logged during add/remove will
  /// reconcile the server state.
  Future<void> _saveAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_hasChanges) {
        // Wipe local answer_pages rows for this student so they don't
        // reappear when the sheet is re-opened before sync completes.
        // logUploadAnswerSheet / logDeleteAnswerSheet already called
        // during add/remove and they schedule a sync push internally.
        await widget.dao.deleteAnswerPagesLocally(
          schoolId: widget.schoolId,
          examId: widget.examId,
          student: widget.student.adm,
          subject: widget.subject,
          paperNum: widget.paperNum,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhoto(int index) async {
    if (_removing) return;
    _removing = true;
    try {
      final removedPath = _paths[index];
      print(
        '[ANSWER-SHEET] _removePhoto(index=$index) — '
        'removing $removedPath, total before=${_paths.length}',
      );
      // 1. Delete file from disk.
      try {
        final file = File(removedPath);
        if (await file.exists()) await file.delete();
        print('[ANSWER-SHEET] deleted file from disk: $removedPath');
      } catch (e) {
        print('[ANSWER-SHEET] WARNING: failed to delete $removedPath: $e');
      }
      setState(() {
        _paths.removeAt(index);
        _hasChanges = true;
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
      // NOTE: Do NOT call widget.onUpdated here — paths are not yet re-indexed.
      // The parent must receive correctly indexed paths (0.jpg, 1.jpg, …).
      // We call onUpdated after the re-indexing loop below.

      // 2. Delete the removed path from local DB.
      await widget.dao.deleteSubmission(
        schoolId: widget.schoolId,
        examId: widget.examId,
        student: widget.student.adm,
        subject: widget.subject,
        paperNum: widget.paperNum,
        path: removedPath,
      );

      // 3. Re-index remaining files on disk and update DB to match new paths.
      final base = await FileCache.baseDir();
      final relDir = FileCache.answerDir(
        widget.schoolId,
        widget.examId,
        widget.subject,
        widget.paperNum ?? 0,
        widget.student.adm,
      );
      print(
        '[ANSWER-SHEET] re-indexing ${_paths.length - index} file(s) '
        'starting at index=$index',
      );
      for (int i = index; i < _paths.length; i++) {
        final oldFile = File(_paths[i]);
        final newDest = File('$base/$relDir/$i.jpg');
        if (oldFile.path != newDest.path && await oldFile.exists()) {
          print('[ANSWER-SHEET] re-index[$i]: ${_paths[i]} → ${newDest.path}');
          await widget.dao.deleteSubmission(
            schoolId: widget.schoolId,
            examId: widget.examId,
            student: widget.student.adm,
            subject: widget.subject,
            paperNum: widget.paperNum,
            path: _paths[i],
          );
          await oldFile.rename(newDest.path);
          _paths[i] = newDest.path;
          await widget.dao.insertSubmission(
            schoolId: widget.schoolId,
            examId: widget.examId,
            student: widget.student.adm,
            subject: widget.subject,
            paperNum: widget.paperNum,
            path: newDest.path,
          );
        }
      }

      // 3b. NOW notify the parent with correctly re-indexed paths.
      if (mounted) setState(() {}); // Refresh thumbnails with re-indexed paths
      print(
        '[ANSWER-SHEET] _removePhoto done — '
        'final paths(${_paths.length}): $_paths',
      );
      widget.onUpdated(_paths);

      // 4. Log sync action and immediately delete local answer_pages rows
      //    so getSubmissionsForPaper (which merges answer_pages + paperSubmissions)
      //    won't resurrect deleted images before the server sync completes.
      final accountId = cache.currentUser?.user.id;
      if (accountId != null) {
        if (_paths.isEmpty) {
          await widget.dao.logDeleteAnswerSheet(
            schoolId: widget.schoolId,
            examId: widget.examId,
            student: widget.student.adm,
            subject: widget.subject,
            paper: widget.paperNum,
            accountId: accountId,
          );
        } else {
          await widget.dao.logUploadAnswerSheet(
            schoolId: widget.schoolId,
            examId: widget.examId,
            student: widget.student.adm,
            subject: widget.subject,
            paper: widget.paperNum,
            count: _paths.length,
            accountId: accountId,
          );
        }
        // Immediately delete local answer_pages so the UI reflects the change
        // before the server sync round-trip completes.
        await widget.dao.deleteAnswerPagesLocally(
          schoolId: widget.schoolId,
          examId: widget.examId,
          student: widget.student.adm,
          subject: widget.subject,
          paperNum: widget.paperNum,
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
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
          // Action buttons row: Camera + Gallery
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Camera button (primary)
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _picking ? null : _takePhoto,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.25),
                        ),
                      ),
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
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: cs.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Camera',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: cs.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Gallery button (secondary)
                Expanded(
                  flex: 2,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gallery',
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Save / Done button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: (_saving || _picking || _removing)
                  ? null
                  : () => _saveAndClose(),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _saving
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _hasChanges ? 'Save' : 'Done',
                        style: const TextStyle(
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
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  _ImagePreviewPage(paths: _paths, initialIndex: index),
            ),
          ),
          child: ClipRRect(
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
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Self-contained sheet — provides its own EduSheet wrapper (background,
    // handle, title, keyboard padding) per BUG-010 convention.
    return EduSheet(
      title: widget.student.name,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student admission number as a compact subtitle under the
              // EduSheet title row (student name is already shown in the title).
              Text(
                'Adm: ${widget.student.adm}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
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
                      decoration: _inputDeco(cs, label: 'Score').copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
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
                      decoration: _inputDeco(cs, label: 'Out of').copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel
                  IconButton(
                    tooltip: 'Cancel',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Save
                  IconButton(
                    tooltip: 'Save Grade',
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                    onPressed: _saving ? null : _save,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.brandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                      ),
                    ),
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
// Full-screen image preview (pinch-to-zoom + swipe between pages)
// ═════════════════════════════════════════════════════════════════════════════

class _ImagePreviewPage extends StatefulWidget {
  const _ImagePreviewPage({required this.paths, required this.initialIndex});
  final List<String> paths;
  final int initialIndex;

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 24,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentPage + 1} / ${widget.paths.length}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.file(
                File(widget.paths[index]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Colors.white38,
                ),
              ),
            ),
          );
        },
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

// ═════════════════════════════════════════════════════════════════════════════
// Edit Time Sheet — shown from PaperDetailPage header (pending papers only)
// ═════════════════════════════════════════════════════════════════════════════

class _EditTimeSheet extends StatefulWidget {
  const _EditTimeSheet({
    required this.currentDate,
    required this.currentStartTime,
    required this.currentDurationMinutes,
    required this.subjectName,
    required this.onSave,
  });

  final DateTime currentDate;
  final TimeOfDay currentStartTime;
  final int currentDurationMinutes;
  final String subjectName;
  final void Function(DateTime date, TimeOfDay startTime, int durationMinutes)
  onSave;

  @override
  State<_EditTimeSheet> createState() => _EditTimeSheetState();
}

class _EditTimeSheetState extends State<_EditTimeSheet> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late final TextEditingController _durationCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.currentDate;
    _startTime = widget.currentStartTime;
    _durationCtrl = TextEditingController(
      text: widget.currentDurationMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  DateTime get _endDateTime => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _startTime.hour,
    _startTime.minute,
  ).add(Duration(minutes: int.tryParse(_durationCtrl.text) ?? 60));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle bar ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────
            Text(
              'Edit Paper Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subjectName,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // ── Date picker ─────────────────────────────────────────────
            _SheetField(
              label: 'Date',
              cs: cs,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.12),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_date.day} ${_months[_date.month - 1]} ${_date.year}',
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Start time picker ───────────────────────────────────────
            _SheetField(
              label: 'Start Time',
              cs: cs,
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (picked != null) setState(() => _startTime = picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.12),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _startTime.format(context),
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Duration field ──────────────────────────────────────────
            _SheetField(
              label: 'Duration (minutes)',
              cs: cs,
              child: TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Computed end time ───────────────────────────────────────
            Text(
              'Ends at ${_endDateTime.hour.toString().padLeft(2, '0')}:${_endDateTime.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),

            // ── Save button ─────────────────────────────────────────────
            FilledButton(
              onPressed: _saving
                  ? null
                  : () {
                      final duration = int.tryParse(_durationCtrl.text) ?? 60;
                      if (duration < 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Duration must be at least 1 minute'),
                          ),
                        );
                        return;
                      }
                      setState(() => _saving = true);
                      widget.onSave(_date, _startTime, duration);
                    },
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.cs,
    required this.child,
  });

  final String label;
  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
