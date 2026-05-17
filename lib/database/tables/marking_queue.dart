import 'package:drift/drift.dart';

/// Client mirror of the server-side `marking_queue` table.
///
/// Tracks AI marking progress for each paper — syncs in real-time via the
/// watch stream so all permitted clients see live phase transitions and
/// student counts without polling.
///
/// PK: paper (one row per paper UUID)
class MarkingQueue extends Table {
  @override
  String get tableName => 'marking_queue';

  IntColumn get id => integer()();
  TextColumn get paper => text()();
  IntColumn get phase => integer()();
  TextColumn get progress => text()();
  TextColumn get error => text().nullable()();
  IntColumn get totalStudents => integer()();
  IntColumn get markedStudents => integer()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {paper};
}
