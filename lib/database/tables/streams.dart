import 'package:drift/drift.dart';
import 'schools.dart';

/// Per-school stream definitions. Links a named stream to a grade.
@DataClassName('SchoolStream')
class Streams extends Table {
  @override
  String get tableName => 'streams';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  TextColumn get name => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, grade, stream};
}
