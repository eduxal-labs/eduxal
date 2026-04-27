import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:grpc/grpc.dart';

import '../models/marking_status.dart' as models;
import '../models/paper_generation.dart' as models;
import '../models/question.dart' as models;
import '../models/question_grade.dart' as models;
import '../models/result.dart';
import '../proto/services/question_bank.pb.dart' as pb;
import '../proto/services/question_bank.pbgrpc.dart' as pbgrpc;

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
  static const String _questionBankLog = 'QuestionBankService';
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
      final req = pb.GetQuestionRequest()..questionId = id;
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
        ..questionId = id
        ..text = text
        ..marks = marks;
      req.rubric.addAll(rubric.map(_toProtoCriterion));
      if (exampleAnswer != null) req.exampleAnswer = exampleAnswer;
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
      final req = pb.DeleteQuestionRequest()..questionId = id;
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
  ///
  /// This endpoint is system-wide for question-bank imports. It does not send,
  /// derive, or require a school identifier on the client request path.
  Future<Result<models.BulkImportResult, GrpcError>> bulkImport({
    required String jsonContent,
    required String accessToken,
    String? diagnosticLabel,
  }) async {
    final label = diagnosticLabel?.trim().isNotEmpty == true
        ? diagnosticLabel!.trim()
        : 'bulk import';
    _logImportDiagnostic(
      'bulkImport.request',
      'label=$label scope=system-wide school=none jsonLength=${jsonContent.length}',
    );
    try {
      final req = pb.BulkImportRequest()..jsonContent = jsonContent;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.bulkImportQuestions(req, options: options);
      final result = models.BulkImportResult.fromProto(resp);
      _logImportDiagnostic(
        'bulkImport.response',
        'label=$label scope=system-wide school=none created=${result.createdCount} errors=${result.errors.length}',
      );
      return Ok(result);
    } on GrpcError catch (e, st) {
      _logGrpcFailure(
        operation: 'bulkImport',
        error: e,
        stackTrace: st,
        context:
            'label=$label scope=system-wide school=none jsonLength=${jsonContent.length}',
      );
      return Err(e);
    } catch (e, st) {
      _logImportDiagnostic(
        'bulkImport.unexpected',
        'label=$label scope=system-wide school=none errorType=${e.runtimeType} error=$e',
        stackTrace: st,
      );
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

  /// Generate questions for a paper from topic allocations.
  ///
  /// Triggers async paper generation on the server. On success, call
  /// [getPaperQuestions] to retrieve the generated questions.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<void, GrpcError>> generatePaper({
    required String paperId,
    required int totalMarks,
    required List<models.TopicAllocation> allocations,
    required String accessToken,
  }) async {
    print(
      '[QB] generatePaper → paperId=$paperId '
      'totalMarks=$totalMarks allocations=${allocations.length}',
    );
    try {
      final req = pb.GeneratePaperRequest()
        ..paperId = paperId
        ..totalMarks = totalMarks;
      req.topicAllocations.addAll(
        allocations.map(
          (a) => pb.TopicAllocation()
            ..topicId = a.topicId
            ..totalMarks = a.marks,
        ),
      );
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.generatePaper(req, options: options);
      if (!resp.success) {
        return Err(
          GrpcError.internal(
            resp.message.isNotEmpty ? resp.message : 'Paper generation failed',
          ),
        );
      }
      print('[QB] generatePaper ← OK');
      return const Ok(null);
    } on GrpcError catch (e) {
      print('[QB] generatePaper ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] generatePaper ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('generatePaper failed: $e'));
    }
  }

  /// Regenerate a single question on the paper.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<models.PaperQuestion, GrpcError>> regenerateQuestion({
    required String paperId,
    required int position,
    required int topicId,
    required int marks,
    required String accessToken,
  }) async {
    print(
      '[QB] regenerateQuestion → paperId=$paperId '
      'position=$position topicId=$topicId marks=$marks',
    );
    try {
      final req = pb.RegenerateQuestionRequest()
        ..paperId = paperId
        ..position = position
        ..topicId = topicId
        ..marks = marks;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.regenerateQuestion(req, options: options);
      final question = models.PaperQuestion.fromProto(resp.question);
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
  ///
  /// NOTE: This method has been removed from the server API (M0 proto
  /// regeneration). Returns [GrpcError.unimplemented] immediately.
  Future<Result<models.Question, GrpcError>> editPaperQuestion({
    required int questionId,
    required String text,
    required int marks,
    required List<models.RubricCriterion> rubric,
    String? exampleAnswer,
    required String accessToken,
  }) async {
    print('[QB] editPaperQuestion → STUB (removed from server API)');
    return Err(
      GrpcError.unimplemented(
        'editPaperQuestion has been removed from the server API',
      ),
    );
  }

  /// Set (or clear) the section label for a single question on a generated paper.
  ///
  /// NOTE: This method has been removed from the server API (M0 proto
  /// regeneration). Returns [GrpcError.unimplemented] immediately.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<void, GrpcError>> setPaperQuestionSection({
    required String paperId,
    required int position,
    String? section,
    required String accessToken,
  }) async {
    print('[QB] setPaperQuestionSection → STUB (removed from server API)');
    return Err(
      GrpcError.unimplemented(
        'setPaperQuestionSection has been removed from the server API',
      ),
    );
  }

  /// Finalize the paper and generate PDF.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<models.PaperPdf, GrpcError>> finalizePaper({
    required String paperId,
    required String accessToken,
  }) async {
    print('[QB] finalizePaper → paperId=$paperId');
    try {
      final req = pb.FinalizePaperRequest()..paperId = paperId;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.finalizePaper(req, options: options);
      final pdf = models.PaperPdf.fromProto(resp);
      print('[QB] finalizePaper ← OK (pdfKey=${pdf.pdfUrl})');
      return Ok(pdf);
    } on GrpcError catch (e) {
      print('[QB] finalizePaper ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] finalizePaper ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('finalizePaper failed: $e'));
    }
  }

  /// Delete all generated questions for a paper and invalidate its S3 PDF.
  /// Only valid when the paper is still in Pending status.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<void, GrpcError>> clearPaperQuestions({
    required String paperId,
    required String accessToken,
  }) async {
    print('[QB] clearPaperQuestions → paperId=$paperId');
    try {
      final req = pb.ClearPaperQuestionsRequest()..paperId = paperId;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      await client.clearPaperQuestions(req, options: options);
      print('[QB] clearPaperQuestions ← OK');
      return const Ok(null);
    } on GrpcError catch (e) {
      print('[QB] clearPaperQuestions ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] clearPaperQuestions ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('clearPaperQuestions failed: $e'));
    }
  }

  /// Copy a finalized paper's question set to one or more additional streams.
  ///
  /// NOTE: This method has been removed from the server API (M0 proto
  /// regeneration). Returns [GrpcError.unimplemented] immediately.
  Future<Result<List<models.StreamCopyResult>, GrpcError>> copyPaperToStreams({
    required String paperId,
    required List<int> targetStreams,
    required String accessToken,
  }) async {
    print('[QB] copyPaperToStreams → STUB (removed from server API)');
    return Err(
      GrpcError.unimplemented(
        'copyPaperToStreams has been removed from the server API',
      ),
    );
  }

  /// Get the PDF URL for a finalized paper.
  ///
  /// NOTE: This method has been removed from the server API (M0 proto
  /// regeneration). Use the pdfKey returned by [finalizePaper] instead.
  Future<Result<models.PaperPdf, GrpcError>> getPaperPdf({
    required String paperId,
    required String accessToken,
  }) async {
    print('[QB] getPaperPdf → STUB (removed from server API)');
    return Err(
      GrpcError.unimplemented(
        'getPaperPdf has been removed from the server API',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Get Paper Questions (Task 04)
  // ---------------------------------------------------------------------------

  /// Fetch the currently assembled question list for a paper from the server.
  /// Returns an empty list if no paper has been generated yet.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<List<models.PaperQuestion>, GrpcError>> getPaperQuestions({
    required String paperId,
    int? student,
    required String accessToken,
  }) async {
    print('[QB] getPaperQuestions → paperId=$paperId');
    try {
      final req = pb.GetPaperQuestionsRequest()..paperId = paperId;
      if (student != null) req.student = student;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.getPaperQuestions(req, options: options);
      final questions = resp.questions
          .map(models.PaperQuestion.fromProto)
          .toList();
      print('[QB] getPaperQuestions ← OK (questions=${questions.length})');
      return Ok(questions);
    } on GrpcError catch (e) {
      print('[QB] getPaperQuestions ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[QB] getPaperQuestions ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('getPaperQuestions failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Marking Status & Question Grades (Task 05)
  // ---------------------------------------------------------------------------

  /// Get current marking job status.
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<models.MarkingStatus, GrpcError>> getMarkingStatus({
    required String paperId,
    required String accessToken,
  }) async {
    print('[QB] getMarkingStatus → paperId=$paperId');
    try {
      final req = pb.MarkingStatusRequest()..paperId = paperId;
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
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Future<Result<List<models.QuestionGradeDetail>, GrpcError>>
  getQuestionGrades({
    required String paperId,
    required int student,
    required String accessToken,
  }) async {
    print('[QB] getQuestionGrades → paperId=$paperId student=$student');
    try {
      final req = pb.GetQuestionGradesRequest()
        ..paperId = paperId
        ..student = student;
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 30),
      );
      final client = pbgrpc.QuestionBankClient(_mainChannel);
      final resp = await client.getQuestionGrades(req, options: options);
      final grades = resp.grades
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
  ///
  /// [paperId] is the composite paper identity string:
  /// `"$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}"`.
  Stream<models.MarkingStatus> watchMarkingStatus({
    required String paperId,
    required String accessToken,
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      final result = await getMarkingStatus(
        paperId: paperId,
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
    final diagnosticLabel =
        '${parsed.fileName} topic="${parsed.topic}" subject="${parsed.subject}"';

    _logImportDiagnostic(
      'importFileWithImages.start',
      'label=$diagnosticLabel scope=system-wide school=none '
          'curriculum=${parsed.curriculum} grade=${parsed.grade} '
          'questions=${parsed.questionCount} images=${parsed.totalImageRefs} '
          'missingImages=${parsed.missingImages.length}',
    );

    // ── Phase 1: Bulk import questions ────────────────────────────────────
    onProgress?.call(
      'importing',
      'Importing ${parsed.questionCount} questions…',
      0.0,
    );

    final importResult = await bulkImport(
      jsonContent: parsed.cleanedJson!,
      accessToken: accessToken,
      diagnosticLabel: diagnosticLabel,
    );

    switch (importResult) {
      case Err(:final error):
        final exactMessage = _grpcMessage(error);
        _logImportDiagnostic(
          'importFileWithImages.importFailed',
          'label=$diagnosticLabel scope=system-wide school=none '
              'grpcCode=${error.code} grpcMessage=$exactMessage',
        );
        return FileImportResult(
          fileName: parsed.fileName,
          topic: parsed.topic,
          questionsCreated: 0,
          questionsErrored: parsed.questionCount,
          imagesUploaded: 0,
          imagesFailed: 0,
          imagesSkipped: parsed.missingImages.length,
          errors: ['Import failed: $exactMessage'],
        );
      case Ok(:final value):
        _logImportDiagnostic(
          'importFileWithImages.importSucceeded',
          'label=$diagnosticLabel scope=system-wide school=none '
              'created=${value.createdCount} questionErrors=${value.errors.length} '
              'questionIds=${value.questionIds.length}',
        );

        // Collect per-question import errors.
        final errorIndices = <int>{};
        for (final e in value.errors) {
          errorIndices.add(e.index);
          errors.add('Q${e.index + 1}: ${e.message}');
        }

        final createdIds = value.questionIds;

        // If no questions were created or no images to upload, return early.
        if (createdIds.isEmpty || !parsed.hasImages) {
          _logImportDiagnostic(
            'importFileWithImages.complete',
            'label=$diagnosticLabel scope=system-wide school=none '
                'questionsCreated=${value.createdCount} questionsErrored=${value.errors.length} '
                'imagesUploaded=0 imagesFailed=0 imagesSkipped=${parsed.missingImages.length}',
          );
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
          _logImportDiagnostic(
            'importFileWithImages.complete',
            'label=$diagnosticLabel scope=system-wide school=none '
                'questionsCreated=${value.createdCount} questionsErrored=${value.errors.length} '
                'imagesUploaded=0 imagesFailed=0 imagesSkipped=$imagesSkipped',
          );
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

        _logImportDiagnostic(
          'importFileWithImages.imageUploadRequest',
          'label=$diagnosticLabel scope=system-wide school=none uploadSpecs=$totalUploads',
        );

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
            final exactMessage = _grpcMessage(error);
            _logImportDiagnostic(
              'importFileWithImages.imageUploadRequestFailed',
              'label=$diagnosticLabel scope=system-wide school=none '
                  'grpcCode=${error.code} grpcMessage=$exactMessage',
            );
            errors.add('Image URL request failed: $exactMessage');
          case Ok(:final value):
            _logImportDiagnostic(
              'importFileWithImages.imageUploadResponse',
              'label=$diagnosticLabel scope=system-wide school=none urls=${value.length}',
            );
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

        _logImportDiagnostic(
          'importFileWithImages.complete',
          'label=$diagnosticLabel scope=system-wide school=none '
              'questionsCreated=${value.createdCount} questionsErrored=${value.errors.length} '
              'imagesUploaded=$imagesUploaded imagesFailed=$imagesFailed imagesSkipped=$imagesSkipped',
        );

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

  void _logImportDiagnostic(
    String event,
    String message, {
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: _questionBankLog,
      error: event,
      stackTrace: stackTrace,
    );
  }

  void _logGrpcFailure({
    required String operation,
    required GrpcError error,
    required StackTrace stackTrace,
    required String context,
  }) {
    _logImportDiagnostic(
      '$operation.grpcError',
      '$context grpcCode=${error.code} grpcMessage=${_grpcMessage(error)}',
      stackTrace: stackTrace,
    );
  }

  String _grpcMessage(GrpcError error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'gRPC error ${error.code}';
  }

  // ---------------------------------------------------------------------------
  // Proto Mapping Helpers
  // ---------------------------------------------------------------------------

  /// Convert domain [models.RubricCriterion] to proto [pb.RubricCriterionInput].
  pb.RubricCriterionInput _toProtoCriterion(models.RubricCriterion r) =>
      pb.RubricCriterionInput()
        ..criterion = r.criterion
        ..marks = r.marks;
}
