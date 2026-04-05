import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A self-updating countdown chip that ticks toward [targetTime].
///
/// Used by Teacher (next class), Student (next class), Owner (term countdown).
/// Switches to urgency colours when ≤ 5 minutes remain and calls [onReached]
/// when the target is hit.
class CountdownChip extends StatefulWidget {
  const CountdownChip({
    super.key,
    required this.label,
    required this.targetTime,
    this.icon,
    this.onReached,
    this.reachedLabel,
    this.compact = false,
  });

  /// Descriptive label, e.g. "Physics".
  final String label;

  /// The [DateTime] we are counting down to.
  final DateTime targetTime;

  /// Optional leading icon shown before the label / time.
  final IconData? icon;

  /// Fired once when the countdown reaches zero.
  final VoidCallback? onReached;

  /// Text to display when the countdown reaches zero (defaults to "Now!").
  final String? reachedLabel;

  /// When `true`, only the icon and remaining time are shown (no [label]).
  final bool compact;

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _reached = false;

  // Entrance fade
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // ───────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _tick(); // initial calculation
    _scheduleTimer();
  }

  @override
  void didUpdateWidget(covariant CountdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTime != widget.targetTime) {
      _reached = false;
      _tick();
      _scheduleTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Timer logic
  // ───────────────────────────────────────────────────────────────────────

  void _tick() {
    final now = DateTime.now();
    final diff = widget.targetTime.difference(now);

    if (diff.isNegative || diff == Duration.zero) {
      if (!_reached) {
        _reached = true;
        widget.onReached?.call();
      }
      _remaining = Duration.zero;
    } else {
      _remaining = diff;
    }

    if (mounted) setState(() {});
  }

  void _scheduleTimer() {
    _timer?.cancel();

    if (_reached) return;

    // Tick every second when < 60 s remain; otherwise every 60 s.
    final interval = _remaining.inSeconds < 60
        ? const Duration(seconds: 1)
        : const Duration(seconds: 60);

    _timer = Timer.periodic(interval, (_) {
      _tick();
      // Re-schedule with a different interval if we just crossed the 60 s boundary.
      if (!_reached && _remaining.inSeconds < 60 && interval.inSeconds != 1) {
        _scheduleTimer();
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Formatting
  // ───────────────────────────────────────────────────────────────────────

  String _formatRemaining(Duration d) {
    if (d == Duration.zero) return widget.reachedLabel ?? 'Now!';

    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '$minutes min';
    }

    final seconds = d.inSeconds;
    return '${seconds}s';
  }

  // ───────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool urgent = !_reached && _remaining.inMinutes <= 5;

    final Color bg = urgent ? cs.errorContainer : cs.primaryContainer;
    final Color fg = urgent ? cs.onErrorContainer : cs.onPrimaryContainer;

    final timeText = _formatRemaining(_remaining);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            if (!widget.compact) ...[
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: fg,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
            Text(
              timeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
