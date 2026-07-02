import 'dart:io';
import 'dart:math' as math;

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

// -- Content detection (Phase 2: white-margin trim) --
const int _kContentThreshold = 230;
const int _kTrimPadding = 24;
const int _kSampleStep = 3;
const double _kMinMarginRatio = 0.03;

// -- Paper detection (Phase 1: desk/background removal) --
/// Normalised luminance above which a pixel is considered "paper" rather than
/// desk/table surface. Desk wood is typically 0.30–0.65, paper 0.80–1.0.
/// 0.72 gives comfortable separation even for shadowed paper edges.
const double _kPaperBrightness = 0.72;

/// Row/column scan step for paper detection. Coarser than content scanning
/// because we are looking for a broad desk→paper transition, not individual
/// characters.
const int _kPaperScanStep = 4;

/// Within-row pixel sampling step for paper detection. Coarser than content
/// sampling — we only need the overall brightness profile of a row, not
/// per-character precision.
const int _kPaperPixelStep = 8;

/// Fraction of sampled pixels in a row/column that must be bright for it to
/// count as a "paper line". 60 % accounts for rows that cross handwriting.
const double _kPaperLineBrightFraction = 0.60;

/// How many consecutive bright rows/columns are required before we trust
/// that we have found the paper edge. At [_kPaperScanStep]=4 this spans
/// ~20 px — enough to confirm a genuine transition while tolerating noise.
const int _kConsecutivePaperLines = 5;

/// If > 75 % of the image's border pixels are already bright, there is no
/// desk background and we skip paper detection entirely (fast path).
const double _kBorderBrightFraction = 0.75;

/// Safety net: if the final crop area is less than 20 % of the original
/// image area, the algorithm almost certainly misfired. Return the original.
const double _kMinCropAreaRatio = 0.20;

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

// ===========================================================================
//  TRIM PIPELINE — Two-phase + safety net
// ===========================================================================
//
//  Phase 1 (_cropToPaper):  If the image border is dark (desk/table visible),
//           scan inward from each edge to find the paper region, then crop to
//           it. If borders are already bright, this is a no-op.
//
//  Phase 2 (_trimWhiteMargins):  Within the (now paper-only) image, scan for
//           the content bounding box and crop away blank white margins.
//           This is the original trim algorithm.
//
//  Safety net:  If the final result is < 20 % of the original area, the
//               algorithm misfired — return the original image unchanged.
// ===========================================================================

/// Top-level entry point called by the isolate processing functions.
/// Orchestrates paper detection → white-margin trim → safety net.
img.Image _trimContentMarginsImpl(img.Image image) {
  final originalW = image.width;
  final originalH = image.height;
  final originalArea = originalW * originalH;

  // Phase 1: Detect and crop to the paper region (handles desk background).
  var result = _cropToPaper(image);

  // Phase 2: Trim white margins within the paper region.
  result = _trimWhiteMargins(result);

  // Safety net: reject catastrophically small crops.
  final resultArea = result.width * result.height;
  if (resultArea < originalArea * _kMinCropAreaRatio) {
    print(
      '[ImageUtils] safety net — crop is only '
      '${(resultArea * 100 / originalArea).toStringAsFixed(0)}% of original '
      '(${result.width}×${result.height} from $originalW×$originalH), '
      'returning uncropped',
    );
    return image;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Phase 1: Paper detection — find the paper within a desk photo
// ---------------------------------------------------------------------------

/// Returns `true` if the pixel at ([x], [y]) is bright enough to be paper.
bool _isBrightImpl(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return pixel.luminance > _kPaperBrightness;
}

/// Samples pixels along the four borders of [image] and returns `true` if
/// the majority are bright (paper). When this returns `true` there is no
/// desk background and paper detection can be skipped.
bool _borderIsBright(img.Image image) {
  final w = image.width;
  final h = image.height;
  final step = _kPaperPixelStep * 2; // very coarse — just a quick sniff test
  int bright = 0;
  int total = 0;

  // Top row.
  for (int x = 0; x < w; x += step) {
    if (_isBrightImpl(image, x, 0)) bright++;
    total++;
  }
  // Bottom row.
  for (int x = 0; x < w; x += step) {
    if (_isBrightImpl(image, x, h - 1)) bright++;
    total++;
  }
  // Left column.
  for (int y = 0; y < h; y += step) {
    if (_isBrightImpl(image, 0, y)) bright++;
    total++;
  }
  // Right column.
  for (int y = 0; y < h; y += step) {
    if (_isBrightImpl(image, w - 1, y)) bright++;
    total++;
  }

  return total > 0 && bright / total > _kBorderBrightFraction;
}

/// Returns `true` if the horizontal line at [y] is predominantly bright
/// (paper-like) when sampled every [_kPaperPixelStep] pixels.
bool _isRowBright(img.Image image, int y) {
  final w = image.width;
  int bright = 0;
  int total = 0;
  for (int x = 0; x < w; x += _kPaperPixelStep) {
    if (_isBrightImpl(image, x, y)) bright++;
    total++;
  }
  return total > 0 && bright / total >= _kPaperLineBrightFraction;
}

/// Returns `true` if the vertical line at [x] (between [top] and [bottom])
/// is predominantly bright (paper-like).
bool _isColumnBright(img.Image image, int x, int top, int bottom) {
  int bright = 0;
  int total = 0;
  for (int y = top; y <= bottom; y += _kPaperPixelStep) {
    if (_isBrightImpl(image, x, y)) bright++;
    total++;
  }
  return total > 0 && bright / total >= _kPaperLineBrightFraction;
}

/// Phase 1: Detects the paper region within a photo that may contain a
/// desk/table background. If the border is already bright (no desk), returns
/// [image] unchanged.
///
/// Algorithm: scan inward from each edge looking for the transition from dark
/// (desk) to a sustained run of bright rows/columns (paper). "Sustained"
/// means [_kConsecutivePaperLines] consecutive bright lines at
/// [_kPaperScanStep] intervals.
img.Image _cropToPaper(img.Image image) {
  final w = image.width;
  final h = image.height;

  // Fast path: borders are already bright → no desk background.
  if (_borderIsBright(image)) return image;

  print('[ImageUtils] non-paper background detected — finding paper region');

  // -- Scan from top --
  int paperTop = 0;
  {
    int consecutive = 0;
    for (int y = 0; y < h; y += _kPaperScanStep) {
      if (_isRowBright(image, y)) {
        consecutive++;
        if (consecutive >= _kConsecutivePaperLines) {
          // Paper starts at the first bright row of this run.
          paperTop = y - (consecutive - 1) * _kPaperScanStep;
          break;
        }
      } else {
        consecutive = 0;
      }
    }
  }

  // -- Scan from bottom --
  int paperBottom = h - 1;
  {
    int consecutive = 0;
    for (int y = h - 1; y >= paperTop; y -= _kPaperScanStep) {
      if (_isRowBright(image, y)) {
        consecutive++;
        if (consecutive >= _kConsecutivePaperLines) {
          paperBottom = y + (consecutive - 1) * _kPaperScanStep;
          if (paperBottom > h - 1) paperBottom = h - 1;
          break;
        }
      } else {
        consecutive = 0;
      }
    }
  }

  // -- Scan from left (within the vertical paper range) --
  int paperLeft = 0;
  {
    int consecutive = 0;
    for (int x = 0; x < w; x += _kPaperScanStep) {
      if (_isColumnBright(image, x, paperTop, paperBottom)) {
        consecutive++;
        if (consecutive >= _kConsecutivePaperLines) {
          paperLeft = x - (consecutive - 1) * _kPaperScanStep;
          break;
        }
      } else {
        consecutive = 0;
      }
    }
  }

  // -- Scan from right --
  int paperRight = w - 1;
  {
    int consecutive = 0;
    for (int x = w - 1; x >= paperLeft; x -= _kPaperScanStep) {
      if (_isColumnBright(image, x, paperTop, paperBottom)) {
        consecutive++;
        if (consecutive >= _kConsecutivePaperLines) {
          paperRight = x + (consecutive - 1) * _kPaperScanStep;
          if (paperRight > w - 1) paperRight = w - 1;
          break;
        }
      } else {
        consecutive = 0;
      }
    }
  }

  // Clamp to image bounds.
  paperTop = math.max(0, paperTop);
  paperLeft = math.max(0, paperLeft);
  paperBottom = math.min(h - 1, paperBottom);
  paperRight = math.min(w - 1, paperRight);

  final paperW = paperRight - paperLeft + 1;
  final paperH = paperBottom - paperTop + 1;

  // Sanity check: the detected paper region must be at least 30 % of the
  // image in each dimension. If it's smaller, detection probably failed.
  if (paperW < w * 0.30 || paperH < h * 0.30) {
    print(
      '[ImageUtils] paper detection failed — region too small '
      '($paperW×$paperH from $w×$h), skipping crop',
    );
    return image;
  }

  // If we barely removed anything, skip the crop.
  if (paperLeft == 0 &&
      paperTop == 0 &&
      paperRight == w - 1 &&
      paperBottom == h - 1) {
    return image;
  }

  print(
    '[ImageUtils] paper region: ($paperLeft,$paperTop)→($paperRight,$paperBottom) '
    '— $paperW×$paperH from $w×$h '
    '(removed ${((1 - paperW * paperH / (w * h)) * 100).toStringAsFixed(0)}% background)',
  );

  return img.copyCrop(
    image,
    x: paperLeft,
    y: paperTop,
    width: paperW,
    height: paperH,
  );
}

// ---------------------------------------------------------------------------
// Phase 2: White-margin trim — find content within the paper region
// ---------------------------------------------------------------------------

/// Returns `true` if the pixel at ([x], [y]) is darker than the content
/// threshold — i.e. it contains handwriting, print, or ruled lines rather
/// than blank paper.
bool _isDarkImpl(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  // For grayscale images R == G == B. For color images, luminance is a
  // reasonable single-value proxy. Using .luminance normalises to 0.0–1.0
  // in image 4.x, so we compare against a normalised threshold.
  return pixel.luminance < _kContentThreshold / 255.0;
}

/// Phase 2: Detects the bounding box of non-blank content in [image] and
/// crops to it with [_kTrimPadding] pixels of breathing room on each side.
///
/// The algorithm scans inward from each edge, sampling every [_kSampleStep]
/// pixels, looking for any pixel darker than [_kContentThreshold]. Once the
/// first content row/column is found on each side, the image is cropped to
/// that rectangle (plus padding).
///
/// Returns the original [image] unchanged if:
/// - No content is found (blank page)
/// - Margins are smaller than [_kMinMarginRatio] on both axes
img.Image _trimWhiteMargins(img.Image image) {
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
    '$w×$h → $cropW×$cropH '
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
///
/// The trim step uses a **two-phase approach**:
/// 1. **Paper detection** — if the photo contains a desk/table background,
///    find the paper region first and crop to it.
/// 2. **White-margin trim** — within the paper, crop away blank margins
///    around the handwritten content.
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
