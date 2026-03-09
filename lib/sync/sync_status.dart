/// Sync status observable — tracks the current state of the sync engine
/// for UI consumption.
///
/// The [SyncStatus] enum represents the four possible states of the sync
/// engine. The sync engine exposes a [ValueNotifier<SyncStatus>] that
/// widgets can listen to via [ValueListenableBuilder].
library;

/// The current operational state of the sync engine.
enum SyncStatus {
  /// Not connected to the server. Either the sync engine has not been
  /// started, the device is offline, or the connection was lost.
  disconnected,

  /// Connected to the server with no active data transfer. Everything
  /// is up to date (or waiting for the next push/pull cycle).
  idle,

  /// Actively sending local mutations to the server.
  pushing,

  /// Actively receiving deltas from the server.
  pulling,
}
