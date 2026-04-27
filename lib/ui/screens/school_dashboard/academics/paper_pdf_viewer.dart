import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:printing/printing.dart';
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
    final paperId =
        '$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}';
    final result = await questionBankService.getPaperPdf(
      paperId: paperId,
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

// ─────────────────────────────────────────────────────────────────────────────
// PaperPdfViewerPage
//
// Full-screen in-app PDF viewer. Downloads the paper PDF from the server and
// renders it inline using the `printing` package (cross-platform, including Linux).
// ─────────────────────────────────────────────────────────────────────────────

class PaperPdfViewerPage extends StatefulWidget {
  const PaperPdfViewerPage({
    super.key,
    required this.school,
    required this.exam,
    required this.subject,
    this.paper,
    required this.grade,
    this.stream,
    required this.accessToken,
    required this.title,
  });

  final String school;
  final String exam;
  final int subject;
  final int? paper;
  final int grade;
  final int? stream;
  final String accessToken;

  /// Shown in the AppBar — e.g. "Mathematics Paper 1".
  final String title;

  @override
  State<PaperPdfViewerPage> createState() => _PaperPdfViewerPageState();
}

class _PaperPdfViewerPageState extends State<PaperPdfViewerPage> {
  Uint8List? _pdfBytes;
  bool _loading = true;
  String? _error;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPdf() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Step 1 — get presigned URL from the question bank service.
      final paperId =
          '${widget.school}|${widget.exam}|${widget.subject}|'
          '${widget.paper ?? ''}|${widget.grade}|${widget.stream ?? ''}';
      final urlResult = await questionBankService.getPaperPdf(
        paperId: paperId,
        accessToken: widget.accessToken,
      );

      final String pdfUrl;
      switch (urlResult) {
        case Ok(:final value):
          pdfUrl = value.pdfUrl;
        case Err(:final error):
          throw Exception(error.message ?? 'Failed to get PDF URL');
      }

      // Step 2 — download PDF bytes.
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(Uri.parse(pdfUrl));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception('Download failed (HTTP ${response.statusCode})');
        }
        final bytes = await consolidateHttpClientResponseBytes(response);

        if (!mounted) return;

        // Step 3 — store bytes; PdfPreview handles rendering.
        _pdfBytes = bytes;
        setState(() => _loading = false);
      } finally {
        httpClient.close();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _print() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: widget.title,
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _share() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final paperSuffix = widget.paper != null ? '_${widget.paper}' : '';
    final filename = 'paper_${widget.exam}_${widget.subject}$paperSuffix.pdf';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/pdf'),
    ], subject: '${widget.title} PDF');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF2F2F2),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (!_loading && _error == null) ...[
            // Print button (uses the `printing` package).
            IconButton(
              icon: _isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.print_rounded, size: 20),
              tooltip: 'Print',
              onPressed: _isPrinting ? null : _print,
            ),
            // Share / save to files.
            IconButton(
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: 'Share PDF',
              onPressed: _share,
            ),
          ],
          const SizedBox(width: 4),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load PDF',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _loadPdf,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return PdfPreview(
      build: (_) async => _pdfBytes!,
      useActions: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      scrollViewDecoration: const BoxDecoration(color: Colors.transparent),
      pdfFileName: widget.title,
    );
  }
}
