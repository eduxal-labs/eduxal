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
///
/// Uses the **main** [ClientChannel] (shared with the sync engine) for all gRPC
/// calls. The sync engine's bidirectional stream keeps this channel alive via
/// HTTP/2 keepalive, so it is guaranteed to be connected when we need it.
/// A fresh-channel fallback is available if the main channel fails.
class AiMarkingService {
  AiMarkingService({
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
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

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
    // Use print() — not debugPrint() — for critical-path logging so output
    // is never throttled or dropped by Flutter's debugPrint buffer.
    print(
      '[AI] requestUploadUrls → school=$school exam=$exam subject=$subject '
      'schemeCount=$schemeCount students=${studentSheetCounts.length}',
    );
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
      final client = AiMarkingClient(_mainChannel);
      final resp = await client.requestUploadUrls(req, options: options);
      print(
        '[AI] requestUploadUrls ← OK (scheme=${resp.schemeUrls.length} students=${resp.studentUrls.length})',
      );
      return Ok(resp);
    } on GrpcError catch (e) {
      print('[AI] requestUploadUrls ← GrpcError: ${e.code} ${e.message}');
      return Err(e);
    } catch (e, st) {
      print('[AI] requestUploadUrls ← UNEXPECTED ${e.runtimeType}: $e\n$st');
      return Err(GrpcError.internal('requestUploadUrls failed: $e'));
    }
  }

  /// Upload a single file to S3 using a presigned PUT URL.
  /// Returns true on success.
  Future<bool> uploadFile(String putUrl, String localPath) async {
    if (putUrl.isEmpty) {
      print('[AI] uploadFile: putUrl is empty — skipping (treated as ok)');
      return true;
    }
    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('[AI] uploadFile: file not found — $localPath');
        return false;
      }
      final bytes = await file.readAsBytes();
      // Log a content fingerprint (first+last 4 bytes) so we can verify
      // whether old or new file content is actually being uploaded.
      final fingerprint = bytes.length >= 8
          ? '${bytes.sublist(0, 4)}...${bytes.sublist(bytes.length - 4)}'
          : bytes.toString();
      print(
        '[AI] uploadFile: uploading ${bytes.length} bytes from $localPath '
        'fingerprint=$fingerprint',
      );
      httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
      request.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      request.add(bytes);
      final response = await request.close();
      await response.drain<void>();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      print(
        '[AI] uploadFile: HTTP ${response.statusCode} — ${ok ? 'OK' : 'FAILED'}',
      );
      return ok;
    } catch (e, st) {
      print('[AI] uploadFile: EXCEPTION ${e.runtimeType}: $e\n$st');
      return false;
    } finally {
      httpClient?.close();
    }
  }

  /// Request the server to mark a paper using AI.
  ///
  /// Strategy: try the **main channel** first (kept alive by the sync engine).
  /// If that fails for any transport/connectivity reason, retry once on a
  /// **fresh channel** (brand-new TCP connection). This covers:
  /// - Stale connections dropped by routers during the upload phase
  /// - Transient HTTP/2 framing errors
  /// - Channel state-machine bugs in the Dart gRPC library
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
    print(
      '[AI] markPaper → school=$school exam=$exam subject=$subject paper=$paper '
      'grade=$grade stream=$stream totalMarks=$totalMarks '
      'schemeKeys=${schemeKeys.length} students=${studentKeys.length}',
    );

    // Build the proto request once — reused across attempts.
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
      timeout: const Duration(seconds: 60),
    );

    // ── Attempt 1: main channel (shared with sync engine, proven alive) ──
    print('[AI] markPaper: attempt 1 — using main channel');
    try {
      final client = AiMarkingClient(_mainChannel);
      final resp = await client.markPaper(req, options: options);
      print(
        '[AI] markPaper ← OK via main channel '
        '(accepted=${resp.accepted} message="${resp.message}")',
      );
      return Ok(resp);
    } on GrpcError catch (e) {
      // Permission / validation errors from the server are authoritative —
      // retrying on a fresh channel won't change the outcome.
      if (e.code == StatusCode.permissionDenied ||
          e.code == StatusCode.invalidArgument ||
          e.code == StatusCode.unauthenticated) {
        print(
          '[AI] markPaper ← GrpcError (non-retryable): ${e.code} ${e.message}',
        );
        return Err(e);
      }
      print(
        '[AI] markPaper: main channel failed with GrpcError ${e.code} '
        '${e.message} — will retry on fresh channel',
      );
    } catch (e, st) {
      print(
        '[AI] markPaper: main channel failed with ${e.runtimeType}: $e\n$st'
        ' — will retry on fresh channel',
      );
    }

    // ── Attempt 2: fresh channel (new TCP connection, bypasses any state) ──
    print('[AI] markPaper: attempt 2 — creating fresh channel → $_host:$_port');
    final channel = _freshChannel();
    try {
      final client = AiMarkingClient(channel);
      final resp = await client.markPaper(req, options: options);
      print(
        '[AI] markPaper ← OK via fresh channel '
        '(accepted=${resp.accepted} message="${resp.message}")',
      );
      return Ok(resp);
    } on GrpcError catch (e) {
      print(
        '[AI] markPaper ← GrpcError (fresh channel): ${e.code} ${e.message}',
      );
      return Err(e);
    } catch (e, st) {
      print(
        '[AI] markPaper ← UNEXPECTED (fresh channel) ${e.runtimeType}: $e\n$st',
      );
      return Err(GrpcError.internal('markPaper failed: $e'));
    } finally {
      await channel.shutdown();
    }
  }
}
