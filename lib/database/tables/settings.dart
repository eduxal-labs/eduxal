import 'package:drift/drift.dart';
import 'schools.dart';

class Settings extends Table {
  @override
  String get tableName => 'settings';

  // school is both the PK and the FK to schools.
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get data => text()(); // JSON — school configuration
  TextColumn get mpesa => text().nullable()(); // JSON — M-Pesa configuration
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school};
}
