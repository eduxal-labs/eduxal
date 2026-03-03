import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/settings.dart';
import '../../models/school_config.dart';

part 'settings_dao.g.dart';

/// DAO for the [Settings] table.
///
/// Provides reactive streams and mutation methods for school-level settings,
/// including M-Pesa configuration. Local mutations write corresponding entries
/// to the [Logs] table inside the same transaction.
@DriftAccessor(tables: [Settings, Logs])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the settings row for [schoolId] whenever it changes, or `null` if
  /// no settings row exists for that school yet.
  ///
  /// Used by the school detail screen's Integrations tab to reactively display
  /// the current M-Pesa configuration state.
  Stream<Setting?> watchSettings(String schoolId) {
    return (select(
      settings,
    )..where((t) => t.school.equals(schoolId))).watchSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns the settings row for [schoolId], or `null` if none exists.
  Future<Setting?> getSettings(String schoolId) {
    return (select(
      settings,
    )..where((t) => t.school.equals(schoolId))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Sync-sourced writes
  // ---------------------------------------------------------------------------

  /// Inserts a new settings row, or replaces an existing row with the same
  /// school PK.
  ///
  /// Called by the sync engine when the server pushes a settings insert or
  /// update delta. Does **not** write a log entry.
  Future<void> upsertSettings(SettingsCompanion row) {
    return into(settings).insertOnConflictUpdate(row);
  }

  // ---------------------------------------------------------------------------
  // Local mutation writes
  // ---------------------------------------------------------------------------

  /// Updates the `mpesa` JSON column for a school's settings row and writes a
  /// log entry with the [SettingsColumn.mpesa] bitmask.
  ///
  /// If no settings row exists for [schoolId], one is created with an empty
  /// `data` JSON object and the provided [mpesaJson].
  ///
  /// [mpesaJson] is the serialized JSON string from `MpesaConfig.toJson()`,
  /// or `null` to clear/disable the M-Pesa integration.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateMpesa(
    String schoolId, {
    required String? mpesaJson,
    required String accountId,
  }) {
    return transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Check if a settings row already exists.
      final existing = await getSettings(schoolId);

      if (existing != null) {
        // Update existing row.
        await (update(settings)..where((t) => t.school.equals(schoolId))).write(
          SettingsCompanion(
            mpesa: Value(mpesaJson),
            updated: Value(nowSeconds),
          ),
        );
      } else {
        // Insert a new settings row with empty data and the mpesa config.
        await into(settings).insert(
          SettingsCompanion(
            school: Value(schoolId),
            data: const Value('{}'),
            mpesa: Value(mpesaJson),
            created: Value(nowSeconds),
            updated: Value(nowSeconds),
          ),
        );
      }

      // Build the column bitmask.
      int mask = 0;
      mask |= (1 << SettingsColumn.mpesa.bit);
      mask |= (1 << SettingsColumn.updated.bit);

      // Write a log entry.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.settings),
          op: Value(
            existing != null ? LogOperation.update : LogOperation.insert,
          ),
          rowKey: Value(schoolId),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Updates the `data` JSON column with the [SchoolConfig] for a school and
  /// writes a log entry with the [SettingsColumn.data] bitmask.
  ///
  /// If no settings row exists for [schoolId], one is created with an empty
  /// `mpesa` field and the provided config stored in `data`.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateSchoolConfig(
    String schoolId,
    SchoolConfig config, {
    required String accountId,
  }) {
    return transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final configJson = jsonEncode(config.toJson());

      // Check if a settings row already exists.
      final existing = await getSettings(schoolId);

      if (existing != null) {
        // Update existing row — merge config into the existing data JSON so
        // other data fields (e.g. future keys) are preserved.
        Map<String, dynamic> dataMap = {};
        try {
          final decoded = jsonDecode(existing.data);
          if (decoded is Map<String, dynamic>) {
            dataMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Malformed JSON — start fresh.
        }
        dataMap.addAll(config.toJson());

        await (update(settings)..where((t) => t.school.equals(schoolId))).write(
          SettingsCompanion(
            data: Value(jsonEncode(dataMap)),
            updated: Value(nowSeconds),
          ),
        );
      } else {
        // Insert a new settings row with the config in data and null mpesa.
        await into(settings).insert(
          SettingsCompanion(
            school: Value(schoolId),
            data: Value(configJson),
            mpesa: const Value(null),
            created: Value(nowSeconds),
            updated: Value(nowSeconds),
          ),
        );
      }

      // Build the column bitmask.
      int mask = 0;
      mask |= (1 << SettingsColumn.data.bit);
      mask |= (1 << SettingsColumn.updated.bit);

      // Write a log entry.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.settings),
          op: Value(
            existing != null ? LogOperation.update : LogOperation.insert,
          ),
          rowKey: Value(schoolId),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }
}
