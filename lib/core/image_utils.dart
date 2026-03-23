import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Constants used by the isolate processing function.
// These are top-level so they are accessible from both the class and the
// top-level isolate entry point (isolates cannot access class statics
// defined in another library scope reliably on all platforms).
// ---------------------------------------------------------------------------

const int _kMaxDimension = 1500;
const int _kQuality = 80;
const int _kContentThreshold = 230;
const int _kTrimPadding = 24;
const int _kSampleStep = 3;
const double _kMinMarginRatio = 0.03;

// ---------------------------------------------------------------------------
// Data class passed into the isolate.
// ---------------------------------------------------------------------------

/// Parameters passed to the background isolate for pure-Dart processing.
class _ProcessParams {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;
  final bool grayscale;
  final bool trimMargins;

  const _ProcessParams({
    required this.bytes,
    required this.maxDimension,
    required this.quality,
    required this.grayscale,
    required this.trimMargins,
  });
}

// ---------------------------------------------------------------------------
// Top-level isolate entry points.
// ---------------------------------------------------------------------------

/// Full decode → resize → grayscale → trim → encode pipeline.
/// Runs in a background isolate via [compute].
Uint8List _processInIsolate(_ProcessParams params) {
  var image = img.decodeImage(params.bytes);
  if (image == null) return params.bytes; // decode failed — return original

  // Resize if either dimension exceeds the cap.
  if (image.width > params.maxDimension || image.height > params.maxDimension) {
    if (image.width >= image.height) {
      image = img.copyResize(image, width: params.maxDimension);
    } else {
      image = img.copyResize(image, height: params.maxDimension);
    }
  }

  if (params.grayscale) {
    image = img.grayscale(image);
  }

  if (params.trimMargins) {
    image = _trimContentMarginsImpl(image);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
}

/// Grayscale + trim only (image already resized by native compress).
/// Runs in a background isolate via [compute].
Uint8List _postNativeProcessInIsolate(_ProcessParams params) {
  var image = img.decodeImage(params.bytes);
  if (image == null) return params.bytes; // decode failed — return as-is

  if (params.grayscale) {
    image = img.grayscale(image);
  }

  if (params.trimMargins) {
    image = _trimContentMarginsImpl(image);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
}

// ---------------------------------------------------------------------------
// Trim / dark-pixel helpers (top-level so isolates can call them).
// ---------------------------------------------------------------------------

/// Returns `true` if the pixel at ([x], [y]) is darker than the content
/// threshold — i.e. it contains handwriting, print, or ruled lines rather
/// than blank paper.
bool _isDarkImpl(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return pixel.luminance < _kContentThreshold / 255.0;
}

/// Detects the bounding box of non-blank content in [image] and crops to it
/// with [_kTrimPadding] pixels of breathing room on each side.
///
/// For a typical A4 answer sheet with 2–3 cm margins on each side, this
/// removes ~20–40 % of the image area, directly reducing the number of
/// tokens consumed when the image is sent to an AI model.
img.Image _trimContentMarginsImpl(img.Image image) {
  final w = image.width;
  final h = image.height;

  // Scan from top: find first row with content.
  int top = 0;
  topScan:
  for (int y = 0; y < h; y += _kSampleStep) {
    for (int x = 0; x < w; x += _kSampleStep) {
      if (_isDarkImpl(image, x, y)) {
        top = y;
        break topScan;
      }
    }
  }

  // Scan from bottom: find last row with content.
  int bottom = h - 1;
  bottomScan:
  for (int y = h - 1; y > top; y -= _kSampleStep) {
    for (int x = 0; x < w; x += _kSampleStep) {
      if (_isDarkImpl(image, x, y)) {
        bottom = y;
        break bottomScan;
      }
    }
  }

  // Scan from left: find first column with content (within top–bottom).
  int left = 0;
  leftScan:
  for (int x = 0; x < w; x += _kSampleStep) {
    for (int y = top; y <= bottom; y += _kSampleStep) {
      if (_isDarkImpl(image, x, y)) {
        left = x;
        break leftScan;
      }
    }
  }

  // Scan from right: find last column with content (within top–bottom).
  int right = w - 1;
  rightScan:
  for (int x = w - 1; x > left; x -= _kSampleStep) {
    for (int y = top; y <= bottom; y += _kSampleStep) {
      if (_isDarkImpl(image, x, y)) {
        right = x;
        break rightScan;
      }
    }
  }

  // Check if we found any content at all (blank page guard).
  if (top == 0 && bottom == h - 1 && left == 0 && right == w - 1) {
    bool hasAnyContent = false;
    for (int y = 0; y < h && !hasAnyContent; y += _kSampleStep * 4) {
      for (int x = 0; x < w && !hasAnyContent; x += _kSampleStep * 4) {
        if (_isDarkImpl(image, x, y)) hasAnyContent = true;
      }
    }
    if (!hasAnyContent) {
      // Cannot use debugPrint inside an isolate — print is fine.
      print('[ImageUtils] blank page detected — skipping trim');
      return image;
    }
  }

  // Apply padding around the content box.
  final cropLeft = math.max(0, left - _kTrimPadding);
  final cropTop = math.max(0, top - _kTrimPadding);
  final cropRight = math.min(w - 1, right + _kTrimPadding);
  final cropBottom = math.min(h - 1, bottom + _kTrimPadding);

  final cropW = cropRight - cropLeft + 1;
  final cropH = cropBottom - cropTop + 1;

  // Only trim if margins are meaningful (> _kMinMarginRatio on at least one
  // axis). This prevents micro-crops from sampling noise.
  final horizontalMargin = (w - cropW) / w;
  final verticalMargin = (h - cropH) / h;

  if (horizontalMargin < _kMinMarginRatio &&
      verticalMargin < _kMinMarginRatio) {
    print(
      '[ImageUtils] margins too small to trim '
      '(h: ${(horizontalMargin * 100).toStringAsFixed(1)}%, '
      'v: ${(verticalMargin * 100).toStringAsFixed(1)}%)',
    );
    return image;
  }

  print(
    '[ImageUtils] trimming margins — '
    '${w}×$h → ${cropW}×$cropH '
    '(removed ${(horizontalMargin * 100).toStringAsFixed(0)}% horizontal, '
    '${(verticalMargin * 100).toStringAsFixed(0)}% vertical)',
  );

  return img.copyCrop(
    image,
    x: cropLeft,
    y: cropTop,
    width: cropW,
    height: cropH,
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Image processing utilities for answer sheets and marking schemes.
///
/// Provides compression, resizing, grayscale conversion, and content-aware
/// margin trimming to reduce file sizes and improve AI marking accuracy
/// for handwritten content.
///
/// Uses a **hybrid pipeline**:
/// - **Android / iOS / macOS**: native GPU-accelerated resize via
///   `flutter_image_compress`, then pure-Dart grayscale + trim in an isolate.
/// - **Windows / Linux** (and native fallback): entire pipeline runs as pure
///   Dart in a background isolate via `compute()`, ensuring zero UI jank.
class ImageUtils {
  ImageUtils._();

  /// Maximum dimension (width or height) for answer sheet / scheme images.
  /// 1500 px at ~180 DPI is more than sufficient for clear handwriting on A4.
  static const int maxDimension = _kMaxDimension;

  /// JPEG quality for compressed images (0–100).
  /// 80 is the sweet spot: visually identical to 95 for handwriting,
  /// but ~60 % smaller file size.
  static const int quality = _kQuality;

  /// Whether the current platform supports `flutter_image_compress`.
  /// Android, iOS, and macOS have native codec support. Windows and Linux
  /// do not — they fall back to the pure-Dart pipeline.
  static bool get _hasNativeCompress =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Compresses, resizes, converts to grayscale, and trims blank margins
  /// from an image, writing the result to [destPath] as JPEG.
  ///
  /// The full pipeline for paper documents (all flags `true`):
  ///
  /// 1. **Resize** — scales to ≤ [maxDimension] px.
  /// 2. **Grayscale** — removes colour noise from paper tint, pen colour
  ///    variation, and lighting for cleaner AI input.
  /// 3. **Trim margins** — detects the bounding box of actual handwritten /
  ///    printed content and crops away blank paper margins, reducing the
  ///    image area (and thus AI input tokens) by 20–40 % on typical pages.
  /// 4. **JPEG encode** — final compression at [quality] 80.
  ///
  /// Returns the destination [File]. If processing fails for any reason the
  /// original file is copied verbatim as a fallback so callers never receive
  /// `null`.
  static Future<File> compressAndSave(
    String srcPath,
    String destPath, {
    bool grayscale = true,
    bool trimMargins = true,
  }) async {
    final srcSize = await File(srcPath).length();

    // ------------------------------------------------------------------
    // Native path (Android / iOS / macOS)
    // ------------------------------------------------------------------
    if (_hasNativeCompress) {
      try {
        // Step 1: Native resize + compress (fast, GPU-accelerated).
        final resized = await FlutterImageCompress.compressAndGetFile(
          srcPath,
          destPath,
          quality: (grayscale || trimMargins) ? 95 : quality,
          minWidth: maxDimension,
          minHeight: maxDimension,
          format: CompressFormat.jpeg,
          keepExif: false,
        );

        if (resized == null || !await File(resized.path).exists()) {
          throw Exception('compressAndGetFile returned null');
        }

        // Steps 2 + 3: Grayscale + trim in a background isolate.
        if (grayscale || trimMargins) {
          final resizedBytes = await File(resized.path).readAsBytes();
          final processed = await compute(
            _postNativeProcessInIsolate,
            _ProcessParams(
              bytes: resizedBytes,
              maxDimension: maxDimension,
              quality: quality,
              grayscale: grayscale,
              trimMargins: trimMargins,
            ),
          );
          await File(destPath).writeAsBytes(processed, flush: true);
        }

        final destSize = await File(destPath).length();
        _logResult(srcSize, destSize, grayscale, trimMargins, 'native');
        return File(destPath);
      } catch (e, st) {
        debugPrint(
          '[ImageUtils] native processing failed, falling back to '
          'pure-Dart isolate path: $e\n$st',
        );
        // Fall through to pure-Dart path below.
      }
    }

    // ------------------------------------------------------------------
    // Pure-Dart path (Windows / Linux, or native-path fallback)
    // ------------------------------------------------------------------
    try {
      final srcBytes = await File(srcPath).readAsBytes();

      final processed = await compute(
        _processInIsolate,
        _ProcessParams(
          bytes: srcBytes,
          maxDimension: maxDimension,
          quality: quality,
          grayscale: grayscale,
          trimMargins: trimMargins,
        ),
      );

      await File(destPath).writeAsBytes(processed, flush: true);

      final destSize = await File(destPath).length();
      _logResult(srcSize, destSize, grayscale, trimMargins, 'dart-isolate');
      return File(destPath);
    } catch (e, st) {
      debugPrint(
        '[ImageUtils] pure-Dart processing failed, '
        'copying original: $e\n$st',
      );
    }

    // ------------------------------------------------------------------
    // Ultimate fallback: copy the original uncompressed file.
    // ------------------------------------------------------------------
    return File(srcPath).copy(destPath);
  }

  /// Compresses a list of files (returned from the document scanner or
  /// gallery picker) into the target [directory], naming them sequentially
  /// starting from [startIndex].
  ///
  /// When [grayscale] is `true` (default), each image is converted to
  /// grayscale for optimal AI marking input. When [trimMargins] is `true`
  /// (default), blank paper margins are cropped away.
  ///
  /// Returns the list of destination paths.
  static Future<List<String>> compressBatch({
    required List<String> sourcePaths,
    required String directory,
    required int startIndex,
    bool grayscale = true,
    bool trimMargins = true,
  }) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    final destPaths = <String>[];
    for (int i = 0; i < sourcePaths.length; i++) {
      final index = startIndex + i;
      final destPath = '$directory/$index.jpg';
      await compressAndSave(
        sourcePaths[i],
        destPath,
        grayscale: grayscale,
        trimMargins: trimMargins,
      );
      destPaths.add(destPath);
    }
    return destPaths;
  }

  // -----------------------------------------------------------------------
  // Private helpers (main-isolate only)
  // -----------------------------------------------------------------------

  /// Logs the compression result to the debug console.
  static void _logResult(
    int srcSize,
    int destSize,
    bool grayscale,
    bool trimMargins,
    String pipeline,
  ) {
    final flags = [
      if (grayscale) 'grayscale',
      if (trimMargins) 'trimmed',
      'compressed',
    ].join(' + ');
    debugPrint(
      '[ImageUtils] $flags ($pipeline) '
      '${_kb(srcSize)} → ${_kb(destSize)} '
      '(${(100 - destSize * 100 / srcSize).round()}% reduction)',
    );
  }

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';
}
