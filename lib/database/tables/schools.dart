import 'package:drift/drift.dart';
import 'enums.dart';

@DataClassName('SchoolsData')
class Schools extends Table {
  @override
  String get tableName => 'schools';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get motto => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  IntColumn get county => integer()();
  TextColumn get domain => text().nullable()();
  IntColumn get established => integer().nullable()();
  IntColumn get status => integer()
      .map(const SchoolStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
