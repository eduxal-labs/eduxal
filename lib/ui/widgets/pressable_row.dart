// lib/ui/widgets/pressable_row.dart

import 'package:flutter/material.dart';

/// Mixin that adds press-scale animation to any StatefulWidget.
///
/// Usage:
/// ```dart
/// class _MyRowState extends State<MyRow>
///     with TickerProviderStateMixin, PressableRowMixin {
///   @override
///   Widget build(BuildContext context) {
///     return buildPressable(
///       onTap: () { /* action */ },
///       child: Container(/* row content */),
///     );
///   }
/// }
/// ```
mixin PressableRowMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  /// Wraps [child] in a ScaleTransition with tap handlers.
  Widget buildPressable({
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          onTap?.call();
        },
        onTapCancel: () => _pressController.reverse(),
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
