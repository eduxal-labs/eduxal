import 'dart:async';

import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../models/marking_status.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MarkingStatusIndicator
//
// Compact widget that watches the synced marking_queue table for real-time
// marking progress and renders phase-appropriate feedback: pulsing dot
// (queued), progress bar (downloading/marking/computing), green check
// (complete), or error + retry (failed).
//
// Max height: 36px. Horizontal layout.
// ─────────────────────────────────────────────────────────────────────────────

class MarkingStatusIndicator extends StatefulWidget {
  const MarkingStatusIndicator({
    super.key,
    required this.resolvedPaperId,
    this.onComplete,
    this.onRetry,
  });

  /// Server UUID paper ID used as the row key in the marking_queue table.
  final String resolvedPaperId;

  /// Called when marking reaches phase 5 (complete).
  final VoidCallback? onComplete;

  /// Called when the user taps "Retry" after a failure.
  final VoidCallback? onRetry;

  @override
  State<MarkingStatusIndicator> createState() => _MarkingStatusIndicatorState();
}

class _MarkingStatusIndicatorState extends State<MarkingStatusIndicator>
    with SingleTickerProviderStateMixin {
  StreamSubscription<MarkingQueueData>? _sub;
  MarkingStatus? _status;
  bool _hidden = false;

  // Pulsing amber dot animation (used in queued phase).
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();

    final query = db.select(db.markingQueue)
      ..where((t) => t.paper.equals(widget.resolvedPaperId));

    _sub = query.watchSingle().listen(
      (row) {
        if (!mounted) return;
        final phase = phaseFromInt(row.phase);
        final total = row.totalStudents;
        final marked = row.markedStudents;
        setState(() {
          _status = MarkingStatus(
            phase: phase,
            progressCurrent: marked,
            progressTotal: total,
            errorMessage: row.error,
            progressText: row.progress,
          );
        });

        if (phase == MarkingPhase.complete) {
          widget.onComplete?.call();
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _hidden = true);
          });
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(
          () => _status = MarkingStatus(
            phase: MarkingPhase.failed,
            progressCurrent: 0,
            progressTotal: 0,
            errorMessage: e.toString(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || _hidden) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: _buildPhase(status, cs, isDark),
      ),
    );
  }

  Widget _buildPhase(MarkingStatus status, ColorScheme cs, bool isDark) {
    return switch (status.phase) {
      MarkingPhase.queued => _buildQueued(cs),
      MarkingPhase.downloading => _buildIndeterminate(cs, status.displayLabel),
      MarkingPhase.marking => _buildDeterminate(cs, status),
      MarkingPhase.computing => _buildIndeterminate(cs, status.displayLabel),
      MarkingPhase.complete => _buildComplete(cs),
      MarkingPhase.failed => _buildFailed(cs, status),
    };
  }

  // ── Queued: pulsing amber dot ─────────────────────────────────────────

  Widget _buildQueued(ColorScheme cs) {
    return Row(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Queued for marking...',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ── Indeterminate progress (downloading / computing) ──────────────────

  Widget _buildIndeterminate(ColorScheme cs, String label) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: cs.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Determinate progress (marking) ────────────────────────────────────

  Widget _buildDeterminate(ColorScheme cs, MarkingStatus status) {
    final pct = (status.progressFraction * 100).toInt();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status.displayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: status.progressFraction,
                  minHeight: 2,
                  backgroundColor: cs.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Complete: green check ─────────────────────────────────────────────

  Widget _buildComplete(ColorScheme cs) {
    return const Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF43A047)),
        SizedBox(width: 8),
        Text(
          'Marking complete',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF43A047),
          ),
        ),
      ],
    );
  }

  // ── Failed: error + retry ─────────────────────────────────────────────

  Widget _buildFailed(ColorScheme cs, MarkingStatus status) {
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            status.errorMessage ?? 'Marking failed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: cs.error,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.onRetry != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _hidden = false;
                _status = null;
              });
              widget.onRetry?.call();
              _subscribe();
            },
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
