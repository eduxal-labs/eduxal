import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors device connectivity and fires [onOnline] when an offline → online
/// transition is detected.
///
/// This is intentionally simple and focused — it does not try to be a general
/// connectivity service. Its sole purpose is to detect when the device regains
/// network access so that the [SyncEngine] can be revived immediately instead
/// of waiting for the next backoff timer or app-resume lifecycle event.
///
/// Usage:
/// ```dart
/// final monitor = ConnectivityMonitor(
///   onOnline: () => syncEngine.revive(),
/// );
/// monitor.start();
/// // ...later...
/// monitor.stop();
/// ```
class ConnectivityMonitor {
  ConnectivityMonitor({required this.onOnline});

  /// Called when the device transitions from offline to online.
  /// Expected to be a lightweight, synchronous call (e.g. `syncEngine.revive()`).
  final VoidCallback onOnline;

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Whether the device was online at the last check. Defaults to `true` so
  /// that the first emission doesn't trigger a false offline→online transition
  /// if the device was already connected at startup.
  bool _wasOnline = true;

  /// Debounce timer to avoid firing [onOnline] on rapid connectivity flaps
  /// (e.g. switching from Wi-Fi to mobile data often produces a brief
  /// "none" result in between).
  Timer? _debounce;

  /// Starts monitoring connectivity changes.
  ///
  /// Safe to call multiple times — each call stops the previous session first.
  /// The initial connectivity state is checked synchronously-ish (via a
  /// platform call) so that the first real change event is compared against
  /// the actual starting state, not an assumption.
  void start() {
    stop();

    // Check the initial connectivity state so we have an accurate baseline.
    // This is fire-and-forget — if the platform call fails, we keep the
    // default `_wasOnline = true` which is the safe assumption (avoids a
    // spurious revive on the very first emission).
    _connectivity.checkConnectivity().then(
      (results) {
        _wasOnline = _isOnline(results);
        debugPrint(
          '[ConnectivityMonitor] Initial state: '
          '${_wasOnline ? "online" : "offline"}',
        );
      },
      onError: (Object e) {
        debugPrint('[ConnectivityMonitor] Failed to check initial state: $e');
      },
    );

    _subscription = _connectivity.onConnectivityChanged.listen(
      _onChanged,
      onError: (Object e) {
        debugPrint('[ConnectivityMonitor] Stream error: $e');
      },
    );

    debugPrint('[ConnectivityMonitor] Started');
  }

  /// Stops monitoring and cancels any pending debounce timer.
  void stop() {
    _debounce?.cancel();
    _debounce = null;
    _subscription?.cancel();
    _subscription = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal
  // ─────────────────────────────────────────────────────────────────────────

  void _onChanged(List<ConnectivityResult> results) {
    final online = _isOnline(results);

    debugPrint(
      '[ConnectivityMonitor] Connectivity changed: '
      '${online ? "online" : "offline"} '
      '(was: ${_wasOnline ? "online" : "offline"})',
    );

    if (online && !_wasOnline) {
      // Offline → Online transition detected.
      // Debounce for 500 ms to let the connection stabilise and to
      // deduplicate rapid flaps (e.g. Wi-Fi → mobile handoff).
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        debugPrint(
          '[ConnectivityMonitor] Offline → Online transition confirmed '
          '— firing onOnline callback',
        );
        onOnline();
      });
    } else if (!online) {
      // Went offline — cancel any pending online callback since the device
      // didn't actually stabilise on a connection.
      _debounce?.cancel();
      _debounce = null;
    }

    _wasOnline = online;
  }

  /// Returns `true` if any of the reported results indicate an active
  /// network connection (i.e. anything other than [ConnectivityResult.none]).
  static bool _isOnline(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
  }
}
