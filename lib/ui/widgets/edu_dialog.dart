import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard dialog wrapper following the EduXal design system.
///
/// Renders: modalBg, kModalRadius, modalShadow, 1px borderColor border,
/// constrained width, optional title row.
class EduDialog extends StatelessWidget {
  const EduDialog({
    super.key,
    required this.child,
    this.title,
    this.maxWidth = 440,
  });

  final Widget child;
  final String? title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) _buildTitleRow(context, cs),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(
            children: [
              Text(
                title!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.3)),
      ],
    );
  }
}
