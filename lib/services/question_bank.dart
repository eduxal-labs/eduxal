import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';

import '../models/marking_status.dart' as models;
import '../models/paper_generation.dart' as models;
import '../models/question.dart' as models;
import '../models/question_grade.dart' as models;
import '../models/result.dart';
import '../proto/services/question_bank.pb.dart' as pb;
import '../proto/services/question_bank.pbgrpc.dart' as pbgrpc;
import '../proto/services/question_bank.pbenum.dart' as pbenum;
import 'import_file_parser.dart';

/// Callback for reporting progress from [QuestionBankService.importFileWithImages].
typedef ImportProgressCallback =
    void Function(String phase, String detail, double progress);

/// Result of importing a single file with its images.
class FileImportResult {
  final String fileName;
  final String topic;
  final int questionsCreated;
  final int questionsErrored;
  final int imagesUploaded;
  final int imagesFailed;
  final int imagesSkipped; // missing on disk
  final List<String>
  errors; // per-question import errors + per-image upload errors

  const FileImportResult({
    required this.fileName,
    required this.topic,
    required this.questionsCreated,
    required this.questionsErrored,
    required this.imagesUploaded,
    required this.imagesFailed,
    required this.imagesSkipped,
    required this.errors,
  });

  bool get isFullSuccess =>
      questionsErrored == 0 && imagesFailed == 0 && imagesSkipped == 0;
  bool get isPartialSuccess => questionsCreated > 0;
}

/// Service for question bank operations.
///
/// Wraps the `QuestionBank` gRPC service. Handles:
/// 1. CRUD operations for questions within topics.
/// 2. Bulk importing questions from JSON.
/// 3. Requesting presigned S3 upload URLs for question images.
///
/// Uses the **main** [ClientChannel] (shared with the sync engine) for all gRPC
/// calls. A fresh-channel fallback is available if the main channel fails.
class QuestionBankService {
  QuestionBankService({
    required ClientChannel channel,
    required String host,
    required int port,
  }) : _mainChannel = channel,
       _host = host,
       _port = port;

  final ClientChannel _mainChannel;
  final String _host;
  final int _port;

  /// Creates a brand-new [ClientChannel] for fallback use.
  /// Caller is responsible for shutting it down.
  ClientChannel _freshChannel() => ClientChannel(
    _host,
    port: _port,
    options: const ChannelOptions(credentials: ChannelCredentials.secure()),
  );

  // ---------------------------------------------------------------------------
  // Question CRUD
  // ---------------------------------------------------------------------------

  /// List questions for a topic with pagination.
  ///
  /// Returns a tuple of `(questions, totalCount)`.
  Future<Result<(List<models.Question>, int), GrpcError>> listQuestions({
    required int topicId,
    int offset = 0,
    int limit = 50,
    required String accessToken,
  }) async {
    print('[QB] listQuestions → topicId=$topicId offset=$offset limit=$limit');
    try {
      final req = pb.ListQuestionsRequest()
        ..topicId = topicId
        ..offset = offset
        ..limit = limit;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.listQuestions(req, options: options);
      final questions = resp.questions.map(models.Question.fromProto).toList();
      print(
        '[QB] listQuestions ← OK (count=${questions.length} total=${resp.total})',
      );
      return Ok((questions, resp.total));
    } on GrpcError catch (e) {
      print('[QB] listQuestions ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] listQuestions ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('listQuestions failed: $e'));
    }
  }

  /// Get a single question by ID.
  Future<Result<models.Question, GrpcError>> getQuestion({
    required int id,
    required String accessToken,
  }) async {
    print('[QB] getQuestion → id=$id');
    try {
      final req = pb.GetQuestionRequest()..id = id;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.getQuestion(req, options: options);
      final question = models.Question.fromProto(resp.question);
      print('[QB] getQuestion ← OK (id=${question.id})');
      return Ok(question);
    } on GrpcError catch (e) {
      print('[QB] getQuestion ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] getQuestion ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('getQuestion failed: $e'));
    }
  }

  /// Create a new question in a topic.
  Future<Result<models.Question, GrpcError>> createQuestion({
    required int topicId,
    required String text,
    required int marks,
    required List<models.RubricCriterion> rubric,
    String? exampleAnswer,
    List<models.QuestionImage> images = const [],
    required String accessToken,
  }) async {
    print(
      '[QB] createQuestion → topicId=$topicId marks=$marks '
      'rubric=${rubric.length} images=${images.length}',
    );
    try {
      final req = pb.CreateQuestionRequest()
        ..topicId = topicId
        ..text = text
        ..marks = marks;
      req.rubric.addAll(rubric.map(_toProtoCriterion));
      if (exampleAnswer != null) req.exampleAnswer = exampleAnswer;
      req.images.addAll(images.map(_toProtoImage));
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.createQuestion(req, options: options);
      final question = models.Question.fromProto(resp.question);
      print('[QB] createQuestion ← OK (id=${question.id})');
      return Ok(question);
    } on GrpcError catch (e) {
      print('[QB] createQuestion ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] createQuestion ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('createQuestion failed: $e'));
    }
  }

  /// Update an existing question.
  Future<Result<models.Question, GrpcError>> updateQuestion({
    required int id,
    required String text,
    required int marks,
    required List<models.RubricCriterion> rubric,
    String? exampleAnswer,
    List<models.QuestionImage> images = const [],
    required String accessToken,
  }) async {
    print(
      '[QB] updateQuestion → id=$id marks=$marks '
      'rubric=${rubric.length} images=${images.length}',
    );
    try {
      final req = pb.UpdateQuestionRequest()
        ..id = id
        ..text = text
        ..marks = marks;
      req.rubric.addAll(rubric.map(_toProtoCriterion));
      if (exampleAnswer != null) req.exampleAnswer = exampleAnswer;
      req.images.addAll(images.map(_toProtoImage));
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.updateQuestion(req, options: options);
      final question = models.Question.fromProto(resp.question);
      print('[QB] updateQuestion ← OK (id=${question.id})');
      return Ok(question);
    } on GrpcError catch (e) {
      print('[QB] updateQuestion ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] updateQuestion ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('updateQuestion failed: $e'));
    }
  }

  /// Delete a question by ID.
  Future<Result<void, GrpcError>> deleteQuestion({
    required int id,
    required String accessToken,
  }) async {
    print('[QB] deleteQuestion → id=$id');
    try {
      final req = pb.DeleteQuestionRequest()..id = id;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      await client.deleteQuestion(req, options: options);
      print('[QB] deleteQuestion ← OK');
      return const Ok(null);
    } on GrpcError catch (e) {
      print('[QB] deleteQuestion ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] deleteQuestion ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('deleteQuestion failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Bulk Import
  // ---------------------------------------------------------------------------

  /// Bulk import questions from JSON content.
  Future<Result<models.BulkImportResult, GrpcError>> bulkImport({
    required String jsonContent,
    required String accessToken,
  }) async {
    print('[QB] bulkImport → jsonContent.length=${jsonContent.length}');
    try {
      final req = pb.BulkImportRequest()..jsonContent = jsonContent;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.bulkImportQuestions(req, options: options);
      final result = models.BulkImportResult.fromProto(resp);
      print(
        '[QB] bulkImport ← OK (created=${result.createdCount} errors=${result.errors.length})',
      );
      return Ok(result);
    } on GrpcError catch (e) {
      print('[QB] bulkImport ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] bulkImport ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('bulkImport failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Image Upload URLs
  // ---------------------------------------------------------------------------

  /// Requests presigned S3/R2 PUT URLs for uploading question images.
  ///
  /// Each [spec] in [imageSpecs] must contain:
  /// - `questionId`: the server-assigned question ID
  /// - `position`: 1-indexed position within the question's images
  /// - `context`: 0=question, 1=rubric, 2=example_answer
  /// - `filename`: basename of the file (for extension detection)
  /// - `caption`: optional caption text
  ///
  /// Returns [ImageUploadUrl] objects with `putUrl` for each image.
  Future<Result<List<pb.ImageUploadUrl>, GrpcError>> requestImageUploadUrls({
    required List<pb.ImageUploadSpec> imageSpecs,
    required String accessToken,
  }) async {
    print('[QB] requestImageUploadUrls → specs=${imageSpecs.length}');
    try {
      final req = pb.ImageUploadUrlsRequest();
      req.images.addAll(imageSpecs);
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.requestImageUploadUrls(req, options: options);
      print('[QB] requestImageUploadUrls ← OK (urls=${resp.urls.length})');
      return Ok(resp.urls.toList());
    } on GrpcError catch (e) {
      print('[QB] requestImageUploadUrls ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print(
        '[QB] requestImageUploadUrls ← UNEXPECTED ${e.runtimeType}: $e\n$st',
      );
      return Err(GrpcError.internal('requestImageUploadUrls failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Paper Generation (Task 04)
  // ---------------------------------------------------------------------------

  /// Generate paper questions from topic allocations using AI.
  Future<Result<List<models.PaperQuestion>, GrpcError>> generatePaper({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required int totalMarks,
    required List<models.TopicAllocation> allocations,
    required String accessToken,
  }) async {
    print(
      '[QB] generatePaper → school=$school exam=$exam subject=$subject '
      'grade=$grade totalMarks=$totalMarks allocations=${allocations.length}',
    );
    try {
      final req = pb.GeneratePaperRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade
        ..totalMarks = totalMarks;
      if (paper != null) req.paper = paper;
      if (stream != null) req.stream = stream;
      req.topicAllocations.addAll(
        allocations.map(
          (a) => pb.TopicAllocation()
            ..topicId = a.topicId
            ..marks = a.marks,
        ),
      );
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.generatePaper(req, options: options);
      final questions = resp.paperQuestions
          .map(models.PaperQuestion.fromProto)
          .toList();
      print('[QB] generatePaper ← OK (questions=${questions.length})');
      return Ok(questions);
    } on GrpcError catch (e) {
      print('[QB] generatePaper ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] generatePaper ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('generatePaper failed: $e'));
    }
  }

  /// Regenerate a single question on the paper.
  Future<Result<models.PaperQuestion, GrpcError>> regenerateQuestion({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    required String paperQuestionId,
    required int topicId,
    required int marks,
    required String accessToken,
  }) async {
    print(
      '[QB] regenerateQuestion → school=$school exam=$exam '
      'paperQuestionId=$paperQuestionId topicId=$topicId marks=$marks',
    );
    try {
      final req = pb.RegenerateQuestionRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade
        ..paperQuestionId = paperQuestionId
        ..topicId = topicId
        ..marks = marks;
      if (paper != null) req.paper = paper;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.regenerateQuestion(req, options: options);
      final question = models.PaperQuestion.fromProto(resp.paperQuestion);
      print('[QB] regenerateQuestion ← OK (id=${question.id})');
      return Ok(question);
    } on GrpcError catch (e) {
      print('[QB] regenerateQuestion ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] regenerateQuestion ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('regenerateQuestion failed: $e'));
    }
  }

  /// Edit a question on the generated paper.
  Future<Result<models.PaperQuestion, GrpcError>> editPaperQuestion({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required String paperQuestionId,
    required String text,
    required int marks,
    required List<models.RubricCriterion> rubric,
    required String accessToken,
  }) async {
    print(
      '[QB] editPaperQuestion → school=$school exam=$exam '
      'paperQuestionId=$paperQuestionId marks=$marks rubric=${rubric.length}',
    );
    try {
      final req = pb.EditPaperQuestionRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..paperQuestionId = paperQuestionId
        ..text = text
        ..marks = marks;
      if (paper != null) req.paper = paper;
      req.rubric.addAll(rubric.map(_toProtoCriterion));
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.editPaperQuestion(req, options: options);
      final question = models.PaperQuestion.fromProto(resp.paperQuestion);
      print('[QB] editPaperQuestion ← OK (id=${question.id})');
      return Ok(question);
    } on GrpcError catch (e) {
      print('[QB] editPaperQuestion ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] editPaperQuestion ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('editPaperQuestion failed: $e'));
    }
  }

  /// Finalize the paper and generate PDF.
  Future<Result<models.PaperPdf, GrpcError>> finalizePaper({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required List<String> paperQuestionIds,
    required String accessToken,
  }) async {
    print(
      '[QB] finalizePaper → school=$school exam=$exam subject=$subject '
      'grade=$grade questions=${paperQuestionIds.length}',
    );
    try {
      final req = pb.FinalizePaperRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade;
      if (paper != null) req.paper = paper;
      if (stream != null) req.stream = stream;
      req.paperQuestionIds.addAll(paperQuestionIds);
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.finalizePaper(req, options: options);
      final pdf = models.PaperPdf.fromProto(resp);
      print(
        '[QB] finalizePaper ← OK (pdfUrl=${pdf.pdfUrl.substring(0, 40)}...)',
      );
      return Ok(pdf);
    } on GrpcError catch (e) {
      print('[QB] finalizePaper ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] finalizePaper ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('finalizePaper failed: $e'));
    }
  }

  /// Get the PDF URL for a finalized paper.
  Future<Result<models.PaperPdf, GrpcError>> getPaperPdf({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required String accessToken,
  }) async {
    print(
      '[QB] getPaperPdf → school=$school exam=$exam '
      'subject=$subject grade=$grade',
    );
    try {
      final req = pb.GetPaperPdfRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade;
      if (paper != null) req.paper = paper;
      if (stream != null) req.stream = stream;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.getPaperPdf(req, options: options);
      final pdf = models.PaperPdf.fromGetPdfProto(resp);
      print('[QB] getPaperPdf ← OK (pdfUrl=${pdf.pdfUrl.substring(0, 40)}...)');
      return Ok(pdf);
    } on GrpcError catch (e) {
      print('[QB] getPaperPdf ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] getPaperPdf ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('getPaperPdf failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Marking Status & Question Grades (Task 05)
  // ---------------------------------------------------------------------------

  /// Get current marking job status.
  Future<Result<models.MarkingStatus, GrpcError>> getMarkingStatus({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required String accessToken,
  }) async {
    print(
      '[QB] getMarkingStatus → school=$school exam=$exam '
      'subject=$subject grade=$grade',
    );
    try {
      final req = pb.MarkingStatusRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade;
      if (paper != null) req.paper = paper;
      if (stream != null) req.stream = stream;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.getMarkingStatus(req, options: options);
      final status = models.MarkingStatus.fromProto(resp);
      print('[QB] getMarkingStatus ← OK (phase=${status.phase})');
      return Ok(status);
    } on GrpcError catch (e) {
      print('[QB] getMarkingStatus ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] getMarkingStatus ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('getMarkingStatus failed: $e'));
    }
  }

  /// Get per-question grade breakdown for a student.
  Future<Result<List<models.QuestionGradeDetail>, GrpcError>>
  getQuestionGrades({
    required String school,
    required String exam,
    required int student,
    required int subject,
    int? paper,
    required String accessToken,
  }) async {
    print(
      '[QB] getQuestionGrades → school=$school exam=$exam '
      'student=$student subject=$subject',
    );
    try {
      final req = pb.GetQuestionGradesRequest()
        ..school = school
        ..exam = exam
        ..student = student
        ..subject = subject;
      if (paper != null) req.paper = paper;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.getQuestionGrades(req, options: options);
      final grades = resp.questionGrades
          .map(models.QuestionGradeDetail.fromProto)
          .toList();
      print('[QB] getQuestionGrades ← OK (count=${grades.length})');
      return Ok(grades);
    } on GrpcError catch (e) {
      print('[QB] getQuestionGrades ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] getQuestionGrades ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('getQuestionGrades failed: $e'));
    }
  }

  /// Polls marking status every [interval] until complete or failed.
  /// Yields each status update to the caller.
  Stream<models.MarkingStatus> watchMarkingStatus({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required String accessToken,
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      final result = await getMarkingStatus(
        school: school,
        exam: exam,
        subject: subject,
        paper: paper,
        grade: grade,
        stream: stream,
        accessToken: accessToken,
      );
      switch (result) {
        case Ok(:final value):
          yield value;
          if (value.phase == models.MarkingPhase.complete ||
              value.phase == models.MarkingPhase.failed) {
            return;
          }
        case Err(:final error):
          yield models.MarkingStatus(
            phase: models.MarkingPhase.failed,
            progressCurrent: 0,
            progressTotal: 0,
            errorMessage: error.message,
          );
          return;
      }
      await Future.delayed(interval);
    }
  }

  // ---------------------------------------------------------------------------
  // Image File Upload
  // ---------------------------------------------------------------------------

  /// Uploads a local file to a presigned S3/R2 PUT URL.
  ///
  /// [putUrl] — the presigned PUT URL from [requestImageUploadUrls].
  /// [localPath] — absolute path to the file on the local filesystem.
  ///
  /// Returns `true` on HTTP 2xx, `false` on any failure.
  static Future<bool> uploadFileToUrl(String putUrl, String localPath) async {
    if (putUrl.isEmpty || localPath.isEmpty) return false;
    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('[QB] uploadFileToUrl: file not found at $localPath');
        return false;
      }
      final length = await file.length();
      final contentType = _contentTypeForExtension(localPath);

      httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      request.headers.set(HttpHeaders.contentLengthHeader, length.toString());
      await request.addStream(file.openRead());
      final response = await request.close();
      await response.drain<void>();

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      print(
        '[QB] uploadFileToUrl: ${ok ? 'OK' : 'FAIL'} '
        '(${response.statusCode}) ${localPath.split('/').last}',
      );
      return ok;
    } catch (e) {
      print('[QB] uploadFileToUrl: ERROR $e');
      return false;
    } finally {
      httpClient?.close(force: false);
    }
  }

  /// Returns the MIME Content-Type for common image file extensions.
  static String _contentTypeForExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  // ---------------------------------------------------------------------------
  // File Import Orchestrator
  // ---------------------------------------------------------------------------

  /// Imports a single parsed file: bulk-imports questions, then uploads images.
  ///
  /// [parsed] — a validated [ParsedImportFile] (must have `isValid == true`).
  /// [accessToken] — auth token.
  /// [onProgress] — optional progress callback.
  ///
  /// Flow:
  /// 1. Call `bulkImport(parsed.cleanedJson)`.
  /// 2. Map `question_ids` back to original question indices (skipping errored
  ///    indices from the import response).
  /// 3. Build `ImageUploadSpec` objects for all images across all created
  ///    questions and call `requestImageUploadUrls` once with all specs.
  /// 4. Upload each image file to its PUT URL via `uploadFileToUrl`.
  /// 5. Collect results.
  Future<FileImportResult> importFileWithImages({
    required ParsedImportFile parsed,
    required String accessToken,
    ImportProgressCallback? onProgress,
  }) async {
    assert(parsed.isValid && parsed.cleanedJson != null);

    final errors = <String>[];

    // ── Phase 1: Bulk import questions ────────────────────────────────────
    onProgress?.call(
      'importing',
      'Importing ${parsed.questionCount} questions…',
      0.0,
    );

    final importResult = await bulkImport(
      jsonContent: parsed.cleanedJson!,
      accessToken: accessToken,
    );

    switch (importResult) {
      case Err(:final error):
        return FileImportResult(
          fileName: parsed.fileName,
          topic: parsed.topic,
          questionsCreated: 0,
          questionsErrored: parsed.questionCount,
          imagesUploaded: 0,
          imagesFailed: 0,
          imagesSkipped: parsed.missingImages.length,
          errors: ['Import failed: ${error.message ?? error.code}'],
        );
      case Ok(:final value):
        // Collect per-question import errors.
        final errorIndices = <int>{};
        for (final e in value.errors) {
          errorIndices.add(e.index);
          errors.add('Q${e.index + 1}: ${e.message}');
        }

        final createdIds = value.questionIds;

        // If no questions were created or no images to upload, return early.
        if (createdIds.isEmpty || !parsed.hasImages) {
          return FileImportResult(
            fileName: parsed.fileName,
            topic: parsed.topic,
            questionsCreated: value.createdCount,
            questionsErrored: value.errors.length,
            imagesUploaded: 0,
            imagesFailed: 0,
            imagesSkipped: parsed.missingImages.length,
            errors: errors,
          );
        }

        // ── Phase 2: Build ImageUploadSpec objects ───────────────────────
        int imagesUploaded = 0;
        int imagesFailed = 0;
        int imagesSkipped = parsed.missingImages.length;

        final allSpecs = <pb.ImageUploadSpec>[];
        final specToLocalPath =
            <String, String>{}; // "qid:position" → local path

        final cleanedParsed =
            jsonDecode(parsed.cleanedJson!) as Map<String, dynamic>;
        final questions = cleanedParsed['questions'] as List<dynamic>;

        int k = 0;
        for (
          var j = 0;
          j < parsed.questionCount && k < createdIds.length;
          j++
        ) {
          if (errorIndices.contains(j)) continue;
          final questionId = createdIds[k];
          k++;

          if (j >= questions.length) continue;
          final q = questions[j] as Map<String, dynamic>;
          final images = q['images'] as List<dynamic>? ?? [];

          for (var p = 0; p < images.length; p++) {
            final img = images[p] as Map<String, dynamic>;
            final basename = (img['filename'] as String?) ?? '';
            if (basename.isEmpty) continue;

            final localPath = parsed.imagePathMap[basename];
            if (localPath == null) continue; // missing on disk

            final contextStr = (img['context'] as String?) ?? 'question';
            final contextInt = switch (contextStr) {
              'rubric' => 1,
              'example_answer' => 2,
              _ => 0, // question
            };

            final spec = pb.ImageUploadSpec()
              ..questionId = questionId
              ..position = p + 1
              ..context = contextInt
              ..filename = basename;
            if (img['caption'] is String) {
              spec.caption = img['caption'] as String;
            }

            allSpecs.add(spec);
            specToLocalPath['$questionId:${p + 1}'] = localPath;
          }
        }

        if (allSpecs.isEmpty) {
          return FileImportResult(
            fileName: parsed.fileName,
            topic: parsed.topic,
            questionsCreated: value.createdCount,
            questionsErrored: value.errors.length,
            imagesUploaded: 0,
            imagesFailed: 0,
            imagesSkipped: imagesSkipped,
            errors: errors,
          );
        }

        // ── Phase 3: Request upload URLs and upload files ────────────────
        int uploadsDone = 0;
        final totalUploads = allSpecs.length;

        onProgress?.call(
          'uploading',
          'Uploading images (0/$totalUploads)…',
          0.0,
        );

        // Single batched call for all images in this file.
        final urlResult = await requestImageUploadUrls(
          imageSpecs: allSpecs,
          accessToken: accessToken,
        );

        switch (urlResult) {
          case Err(:final error):
            imagesFailed += allSpecs.length;
            errors.add(
              'Image URL request failed: '
              '${error.message ?? error.code}',
            );
          case Ok(:final value):
            for (final uploadUrl in value) {
              final key = '${uploadUrl.questionId}:${uploadUrl.position}';
              final localPath = specToLocalPath[key];
              if (localPath == null) {
                imagesFailed++;
                errors.add(
                  'No local path for Q${uploadUrl.questionId} '
                  'pos ${uploadUrl.position}.',
                );
                uploadsDone++;
                onProgress?.call(
                  'uploading',
                  'Uploading images ($uploadsDone/$totalUploads)…',
                  uploadsDone / totalUploads,
                );
                continue;
              }

              final ok = await uploadFileToUrl(uploadUrl.putUrl, localPath);
              if (ok) {
                imagesUploaded++;
              } else {
                imagesFailed++;
                errors.add(
                  'Upload failed: Q${uploadUrl.questionId} '
                  'pos ${uploadUrl.position}.',
                );
              }
              uploadsDone++;
              onProgress?.call(
                'uploading',
                'Uploading images ($uploadsDone/$totalUploads)…',
                uploadsDone / totalUploads,
              );
            }
        }

        return FileImportResult(
          fileName: parsed.fileName,
          topic: parsed.topic,
          questionsCreated: value.createdCount,
          questionsErrored: value.errors.length,
          imagesUploaded: imagesUploaded,
          imagesFailed: imagesFailed,
          imagesSkipped: imagesSkipped,
          errors: errors,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Proto Mapping Helpers
  // ---------------------------------------------------------------------------

  /// Convert domain [models.ImageContext] to proto [pbenum.ImageContext].
  pbenum.ImageContext _toProtoImageContext(models.ImageContext ctx) =>
      switch (ctx) {
        models.ImageContext.question => pbenum.ImageContext.QUESTION,
        models.ImageContext.rubric => pbenum.ImageContext.RUBRIC,
        models.ImageContext.exampleAnswer => pbenum.ImageContext.EXAMPLE_ANSWER,
      };

  /// Convert domain [models.RubricCriterion] to proto [pb.RubricCriterion].
  pb.RubricCriterion _toProtoCriterion(models.RubricCriterion r) =>
      pb.RubricCriterion()
        ..criterion = r.criterion
        ..marks = r.marks;

  /// Convert domain [models.QuestionImage] to proto [pb.QuestionImage].
  pb.QuestionImage _toProtoImage(models.QuestionImage img) {
    final proto = pb.QuestionImage()
      ..context = _toProtoImageContext(img.context)
      ..filename = img.filename
      ..description = img.description;
    if (img.caption != null) proto.caption = img.caption!;
    return proto;
  }
}
