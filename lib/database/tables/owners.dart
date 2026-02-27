import 'package:drift/drift.dart';
import 'schools.dart';
import 'users.dart';

@DataClassName('OwnersData')
class Owners extends Table {
  @override
  String get tableName => 'owners';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get user =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  Int64Column get created => int64()();

  @override
  Set<Column> get primaryKey => {school, user};
}
