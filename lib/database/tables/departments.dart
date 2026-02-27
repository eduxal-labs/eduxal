import 'package:drift/drift.dart';
import 'schools.dart';

class Departments extends Table {
  @override
  String get tableName => 'departments';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, name};
}
