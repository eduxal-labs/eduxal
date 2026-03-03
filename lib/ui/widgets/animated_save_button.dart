import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact icon button that animates through four states:
///
/// - **idle**:    no unsaved changes.
///               Shows a faint static checkmark (alpha 0.25).
///               No arc.
///
/// - **dirty**:   unsaved changes exist.
///               Shows a red checkmark + a small static partial arc
///               (15 % of circle) hinting at "incomplete".
///
/// - **saving**:  save in progress.
///               Shows an indigo checkmark + a continuously spinning
///               270° arc (repeating, 900 ms period).
///               The button is non-tappable while in this state.
///
/// - **success**: save just completed (triggered automatically when
///               `isSaving` transitions false→false with `isDirty` also
///               false). The arc sweeps to a full 360° in brand green
///               over 300 ms, then the icon turns green. After 1 500 ms
///               the button auto-reverts to idle with a 150 ms fade.
///
/// ## Parent API
/// Simply pass boolean props. The widget drives its own animation by
/// watching prop changes in [didUpdateWidget]:
///
/// ```dart
/// AnimatedSaveButton(
///   isDirty: _isDirty,
///   isSaving: _saving,
///   onSave: _isDirty ? _save : null,
/// )
/// ```
class AnimatedSaveButton extends StatefulWidget {
  const AnimatedSaveButton({
    super.key,
    required this.isDirty,
    required this.isSaving,
    required this.onSave,
    this.size = 36.0,
  });

  final bool isDirty;
  final bool isSaving;

  /// Callback fired when the button is tapped. Pass `null` to disable.
  final VoidCallback? onSave;

  /// Outer size of the hit-target / ink-well circle.
  final double size;

  @override
  State<AnimatedSaveButton> createState() => _AnimatedSaveButtonState();
}

// ─────────────────────────────────────────────────────────────────────────────

enum _SaveState { idle, dirty, saving, success }

class _AnimatedSaveButtonState extends State<AnimatedSaveButton>
    with TickerProviderStateMixin {
  // ── State machine ─────────────────────────────────────────────────────────
  _SaveState _state = _SaveState.idle;

  // ── Spinner (saving state) ────────────────────────────────────────────────
  late final AnimationController _spinCtrl;
  late final Animation<double> _spinAngle; // 0 → 2π, repeating

  // ── Completion arc (success state) ────────────────────────────────────────
  late final AnimationController _completeCtrl;
  late final Animation<double> _completeSweep; // 0 → 1
  late final Animation<double> _completeFade; // 1 → 0 (fade-out to idle)

  // ── Dirty hint arc (dirty state) ─────────────────────────────────────────
  late final AnimationController _dirtyCtrl;
  late final Animation<double> _dirtyHint; // 0 → 1

  @override
  void initState() {
    super.initState();

    // Spinner — repeating rotation
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _spinAngle = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _spinCtrl, curve: Curves.linear));

    // Completion — one-shot sweep then fade
    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300 + 150), // sweep + fade
    );
    _completeSweep = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _completeCtrl,
        curve: const Interval(0.0, 0.667, curve: Curves.easeOut), // 0→300ms
      ),
    );
    _completeFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _completeCtrl,
        curve: const Interval(0.667, 1.0, curve: Curves.easeIn), // 300→450ms
      ),
    );

    // Dirty hint — quick ease-in
    _dirtyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _dirtyHint = CurvedAnimation(parent: _dirtyCtrl, curve: Curves.easeOut);

    // Initialise from current props
    _state = _stateFromProps(widget.isDirty, widget.isSaving);
    _syncAnimations(null, _state);
  }

  @override
  void didUpdateWidget(AnimatedSaveButton old) {
    super.didUpdateWidget(old);

    final prev = _state;
    final next = _resolveNextState(old, widget);

    if (next == prev) return;

    _state = next;
    _syncAnimations(prev, next);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _completeCtrl.dispose();
    _dirtyCtrl.dispose();
    super.dispose();
  }

  // ── State resolution ──────────────────────────────────────────────────────

  static _SaveState _stateFromProps(bool isDirty, bool isSaving) {
    if (isSaving) return _SaveState.saving;
    if (isDirty) return _SaveState.dirty;
    return _SaveState.idle;
  }

  _SaveState _resolveNextState(
    AnimatedSaveButton old,
    AnimatedSaveButton current,
  ) {
    // Transition from saving → (not saving, not dirty) → success
    if (old.isSaving && !current.isSaving && !current.isDirty) {
      return _SaveState.success;
    }
    return _stateFromProps(current.isDirty, current.isSaving);
  }

  // ── Animation orchestration ───────────────────────────────────────────────

  void _syncAnimations(_SaveState? from, _SaveState to) {
    switch (to) {
      case _SaveState.idle:
        _spinCtrl.stop();
        _dirtyCtrl.reverse();
        _completeCtrl.reset();

      case _SaveState.dirty:
        _spinCtrl.stop();
        _completeCtrl.reset();
        _dirtyCtrl.forward();

      case _SaveState.saving:
        _dirtyCtrl.reverse();
        _completeCtrl.reset();
        _spinCtrl.repeat();

      case _SaveState.success:
        _spinCtrl.stop();
        _dirtyCtrl.reverse();
        _completeCtrl.reset();
        _completeCtrl.forward().then((_) {
          // Hold the green checkmark for 1 500 ms, then fade to idle.
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!mounted) return;
            // Guard: if by now the parent has dirtied the form again, skip.
            if (_state != _SaveState.success) return;
            setState(() => _state = _SaveState.idle);
            _dirtyCtrl.reverse();
          });
        });
    }
  }

  // ── Paint colours ─────────────────────────────────────────────────────────

  static const _brandGreen = Color(0xFF4CAF50);

  Color _iconColor(ColorScheme cs) => switch (_state) {
    _SaveState.idle => cs.onSurfaceVariant.withValues(alpha: 0.25),
    _SaveState.dirty => cs.error,
    _SaveState.saving => cs.primary,
    _SaveState.success => _brandGreen,
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: InkWell(
        onTap: (_state == _SaveState.saving || widget.onSave == null)
            ? null
            : (_state == _SaveState.dirty ? widget.onSave : null),
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _spinAngle,
            _completeSweep,
            _completeFade,
            _dirtyHint,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _ArcPainter(
                state: _state,
                spinAngle: _spinAngle.value,
                completeSweep: _completeSweep.value,
                completeFade: _completeFade.value,
                dirtyHint: _dirtyHint.value,
                cs: cs,
                brandGreen: _brandGreen,
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: _iconColor(cs),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — draws the arc on top of the icon
// ─────────────────────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.state,
    required this.spinAngle,
    required this.completeSweep,
    required this.completeFade,
    required this.dirtyHint,
    required this.cs,
    required this.brandGreen,
  });

  final _SaveState state;
  final double spinAngle; // radians, current rotation
  final double completeSweep; // 0 → 1, completion arc
  final double completeFade; // 1 → 0, fade-out
  final double dirtyHint; // 0 → 1, dirty hint arc
  final ColorScheme cs;
  final Color brandGreen;

  static const double _strokeWidth = 1.5;
  // Arc drawn just inside the widget bounds with a small inset.
  static const double _inset = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - _inset;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    switch (state) {
      case _SaveState.idle:
        // No arc in idle.
        break;

      case _SaveState.dirty:
        // Small static partial arc (15 % = ~54°) hinting at incompleteness.
        // Animates in via dirtyHint (0 → 1).
        final sweep = 2 * math.pi * 0.15 * dirtyHint;
        if (sweep > 0) {
          paint.color = cs.error.withValues(alpha: 0.4);
          canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
        }

      case _SaveState.saving:
        // Spinning 270° arc. Rotates continuously.
        paint.color = cs.primary;
        const sweepAngle = 2 * math.pi * 0.75; // 270°
        canvas.drawArc(rect, spinAngle - math.pi / 2, sweepAngle, false, paint);

      case _SaveState.success:
        // Phase 1 (completeSweep 0→1): green arc sweeps 0° → 360°.
        // Phase 2 (completeFade 1→0): entire arc fades out.
        final sweep = 2 * math.pi * completeSweep;
        final alpha = completeFade; // 1 while sweeping, then fades
        if (sweep > 0) {
          paint.color = brandGreen.withValues(alpha: alpha);
          canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
        }
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.state != state ||
      old.spinAngle != spinAngle ||
      old.completeSweep != completeSweep ||
      old.completeFade != completeFade ||
      old.dirtyHint != dirtyHint;
}
