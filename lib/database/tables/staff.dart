import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'users.dart';

class Staff extends Table {
  @override
  String get tableName => 'staff';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get user =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get idnumber => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get department => text().nullable()();
  IntColumn get status => integer()
      .map(const StaffStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, user};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, department) REFERENCES departments(school, name) ON DELETE NO ACTION',
  ];
}
