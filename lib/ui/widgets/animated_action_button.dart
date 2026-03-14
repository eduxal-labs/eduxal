import 'package:flutter/material.dart';

/// A compact icon button with animated feedback for mutation actions.
///
/// Cycles through three states:
///   **idle** → tap detected → **busy** (spinner) → **done** (check flash) → **idle**
///
/// Default size is 32×32 with a 6-radius rounded rectangle shape.
///
/// ## Usage
/// ```dart
/// AnimatedActionButton(
///   icon: Icons.delete_outline_rounded,
///   tooltip: 'Delete',
///   color: cs.error,
///   onTap: () async {
///     await dao.deleteItem(id, accountId: userId);
///   },
/// )
/// ```
class AnimatedActionButton extends StatefulWidget {
  const AnimatedActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = 32,
    this.iconSize = 16,
    this.showCheckOnSuccess = true,
  });

  /// The icon to display in the idle state.
  final IconData icon;

  /// The async action to perform when tapped.
  /// Errors are caught silently — the button reverts to idle without showing
  /// the check. If you need error handling, do it inside this callback.
  final Future<void> Function() onTap;

  /// Optional tooltip shown on long-press / hover.
  final String? tooltip;

  /// Icon colour in idle and done states.
  /// Defaults to [ColorScheme.onSurfaceVariant].
  final Color? color;

  /// Background fill of the container.
  /// Defaults to [Colors.transparent].
  final Color? backgroundColor;

  /// Width and height of the hit-target container. Defaults to 32.
  final double size;

  /// Size of the icon in idle state and the check icon in done state.
  /// Defaults to 16.
  final double iconSize;

  /// Whether to flash a check icon after a successful [onTap].
  /// Set to `false` for destructive actions where the item will be removed
  /// from the list immediately (the feedback would be redundant).
  final bool showCheckOnSuccess;

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

// ─────────────────────────────────────────────────────────────────────────────

enum _ButtonState { idle, busy, done }

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  _ButtonState _state = _ButtonState.idle;

  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkScale = CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_state != _ButtonState.idle) return;

    setState(() => _state = _ButtonState.busy);

    try {
      await widget.onTap();
    } catch (_) {
      // On error: silently revert to idle, no check flash.
      if (mounted) setState(() => _state = _ButtonState.idle);
      return;
    }

    if (!mounted) return;

    if (widget.showCheckOnSuccess) {
      setState(() => _state = _ButtonState.done);
      _checkCtrl.reset();
      await _checkCtrl.forward();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _checkCtrl.reverse();
      if (!mounted) return;
    }

    setState(() => _state = _ButtonState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget button = AnimatedScale(
      scale: _state == _ButtonState.busy ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: _buildCenter(cs),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }

  Widget _buildCenter(ColorScheme cs) {
    return switch (_state) {
      _ButtonState.busy => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: widget.color ?? cs.onSurfaceVariant,
        ),
      ),
      _ButtonState.done => ScaleTransition(
        scale: _checkScale,
        child: Icon(
          Icons.check_rounded,
          size: widget.iconSize,
          color: widget.color ?? cs.primary,
        ),
      ),
      _ButtonState.idle => Icon(
        widget.icon,
        size: widget.iconSize,
        color: widget.color ?? cs.onSurfaceVariant,
      ),
    };
  }
}
