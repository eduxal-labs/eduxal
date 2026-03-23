import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image processing utilities for answer sheets and marking schemes.
///
/// Provides compression and resizing to reduce file sizes while
/// preserving readability of handwritten content.
class ImageUtils {
  ImageUtils._();

  /// Maximum dimension (width or height) for answer sheet / scheme images.
  /// 1500px at ~180 DPI is more than sufficient for clear handwriting on A4.
  static const int maxDimension = 1500;

  /// JPEG quality for compressed images (0–100).
  /// 80 is the sweet spot: visually identical to 95 for handwriting,
  /// but ~60 % smaller file size.
  static const int quality = 80;

  /// Compresses and resizes an image from [srcPath], writing the result to
  /// [destPath] as JPEG.
  ///
  /// The output image will be scaled so that neither its width nor its height
  /// exceeds [maxDimension], preserving the original aspect ratio.
  ///
  /// Returns the destination [File]. If native compression fails for any
  /// reason the original file is copied verbatim as a fallback so callers
  /// never receive `null`.
  static Future<File> compressAndSave(String srcPath, String destPath) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        srcPath,
        destPath,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result != null) {
        final compressed = File(result.path);
        if (await compressed.exists()) {
          final srcSize = await File(srcPath).length();
          final destSize = await compressed.length();
          debugPrint(
            '[ImageUtils] compressed ${_kb(srcSize)} → ${_kb(destSize)} '
            '(${(100 - destSize * 100 / srcSize).round()}% reduction)',
          );
          return compressed;
        }
      }
    } catch (e, st) {
      debugPrint('[ImageUtils] compression failed, copying original: $e\n$st');
    }
    // Fallback: copy the original uncompressed file.
    return File(srcPath).copy(destPath);
  }

  /// Compresses a list of files (returned as paths from the document scanner
  /// or gallery picker) into the target [directory], naming them sequentially
  /// starting from [startIndex].
  ///
  /// Returns the list of destination paths.
  static Future<List<String>> compressBatch({
    required List<String> sourcePaths,
    required String directory,
    required int startIndex,
  }) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    final destPaths = <String>[];
    for (int i = 0; i < sourcePaths.length; i++) {
      final index = startIndex + i;
      final destPath = '$directory/$index.jpg';
      await compressAndSave(sourcePaths[i], destPath);
      destPaths.add(destPath);
    }
    return destPaths;
  }

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';
}
