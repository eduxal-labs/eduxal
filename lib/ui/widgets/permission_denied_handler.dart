import 'package:flutter/material.dart';
import '../../services/authorization_service.dart';
import '../theme/app_theme.dart';

/// Shows a standardized permission-denied snackbar on [context].
///
/// Call this whenever a [PermissionException] is caught in a widget's
/// button handler:
///
/// ```dart
/// try {
///   await db.examsGradesDao.deleteExam(examId, accountId: accountId);
/// } on PermissionException catch (e) {
///   if (context.mounted) showPermissionDenied(context, e.reason);
/// }
/// ```
void showPermissionDenied(BuildContext context, String reason) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.kPermissionDeniedColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
      ),
    );
}

/// Wraps an async action and automatically shows a permission-denied snackbar
/// on [PermissionException].
///
/// Usage:
/// ```dart
/// await guardedAction(context, () => dao.deleteExam(examId, accountId: id));
/// ```
Future<void> guardedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on PermissionException catch (e) {
    if (context.mounted) showPermissionDenied(context, e.reason);
  }
}
