import 'package:drift/drift.dart';
import 'enums.dart';
import 'accounts.dart';

/// Client-only offline mutation queue — not synced to the server directly.
///
/// Every local write to a synced table produces one or more rows here.
/// The sync engine reads these rows and replays them to the server in order.
/// Successfully synced rows are DELETED (never marked as synced).
///
/// See AGENT.md §7 for the full log table specification.
@DataClassName('LogsData')
class Logs extends Table {
  @override
  String get tableName => 'logs';

  /// Auto-incrementing surrogate PK — ensures replay order is preserved.
  IntColumn get id => integer().autoIncrement()();

  /// The account that made this mutation. Mutations are per-account.
  TextColumn get account =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// Which of the 30 synced backend tables was mutated.
  IntColumn get tbl => integer().map(const LogTableConverter())();

  /// The type of mutation: Insert, Update, or Delete.
  IntColumn get op => integer().map(const LogOperationConverter())();

  /// "|"-delimited primary key values identifying the mutated row.
  /// Example for a composite PK: "schoolId|2024|1"
  TextColumn get rowKey => text()();

  /// Bitmask of changed columns — only meaningful for [LogOperation.update].
  /// Each bit position maps to a column via the per-table XxxColumn enum.
  /// Null for Insert and Delete operations.
  IntColumn get columns => integer().nullable()();

  /// Whether this entry is awaiting replay or has permanently failed.
  IntColumn get status => integer()
      .map(const LogStatusConverter())
      .withDefault(const Constant(0))();

  /// Number of times the sync engine has attempted to replay this entry.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last error message received from the server, if any.
  TextColumn get error => text().nullable()();

  /// Milliseconds since epoch when this log entry was created.
  Int64Column get created => int64()();
}
