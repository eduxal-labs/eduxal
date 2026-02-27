import 'package:drift/drift.dart';
import 'schools.dart';

class Roles extends Table {
  @override
  String get tableName => 'roles';

  TextColumn get id => text()();
  TextColumn get school =>
      text().nullable().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get permissions => text()(); // JSON map of permissions
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
