import 'dart:io';

import 'package:grpc/grpc.dart';

import '../models/result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain types
// ─────────────────────────────────────────────────────────────────────────────

/// A successfully uploaded answer-sheet file with its assigned file number
/// and the server-issued read URL.
class AnswerSheetFile {
  final int fileNumber;
  final String readUrl;
  const AnswerSheetFile({required this.fileNumber, required this.readUrl});
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Handles uploading answer-sheet images to remote object storage.
///
/// Upload flow (once the Files gRPC service protos exist):
///   1. Call `Files.GetAnswerSheetUploadUrls` on the server to obtain signed
///      HTTP PUT URLs — one per file.
///   2. HTTP PUT each local file to its signed URL.
///   3. Return the assigned file numbers on success.
///
/// Until the proto stubs are generated the URL-fetch step is **stubbed** (see
/// [_getUploadUrls]).  The rest of the infrastructure (HTTP PUT logic,
/// error mapping, and the public API surface) is fully wired so the UI works
/// as soon as the real protos arrive.
class FileUploadService {
  FileUploadService(this._channel);

  // ignore: unused_field
  final ClientChannel _channel;

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Upload answer-sheet images for a student's paper submission.
  ///
  /// Steps:
  ///   1. Obtain signed PUT URLs from the server (stubbed until proto exists).
  ///   2. HTTP PUT each file to its URL.
  ///   3. Return `Ok(fileNumbers)` or `Err(message)`.
  ///
  /// The upload runs sequentially — one file at a time — to keep memory usage
  /// low and to make per-file error reporting straightforward.
  Future<Result<List<int>, String>> uploadAnswerSheets({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paper,
    required int studentAdm,
    required List<String> localPaths,
    required String accessToken,
  }) async {
    if (localPaths.isEmpty) return const Ok([]);

    try {
      // Step 1: obtain signed PUT URLs
      final urlResult = await _getUploadUrls(
        schoolId: schoolId,
        examId: examId,
        subject: subject,
        paper: paper,
        studentAdm: studentAdm,
        count: localPaths.length,
        accessToken: accessToken,
      );

      switch (urlResult) {
        case Err(:final error):
          return Err(error);
        case Ok(:final value):
          final uploadEntries = value; // List<_UploadEntry>

          // Step 2: PUT each file
          final fileNumbers = <int>[];
          for (int i = 0; i < localPaths.length; i++) {
            final entry = uploadEntries[i];
            final putResult = await _putFile(
              localPath: localPaths[i],
              putUrl: entry.putUrl,
            );
            switch (putResult) {
              case Err(:final error):
                return Err('Failed to upload file ${i + 1}: $error');
              case Ok():
                fileNumbers.add(entry.fileNumber);
            }
          }

          return Ok(fileNumbers);
      }
    } catch (e) {
      return Err(e.toString());
    }
  }

  /// Fetch the server-issued read URLs for a student's existing answer sheets.
  ///
  /// Returns `Ok([])` when no sheets are on record (not an error).
  Future<Result<List<AnswerSheetFile>, String>> getAnswerSheetUrls({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paper,
    required int studentAdm,
    required String accessToken,
  }) async {
    try {
      // TODO: replace stub with real gRPC call to Files.GetAnswerSheetReadUrls
      //
      // When the proto is available this will look roughly like:
      //
      //   final stub = FilesClient(_channel);
      //   final req = GetAnswerSheetReadUrlsRequest()
      //     ..schoolId   = schoolId
      //     ..examId     = examId
      //     ..subject    = subject
      //     ..paper      = paper ?? 0
      //     ..studentAdm = studentAdm;
      //   final options = CallOptions(
      //     metadata: {'authorization': 'Bearer $accessToken'},
      //   );
      //   final resp = await stub.getAnswerSheetReadUrls(req, options: options);
      //   return Ok(resp.files.map((f) => AnswerSheetFile(
      //     fileNumber: f.fileNumber,
      //     readUrl: f.readUrl,
      //   )).toList());
      return const Ok([]);
    } catch (e) {
      return Err(e.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtain signed PUT URLs from the server.
  ///
  /// **STUBBED** — simulates a short network round-trip and returns mock
  /// entries.  Replace the body with the real gRPC call once
  /// `Files.GetAnswerSheetUploadUrls` proto stubs are generated.
  Future<Result<List<_UploadEntry>, String>> _getUploadUrls({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paper,
    required int studentAdm,
    required int count,
    required String accessToken,
  }) async {
    // TODO: replace stub with real gRPC call to Files.GetAnswerSheetUploadUrls
    //
    // When the proto is available this will look roughly like:
    //
    //   final stub = FilesClient(_channel);
    //   final req = GetAnswerSheetUploadUrlsRequest()
    //     ..schoolId   = schoolId
    //     ..examId     = examId
    //     ..subject    = subject
    //     ..paper      = paper ?? 0
    //     ..studentAdm = studentAdm
    //     ..count      = count;
    //   final options = CallOptions(
    //     metadata: {'authorization': 'Bearer $accessToken'},
    //   );
    //   final resp = await stub.getAnswerSheetUploadUrls(req, options: options);
    //   final entries = resp.files.map((f) => _UploadEntry(
    //     fileNumber: f.fileNumber,
    //     putUrl:     f.putUrl,
    //   )).toList();
    //   return Ok(entries);

    // --- STUB: simulate a brief server round-trip ---
    await Future.delayed(const Duration(milliseconds: 150));
    final entries = List.generate(
      count,
      (i) => _UploadEntry(
        fileNumber: i + 1,
        putUrl: '', // stub: no real URL — _putFile handles the empty-URL case
      ),
    );
    return Ok(entries);
  }

  /// HTTP PUT [localPath] bytes to the signed [putUrl].
  ///
  /// When [putUrl] is empty (stub mode) the method succeeds immediately so
  /// the rest of the flow can be exercised without a real server.
  Future<Result<void, String>> _putFile({
    required String localPath,
    required String putUrl,
  }) async {
    // Stub mode: empty URL means we are in development without a real server.
    if (putUrl.isEmpty) return const Ok(null);

    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return Err('File not found: $localPath');
      }

      final bytes = await file.readAsBytes();
      final uri = Uri.parse(putUrl);

      httpClient = HttpClient();
      final request = await httpClient.putUrl(uri);

      // Standard S3-compatible signed PUT headers
      request.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
      request.headers.set(HttpHeaders.contentLengthHeader, bytes.length);

      request.add(bytes);
      final response = await request.close();
      await response.drain<void>(); // discard body

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Ok(null);
      }
      return Err('PUT failed with HTTP ${response.statusCode}');
    } on SocketException catch (e) {
      return Err('Network error: ${e.message}');
    } on HttpException catch (e) {
      return Err('HTTP error: ${e.message}');
    } catch (e) {
      return Err(e.toString());
    } finally {
      httpClient?.close();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal models
// ─────────────────────────────────────────────────────────────────────────────

/// Pairs a file number (server-assigned ordinal) with the signed PUT URL.
class _UploadEntry {
  final int fileNumber;
  final String putUrl;
  const _UploadEntry({required this.fileNumber, required this.putUrl});
}
