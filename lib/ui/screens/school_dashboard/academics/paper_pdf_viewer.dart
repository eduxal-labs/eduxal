import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../client.dart';
import '../../../../models/result.dart';

/// Downloads a finalized paper PDF and opens it with the system viewer.
///
/// Shows a loading SnackBar while downloading, and an error SnackBar on failure.
/// On desktop platforms, opens the PDF with the system default viewer.
/// On mobile or unsupported platforms, shows the saved file path in a SnackBar.
///
/// [title] is used in the loading/error SnackBar messages (default: 'Exam Paper').
Future<void> downloadAndOpenPdf({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? stream,
  required String accessToken,
  required BuildContext context,
  String title = 'Exam Paper',
}) async {
  final messenger = ScaffoldMessenger.of(context);

  // Show persistent loading SnackBar — dismissed on completion or error.
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
          Text('Downloading $title…'),
        ],
      ),
      duration: const Duration(minutes: 5),
    ),
  );

  try {
    // 1. Get presigned PDF URL from the question bank service.
    final result = await questionBankService.getPaperPdf(
      school: school,
      exam: exam,
      subject: subject,
      paper: paper,
      grade: grade,
      stream: stream,
      accessToken: accessToken,
    );

    switch (result) {
      case Err(:final error):
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to get $title: ${error.message}')),
        );
        return;

      case Ok(:final value):
        // 2. Download PDF bytes from the presigned URL.
        final httpClient = HttpClient();
        try {
          final request = await httpClient.getUrl(Uri.parse(value.pdfUrl));
          final response = await request.close();

          if (response.statusCode != 200) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  '$title download failed (HTTP ${response.statusCode})',
                ),
              ),
            );
            return;
          }

          // 3. Save to temp directory with a deterministic filename.
          final tempDir = await getTemporaryDirectory();
          final paperSuffix = paper != null ? '_$paper' : '';
          final filename = 'paper_${exam}_$subject$paperSuffix.pdf';
          final file = File('${tempDir.path}/$filename');
          final sink = file.openWrite();
          await response.pipe(sink);

          messenger.hideCurrentSnackBar();

          // 4. Open with system viewer (desktop) or show share sheet (mobile).
          if (Platform.isLinux) {
            await Process.run('xdg-open', [file.path]);
          } else if (Platform.isMacOS) {
            await Process.run('open', [file.path]);
          } else if (Platform.isWindows) {
            await Process.run('start', ['', file.path], runInShell: true);
          } else {
            // Android / iOS — open system share sheet so the user can print,
            // open in a PDF viewer, or share the file.
            await Share.shareXFiles([
              XFile(file.path, mimeType: 'application/pdf'),
            ], subject: '$title PDF');
          }
        } finally {
          httpClient.close();
        }
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to download $title: $e')),
    );
  }
}

/// Downloads a PDF from a direct presigned URL and opens it with the system
/// viewer.
///
/// Unlike [downloadAndOpenPdf], this function does not make a gRPC call to
/// retrieve a URL first — the caller provides [url] directly (e.g. a marking
/// scheme URL from [FinalizePaperResponse]).
///
/// [title] is used in the loading/error SnackBar messages (default: 'PDF').
Future<void> downloadAndOpenDirectUrl({
  required String url,
  required BuildContext context,
  String title = 'PDF',
}) async {
  final messenger = ScaffoldMessenger.of(context);

  // Show persistent loading SnackBar — dismissed on completion or error.
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
          Text('Downloading $title…'),
        ],
      ),
      duration: const Duration(minutes: 5),
    ),
  );

  try {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$title download failed (HTTP ${response.statusCode})',
            ),
          ),
        );
        return;
      }

      // Save to temp directory with a sanitized, timestamped filename.
      final tempDir = await getTemporaryDirectory();
      final safeName = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final filename =
          '${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$filename');
      final sink = file.openWrite();
      await response.pipe(sink);

      messenger.hideCurrentSnackBar();

      // Open with system viewer (desktop) or share sheet (mobile).
      if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isWindows) {
        await Process.run('start', ['', file.path], runInShell: true);
      } else {
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'application/pdf'),
        ], subject: '$title PDF');
      }
    } finally {
      httpClient.close();
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to download $title: $e')),
    );
  }
}
