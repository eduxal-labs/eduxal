import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

/// Server-side event (migration 0007 — replaces old `exams` table).
///
/// Stored in `events` to match the server table name. The server syncs this
/// as table ID 38.
///
/// An event is an exam period (e.g. "End Term 1 2026", "Mid Term 2 Mock").
/// Papers are linked to events via [PapersV2.event].
@DataClassName('EventData')
class Events extends Table {
  @override
  String get tableName => 'events';

  TextColumn get id => text()(); // server-generated ObjectId hex (PK)
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get type_ => integer()
      .map(const EventTypeConverter())
      .named('type')();
  IntColumn get term => integer()();
  IntColumn get year => integer()();
  IntColumn get startDate => integer().named('start_date')(); // days since epoch
  IntColumn get endDate => integer().named('end_date')(); // days since epoch
  IntColumn get status => integer()
      .map(const EventStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (start_date <= end_date)',
  ];
}
