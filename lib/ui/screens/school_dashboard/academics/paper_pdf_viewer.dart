import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
    // 1. Get presigned PDF URL from the paper service.
    final paperId =
        '$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}';
    final result = await paperService.getPaperPdfUrl(
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

/// Downloads a finalized paper MS Word (.docx) document and prompts the user
/// to choose the save location and filename.
///
/// Shows a loading SnackBar while downloading, prompts the native OS file picker
/// for the destination folder and filename, saves the file, and provides an "Open"
/// action on the completion SnackBar.
///
/// [title] is used for the default filename and SnackBar messages (default: 'Exam Paper').
Future<void> downloadAndOpenDocx({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? stream,
  required String accessToken,
  required BuildContext context,
  String title = 'Exam Paper',
  String? serverPaperId,
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
          Text('Preparing $title (.docx)…'),
        ],
      ),
      duration: const Duration(minutes: 5),
    ),
  );

  try {
    // 1. Get presigned DOCX URL from the paper service.
    final paperId = serverPaperId ??
        '$school|$exam|$subject|${paper ?? ''}|$grade|${stream ?? ''}';
    final result = await paperService.getPaperDocxUrl(
      paperId: paperId,
      accessToken: accessToken,
    );

    switch (result) {
      case Err(:final error):
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to get $title (.docx): ${error.message ?? 'Unknown error'}',
            ),
          ),
        );
        return;

      case Ok(:final value):
        messenger.hideCurrentSnackBar();
        if (!context.mounted) return;
        await downloadAndOpenDirectDocxUrl(
          url: value,
          context: context,
          title: title,
        );
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to download $title (.docx): $e')),
    );
  }
}

/// Downloads a Word document (.docx) from a direct presigned URL, prompts the user
/// for the download location and filename via the native OS file dialog, and saves it.
Future<void> downloadAndOpenDirectDocxUrl({
  required String url,
  required BuildContext context,
  String title = 'Document',
}) async {
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
          Text('Downloading $title (.docx)…'),
        ],
      ),
      duration: const Duration(minutes: 5),
    ),
  );

  try {
    final httpClient = HttpClient();
    final Uint8List bytes;
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

      bytes = await consolidateHttpClientResponseBytes(response);
    } finally {
      httpClient.close();
    }

    messenger.hideCurrentSnackBar();

    // Clean human-readable default filename based on the title.
    String cleanFileName = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleanFileName.isEmpty) {
      cleanFileName = 'Assessment_Paper';
    }
    if (!cleanFileName.toLowerCase().endsWith('.docx')) {
      cleanFileName = '$cleanFileName.docx';
    }

    // Prompt user for download directory and file name.
    String? savedPath;
    try {
      savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save Word Document (.docx)',
        fileName: cleanFileName,
        type: FileType.custom,
        allowedExtensions: const ['docx'],
        bytes: bytes,
      );
    } catch (_) {
      // Fallback if desktop portal or native picker encounters an issue
      final downloadsDir =
          await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final fallbackFile = File('${downloadsDir.path}/$cleanFileName');
      await fallbackFile.writeAsBytes(bytes);
      savedPath = fallbackFile.path;
    }

    if (savedPath == null) {
      // User dismissed or cancelled the save dialog
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Download cancelled'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Ensure bytes are on disk (some platform pickers return the selected target path)
    final file = File(savedPath);
    if (!await file.exists() || (await file.length()) == 0) {
      await file.writeAsBytes(bytes);
    }

    final fileNameOnly = file.path.split(Platform.pathSeparator).last;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved $fileNameOnly'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () async {
            if (Platform.isLinux) {
              await Process.run('xdg-open', [file.path]);
            } else if (Platform.isMacOS) {
              await Process.run('open', [file.path]);
            } else if (Platform.isWindows) {
              await Process.run('start', ['', file.path], runInShell: true);
            } else {
              await Share.shareXFiles([
                XFile(
                  file.path,
                  mimeType:
                      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                ),
              ], subject: '$title Word Document');
            }
          },
        ),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to download $title (.docx): $e')),
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
    this.localFilePath,
    this.localPdfBytes,
    this.serverPaperId,
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

  /// Absolute path to a locally cached PDF file.
  /// When provided, the viewer loads from disk instead of the network.
  final String? localFilePath;

  /// Pre-loaded PDF bytes. When provided, used directly without any I/O.
  final Uint8List? localPdfBytes;

  /// Server paper ObjectId hex string. When non-null, used for the gRPC call
  /// instead of the composite pipe-delimited fallback.
  final String? serverPaperId;

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
      // If local bytes are provided, use directly.
      if (widget.localPdfBytes != null) {
        _pdfBytes = widget.localPdfBytes;
        if (mounted) setState(() => _loading = false);
        return;
      }

      // If a local file path is provided and the file exists, load from disk.
      if (widget.localFilePath != null) {
        final file = File(widget.localFilePath!);
        if (await file.exists()) {
          try {
            _pdfBytes = await file.readAsBytes();
            if (mounted) setState(() => _loading = false);
            return;
          } catch (_) {
            // Fall through to network load on read error.
          }
        }
      }

      // Step 1 — get presigned URL from the paper service.
      final rpcPaperId = widget.serverPaperId ??
          '${widget.school}|${widget.exam}|${widget.subject}|'
          '${widget.paper ?? ''}|${widget.grade}|${widget.stream ?? ''}';
      final urlResult = await paperService.getPaperPdfUrl(
        paperId: rpcPaperId,
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
            // Download MS Word (.docx) button.
            IconButton(
              icon: const Icon(Icons.description_outlined, size: 20),
              tooltip: 'Download MS Word (.docx)',
              onPressed: () => downloadAndOpenDocx(
                school: widget.school,
                exam: widget.exam,
                subject: widget.subject,
                paper: widget.paper,
                grade: widget.grade,
                stream: widget.stream,
                accessToken: widget.accessToken,
                context: context,
                title: widget.title,
                serverPaperId: widget.serverPaperId,
              ),
            ),
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
