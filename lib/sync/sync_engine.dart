import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../database/database.dart';
import '../database/daos/accounts_dao.dart';
import '../database/daos/exams_grades_dao.dart';
import '../database/daos/logs_dao.dart';
import '../proto/services/sync.pb.dart' as sync_pb;
import '../proto/services/sync.pbgrpc.dart';
import '../cache/file_cache.dart';
import '../database/tables/enums.dart';
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

/// Random instance for adding jitter to backoff delays.
final _random = Random();

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
/// - **Reconnection:** Exponential backoff with jitter on watch stream errors,
///   up to [_maxReconnectDelay].
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

  /// Timer that flushes the DeltaWriter buffer after a short idle period.
  /// This ensures that small batches (< [DeltaWriter._batchSize]) are written
  /// to SQLite promptly rather than sitting in memory indefinitely.
  Timer? _flushTimer;

  // ── Push (outbound) state ────────────────────────────────────────────────
  /// Safety-net timer that calls [pushNow] periodically to catch any
  /// mutations that were not pushed immediately (e.g. due to transient errors).
  /// The interval increases when push fails (server unreachable) and resets
  /// to [_basePushInterval] on success.
  Timer? _pushTimer;

  /// Base push interval when connected.
  static const _basePushInterval = Duration(seconds: 5);

  /// Maximum push interval when server is unreachable.
  static const _maxPushInterval = Duration(seconds: 60);

  /// Current push interval — increases on failure, resets on success.
  Duration _currentPushInterval = _basePushInterval;

  // ── Session state ────────────────────────────────────────────────────────
  bool _running = false;
  int _lastSeq = 0;
  String _accountId = '';
  String _accessToken = '';

  /// Callback invoked when the server returns [StatusCode.unauthenticated].
  /// Set by `client.dart` to trigger token refresh and sync restart.
  VoidCallback? onUnauthenticated;

  // ── Push throttle ────────────────────────────────────────────────────────
  bool _pushing = false;
  bool _pushScheduled = false;

  // ── Reconnection state ───────────────────────────────────────────────────
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectDelay = Duration(seconds: 30);

  /// Tracks when the last delta was received from the watch stream.
  /// Used by [revive] to detect silently dead streams on Android: the OS
  /// kills the TCP socket when the app is backgrounded but no stream error
  /// is delivered, so [_watchDead] stays `false`. A staleness check against
  /// this timestamp lets us detect and force-reconnect in that situation.
  DateTime _lastDeltaReceivedAt = DateTime.now();

  /// How long the watch stream can go without a delta before [revive]
  /// considers it silently dead (Android background socket kill).
  static const _watchStalenessThreshold = Duration(seconds: 45);

  /// Guard flag to prevent [_onWatchDone] from scheduling a redundant
  /// reconnect when [_onWatchError] has already handled the failure.
  /// Set to `true` by [_onWatchError] before it cancels the subscription
  /// (which triggers [_onWatchDone]). Reset to `false` by [_onWatchDone]
  /// after checking it.
  bool _errorHandledReconnect = false;

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
  /// 3. A periodic timer pushes pending mutations as a safety net.
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
    _reconnectAttempts = 0;
    _errorHandledReconnect = false;
    _currentPushInterval = _basePushInterval;

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

    // Periodic push safety net.
    _startPushTimer();
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

    _flushTimer?.cancel();
    _flushTimer = null;

    _errorHandledReconnect = false;

    // Flush any remaining buffered deltas before tearing down the stream.
    if (!_deltaWriter.bufferIsEmpty) {
      debugPrint('[SyncEngine] stop: flushing remaining buffered deltas');
      await _deltaWriter.flush();
      await _accountsDao.updateLastSeq(_accountId, _lastSeq);
    }

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
      debugPrint('[SyncEngine] pushNow — sending ${pending.length} action(s)');

      status.value = SyncStatus.pushing;

      await _pushActions(pending);

      // Push succeeded — reset push interval to base.
      _resetPushInterval();

      if (_running) status.value = SyncStatus.idle;
      return true;
    } catch (e, st) {
      // Offline or unexpected error — actions stay in logs table, will
      // retry on the next pushNow() call or periodic timer tick.
      _log('pushNow error: $e', stackTrace: st);
      debugPrint('[SyncEngine] pushNow error: $e');

      // Back off the push timer since the server is likely unreachable.
      _backOffPushInterval();

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

    // If the watch stream appears alive, check for staleness. On Android,
    // the OS silently kills the TCP socket when the app is backgrounded but
    // no gRPC stream error is delivered — _watchDead stays false. We use
    // _lastDeltaReceivedAt to detect this: if no delta has arrived for
    // longer than _watchStalenessThreshold, the stream is assumed dead.
    if (!_watchDead) {
      final staleDuration = DateTime.now().difference(_lastDeltaReceivedAt);
      if (staleDuration > _watchStalenessThreshold) {
        debugPrint(
          '[SyncEngine] revive() — watch appears alive but stale '
          '(${staleDuration.inSeconds}s since last delta), forcing reconnect',
        );
        // Force-kill the existing stream and fall through to reconnect.
        _watchSubscription?.cancel();
        _watchSubscription = null;
        // _watchDead is now true (subscription is null), so the reconnect
        // logic below will execute.
      } else {
        debugPrint(
          '[SyncEngine] revive() — watch alive and fresh '
          '(${staleDuration.inSeconds}s since last delta), triggering push only',
        );
        pushNow();
        return;
      }
    }

    debugPrint(
      '[SyncEngine] revive() — watch dead, resetting backoff and '
      'reconnecting immediately',
    );

    // Cancel any pending reconnect timer — we're taking over.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _errorHandledReconnect = false;

    // Reset push interval and restart the periodic push safety-net timer.
    // On mobile the OS may have killed the previous Timer.periodic while
    // the app was suspended, so it would never fire again even though
    // _running is still true.
    _currentPushInterval = _basePushInterval;
    _startPushTimer();

    // Reopen the watch stream immediately.
    _watchSubscription?.cancel();
    _watchSubscription = null;
    _runGuarded(_startWatch);

    // Also push any pending mutations right away.
    pushNow();
  }

  // =========================================================================
  // Push timer management
  // =========================================================================

  /// Starts (or restarts) the periodic push timer with [_currentPushInterval].
  void _startPushTimer() {
    _pushTimer?.cancel();
    _pushTimer = Timer.periodic(_currentPushInterval, (_) => pushNow());
  }

  /// Resets the push interval back to [_basePushInterval] and restarts the
  /// timer. Called when a push succeeds or a watch delta confirms connectivity.
  void _resetPushInterval() {
    if (_currentPushInterval != _basePushInterval) {
      debugPrint(
        '[SyncEngine] Push interval reset to '
        '${_basePushInterval.inSeconds}s (was ${_currentPushInterval.inSeconds}s)',
      );
      _currentPushInterval = _basePushInterval;
      if (_running) _startPushTimer();
    }
  }

  /// Doubles the push interval (up to [_maxPushInterval]) and restarts the
  /// timer. Called when a push fails due to the server being unreachable.
  void _backOffPushInterval() {
    final next = Duration(
      milliseconds: min(
        (_currentPushInterval.inMilliseconds * 2),
        _maxPushInterval.inMilliseconds,
      ),
    );
    if (next != _currentPushInterval) {
      debugPrint(
        '[SyncEngine] Push interval backed off to '
        '${next.inSeconds}s (was ${_currentPushInterval.inSeconds}s)',
      );
      _currentPushInterval = next;
      if (_running) _startPushTimer();
    }
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
    requestController.add(
      sync_pb.ActionRequest(
        id: first.id,
        action: first.action.value,
        payload: first.payload,
      ),
    );
    debugPrint(
      '[SyncEngine] Sent action #${first.id} '
      '(${first.action.name}, 1/${pending.length})',
    );

    // Build a lookup from log ID → SyncAction so _processActionResponse can
    // distinguish delete actions from update actions (needed for error code 4).
    final actionByLogId = {for (final log in pending) log.id: log.action};

    int nextIndex = 1;

    try {
      await for (final response in responseStream) {
        if (!_running) {
          debugPrint('[SyncEngine] Push aborted — engine stopped');
          break;
        }

        await _processActionResponse(response, actionByLogId[response.id]);

        // Send the next action if there are more.
        if (nextIndex < pending.length) {
          final next = pending[nextIndex];
          requestController.add(
            sync_pb.ActionRequest(
              id: next.id,
              action: next.action.value,
              payload: next.payload,
            ),
          );
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
        debugPrint('[SyncEngine]   code       : ${e.code} (${e.codeName})');
        debugPrint('[SyncEngine]   message    : ${e.message}');
        debugPrint('[SyncEngine]   details    : ${e.details}');
        debugPrint('[SyncEngine]   trailers   : ${e.trailers}');
        debugPrint('[SyncEngine] ── end Push GrpcError details ──');

        if (e.code == StatusCode.unauthenticated) {
          _log('Unauthenticated on push — stopping sync');
          await stop();
          onUnauthenticated?.call();
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
  /// [action] is the [SyncAction] from the log entry that triggered this
  /// response. Used to distinguish delete actions from update actions when
  /// handling error code 4 (not_found).
  ///
  /// Error codes:
  /// - 0: ok — delete log, apply returned rows.
  /// - 1: permission_denied — mark failed, show in notifications.
  /// - 2: conflict — apply server version, delete log.
  /// - 3: validation_error — mark failed, user must fix.
  /// - 4: not_found — delete log for deletes, mark failed for others.
  Future<void> _processActionResponse(
    sync_pb.ActionResponse response,
    SyncAction? action,
  ) async {
    final logId = response.id;

    try {
      if (response.success) {
        _log('Action $logId succeeded');
        debugPrint('[SyncEngine] Action #$logId — success');
        debugPrint(
          '[SyncEngine] Action #$logId — fileUrls count: ${response.fileUrls.length}',
        );

        // Apply any returned rows to the local DB (server may have set
        // timestamps, resolved conflicts, or created related records).
        for (final row in response.rows) {
          await _applyActionRow(row);
        }

        // Upload local files to S3 if the server provided PUT URLs.
        // Do this BEFORE deleting the log so a failed upload can be retried.
        if (response.fileUrls.isNotEmpty) {
          final uploadOk = await _handleFileUrlsWithResult(
            response.fileUrls,
            isPushOriginator: true,
          );
          if (!uploadOk) {
            debugPrint(
              '[SyncEngine] Action #$logId — file upload failed, '
              'marking log as failed for retry',
            );
            await _logsDao.markFailed(
              logId,
              'File upload to S3 failed — will retry',
            );
            return; // Don't delete the log — it will be retried
          }
        }

        // Delete the log entry — it has been successfully synced
        // AND files uploaded.
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
            if (response.fileUrls.isNotEmpty) {
              await _handleFileUrls(response.fileUrls, isPushOriginator: true);
            }
            await _logsDao.deleteLog(logId);

          case 3: // validation_error
            _log('Action $logId: validation error — $errorMsg');
            debugPrint(
              '[SyncEngine] Action #$logId — validation error: $errorMsg',
            );
            await _logsDao.markFailed(logId, errorMsg);

          case 4: // not_found
            if (action != null && _isDeleteAction(action)) {
              _log(
                'Action $logId: delete target already gone — '
                'treating as success',
              );
              debugPrint(
                '[SyncEngine] Action #$logId — not found but is a delete '
                'action (${action.name}) — deleting log',
              );
              await _logsDao.deleteLog(logId);
            } else {
              _log('Action $logId: not found — $errorMsg');
              debugPrint('[SyncEngine] Action #$logId — not found: $errorMsg');
              await _logsDao.markFailed(logId, errorMsg);
            }

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

  /// Returns `true` if [action] is a delete/remove/unassign action — i.e. the
  /// resource being acted on is expected to no longer exist after the action.
  /// Used by error code 4 (not_found) handling: if the target is already gone
  /// server-side, a delete action is effectively a success.
  bool _isDeleteAction(SyncAction action) => switch (action) {
    SyncAction.deleteSchool ||
    SyncAction.deleteTeacher ||
    SyncAction.deleteStaff ||
    SyncAction.deleteOwner ||
    SyncAction.deleteStudent ||
    SyncAction.deleteGuardian ||
    SyncAction.deleteDepartment ||
    SyncAction.deleteTerm ||
    SyncAction.deleteTimetableEntry ||
    SyncAction.deleteAttendance ||
    SyncAction.deleteLesson ||
    SyncAction.deleteExam ||
    SyncAction.deletePaper ||
    SyncAction.deleteGrade ||
    SyncAction.deleteFee ||
    SyncAction.deleteInvoice ||
    SyncAction.deletePayment ||
    SyncAction.deleteAnnouncement ||
    SyncAction.deleteRole ||
    SyncAction.deleteUser ||
    SyncAction.deletePlan ||
    SyncAction.deleteSubscription ||
    SyncAction.deleteDiscount ||
    SyncAction.deleteSubject ||
    SyncAction.deleteTopic ||
    SyncAction.deleteStream ||
    SyncAction.deleteMpesa ||
    SyncAction.unenrollStudent ||
    SyncAction.unassignClassTeacher ||
    SyncAction.unassignSubject ||
    SyncAction.unassignRole => true,
    _ => false,
  };

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

  /// Handles [FileUrl] entries from either an [ActionResponse] or a [SyncDelta].
  ///
  /// - If [isPushOriginator] is `true`: this device performed the action and
  ///   already has the file locally. For each URL that has a non-empty [putUrl],
  ///   upload the local file to S3. Skip entries with empty [putUrl].
  ///
  /// - If [isPushOriginator] is `false` (watch stream delta): this device is a
  ///   watcher. For each URL that has a non-empty [getUrl], download the file
  ///   from S3 into the local cache. Skip entries with empty [getUrl].
  ///
  /// Errors in individual file operations are logged but do not throw —
  /// a failed upload/download should not abort the sync engine.
  Future<void> _handleFileUrls(
    List<sync_pb.FileUrl> fileUrls, {
    required bool isPushOriginator,
  }) async {
    debugPrint(
      '[FileSync] _handleFileUrls — ${fileUrls.length} url(s), isPushOriginator=$isPushOriginator',
    );
    for (final fileUrl in fileUrls) {
      final path = fileUrl.path;
      if (path.isEmpty) continue;

      debugPrint(
        '[FileSync]   entry: path="${fileUrl.path}", hasPutUrl=${fileUrl.putUrl.isNotEmpty}, hasGetUrl=${fileUrl.getUrl.isNotEmpty}',
      );
      if (isPushOriginator) {
        final putUrl = fileUrl.putUrl;
        if (putUrl.isEmpty) continue;

        // Skip upload if the local file doesn't exist.
        final localFile = await FileCache.get(path);
        if (localFile == null) {
          debugPrint('[FileSync] Skipping upload — local file not found: path=$path');
          continue;
        }

        debugPrint('[SyncEngine] Uploading file: path=$path');
        final ok = await FileCache.upload(putUrl, path);
        debugPrint('[FileSync] Upload result: ok=$ok, path=$path');
      } else {
        final getUrl = fileUrl.getUrl;
        if (getUrl.isEmpty) continue;
        debugPrint('[SyncEngine] Downloading file: path=$path');
        final file = await FileCache.download(getUrl, path);
        debugPrint(
          '[FileSync] Download result: file=${file?.path ?? "NULL"}, path=$path',
        );
      }
    }
  }

  /// Like [_handleFileUrls] but returns `false` if any upload/download failed.
  Future<bool> _handleFileUrlsWithResult(
    List<sync_pb.FileUrl> fileUrls, {
    required bool isPushOriginator,
  }) async {
    bool allOk = true;
    for (final fileUrl in fileUrls) {
      final path = fileUrl.path;
      if (path.isEmpty) continue;

      if (isPushOriginator) {
        final putUrl = fileUrl.putUrl;
        if (putUrl.isEmpty) continue;

        // Skip upload if the local file doesn't exist (e.g. cache cleared,
        // or a non-image UPDATE_USER action that included file URLs).
        final localFile = await FileCache.get(path);
        if (localFile == null) {
          debugPrint('[FileSync] Skipping upload — local file not found: path=$path');
          continue;
        }

        debugPrint('[SyncEngine] Uploading file: path=$path');
        final ok = await FileCache.upload(putUrl, path);
        debugPrint('[FileSync] Upload result: ok=$ok, path=$path');
        if (!ok) allOk = false;
      } else {
        final getUrl = fileUrl.getUrl;
        if (getUrl.isEmpty) continue;
        debugPrint('[SyncEngine] Downloading file: path=$path');
        final file = await FileCache.download(getUrl, path);
        debugPrint(
          '[FileSync] Download result: file=${file?.path ?? "NULL"}, path=$path',
        );
        if (file == null) allOk = false;
      }
    }
    return allOk;
  }

  // =========================================================================
  // Watch (inbound) — server-streaming
  // =========================================================================

  void _startWatch() {
    if (!_running) return;

    // Mark the stream as "just opened" so that revive() doesn't immediately
    // consider it stale before the server has had a chance to send a delta.
    _lastDeltaReceivedAt = DateTime.now();

    try {
      _log('Opening watch stream from seq=$_lastSeq');
      debugPrint(
        '[SyncEngine] _startWatch() — opening watch stream, lastSeq=$_lastSeq',
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
        (List<int> rawBytes) async {
          try {
            final delta = sync_pb.SyncDelta.fromBuffer(rawBytes);
            await _onDelta(delta);
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
      // Record when we last received a delta — used by revive() to detect
      // silently dead streams on Android (see _watchStalenessThreshold).
      _lastDeltaReceivedAt = DateTime.now();

      // First delta confirms the connection is truly alive — reset backoff
      // for both watch reconnect and push timer.
      if (_reconnectAttempts > 0) {
        debugPrint(
          '[SyncEngine] Connection confirmed by delta — '
          'resetting reconnect attempts (was $_reconnectAttempts)',
        );
        _reconnectAttempts = 0;
      }
      _resetPushInterval();

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
      debugPrint(
        '[SyncEngine] ← delta seq=${delta.seq}, '
        'table=${delta.table}, op=${delta.operation}, '
        'key=${delta.rowKey}, hasData=${delta.hasData()}, fileUrls=${delta.fileUrls.length}',
      );

      final seq = delta.seq.toInt();

      // The server sends a sentinel delta (table=0, hasData=false) at the
      // end of the historical backfill to communicate the current head seq.
      // Don't buffer it — just flush any pending deltas and record the seq.
      if (delta.table == 0) {
        // IMPORTANT: _lastSeq is ONLY advanced on sentinel deltas (table=0).
        // This prevents permanent data loss when a connection drops mid-backfill.
        // Regular deltas and flushes must NOT advance or persist the cursor.
        // Worst case: on reconnect, the server resends some already-processed
        // deltas — the client handles duplicates via insertOnConflictUpdate.
        debugPrint('[SyncEngine] Received end-of-backfill sentinel (seq=$seq)');
        if (seq > _lastSeq) _lastSeq = seq;
        _flushTimer?.cancel();
        _flushTimer = null;
        if (!_deltaWriter.bufferIsEmpty) {
          debugPrint('[SyncEngine] Flushing buffered deltas after sentinel');
          await _deltaWriter.flush();
        }
        await _accountsDao.updateLastSeq(_accountId, _lastSeq);
        debugPrint('[SyncEngine] Persisted lastSeq=$_lastSeq after sentinel');
        if (_running) status.value = SyncStatus.idle;
        return;
      }

      await _deltaWriter.apply(delta);

      // Download files from S3 if the server provided GET URLs.
      if (delta.fileUrls.isNotEmpty) {
        // For answer_pages (table 37), skip file downloads and paper_submissions
        // insertion if there are pending local mutations for the same student/paper.
        // This prevents the watch-stream echo from resurrecting files that the
        // user just deleted or replaced locally.
        bool skipAnswerPageFiles = false;
        if (delta.table == 37) {
          skipAnswerPageFiles = await _hasPendingAnswerMutation(delta);
        }

        if (!skipAnswerPageFiles) {
          await _handleFileUrls(delta.fileUrls, isPushOriginator: false);
        }

        if (delta.table == 37 && delta.operation != 2 && !skipAnswerPageFiles) {
          await _insertAnswerSubmissions(delta);
        }

        // When an answer_pages DELETE delta arrives, clean up the
        // corresponding paper_submissions rows and files from disk.
        if (delta.table == 37 && delta.operation == 2) {
          await _cleanupDeletedAnswerSubmissions(delta);
        }
      }

      // NOTE: _lastSeq is NOT advanced here — only sentinel deltas (table=0)
      // advance and persist the cursor. This prevents data loss if the
      // connection drops mid-backfill. Duplicates on reconnect are harmless
      // (insertOnConflictUpdate).

      // When the DeltaWriter just flushed its buffer (bufferIsEmpty == true
      // after apply()), transition to idle. Cursor is NOT persisted here —
      // only sentinels persist the cursor.
      if (_deltaWriter.bufferIsEmpty) {
        if (_running) status.value = SyncStatus.idle;
        _flushTimer?.cancel();
        _flushTimer = null;
      } else {
        // Buffer is not full yet — schedule a flush so small batches
        // (fewer than _batchSize deltas) don't sit in memory forever.
        // Each new delta resets the timer so rapid-fire deltas during
        // initial sync are still batched efficiently.
        _flushTimer?.cancel();
        _flushTimer = Timer(const Duration(milliseconds: 500), () async {
          if (!_running) return;
          try {
            debugPrint(
              '[SyncEngine] Flush timer fired — flushing '
              '${_deltaWriter.bufferIsEmpty ? 0 : "remaining"} buffered deltas',
            );
            await _deltaWriter.flush();
            // Cursor is NOT persisted here — only sentinels persist the cursor.
            if (_running) status.value = SyncStatus.idle;
          } catch (e, st) {
            _log('Flush timer error: $e', stackTrace: st);
            debugPrint('[SyncEngine] Flush timer error: $e');
          }
        });
      }
    } catch (e, st) {
      _log('Error applying delta seq=${delta.seq}: $e', stackTrace: st);
      // Continue listening — one bad delta should not kill the stream.
    }
  }

  /// After downloading answer sheet files from the watch stream, insert
  /// [PaperSubmissions] rows so the existing UI can find them via DAO queries.
  ///
  /// For scheme files (table 36) no hook is needed — the UI uses filesystem
  /// directory listing ([_loadSchemeFiles]) and the files land at predictable
  /// paths automatically.
  Future<void> _insertAnswerSubmissions(sync_pb.SyncDelta delta) async {
    try {
      final k = delta.rowKey.split('|');
      // rowKey: "{school}|{exam}|{student}|{subject}|{paper}|{page}"
      if (k.length < 6) return;

      final schoolId = k[0];
      final examId = k[1];
      final student = int.tryParse(k[2]) ?? 0;
      final subject = int.tryParse(k[3]) ?? 0;
      final paper = k[4].isEmpty ? null : int.tryParse(k[4]);

      final examsGradesDao = ExamsGradesDao(db);

      for (final fileUrl in delta.fileUrls) {
        if (fileUrl.path.isEmpty) continue;

        // Resolve relative path to absolute path for paper_submissions storage.
        final base = await FileCache.baseDir();
        final absPath = '$base/${fileUrl.path}';

        // Only insert if the file was actually downloaded successfully.
        final file = File(absPath);
        if (!file.existsSync()) continue;

        await examsGradesDao.insertSubmission(
          schoolId: schoolId,
          examId: examId,
          student: student,
          subject: subject,
          paperNum: paper,
          path: absPath,
        );
      }
    } catch (e) {
      debugPrint('[SyncEngine] Error inserting answer submissions: $e');
    }
  }

  /// Returns `true` if there is a pending [uploadAnswerSheet] or
  /// [deleteAnswerSheet] log entry that targets the same
  /// (school, exam, student, subject) as [delta].
  ///
  /// When the user modifies answer files locally, log entries are written
  /// *before* the push happens. If a watch-stream delta for the same entity
  /// arrives in the meantime (echo from a prior push, or a stale broadcast),
  /// we must not overwrite the user's local changes.
  Future<bool> _hasPendingAnswerMutation(sync_pb.SyncDelta delta) async {
    try {
      final k = delta.rowKey.split('|');
      if (k.length < 4) return false;
      final school = k[0];
      final exam = k[1];
      final student = int.tryParse(k[2]) ?? 0;
      final subject = int.tryParse(k[3]) ?? 0;

      final pending = await _logsDao.getPendingLogs(_accountId);
      for (final log in pending) {
        if (log.action != SyncAction.uploadAnswerSheet &&
            log.action != SyncAction.deleteAnswerSheet) {
          continue;
        }
        try {
          if (log.action == SyncAction.uploadAnswerSheet) {
            final p = sync_pb.UploadAnswerSheetPayload.fromBuffer(log.payload);
            if (p.school == school &&
                p.exam == exam &&
                p.student == student &&
                p.subject == subject) {
              debugPrint(
                '[SyncEngine] Skipping answer_pages delta — pending '
                'uploadAnswerSheet log #${log.id} for same entity',
              );
              return true;
            }
          } else {
            final p = sync_pb.DeleteAnswerSheetPayload.fromBuffer(log.payload);
            if (p.school == school &&
                p.exam == exam &&
                p.student == student &&
                p.subject == subject) {
              debugPrint(
                '[SyncEngine] Skipping answer_pages delta — pending '
                'deleteAnswerSheet log #${log.id} for same entity',
              );
              return true;
            }
          }
        } catch (_) {
          // Malformed payload — skip
        }
      }
      return false;
    } catch (e) {
      debugPrint('[SyncEngine] Error checking pending answer mutations: $e');
      return false;
    }
  }

  /// Cleans up [PaperSubmissions] rows and local files when the server
  /// broadcasts a DELETE for answer_pages (table 37, operation 2).
  Future<void> _cleanupDeletedAnswerSubmissions(sync_pb.SyncDelta delta) async {
    try {
      final k = delta.rowKey.split('|');
      if (k.length < 5) return;

      final schoolId = k[0];
      final examId = k[1];
      final student = int.tryParse(k[2]) ?? 0;
      final subject = int.tryParse(k[3]) ?? 0;
      final paper = k[4].isEmpty ? null : int.tryParse(k[4]);

      // Don't clean up if there are pending local mutations — the user
      // may have re-added files after the delete.
      if (await _hasPendingAnswerMutation(delta)) return;

      final examsGradesDao = ExamsGradesDao(db);
      await examsGradesDao.clearSubmissionsForStudent(
        schoolId: schoolId,
        examId: examId,
        student: student,
        subject: subject,
        paperNum: paper,
      );

      // Also delete local files for this student's answer pages.
      try {
        final base = await FileCache.baseDir();
        final dirPath = FileCache.answerDir(
          schoolId,
          examId,
          subject,
          paper ?? 0,
          student,
        );
        final dir = Directory('$base/$dirPath');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          debugPrint('[SyncEngine] Cleaned up answer files: $dirPath');
        }
      } catch (e) {
        debugPrint('[SyncEngine] Error cleaning up answer files: $e');
      }
    } catch (e) {
      debugPrint(
        '[SyncEngine] Error cleaning up deleted answer submissions: $e',
      );
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
        _log('Unauthenticated — stopping sync');
        debugPrint('[SyncEngine] Watch: UNAUTHENTICATED — stopping sync');
        stop();
        onUnauthenticated?.call();
        return;
      }
    }

    // Mark that _onWatchError is handling the reconnect. This prevents
    // _onWatchDone (which fires after we cancel the subscription below)
    // from scheduling a redundant second reconnect that would double-
    // increment the backoff counter.
    _errorHandledReconnect = true;

    // For any other error, schedule a reconnection attempt.
    debugPrint('[SyncEngine] Watch error — will reconnect');
    _watchSubscription?.cancel();
    _watchSubscription = null;
    if (_running) status.value = SyncStatus.disconnected;
    _scheduleReconnect();
  }

  Future<void> _onWatchDone() async {
    _log('Watch stream completed');
    debugPrint('[SyncEngine] Watch stream completed (onDone)');
    _watchSubscription = null;

    // Flush any remaining buffered deltas so they are not lost when the
    // stream ends (e.g. server closes after backfill, or clean shutdown).
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_deltaWriter.bufferIsEmpty) {
      debugPrint('[SyncEngine] onDone: flushing remaining buffered deltas');
      await _deltaWriter.flush();
      // Cursor is NOT persisted here — only sentinels persist the cursor.
      // On reconnect, the server resends from the last sentinel seq, and
      // duplicates are harmless (insertOnConflictUpdate).
      debugPrint(
        '[SyncEngine] onDone: buffer flushed but cursor NOT persisted '
        '(lastSeq=$_lastSeq) — only sentinels persist the cursor',
      );
    }

    // If _onWatchError already scheduled a reconnect for this stream failure,
    // skip — otherwise we'd double-increment the backoff counter and replace
    // the timer that _onWatchError just set.
    if (_errorHandledReconnect) {
      debugPrint(
        '[SyncEngine] onDone: skipping reconnect (already handled by onError)',
      );
      _errorHandledReconnect = false;
      return;
    }

    if (_running) {
      debugPrint('[SyncEngine] Watch ended while running — will reconnect');
      status.value = SyncStatus.disconnected;
      _scheduleReconnect();
    }
  }

  // =========================================================================
  // Reconnection — exponential backoff with jitter
  // =========================================================================

  void _scheduleReconnect() {
    if (!_running) return;

    final delay = _reconnectDelay();
    _reconnectAttempts++;

    _log(
      'Scheduling reconnect in ${delay.inMilliseconds}ms '
      '(attempt $_reconnectAttempts)',
    );
    debugPrint(
      '[SyncEngine] Reconnect scheduled in ${delay.inMilliseconds}ms '
      '(attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_running) {
        debugPrint('[SyncEngine] Reconnect timer fired — reopening watch...');
        _errorHandledReconnect = false;
        _watchSubscription?.cancel();
        _watchSubscription = null;
        _runGuarded(_startWatch);
        // Push any pending mutations that accumulated while the server was
        // unreachable. Without this, actions would sit in the logs table until
        // the next _pushTimer tick (which may be up to 60s away due to backoff).
        pushNow();
      }
    });
  }

  /// Computes the reconnect delay using exponential backoff with jitter.
  ///
  /// Base delay doubles each attempt: 1s, 2s, 4s, 8s, 16s, capped at
  /// [_maxReconnectDelay] (30s). Random jitter of ±20% is applied to
  /// prevent thundering herd when multiple clients reconnect simultaneously.
  Duration _reconnectDelay() {
    final baseSeconds = (1 << _reconnectAttempts).clamp(
      1,
      _maxReconnectDelay.inSeconds,
    );
    // Apply ±20% jitter: multiply by a factor in [0.8, 1.2].
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    final ms = (baseSeconds * 1000 * jitter).round();
    return Duration(milliseconds: ms);
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
