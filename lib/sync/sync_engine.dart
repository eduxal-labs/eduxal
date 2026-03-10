import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../database/database.dart';
import '../database/daos/accounts_dao.dart';
import '../database/daos/logs_dao.dart';
import '../proto/services/sync.pb.dart' as sync_pb;
import '../proto/services/sync.pbgrpc.dart';
import 'delta_writer.dart';
import 'sync_status.dart';

/// A raw [ClientMethod] for WatchChanges that returns unparsed bytes instead
/// of a deserialized [SyncDelta]. This lets us catch and diagnose protobuf
/// parse errors that the standard gRPC client swallows as DATA_LOSS.
final _rawWatchMethod = ClientMethod<WatchRequest, List<int>>(
  '/sync.Sync/WatchChanges',
  (WatchRequest req) => req.writeToBuffer(),
  (List<int> raw) => raw, // identity — return raw bytes as-is
);

/// Runs [body] inside a guarded zone that catches unhandled async errors
/// from the `http2` transport layer (e.g. assertion failures during
/// connection teardown when the server is unreachable). Without this,
/// those errors crash the isolate.
void _runGuarded(void Function() body) {
  runZonedGuarded(body, (error, stack) {
    dev.log(
      'Caught transport-level error (suppressed): $error',
      name: 'SyncEngine',
      error: error,
      stackTrace: stack,
    );
    debugPrint('[SyncEngine] Suppressed transport error: $error');
  });
}

/// Top-level orchestrator for bidirectional sync between the local Drift
/// database and the remote gRPC server.
///
/// Responsibilities:
/// - **Outbound (push):** Reads the local `logs` table via [LogsDao],
///   sends each pending action one-at-a-time as an [ActionRequest] via
///   [SyncClient.pushActions], and processes the [ActionResponse] for each.
/// - **Inbound (watch):** Opens a [SyncClient.watchChanges] server-streaming
///   call and applies incoming [SyncDelta] messages to the local DB via
///   [DeltaWriter].
/// - **Reconnection:** Exponential backoff on watch stream errors, up to
///   [_maxReconnectDelay].
/// - **Token expiry:** If the server responds with [StatusCode.unauthenticated],
///   sync stops and the caller (client.dart) is expected to handle token
///   refresh and restart sync.
///
/// The engine is started for a specific account via [start] and stopped via
/// [stop]. Only one account can be syncing at a time — calling [start] while
/// already running will [stop] the previous session first.
class SyncEngine {
  SyncEngine(this._channel, this._accountsDao, this._logsDao);

  final ClientChannel _channel;
  final AccountsDao _accountsDao;
  final LogsDao _logsDao;

  late SyncClient _syncClient;
  late DeltaWriter _deltaWriter;

  // ── Observable sync status ───────────────────────────────────────────────
  /// Current sync status — widgets bind to this via [ValueListenableBuilder].
  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(
    SyncStatus.disconnected,
  );

  // ── Watch (inbound) state ────────────────────────────────────────────────
  StreamSubscription<dynamic>? _watchSubscription;

  // ── Push (outbound) state ────────────────────────────────────────────────
  /// Safety-net timer that calls [pushNow] periodically to catch any
  /// mutations that were not pushed immediately (e.g. due to transient errors).
  Timer? _pushTimer;

  // ── Session state ────────────────────────────────────────────────────────
  bool _running = false;
  int _lastSeq = 0;
  String _accountId = '';
  String _accessToken = '';

  // ── Push throttle ────────────────────────────────────────────────────────
  bool _pushing = false;
  bool _pushScheduled = false;

  // ── Reconnection state ───────────────────────────────────────────────────
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectDelay = Duration(seconds: 30);

  /// Whether the sync engine is currently running.
  bool get isRunning => _running;

  /// Whether the watch stream is currently dead (no active subscription).
  /// Used by [revive] to decide if a reconnect is needed.
  bool get _watchDead => _watchSubscription == null;

  // =========================================================================
  // Public API
  // =========================================================================

  /// Start sync for the given account.
  ///
  /// If already running, the previous session is stopped first. After start:
  /// 1. Any pending local mutations are pushed immediately.
  /// 2. A server-streaming watch is opened to receive inbound deltas.
  /// 3. A periodic timer pushes pending mutations every 5 seconds as a
  ///    safety net.
  Future<void> start({
    required String accountId,
    required String accessToken,
    required int lastSeq,
  }) async {
    if (_running) await stop();

    _running = true;
    _accountId = accountId;
    _accessToken = accessToken;
    _lastSeq = lastSeq;

    _syncClient = SyncClient(_channel);
    _deltaWriter = DeltaWriter(db);

    _log('Starting sync for account=$accountId, lastSeq=$lastSeq');
    debugPrint(
      '[SyncEngine] start() called — account=$accountId, lastSeq=$lastSeq',
    );
    // Status stays disconnected until the watch stream confirms a connection
    // (first delta received or successful stream open acknowledged by gRPC).
    status.value = SyncStatus.disconnected;

    // Push any pending mutations first (fire-and-forget; errors are caught
    // inside pushNow so they don't prevent watch from starting).
    debugPrint('[SyncEngine] Pushing pending mutations on start...');
    await pushNow();

    // Start watching for server changes — wrapped in a guarded zone so that
    // transport-level errors (http2 assertion failures on connection teardown)
    // don't crash the isolate.
    debugPrint('[SyncEngine] Opening watch stream...');
    _runGuarded(_startWatch);

    // Periodic push safety net every 5 seconds.
    _pushTimer = Timer.periodic(const Duration(seconds: 5), (_) => pushNow());
  }

  /// Stop sync entirely. Cancels all streams, timers, and subscriptions.
  Future<void> stop() async {
    _log('Stopping sync');
    _running = false;
    status.value = SyncStatus.disconnected;

    _pushTimer?.cancel();
    _pushTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  /// Schedules a [pushNow] call on the next event-loop turn.
  ///
  /// DAOs call this (via the global `sync.schedulePush()`) after writing log
  /// rows inside a Drift transaction. Because the UI sometimes wraps DAO calls
  /// in an outer `db.transaction()`, calling [pushNow] directly would run
  /// *before* the outer transaction commits — so [getPendingLogs] would see
  /// zero rows and silently skip the push.
  ///
  /// We defer with `Future.delayed(150ms)` rather than `Future.microtask`
  /// because microtasks fire before pending I/O callbacks — including the
  /// SQLite commit of an outer `db.transaction()`. The 150ms delay gives
  /// the outer transaction time to commit before we query the `logs` table.
  ///
  /// Multiple calls within the same synchronous frame are coalesced — only
  /// one [pushNow] is scheduled.
  void schedulePush() {
    if (!_running) return;
    if (_pushScheduled) return;
    _pushScheduled = true;
    Future.delayed(const Duration(milliseconds: 150), () {
      _pushScheduled = false;
      _pushWithRetry();
    });
  }

  /// Calls [pushNow] and, if zero actions were found, retries once after a
  /// short delay. This handles the edge case where an outer `db.transaction()`
  /// wrapper has not yet committed by the time the first [pushNow] runs.
  Future<void> _pushWithRetry() async {
    final found = await pushNow();
    if (!found && _running) {
      // One more attempt after a generous delay — covers deeply nested
      // transactions or slow SQLite flushes.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await pushNow();
    }
  }

  /// Pushes pending local actions immediately.
  ///
  /// Returns `true` if at least one action was found and sent, `false` if
  /// there were no pending actions. The return value is used by
  /// [_pushWithRetry] to decide whether a follow-up attempt is needed.
  Future<bool> pushNow() async {
    if (!_running) return false;
    // Guard against concurrent pushNow calls (periodic timer + manual trigger).
    if (_pushing) return false;
    _pushing = true;

    try {
      final pending = await _logsDao.getPendingLogs(_accountId);
      if (pending.isEmpty) {
        debugPrint('[SyncEngine] pushNow — no pending actions');
        return false;
      }

      _log('Pushing ${pending.length} pending action(s)');
      debugPrint(
        '[SyncEngine] pushNow — sending ${pending.length} action(s)',
      );

      status.value = SyncStatus.pushing;

      await _pushActions(pending);

      if (_running) status.value = SyncStatus.idle;
      return true;
    } catch (e, st) {
      // Offline or unexpected error — actions stay in logs table, will
      // retry on the next pushNow() call or periodic timer tick.
      _log('pushNow error: $e', stackTrace: st);
      debugPrint('[SyncEngine] pushNow error: $e');
      if (_running) status.value = SyncStatus.idle;
      return false;
    } finally {
      _pushing = false;
    }
  }

  /// Immediately attempt to restore sync connectivity.
  ///
  /// Call this when the app returns from background or when the device regains
  /// network access. If the engine is running but the watch stream is dead
  /// (e.g. because timers were killed while the app was suspended), this
  /// cancels any pending reconnect backoff, resets the attempt counter, and
  /// immediately reopens the watch stream and triggers a push.
  ///
  /// If sync is not running or already connected, this is a no-op.
  void revive() {
    if (!_running) return;

    // If the watch stream is still alive, just trigger a push in case
    // mutations accumulated while the app was backgrounded.
    if (!_watchDead) {
      debugPrint('[SyncEngine] revive() — watch alive, triggering push only');
      pushNow();
      return;
    }

    debugPrint(
      '[SyncEngine] revive() — watch dead, resetting backoff and '
      'reconnecting immediately',
    );

    // Cancel any pending reconnect timer — we're taking over.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    // Restart the periodic push safety-net timer. On mobile the OS may have
    // killed the previous Timer.periodic while the app was suspended, so it
    // would never fire again even though _running is still true.
    _pushTimer?.cancel();
    _pushTimer = Timer.periodic(const Duration(seconds: 5), (_) => pushNow());

    // Reopen the watch stream immediately.
    _watchSubscription?.cancel();
    _watchSubscription = null;
    _runGuarded(_startWatch);

    // Also push any pending mutations right away.
    pushNow();
  }

  // =========================================================================
  // Push (outbound) — action-based bidirectional stream
  // =========================================================================

  /// Opens a bidirectional gRPC stream and sends each pending action one at a
  /// time, waiting for the server's [ActionResponse] before sending the next.
  ///
  /// The flow:
  /// 1. Send the first [ActionRequest].
  /// 2. Wait for [ActionResponse].
  /// 3. Process the response (apply rows, delete/mark-failed the log entry).
  /// 4. Send the next action (if any).
  /// 5. Close the stream when all actions are sent and acknowledged.
  Future<void> _pushActions(List<LogsData> pending) async {
    if (pending.isEmpty) return;

    final requestController = StreamController<sync_pb.ActionRequest>();
    ResponseStream<sync_pb.ActionResponse>? responseStream;

    try {
      responseStream = _syncClient.pushActions(
        requestController.stream,
        options: _callOptions(),
      );
    } catch (e, st) {
      _log('Failed to open push stream: $e', stackTrace: st);
      debugPrint('[SyncEngine] Failed to open push stream: $e');
      await requestController.close();
      if (_running) status.value = SyncStatus.disconnected;
      return;
    }

    // Send the first action to kick off the stream.
    final first = pending[0];
    requestController.add(sync_pb.ActionRequest(
      id: first.id,
      action: first.action.value,
      payload: first.payload,
    ));
    debugPrint(
      '[SyncEngine] Sent action #${first.id} '
      '(${first.action.name}, 1/${pending.length})',
    );

    int nextIndex = 1;

    try {
      await for (final response in responseStream) {
        if (!_running) {
          debugPrint('[SyncEngine] Push aborted — engine stopped');
          break;
        }

        await _processActionResponse(response);

        // Send the next action if there are more.
        if (nextIndex < pending.length) {
          final next = pending[nextIndex];
          requestController.add(sync_pb.ActionRequest(
            id: next.id,
            action: next.action.value,
            payload: next.payload,
          ));
          debugPrint(
            '[SyncEngine] Sent action #${next.id} '
            '(${next.action.name}, ${nextIndex + 1}/${pending.length})',
          );
          nextIndex++;
        } else {
          // All actions sent and this was the last response — close the stream.
          debugPrint('[SyncEngine] All ${pending.length} actions acknowledged');
          await requestController.close();
        }
      }
    } catch (e, st) {
      _log('Push stream error: $e', stackTrace: st);
      debugPrint('[SyncEngine] Push stream error: $e');

      if (e is GrpcError) {
        debugPrint('[SyncEngine] ── Push GrpcError details ──');
        debugPrint(
          '[SyncEngine]   code       : ${e.code} (${e.codeName})',
        );
        debugPrint('[SyncEngine]   message    : ${e.message}');
        debugPrint('[SyncEngine]   details    : ${e.details}');
        debugPrint('[SyncEngine]   trailers   : ${e.trailers}');
        debugPrint('[SyncEngine] ── end Push GrpcError details ──');

        if (e.code == StatusCode.unauthenticated) {
          _log('Unauthenticated on push — stopping sync for token refresh');
          stop();
          return;
        }
      }

      if (_running) status.value = SyncStatus.disconnected;
    } finally {
      // Ensure the controller is closed even if we broke out of the loop.
      if (!requestController.isClosed) {
        await requestController.close();
      }
    }
  }

  /// Processes a single [ActionResponse] from the server.
  ///
  /// Error codes:
  /// - 0: ok — delete log, apply returned rows.
  /// - 1: permission_denied — mark failed, show in notifications.
  /// - 2: conflict — apply server version, delete log.
  /// - 3: validation_error — mark failed, user must fix.
  /// - 4: not_found — mark failed.
  Future<void> _processActionResponse(sync_pb.ActionResponse response) async {
    final logId = response.id;

    try {
      if (response.success) {
        _log('Action $logId succeeded');
        debugPrint('[SyncEngine] Action #$logId — success');

        // Apply any returned rows to the local DB (server may have set
        // timestamps, resolved conflicts, or created related records).
        for (final row in response.rows) {
          await _applyActionRow(row);
        }

        // Delete the log entry — it has been successfully synced.
        await _logsDao.deleteLog(logId);
      } else {
        final errorMsg = response.error.isNotEmpty
            ? response.error
            : 'Error code ${response.code}';

        switch (response.code) {
          case 1: // permission_denied
            _log('Action $logId: permission denied — $errorMsg');
            debugPrint(
              '[SyncEngine] Action #$logId — permission denied: $errorMsg',
            );
            await _logsDao.markFailed(logId, errorMsg);

          case 2: // conflict — apply server's version, delete log
            _log(
              'Action $logId: conflict — applying server version, '
              'deleting log',
            );
            debugPrint(
              '[SyncEngine] Action #$logId — conflict, '
              'applying ${response.rows.length} server row(s)',
            );
            for (final row in response.rows) {
              await _applyActionRow(row);
            }
            await _logsDao.deleteLog(logId);

          case 3: // validation_error
            _log('Action $logId: validation error — $errorMsg');
            debugPrint(
              '[SyncEngine] Action #$logId — validation error: $errorMsg',
            );
            await _logsDao.markFailed(logId, errorMsg);

          case 4: // not_found
            _log('Action $logId: not found — $errorMsg');
            debugPrint(
              '[SyncEngine] Action #$logId — not found: $errorMsg',
            );
            await _logsDao.markFailed(logId, errorMsg);

          default:
            _log(
              'Action $logId: unknown error code ${response.code} — $errorMsg',
            );
            debugPrint(
              '[SyncEngine] Action #$logId — unknown code '
              '${response.code}: $errorMsg',
            );
            await _logsDao.markFailed(logId, errorMsg);
        }
      }

      // Update lastSeq if the server included file URLs that imply state
      // changes. (The server may advance seq via ActionResponse.rows.)
      // Note: ActionResponse does not carry a serverSeq field — seq advances
      // come through the watch stream exclusively.
    } catch (e, st) {
      _log('Error processing response for action $logId: $e', stackTrace: st);
      debugPrint('[SyncEngine] Error processing action #$logId response: $e');
    }
  }

  /// Applies a single [ActionRow] from a push response to the local database.
  ///
  /// [ActionRow] has the same shape as [SyncDelta] (minus `seq` and
  /// `fileUrls`): `table`, `operation`, `rowKey`, `data`. We convert it to a
  /// [SyncDelta] and reuse the [DeltaWriter]'s existing apply logic.
  Future<void> _applyActionRow(sync_pb.ActionRow row) async {
    // Convert ActionRow to SyncDelta for reuse of DeltaWriter logic.
    final delta = sync_pb.SyncDelta(
      seq: Int64.ZERO, // Not meaningful for push responses.
      table: row.table,
      operation: row.operation,
      rowKey: row.rowKey,
      data: row.hasData() ? row.data : null,
    );
    await _deltaWriter.apply(delta);
    // Flush immediately — push response rows should be written right away
    // rather than waiting for the buffer to fill.
    await _deltaWriter.flush();
  }

  // =========================================================================
  // Watch (inbound) — server-streaming
  // =========================================================================

  void _startWatch() {
    if (!_running) return;

    try {
      _log('Opening watch stream from seq=$_lastSeq');
      debugPrint(
        '[SyncEngine] _startWatch() — opening stream from seq=$_lastSeq',
      );

      // Use a raw-bytes streaming call so we can intercept deserialization
      // errors with full diagnostics (the standard gRPC client swallows
      // the actual protobuf exception and replaces it with a generic
      // DATA_LOSS: "Error parsing response").
      final rawCall = _channel.createCall(
        _rawWatchMethod,
        Stream.fromIterable([WatchRequest(lastSeq: Int64(_lastSeq))]),
        _callOptions(),
      );
      final rawStream = ResponseStream<List<int>>(rawCall);

      _watchSubscription = rawStream.listen(
        (List<int> rawBytes) {
          try {
            final delta = sync_pb.SyncDelta.fromBuffer(rawBytes);
            _onDelta(delta);
          } catch (e, st) {
            debugPrint('[SyncEngine] ── PROTO PARSE FAILURE ──');
            debugPrint('[SyncEngine]   error: $e');
            debugPrint('[SyncEngine]   rawBytes length: ${rawBytes.length}');
            debugPrint(
              '[SyncEngine]   hex (first 256 bytes): '
              '${rawBytes.take(256).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
            );
            try {
              final text = utf8.decode(rawBytes, allowMalformed: true);
              debugPrint(
                '[SyncEngine]   as text (first 512 chars): '
                '${text.length > 512 ? text.substring(0, 512) : text}',
              );
            } catch (_) {}
            debugPrint('[SyncEngine]   stack: $st');
            debugPrint('[SyncEngine] ── end PROTO PARSE FAILURE ──');
            // Don't kill the stream — skip this message and continue.
          }
        },
        onError: _onWatchError,
        onDone: _onWatchDone,
        cancelOnError: false,
      );

      // Note: gRPC stream creation is lazy — the actual TCP connection
      // happens asynchronously. We set status to idle optimistically here;
      // if the connection fails, _onWatchError will set it back to
      // disconnected. This avoids the UI showing "Offline" when the
      // connection is live but the server has no new deltas to push.
      //
      // _reconnectAttempts is NOT reset here — it is reset in _onDelta()
      // when we know the connection actually succeeded. Resetting here
      // would defeat exponential backoff because gRPC stream creation is
      // lazy and doesn't throw synchronously on connection failure.
      if (_running) status.value = SyncStatus.idle;
      debugPrint(
        '[SyncEngine] _startWatch() — stream listener attached, '
        'waiting for server...',
      );
    } catch (e, st) {
      _log('Failed to open watch stream: $e', stackTrace: st);
      debugPrint('[SyncEngine] _startWatch() FAILED: $e');
      if (_running) status.value = SyncStatus.disconnected;
      _scheduleReconnect();
    }
  }

  Future<void> _onDelta(SyncDelta delta) async {
    try {
      // First delta confirms the connection is truly alive — reset backoff.
      if (_reconnectAttempts > 0) {
        debugPrint(
          '[SyncEngine] Connection confirmed by delta — '
          'resetting reconnect attempts (was $_reconnectAttempts)',
        );
        _reconnectAttempts = 0;
      }
      if (_running) {
        if (status.value == SyncStatus.disconnected) {
          debugPrint(
            '[SyncEngine] Watch stream connected — first delta received',
          );
        }
        if (status.value != SyncStatus.pulling) {
          status.value = SyncStatus.pulling;
        }
      }
      await _deltaWriter.apply(delta);

      final seq = delta.seq.toInt();
      if (seq > _lastSeq) {
        _lastSeq = seq;
      }

      // When the DeltaWriter just flushed its buffer (bufferIsEmpty == true
      // after apply()), persist the lastSeq so a restart resumes correctly.
      if (_deltaWriter.bufferIsEmpty) {
        await _accountsDao.updateLastSeq(_accountId, _lastSeq);
        if (_running) status.value = SyncStatus.idle;
      }
    } catch (e, st) {
      _log('Error applying delta seq=${delta.seq}: $e', stackTrace: st);
      // Continue listening — one bad delta should not kill the stream.
    }
  }

  void _onWatchError(Object error) {
    _log('Watch stream error: $error');
    debugPrint('[SyncEngine] Watch stream error: $error');

    if (error is GrpcError) {
      debugPrint('[SyncEngine] ── GrpcError details ──');
      debugPrint(
        '[SyncEngine]   code       : ${error.code} (${error.codeName})',
      );
      debugPrint('[SyncEngine]   message    : ${error.message}');
      debugPrint('[SyncEngine]   details    : ${error.details}');
      debugPrint('[SyncEngine]   trailers   : ${error.trailers}');
      debugPrint(
        '[SyncEngine]   rawResponse: ${error.rawResponse} '
        '(${error.rawResponse.runtimeType})',
      );
      final rawBytes = error.rawResponse is List<int>
          ? error.rawResponse! as List<int>
          : null;
      if (rawBytes != null) {
        debugPrint('[SyncEngine]   rawResponse length: ${rawBytes.length}');
        debugPrint(
          '[SyncEngine]   rawResponse hex (first 256 bytes): '
          '${rawBytes.take(256).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        // Try interpreting as UTF-8 text in case server sent an error page
        try {
          final text = utf8.decode(rawBytes, allowMalformed: true);
          debugPrint(
            '[SyncEngine]   rawResponse as text (first 512 chars): '
            '${text.length > 512 ? text.substring(0, 512) : text}',
          );
        } catch (_) {}
      }

      // For DATA_LOSS specifically, try a manual deserialization test to get
      // a better error message from protobuf.
      if (error.code == StatusCode.dataLoss && rawBytes != null) {
        debugPrint('[SyncEngine] ── DATA_LOSS manual proto parse attempt ──');
        try {
          final delta = sync_pb.SyncDelta.fromBuffer(rawBytes);
          debugPrint(
            '[SyncEngine]   Surprisingly succeeded! '
            'seq=${delta.seq}, table=${delta.table}, op=${delta.operation}, '
            'rowKey=${delta.rowKey}, hasData=${delta.hasData()}',
          );
        } catch (parseError, parseSt) {
          debugPrint('[SyncEngine]   Proto parse error: $parseError');
          debugPrint('[SyncEngine]   Proto parse stack: $parseSt');
        }
      }
      debugPrint('[SyncEngine] ── end GrpcError details ──');

      if (error.code == StatusCode.unauthenticated) {
        _log('Unauthenticated — stopping sync for token refresh');
        debugPrint('[SyncEngine] Watch: UNAUTHENTICATED — stopping sync');
        stop();
        return;
      }
    }

    // For any other error, schedule a reconnection attempt.
    debugPrint('[SyncEngine] Watch error — will reconnect');
    _watchSubscription?.cancel();
    _watchSubscription = null;
    if (_running) status.value = SyncStatus.disconnected;
    _scheduleReconnect();
  }

  void _onWatchDone() {
    _log('Watch stream completed');
    debugPrint('[SyncEngine] Watch stream completed (onDone)');
    _watchSubscription = null;

    if (_running) {
      debugPrint('[SyncEngine] Watch ended while running — will reconnect');
      status.value = SyncStatus.disconnected;
      _scheduleReconnect();
    }
  }

  // =========================================================================
  // Reconnection — exponential backoff
  // =========================================================================

  void _scheduleReconnect() {
    if (!_running) return;

    final delay = _reconnectDelay();
    _reconnectAttempts++;

    _log(
      'Scheduling reconnect in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempts)',
    );
    debugPrint(
      '[SyncEngine] Reconnect scheduled in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_running) {
        debugPrint('[SyncEngine] Reconnect timer fired — reopening watch...');
        _watchSubscription?.cancel();
        _watchSubscription = null;
        _runGuarded(_startWatch);
      }
    });
  }

  Duration _reconnectDelay() {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
    final seconds = (1 << _reconnectAttempts).clamp(
      1,
      _maxReconnectDelay.inSeconds,
    );
    return Duration(seconds: seconds);
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  /// Builds [CallOptions] with the current access token as a Bearer
  /// authorization header.
  CallOptions _callOptions() {
    final truncated = _accessToken.length > 20
        ? '${_accessToken.substring(0, 20)}…(${_accessToken.length} chars)'
        : _accessToken.isEmpty
        ? '<EMPTY>'
        : _accessToken;
    debugPrint('[SyncEngine] _callOptions() — token: $truncated');
    return CallOptions(metadata: {'authorization': 'Bearer $_accessToken'});
  }

  /// Internal logging — uses `dart:developer` log so it appears in DevTools
  /// and can be filtered by the 'SyncEngine' name.
  void _log(String message, {StackTrace? stackTrace}) {
    dev.log(
      message,
      name: 'SyncEngine',
      error: stackTrace != null ? message : null,
      stackTrace: stackTrace,
    );
  }
}
