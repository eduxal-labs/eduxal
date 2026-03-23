import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Image processing utilities for answer sheets and marking schemes.
///
/// Provides compression, resizing, grayscale conversion, and content-aware
/// margin trimming to reduce file sizes and improve AI marking accuracy
/// for handwritten content.
class ImageUtils {
  ImageUtils._();

  /// Maximum dimension (width or height) for answer sheet / scheme images.
  /// 1500px at ~180 DPI is more than sufficient for clear handwriting on A4.
  static const int maxDimension = 1500;

  /// JPEG quality for compressed images (0–100).
  /// 80 is the sweet spot: visually identical to 95 for handwriting,
  /// but ~60 % smaller file size.
  static const int quality = 80;

  /// Brightness threshold (0–255) for detecting content vs blank margin.
  ///
  /// Pixels with brightness below this value are considered "content"
  /// (handwriting, printed text, ruled lines). Pixels at or above are
  /// treated as blank paper.
  ///
  /// 230 catches handwriting (~50–180), printed text (~0–120), and faint
  /// ruled lines (~200–220) while ignoring slight paper texture (240–255).
  static const int _contentThreshold = 230;

  /// Minimum padding (in pixels) to preserve around detected content after
  /// trimming. Prevents the crop from cutting too tight against the writing.
  static const int _trimPadding = 24;

  /// Sampling step when scanning for content boundaries. Checking every Nth
  /// pixel is 9× faster than every pixel and the ±3 px imprecision is
  /// invisible after [_trimPadding] is applied.
  static const int _sampleStep = 3;

  /// Minimum percentage of a dimension that must be margin before we bother
  /// trimming that axis. Avoids micro-crops that save negligible tokens but
  /// risk clipping content on messy pages.
  static const double _minMarginRatio = 0.03; // 3 %

  /// Compresses, resizes, converts to grayscale, and trims blank margins
  /// from an image, writing the result to [destPath] as JPEG.
  ///
  /// The full pipeline for paper documents (all flags `true`):
  ///
  /// 1. **Native resize** — scales to ≤ [maxDimension] px (GPU-accelerated).
  /// 2. **Grayscale** — removes color noise from paper tint, pen color
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

    try {
      // Step 1: Native resize + compress (fast, GPU-accelerated on most
      // platforms). This brings a 12 MP camera image down to ~1500 px.
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

      // Steps 2 + 3: Grayscale + trim (pure Dart, fast at ≤1500 px).
      if (grayscale || trimMargins) {
        final resizedFile = File(resized.path);
        final bytes = await resizedFile.readAsBytes();
        var decoded = img.decodeImage(bytes);

        if (decoded != null) {
          if (grayscale) {
            decoded = img.grayscale(decoded);
          }

          if (trimMargins) {
            decoded = _trimContentMargins(decoded);
          }

          // Step 4: Final JPEG encode.
          final encoded = Uint8List.fromList(
            img.encodeJpg(decoded, quality: quality),
          );
          await File(destPath).writeAsBytes(encoded, flush: true);
        }
        // If decode failed the resized version is already at destPath,
        // which is still a valid result.
      }

      final destSize = await File(destPath).length();
      final flags = [
        if (grayscale) 'grayscale',
        if (trimMargins) 'trimmed',
        'compressed',
      ].join(' + ');
      debugPrint(
        '[ImageUtils] $flags '
        '${_kb(srcSize)} → ${_kb(destSize)} '
        '(${(100 - destSize * 100 / srcSize).round()}% reduction)',
      );
      return File(destPath);
    } catch (e, st) {
      debugPrint('[ImageUtils] processing failed, copying original: $e\n$st');
    }

    // Fallback: copy the original uncompressed file.
    return File(srcPath).copy(destPath);
  }

  /// Detects the bounding box of non-blank content in [image] and crops
  /// to it with [_trimPadding] pixels of breathing room on each side.
  ///
  /// For a typical A4 answer sheet with 2–3 cm margins on each side,
  /// this removes ~20–40 % of the image area, directly reducing the
  /// number of tokens consumed when the image is sent to an AI model.
  ///
  /// The algorithm scans inward from each edge, sampling every [_sampleStep]
  /// pixels, looking for any pixel darker than [_contentThreshold]. Once the
  /// first content row/column is found on each side, the image is cropped to
  /// that rectangle (plus padding).
  ///
  /// Returns the original [image] unchanged if:
  /// - No content is found (blank page)
  /// - Margins are smaller than [_minMarginRatio] on both axes
  static img.Image _trimContentMargins(img.Image image) {
    final w = image.width;
    final h = image.height;

    // Scan from top: find first row with content.
    int top = 0;
    topScan:
    for (int y = 0; y < h; y += _sampleStep) {
      for (int x = 0; x < w; x += _sampleStep) {
        if (_isDark(image, x, y)) {
          top = y;
          break topScan;
        }
      }
    }

    // Scan from bottom: find last row with content.
    int bottom = h - 1;
    bottomScan:
    for (int y = h - 1; y > top; y -= _sampleStep) {
      for (int x = 0; x < w; x += _sampleStep) {
        if (_isDark(image, x, y)) {
          bottom = y;
          break bottomScan;
        }
      }
    }

    // Scan from left: find first column with content (within top–bottom).
    int left = 0;
    leftScan:
    for (int x = 0; x < w; x += _sampleStep) {
      for (int y = top; y <= bottom; y += _sampleStep) {
        if (_isDark(image, x, y)) {
          left = x;
          break leftScan;
        }
      }
    }

    // Scan from right: find last column with content (within top–bottom).
    int right = w - 1;
    rightScan:
    for (int x = w - 1; x > left; x -= _sampleStep) {
      for (int y = top; y <= bottom; y += _sampleStep) {
        if (_isDark(image, x, y)) {
          right = x;
          break rightScan;
        }
      }
    }

    // Check if we found any content at all (blank page guard).
    if (top == 0 && bottom == h - 1 && left == 0 && right == w - 1) {
      // Likely a blank page or content fills the entire image — no margins
      // were detected. Run a secondary check: if no dark pixel was found at
      // all, this is a blank page and trimming would collapse to nothing.
      bool hasAnyContent = false;
      for (int y = 0; y < h && !hasAnyContent; y += _sampleStep * 4) {
        for (int x = 0; x < w && !hasAnyContent; x += _sampleStep * 4) {
          if (_isDark(image, x, y)) hasAnyContent = true;
        }
      }
      if (!hasAnyContent) {
        debugPrint('[ImageUtils] blank page detected — skipping trim');
        return image;
      }
    }

    // Apply padding around the content box.
    final cropLeft = math.max(0, left - _trimPadding);
    final cropTop = math.max(0, top - _trimPadding);
    final cropRight = math.min(w - 1, right + _trimPadding);
    final cropBottom = math.min(h - 1, bottom + _trimPadding);

    final cropW = cropRight - cropLeft + 1;
    final cropH = cropBottom - cropTop + 1;

    // Only trim if margins are meaningful (> _minMarginRatio on at least one
    // axis). This prevents micro-crops from sampling noise.
    final horizontalMargin = (w - cropW) / w;
    final verticalMargin = (h - cropH) / h;

    if (horizontalMargin < _minMarginRatio &&
        verticalMargin < _minMarginRatio) {
      debugPrint(
        '[ImageUtils] margins too small to trim '
        '(h: ${(horizontalMargin * 100).toStringAsFixed(1)}%, '
        'v: ${(verticalMargin * 100).toStringAsFixed(1)}%)',
      );
      return image;
    }

    debugPrint(
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

  /// Returns `true` if the pixel at ([x], [y]) is darker than the content
  /// threshold — i.e. it contains handwriting, print, or ruled lines rather
  /// than blank paper.
  static bool _isDark(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    // For grayscale images R == G == B. For color images, luminance is a
    // reasonable single-value proxy. Using .luminance normalises to 0.0–1.0
    // in image 4.x, so we compare against a normalised threshold.
    return pixel.luminance < _contentThreshold / 255.0;
  }

  /// Compresses a list of files (returned as paths from the document scanner
  /// or gallery picker) into the target [directory], naming them sequentially
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

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';
}
