import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The type of today-status indicator, controlling the color scheme.
enum TodayStatusType {
  /// Green — present, all marked, on track.
  positive,

  /// Red — absent, missed, behind.
  negative,

  /// Grey — not yet determined, pending.
  neutral,

  /// Amber — partially done, attention needed.
  warning,
}

/// A prominent today-status indicator card.
///
/// Used by Guardian (attendance), Teacher (class marking status),
/// Owner (school-wide attendance), Student (schedule status).
class TodayStatusCard extends StatelessWidget {
  const TodayStatusCard({
    super.key,
    required this.type,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// Determines the color scheme of the card.
  final TodayStatusType type;

  /// Leading icon displayed at the start of the card.
  final IconData icon;

  /// Primary text — e.g. "Present", "3 of 5 Marked", "On Track".
  final String title;

  /// Optional secondary text — e.g. a timestamp or extra detail.
  final String? subtitle;

  /// Optional trailing widget — e.g. a chevron or badge.
  final Widget? trailing;

  /// Tap callback. When non-null the card becomes tappable with an InkWell.
  final VoidCallback? onTap;

  // ───────────────────────────────────────────────────────────────────────
  // Color helpers
  // ───────────────────────────────────────────────────────────────────────

  static Color _bgColor(TodayStatusType type, bool isDark, ColorScheme cs) {
    switch (type) {
      case TodayStatusType.positive:
        return isDark
            ? Colors.green[900]!.withValues(alpha: 0.15)
            : Colors.green[50]!;
      case TodayStatusType.negative:
        return isDark
            ? Colors.red[900]!.withValues(alpha: 0.15)
            : Colors.red[50]!;
      case TodayStatusType.neutral:
        return cs.surfaceContainerHighest;
      case TodayStatusType.warning:
        return isDark
            ? Colors.amber[900]!.withValues(alpha: 0.15)
            : Colors.amber[50]!;
    }
  }

  static Color _fgColor(TodayStatusType type, bool isDark, ColorScheme cs) {
    switch (type) {
      case TodayStatusType.positive:
        return isDark ? Colors.green[300]! : Colors.green[700]!;
      case TodayStatusType.negative:
        return isDark ? Colors.red[300]! : Colors.red[700]!;
      case TodayStatusType.neutral:
        return cs.onSurfaceVariant;
      case TodayStatusType.warning:
        return isDark ? Colors.amber[300]! : Colors.amber[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = _bgColor(type, isDark, cs);
    final fg = _fgColor(type, isDark, cs);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 28, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: fg.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              splashColor: fg.withValues(alpha: 0.08),
              highlightColor: fg.withValues(alpha: 0.04),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64, maxHeight: 72),
                child: content,
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64, maxHeight: 72),
              child: content,
            ),
    );
  }
}
