import 'package:drift/drift.dart';
import 'schools.dart';

class Terms extends Table {
  @override
  String get tableName => 'terms';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  Int64Column get start => int64()(); // seconds since epoch
  Int64Column get end => int64()(); // seconds since epoch
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, year, term};

  @override
  List<String> get customConstraints => ['CHECK (start < end)'];
}
