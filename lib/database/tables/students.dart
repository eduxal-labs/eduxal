import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'users.dart';

@DataClassName('StudentsData')
class Students extends Table {
  @override
  String get tableName => 'students';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get adm => integer()();
  TextColumn get user =>
      text().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  TextColumn get name => text()();
  IntColumn get dob => integer().nullable()(); // days since epoch
  IntColumn get gender => integer().map(const GenderConverter()).nullable()();
  TextColumn get documents => text().nullable()();
  IntColumn get admitted => integer().nullable()(); // days since epoch
  IntColumn get status => integer()
      .map(const StudentStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, adm};
}
