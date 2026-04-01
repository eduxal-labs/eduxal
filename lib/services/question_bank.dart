import 'package:grpc/grpc.dart';

import '../models/question.dart' as models;
import '../models/result.dart';
import '../proto/services/question_bank.pb.dart' as pb;
import '../proto/services/question_bank.pbgrpc.dart' as pbgrpc;
import '../proto/services/question_bank.pbenum.dart' as pbenum;

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

  /// Request presigned PUT URLs for uploading question images.
  ///
  /// Returns the proto [pb.SignedImageUrl] directly since it is only used
  /// transiently in the upload flow (no domain model needed).
  Future<Result<List<pb.SignedImageUrl>, GrpcError>> requestImageUploadUrls({
    required int questionId,
    required List<String> filenames,
    required String accessToken,
  }) async {
    print(
      '[QB] requestImageUploadUrls → questionId=$questionId '
      'filenames=${filenames.length}',
    );
    try {
      final req = pb.ImageUploadUrlsRequest()..questionId = questionId;
      req.filenames.addAll(filenames);
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
