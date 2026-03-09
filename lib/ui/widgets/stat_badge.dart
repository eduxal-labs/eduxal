import 'package:flutter/material.dart';

/// Compact stat badge showing a label + value.
///
/// Renders as a small tinted container with the label above and value below.
/// Used for summary stat rows throughout the Academics section (comparisons
/// summary row, student overview quick stats, etc.).
///
/// ```dart
/// StatBadge(label: 'Students', value: '24')
/// StatBadge(label: 'Average', value: '72.4%', tintColor: Colors.green)
/// StatBadge(label: 'Exams', value: '5', icon: Icons.quiz_outlined)
/// ```
class StatBadge extends StatelessWidget {
  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    this.tintColor,
    this.icon,
  });

  /// Descriptive label displayed above the value (e.g. "Students", "Average").
  final String label;

  /// The stat value displayed prominently below the label (e.g. "24", "72.4%").
  final String value;

  /// Optional tint color for the container background. When provided, the
  /// container uses this color at 8% alpha. When null, falls back to the
  /// theme's `surfaceContainerHighest` at 40% alpha.
  final Color? tintColor;

  /// Optional leading icon displayed inline with the label text.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bgColor = tintColor != null
        ? tintColor!.withValues(alpha: 0.08)
        : cs.surfaceContainerHighest.withValues(alpha: 0.4);

    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Label row (optional icon + text) ─────────────────────────
          if (icon != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color:
                      tintColor ?? cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: 3),

          // ── Value ────────────────────────────────────────────────────
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
