import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';

part 'logs_dao.g.dart';

/// DAO for the client-only [Logs] table — the offline mutation queue.
///
/// Every local write to a synced backend table produces one or more rows in
/// the `logs` table. The sync engine reads these rows and replays them to the
/// server in order. Successfully synced rows are DELETED; they are never
/// marked as "synced".
///
/// See AGENT.md §7 for the full specification of the logs table and the
/// bitset/collapse/supersede semantics.
@DriftAccessor(tables: [Logs])
class LogsDao extends DatabaseAccessor<AppDatabase> with _$LogsDaoMixin {
  LogsDao(super.db);

  // ---------------------------------------------------------------------------
  // Writes — enqueueing mutations
  // ---------------------------------------------------------------------------

  /// Appends a new log entry to the queue.
  ///
  /// The caller is responsible for building the correct [LogsCompanion],
  /// including:
  /// - [LogsCompanion.tbl] — which synced table was mutated
  /// - [LogsCompanion.op]  — Insert, Update, or Delete
  /// - [LogsCompanion.rowKey] — "|"-delimited PK values
  /// - [LogsCompanion.columns] — bitmask of changed columns (Update only; null otherwise)
  /// - [LogsCompanion.created] — milliseconds since epoch
  Future<void> insertLog(LogsCompanion log) {
    return into(logs).insert(log);
  }

  // ---------------------------------------------------------------------------
  // Reads — sync engine consumption
  // ---------------------------------------------------------------------------

  /// Returns all [LogStatus.pending] entries for [accountId], oldest first.
  ///
  /// The sync engine processes these in ascending [id] order to preserve
  /// mutation ordering.
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

  /// Returns all [LogStatus.failed] entries for [accountId].
  ///
  /// Failed entries are kept in the queue until the sync engine decides to
  /// retry or abandon them based on the server error type (see AGENT.md §7).
  Future<List<LogsData>> getFailedLogs(String accountId) {
    return (select(logs)..where(
          (t) =>
              t.account.equals(accountId) &
              t.status.equalsValue(LogStatus.failed),
        ))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Deletes — after successful sync
  // ---------------------------------------------------------------------------

  /// Deletes a single log entry by [id] after it has been successfully
  /// replayed to the server.
  Future<void> deleteLog(int id) {
    return (delete(logs)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes multiple log entries by their [ids] in a single statement.
  ///
  /// Used when the sync engine batches multiple entries into a single server
  /// call and wants to clean them all up at once.
  Future<void> deleteLogs(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(logs)..where((t) => t.id.isIn(ids))).go();
  }

  // ---------------------------------------------------------------------------
  // Error tracking
  // ---------------------------------------------------------------------------

  /// Marks a log entry as [LogStatus.failed] and records the [error] message.
  ///
  /// Also increments the [LogsData.attempts] counter atomically via a raw SQL
  /// UPDATE so no read-modify-write race is possible.
  Future<void> markFailed(int id, String error) {
    return customStatement(
      'UPDATE logs SET status = ?, error = ?, attempts = attempts + 1 WHERE id = ?',
      [LogStatus.failed.index, error, id],
    );
  }

  // ---------------------------------------------------------------------------
  // Collapse / supersede — sync engine optimisation
  // ---------------------------------------------------------------------------

  /// Collapses multiple UPDATE log entries for the same `(tbl, rowKey)` into
  /// one entry by OR-ing all of their [LogsData.columns] bitmasks together.
  ///
  /// After this call, exactly one UPDATE entry remains for the given
  /// `(tbl, rowKey)` pair, carrying the union of all changed-column bitmasks.
  /// The sync engine can then read only the current DB values for those columns
  /// and push a single update to the server.
  ///
  /// [tbl] is the [LogTable] enum value identifying the mutated table.
  ///
  /// No-op if zero or one matching entry exists.
  Future<void> collapseUpdateLogs(
    String accountId,
    LogTable tbl,
    String rowKey,
  ) {
    return transaction(() async {
      final matching =
          await (select(logs)
                ..where(
                  (t) =>
                      t.account.equals(accountId) &
                      t.tbl.equalsValue(tbl) &
                      t.rowKey.equals(rowKey) &
                      t.op.equalsValue(LogOperation.update),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();

      if (matching.length <= 1) return; // nothing to collapse

      // OR all bitmasks; null bitmasks are treated as 0.
      int combined = 0;
      for (final entry in matching) {
        if (entry.columns != null) combined |= entry.columns!;
      }

      final keepId = matching.first.id;
      final deleteIds = matching.skip(1).map((e) => e.id).toList();

      // Write the merged bitmask onto the surviving row.
      await (update(logs)..where((t) => t.id.equals(keepId))).write(
        LogsCompanion(columns: Value(combined)),
      );

      // Remove the duplicate rows.
      await (delete(logs)..where((t) => t.id.isIn(deleteIds))).go();
    });
  }

  /// Supersedes all Insert and Update log entries for a given `(tbl, rowKey)`
  /// when a Delete entry exists for the same row.
  ///
  /// A Delete log means the row will be removed from the server, so any prior
  /// Insert or Update entries for that row are no longer meaningful. Only the
  /// Delete entry is kept.
  ///
  /// [tbl] is the [LogTable] enum value identifying the mutated table.
  ///
  /// Must be called **after** the Delete log entry has been inserted so that
  /// the Delete row itself is preserved.
  Future<void> supersedWithDelete(
    String accountId,
    LogTable tbl,
    String rowKey,
  ) {
    return (delete(logs)..where(
          (t) =>
              t.account.equals(accountId) &
              t.tbl.equalsValue(tbl) &
              t.rowKey.equals(rowKey) &
              (t.op.equalsValue(LogOperation.insert) |
                  t.op.equalsValue(LogOperation.update)),
        ))
        .go();
  }
}
