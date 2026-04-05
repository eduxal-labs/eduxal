import 'package:flutter/material.dart';

import '../../client.dart';
import '../../sync/sync_status.dart';

/// A full-width banner that displays the current sync status:
///
/// - [SyncStatus.disconnected]: 32 px amber offline banner with cloud_off icon
/// - [SyncStatus.pushing] / [SyncStatus.pulling]: 2 px [LinearProgressIndicator]
/// - [SyncStatus.idle]: nothing ([SizedBox.shrink])
///
/// Uses [AnimatedSize] for smooth height transitions between states.
/// Place at the top of a [Column] inside a [Scaffold] body.
///
/// No dismiss button — the banner auto-hides when connectivity is restored.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, status, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: switch (status) {
            SyncStatus.disconnected => const _OfflineBanner(),
            SyncStatus.pushing ||
            SyncStatus.pulling => _SyncProgressBar(status: status),
            SyncStatus.idle => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline banner — 32 px amber strip
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final fg = isDark ? Colors.white70 : Colors.amber.shade900;
    final bg = isDark ? Colors.amber.shade700 : Colors.amber.shade100;

    return Container(
      width: double.infinity,
      height: 32,
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(
            "You\u2019re offline \u2014 changes saved locally",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin progress bar — 2 px indeterminate indicator
// ─────────────────────────────────────────────────────────────────────────────

class _SyncProgressBar extends StatelessWidget {
  const _SyncProgressBar({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 2,
      width: double.infinity,
      child: LinearProgressIndicator(
        backgroundColor: cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
      ),
    );
  }
}
