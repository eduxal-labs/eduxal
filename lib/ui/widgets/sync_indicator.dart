import 'package:flutter/material.dart';

import '../../client.dart';
import '../../sync/sync_status.dart';

/// A tiny, unobtrusive sync status indicator.
///
/// Renders a small dot (7 px) that changes colour and optionally pulses
/// based on the current [SyncStatus] emitted by the global [SyncEngine]:
///
///  - [SyncStatus.disconnected] — muted red/grey dot
///  - [SyncStatus.idle]         — subtle green dot (connected, nothing happening)
///  - [SyncStatus.pushing]      — pulsing blue dot (sending mutations)
///  - [SyncStatus.pulling]      — pulsing blue dot (receiving deltas)
///
/// Place this widget in an app bar or top-bar row. It is deliberately tiny
/// (≤ 20 px touch target) and follows AGENT.md §21: thin, minimal, modern.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, status, _) {
        return Tooltip(
          message: _tooltip(status),
          child: _SyncDot(status: status),
        );
      },
    );
  }

  static String _tooltip(SyncStatus status) => switch (status) {
    SyncStatus.disconnected => 'Offline',
    SyncStatus.idle => 'Connected',
    SyncStatus.pushing => 'Syncing…',
    SyncStatus.pulling => 'Syncing…',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated dot — pulses when pushing or pulling, static otherwise.
// ─────────────────────────────────────────────────────────────────────────────

class _SyncDot extends StatefulWidget {
  const _SyncDot({required this.status});
  final SyncStatus status;

  @override
  State<_SyncDot> createState() => _SyncDotState();
}

class _SyncDotState extends State<_SyncDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _SyncDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (_isActive) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1.0; // fully opaque when static
    }
  }

  bool get _isActive =>
      widget.status == SyncStatus.pushing ||
      widget.status == SyncStatus.pulling;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _dotColor(context);

    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color.withValues(alpha: _isActive ? _pulse.value : 1.0),
                borderRadius: BorderRadius.circular(1.5), // slightly blunted
              ),
            );
          },
        ),
      ),
    );
  }

  Color _dotColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return switch (widget.status) {
      SyncStatus.disconnected =>
        isDark
            ? Colors.red.shade300.withValues(alpha: 0.6)
            : Colors.red.shade400.withValues(alpha: 0.55),
      SyncStatus.idle =>
        isDark
            ? Colors.green.shade300.withValues(alpha: 0.7)
            : Colors.green.shade500.withValues(alpha: 0.6),
      SyncStatus.pushing =>
        isDark ? Colors.blue.shade300 : Colors.blue.shade400,
      SyncStatus.pulling =>
        isDark ? Colors.blue.shade300 : Colors.blue.shade400,
    };
  }
}
