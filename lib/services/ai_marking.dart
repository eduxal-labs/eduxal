import 'dart:io';

import 'package:grpc/grpc.dart';

import '../models/result.dart';
import '../proto/services/ai_marking.pbgrpc.dart';

/// Service for AI-powered paper marking.
///
/// Wraps the `AiMarking` gRPC service. Handles:
/// 1. Requesting presigned S3 PUT URLs for marking scheme + student answer sheets.
/// 2. Uploading files to S3 via HTTP PUT.
/// 3. Triggering server-side AI marking.
class AiMarkingService {
  AiMarkingService(ClientChannel channel) : _client = AiMarkingClient(channel);

  final AiMarkingClient _client;

  /// Request presigned PUT URLs for marking scheme and student answer sheets.
  Future<Result<UploadUrlsResponse, GrpcError>> requestUploadUrls({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int schemeCount,
    required Map<int, int> studentSheetCounts,
    required String accessToken,
  }) async {
    try {
      final req = UploadUrlsRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..schemeCount = schemeCount;
      if (paper != null) req.paper = paper;
      for (final entry in studentSheetCounts.entries) {
        req.students.add(
          StudentSheetCount()
            ..adm = entry.key
            ..count = entry.value,
        );
      }
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
      );
      final resp = await _client.requestUploadUrls(req, options: options);
      return Ok(resp);
    } on GrpcError catch (e) {
      return Err(e);
    }
  }

  /// Upload a single file to S3 using a presigned PUT URL.
  /// Returns true on success.
  Future<bool> uploadFile(String putUrl, String localPath) async {
    if (putUrl.isEmpty) return true;
    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
      request.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      request.add(bytes);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      httpClient?.close();
    }
  }

  /// Request the server to mark a paper using AI.
  /// Returns immediately; actual grades arrive via watchChanges SyncDelta stream.
  Future<Result<MarkPaperResponse, GrpcError>> markPaper({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required int totalMarks,
    required List<String> schemeKeys,
    required Map<int, List<String>> studentKeys,
    required String accessToken,
  }) async {
    try {
      final req = MarkPaperRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade
        ..totalMarks = totalMarks;
      if (paper != null) req.paper = paper;
      if (stream != null) req.stream = stream;
      req.schemeKeys.addAll(schemeKeys);
      for (final entry in studentKeys.entries) {
        req.students.add(
          StudentMarkTarget()
            ..adm = entry.key
            ..keys.addAll(entry.value),
        );
      }
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
      );
      final resp = await _client.markPaper(req, options: options);
      return Ok(resp);
    } on GrpcError catch (e) {
      return Err(e);
    }
  }
}
