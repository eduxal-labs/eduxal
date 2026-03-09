import 'package:flutter/material.dart';

import '../../core/academic_utils.dart';

/// A thin, color-coded horizontal progress bar.
///
/// Used for: exam scores, mastery levels, attendance rates, etc.
/// Height defaults to 6px. Color is auto-determined from [percent] via
/// [percentageColor] or can be overridden with [color].
///
/// Width changes are animated with a 300ms ease-out curve for smooth
/// transitions when data updates.
///
/// ```dart
/// ThinProgressBar(percent: 72.4)
/// ThinProgressBar(percent: 45, color: Colors.amber, height: 4)
/// ThinProgressBar(percent: 90, width: 120, borderRadius: 2)
/// ```
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.percent,
    this.height = 6,
    this.color,
    this.backgroundColor,
    this.borderRadius,
    this.width,
  });

  /// Percentage value (0–100). Values outside this range are clamped.
  final double percent;

  /// Bar height in logical pixels. Default 6.
  final double height;

  /// Override fill color. If null, uses [percentageColor] from
  /// `academic_utils.dart` to auto-determine based on [percent].
  final Color? color;

  /// Background track color. If null, uses the theme's
  /// `surfaceContainerHighest` with reduced alpha.
  final Color? backgroundColor;

  /// Border radius for both the track and fill. If null, defaults to
  /// `height / 2` for a fully rounded appearance.
  final double? borderRadius;

  /// Optional fixed width. If null, the bar expands to fill available
  /// horizontal space.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clamped = percent.clamp(0.0, 100.0);
    final fraction = clamped / 100.0;

    final fillColor = color ?? percentageColor(clamped);
    final trackColor =
        backgroundColor ?? cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final radius = BorderRadius.circular(borderRadius ?? height / 2);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: trackColor,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: fraction),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: radius,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
