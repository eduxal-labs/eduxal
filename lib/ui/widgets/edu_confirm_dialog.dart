import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard confirmation dialog following the EduXal design system.
///
/// Returns `true` if the user confirms, `false` or `null` if cancelled.
class EduConfirmDialog extends StatelessWidget {
  const EduConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmColor,
    this.isDestructive = false,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final Color? confirmColor;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final actionColor = confirmColor ?? (isDestructive ? cs.error : cs.primary);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
            border: Border.all(
              color: AppTheme.borderColor(isDark, cs),
              width: 1,
            ),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Buttons row — right-aligned
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: actionColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience function to show an [EduConfirmDialog].
///
/// Returns `true` if the user confirmed, `false` if cancelled.
Future<bool> showEduConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => EduConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      confirmColor: confirmColor,
    ),
  );
  return result ?? false;
}
