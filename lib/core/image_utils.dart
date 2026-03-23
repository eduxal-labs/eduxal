import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Image processing utilities for answer sheets and marking schemes.
///
/// Provides compression, resizing, and grayscale conversion to reduce file
/// sizes and improve AI marking accuracy for handwritten content.
class ImageUtils {
  ImageUtils._();

  /// Maximum dimension (width or height) for answer sheet / scheme images.
  /// 1500px at ~180 DPI is more than sufficient for clear handwriting on A4.
  static const int maxDimension = 1500;

  /// JPEG quality for compressed images (0–100).
  /// 80 is the sweet spot: visually identical to 95 for handwriting,
  /// but ~60 % smaller file size.
  static const int quality = 80;

  /// Compresses, resizes, and optionally converts an image to grayscale,
  /// writing the result to [destPath] as JPEG.
  ///
  /// The output image will be scaled so that neither its width nor its height
  /// exceeds [maxDimension], preserving the original aspect ratio.
  ///
  /// When [grayscale] is `true` (the default for paper documents), the image
  /// is converted to grayscale after resizing. This:
  /// - Removes color noise from paper tint, pen color variation, and lighting
  /// - Improves contrast between handwriting and background
  /// - Produces cleaner input for AI marking models
  /// - Further reduces file size (~30-40 % smaller than color at same quality)
  ///
  /// Returns the destination [File]. If processing fails for any reason the
  /// original file is copied verbatim as a fallback so callers never receive
  /// `null`.
  static Future<File> compressAndSave(
    String srcPath,
    String destPath, {
    bool grayscale = true,
  }) async {
    final srcSize = await File(srcPath).length();

    try {
      // Step 1: Native resize + compress (fast, GPU-accelerated on most
      // platforms). This brings a 12 MP camera image down to ~1500 px.
      final resized = await FlutterImageCompress.compressAndGetFile(
        srcPath,
        destPath,
        quality: grayscale ? 95 : quality, // higher interim quality when
        minWidth: maxDimension, // grayscale re-encodes below
        minHeight: maxDimension,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (resized == null || !await File(resized.path).exists()) {
        // Native compress failed — fall through to fallback.
        throw Exception('compressAndGetFile returned null');
      }

      // Step 2: Grayscale conversion (pure Dart, but fast at ≤1500 px).
      if (grayscale) {
        final resizedFile = File(resized.path);
        final bytes = await resizedFile.readAsBytes();
        final decoded = img.decodeImage(bytes);

        if (decoded != null) {
          final gray = img.grayscale(decoded);
          final encoded = Uint8List.fromList(
            img.encodeJpg(gray, quality: quality),
          );
          await File(destPath).writeAsBytes(encoded, flush: true);
        }
        // If decode failed the resized color version is already at destPath,
        // which is still a valid (just not grayscale) result.
      }

      final destSize = await File(destPath).length();
      debugPrint(
        '[ImageUtils] ${grayscale ? "grayscale + " : ""}compressed '
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

  /// Compresses a list of files (returned as paths from the document scanner
  /// or gallery picker) into the target [directory], naming them sequentially
  /// starting from [startIndex].
  ///
  /// When [grayscale] is `true` (default), each image is converted to
  /// grayscale for optimal AI marking input.
  ///
  /// Returns the list of destination paths.
  static Future<List<String>> compressBatch({
    required List<String> sourcePaths,
    required String directory,
    required int startIndex,
    bool grayscale = true,
  }) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    final destPaths = <String>[];
    for (int i = 0; i < sourcePaths.length; i++) {
      final index = startIndex + i;
      final destPath = '$directory/$index.jpg';
      await compressAndSave(sourcePaths[i], destPath, grayscale: grayscale);
      destPaths.add(destPath);
    }
    return destPaths;
  }

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';
}
