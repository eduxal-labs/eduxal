import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared helper for showing optimistic mutation feedback.
///
/// Call after any successful DAO mutation to give the user visual
/// confirmation that the action was saved locally and queued for sync.
class OptimisticFeedback {
  OptimisticFeedback._();

  /// Shows a brief floating SnackBar with a success message and sync icon.
  ///
  /// Usage:
  /// ```dart
  /// OptimisticFeedback.show(context, 'Teacher invited ✓');
  /// ```
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.sync_rounded, color: Colors.white70, size: 14),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        width: 320,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
        backgroundColor: const Color(0xFF2E7D32), // green[800]
      ),
    );
  }
}
