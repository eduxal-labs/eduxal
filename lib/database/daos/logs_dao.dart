import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../../models/app_notification.dart';

part 'logs_dao.g.dart';

@DriftAccessor(tables: [Logs])
class LogsDao extends DatabaseAccessor<AppDatabase> with _$LogsDaoMixin {
  LogsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────
  // Writes — enqueueing actions
  // ─────────────────────────────────────────────────────────────────────

  /// Appends a new action log entry to the queue.
  ///
  /// The caller provides:
  /// - [LogsCompanion.action] — SyncAction enum value
  /// - [LogsCompanion.resource] — human-readable display key
  /// - [LogsCompanion.payload] — serialized proto payload bytes
  /// - [LogsCompanion.created] — milliseconds since epoch
  Future<void> insertLog(LogsCompanion log) {
    return into(logs).insert(log);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Reads — sync engine consumption
  // ─────────────────────────────────────────────────────────────────────

  /// Returns all pending entries for [accountId], oldest first.
  Future<List<LogsData>> getPendingLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.pending),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// Returns all failed entries for [accountId].
  Future<List<LogsData>> getFailedLogs(String accountId) {
    return (select(logs)..where(
          (t) =>
              t.account.equals(accountId) &
              t.status.equalsValue(LogStatus.failed),
        ))
        .get();
  }

  /// Emits all failed log entries as [AppNotification] objects,
  /// ordered by created descending, whenever the logs table changes.
  Stream<List<AppNotification>> watchFailedLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.failed),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => AppNotification(
                  logId: row.id,
                  action: row.action,
                  resource: row.resource,
                  errorMessage: row.error,
                  attempts: row.attempts,
                  occurred: DateTime.fromMillisecondsSinceEpoch(
                    row.created.toInt(),
                  ),
                ),
              )
              .toList(),
        );
  }

  /// Reactive count of failed entries for [accountId].
  Stream<int> watchFailedLogCount(String accountId) {
    final countExpr = logs.id.count();
    final query = selectOnly(logs)
      ..addColumns([countExpr])
      ..where(
        logs.account.equals(accountId) &
            logs.status.equalsValue(LogStatus.failed),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Deletes — after successful sync
  // ─────────────────────────────────────────────────────────────────────

  /// Deletes a single log entry by [id] after successful sync.
  Future<void> deleteLog(int id) {
    return (delete(logs)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes multiple log entries by their [ids].
  Future<void> deleteLogs(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(logs)..where((t) => t.id.isIn(ids))).go();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Error tracking
  // ─────────────────────────────────────────────────────────────────────

  /// Marks a log entry as failed and records the error message.
  Future<void> markFailed(int id, String error) {
    return customStatement(
      'UPDATE logs SET status = ?, error = ?, attempts = attempts + 1 WHERE id = ?',
      [LogStatus.failed.index, error, id],
    );
  }
}
