import 'package:flutter/material.dart';

import '../../models/grade_analytics.dart';

/// Compact trajectory indicator showing direction + label.
///
/// Renders as an icon + text in the trajectory's color.
/// Available sizes: compact (icon only) and full (icon + label).
///
/// ```dart
/// TrajectoryIndicator(trajectory: Trajectory.improving)
/// TrajectoryIndicator(trajectory: Trajectory.stable, compact: true)
/// TrajectoryIndicator(trajectory: Trajectory.declining, iconSize: 14, fontSize: 11)
/// ```
class TrajectoryIndicator extends StatelessWidget {
  const TrajectoryIndicator({
    super.key,
    required this.trajectory,
    this.compact = false,
    this.iconSize = 16,
    this.fontSize = 12,
  });

  /// The trajectory direction to display.
  final Trajectory trajectory;

  /// When `true`, only the icon is shown (no label text).
  final bool compact;

  /// Icon size in logical pixels. Default 16.
  final double iconSize;

  /// Label font size in logical pixels. Default 12. Ignored when [compact].
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (IconData icon, String label, Color color) = switch (trajectory) {
      Trajectory.improving => (
        Icons.trending_up_rounded,
        'Improving',
        const Color(0xFF4CAF50),
      ),
      Trajectory.declining => (
        Icons.trending_down_rounded,
        'Declining',
        const Color(0xFFF44336),
      ),
      Trajectory.stable => (
        Icons.trending_flat_rounded,
        'Stable',
        const Color(0xFFFFA726),
      ),
      Trajectory.insufficientData => (
        Icons.help_outline_rounded,
        'Insufficient data',
        cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    };

    if (compact) {
      return Icon(icon, size: iconSize, color: color);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
