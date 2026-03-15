import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../database/tables/enums.dart';

/// A small status indicator overlaid on the bottom-right corner of a profile
/// avatar.
///
/// - **Dot** (8 px filled circle) for [UserLevel.normal] and
///   [UserLevel.system] users.
/// - **Star** (~10 px five-point star) for [UserLevel.super_] users.
///
/// Both shapes are surrounded by a 2 px solid border matching
/// [backgroundColor] to create a "cutout" effect against the avatar.
///
/// Colour is determined by [UserStatus]:
/// - Invited:   `#7986CB` (indigo-300)
/// - Active:    `#26A69A` (teal-400)
/// - Suspended: `#FFB300` (amber)
/// - Deleted:   `#EF5350` (red)
///
/// Usage:
/// ```dart
/// Stack(
///   clipBehavior: Clip.none,
///   children: [
///     UserAvatar(userId: user.id, radius: 20),
///     Positioned(
///       bottom: -1,
///       right: -1,
///       child: StatusIndicator(
///         status: user.status,
///         level: user.level,
///         backgroundColor: cs.surface,
///       ),
///     ),
///   ],
/// )
/// ```
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
    required this.level,
    required this.backgroundColor,
  });

  /// The user's current status — determines the fill colour.
  final UserStatus status;

  /// The user's level — determines the shape (dot vs star).
  final UserLevel level;

  /// The colour behind this indicator (typically the row/card background).
  /// Used as a 2 px border to create a cutout effect.
  final Color backgroundColor;

  /// Returns the indicator colour for a given [UserStatus].
  static Color colorFor(UserStatus status) {
    return switch (status) {
      UserStatus.invited => const Color(0xFF7986CB),
      UserStatus.active => const Color(0xFF26A69A),
      UserStatus.suspended => const Color(0xFFFFB300),
      UserStatus.deleted => const Color(0xFFEF5350),
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);

    if (level == UserLevel.super_) {
      return _StarIndicator(color: color, backgroundColor: backgroundColor);
    }
    if (level == UserLevel.system) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(Icons.shield_rounded, size: 10, color: color),
        ),
      );
    }

    return _DotIndicator(color: color, backgroundColor: backgroundColor);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot indicator (Normal / System)
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.color, required this.backgroundColor});

  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Outer: 12 px (8 px dot + 2 px border on each side).
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star indicator (Super)
// ─────────────────────────────────────────────────────────────────────────────

class _StarIndicator extends StatelessWidget {
  const _StarIndicator({required this.color, required this.backgroundColor});

  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // ~14 px outer (10 px star + 2 px border on each side).
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _StarPainter(
          fillColor: color,
          borderColor: backgroundColor,
          borderWidth: 2.0,
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
  });

  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.4;

    final path = _starPath(center, outerRadius, innerRadius, 5);

    // Draw the border (cutout ring) first — slightly larger stroke.
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    // Draw the filled star on top.
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  Path _starPath(Offset center, double outer, double inner, int points) {
    final path = Path();
    final step = math.pi / points;
    // Start from the top (−π/2 rotation).
    const startAngle = -math.pi / 2;

    for (var i = 0; i < points * 2; i++) {
      final angle = startAngle + i * step;
      final radius = i.isEven ? outer : inner;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) =>
      fillColor != oldDelegate.fillColor ||
      borderColor != oldDelegate.borderColor ||
      borderWidth != oldDelegate.borderWidth;
}

// ─────────────────────────────────────────────────────────────────────────────
// School status dot
// ─────────────────────────────────────────────────────────────────────────────

/// A small coloured dot overlaid on the bottom-right corner of a school logo.
///
/// Same 8 px dot + 2 px cutout border as [StatusIndicator], but colour is
/// determined by [SchoolStatus]:
/// - Trial:     `#42A5F5` (blue)
/// - Active:    `#26A69A` (teal-400)
/// - Cancelled: `#BDBDBD` (grey)
/// - Suspended: `#FFB300` (amber)
/// - Deleted:   `#EF5350` (red)
class SchoolStatusDot extends StatelessWidget {
  const SchoolStatusDot({
    super.key,
    required this.status,
    required this.backgroundColor,
  });

  final SchoolStatus status;
  final Color backgroundColor;

  /// Returns the indicator colour for a given [SchoolStatus].
  static Color colorFor(SchoolStatus status) {
    return switch (status) {
      SchoolStatus.trial => const Color(0xFF42A5F5),
      SchoolStatus.active => const Color(0xFF26A69A),
      SchoolStatus.cancelled => const Color(0xFFBDBDBD),
      SchoolStatus.suspended => const Color(0xFFFFB300),
      SchoolStatus.deleted => const Color(0xFFEF5350),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _DotIndicator(
      color: colorFor(status),
      backgroundColor: backgroundColor,
    );
  }
}
