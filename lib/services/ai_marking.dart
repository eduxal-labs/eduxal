import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../models/result.dart';
import '../proto/services/ai_marking.pbgrpc.dart';

/// Service for AI-powered paper marking.
///
/// Wraps the `AiMarking` gRPC service. Handles:
/// 1. Requesting presigned S3 PUT URLs for marking scheme + student answer sheets.
/// 2. Uploading files to S3 via HTTP PUT.
/// 3. Triggering server-side AI marking.
///
/// Each gRPC call creates a **fresh** [ClientChannel] to avoid stale HTTP/2
/// connections. The upload phase can take minutes, during which an idle channel
/// may be silently dropped by routers or the OS. A fresh channel guarantees a
/// live TCP connection at call time.
class AiMarkingService {
  AiMarkingService({required String host, required int port})
    : _host = host,
      _port = port;

  final String _host;
  final int _port;

  /// Creates a new [ClientChannel] → [AiMarkingClient] pair.
  /// Caller is responsible for shutting down the channel when done.
  (AiMarkingClient, ClientChannel) _freshClient() {
    final channel = ClientChannel(
      _host,
      port: _port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    return (AiMarkingClient(channel), channel);
  }

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
    final (client, channel) = _freshClient();
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
        timeout: const Duration(seconds: 30),
      );
      debugPrint(
        '[AI] requestUploadUrls → school=$school exam=$exam subject=$subject schemeCount=$schemeCount students=${studentSheetCounts.length}',
      );
      final resp = await client.requestUploadUrls(req, options: options);
      debugPrint(
        '[AI] requestUploadUrls ← OK (scheme=${resp.schemeUrls.length} students=${resp.studentUrls.length})',
      );
      return Ok(resp);
    } on GrpcError catch (e) {
      debugPrint('[AI] requestUploadUrls ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      debugPrint(
        '[AI] requestUploadUrls ← UNEXPECTED ${e.runtimeType}: $e\n$st',
      );
      return Err(GrpcError.internal('requestUploadUrls failed: $e'));
    } finally {
      await channel.shutdown();
    }
  }

  /// Upload a single file to S3 using a presigned PUT URL.
  /// Returns true on success.
  Future<bool> uploadFile(String putUrl, String localPath) async {
    if (putUrl.isEmpty) {
      debugPrint('[AI] uploadFile: putUrl is empty — skipping (treated as ok)');
      return true;
    }
    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('[AI] uploadFile: file not found — $localPath');
        return false;
      }
      final bytes = await file.readAsBytes();
      debugPrint(
        '[AI] uploadFile: uploading ${bytes.length} bytes from $localPath',
      );
      httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
      request.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      request.add(bytes);
      final response = await request.close();
      await response.drain<void>();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      debugPrint(
        '[AI] uploadFile: HTTP ${response.statusCode} — ${ok ? 'OK' : 'FAILED'}',
      );
      return ok;
    } catch (e, st) {
      debugPrint('[AI] uploadFile: EXCEPTION ${e.runtimeType}: $e\n$st');
      return false;
    } finally {
      httpClient?.close();
    }
  }

  /// Request the server to mark a paper using AI.
  /// Returns immediately; actual grades arrive via watchChanges SyncDelta stream.
  ///
  /// Creates a **fresh** [ClientChannel] for every call. This is the critical
  /// fix for the "markPaper never reaches the server" bug: the previous shared
  /// channel goes stale during the ~2-minute S3 upload phase because idle
  /// HTTP/2 connections are dropped by routers / the OS before `markPaper`
  /// fires. A fresh channel = fresh TCP connection = guaranteed delivery.
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
    debugPrint(
      '[AI] markPaper → school=$school exam=$exam subject=$subject paper=$paper '
      'grade=$grade stream=$stream totalMarks=$totalMarks '
      'schemeKeys=${schemeKeys.length} students=${studentKeys.length}',
    );
    final (client, channel) = _freshClient();
    debugPrint('[AI] markPaper: fresh channel created → $_host:$_port');
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
      debugPrint('[AI] markPaper: proto request built — sending gRPC call');
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
        timeout: const Duration(seconds: 60),
      );
      final resp = await client.markPaper(req, options: options);
      debugPrint(
        '[AI] markPaper ← OK (accepted=${resp.accepted} message="${resp.message}")',
      );
      return Ok(resp);
    } on GrpcError catch (e) {
      debugPrint('[AI] markPaper ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      // Any non-GrpcError exception (SocketException, OSError, StateError,
      // HTTP/2 framing error, etc.) lands here. Without this catch the
      // exception silently escapes the call site and the UI freezes at 50%.
      debugPrint('[AI] markPaper ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('markPaper failed: $e'));
    } finally {
      await channel.shutdown();
    }
  }
}
