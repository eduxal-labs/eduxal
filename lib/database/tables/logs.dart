import 'package:drift/drift.dart';
import 'enums.dart';
import 'accounts.dart';

/// Client-only offline action queue — not synced to the server directly.
///
/// Every local action (create, update, delete, assign, etc.) produces one row here.
/// The sync engine sends these one-at-a-time to the server via gRPC stream.
/// Successfully synced rows are DELETED (never marked as synced).
@DataClassName('LogsData')
class Logs extends Table {
  @override
  String get tableName => 'logs';

  /// Auto-incrementing surrogate PK — ensures replay order is preserved.
  IntColumn get id => integer().autoIncrement()();

  /// The account that performed this action.
  TextColumn get account =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// The semantic action type (e.g. createSchool, updateTeacher, markAttendance).
  IntColumn get action => integer().map(const SyncActionConverter())();

  /// Human-readable display key for the notification UI.
  /// E.g. school name, user phone, "Attendance 2025-01-15", etc.
  TextColumn get resource => text()();

  /// Serialized protobuf action payload (e.g. CreateSchoolPayload bytes).
  /// Self-contained — the sync engine does NOT read other tables to build the message.
  BlobColumn get payload => blob()();

  /// Whether this entry is awaiting replay or has permanently failed.
  IntColumn get status => integer()
      .map(const LogStatusConverter())
      .withDefault(const Constant(0))();

  /// Number of times the sync engine has attempted to send this action.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Human-readable error message from server, if any.
  TextColumn get error => text().nullable()();

  /// Milliseconds since epoch when this log entry was created.
  Int64Column get created => int64()();
}
