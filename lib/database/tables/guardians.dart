import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'users.dart';

@DataClassName('GuardiansData')
class Guardians extends Table {
  @override
  String get tableName => 'guardians';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get user =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  IntColumn get student => integer()();
  IntColumn get relationship =>
      integer().map(const GuardianRelationshipConverter())();
  IntColumn get role => integer()
      .map(const GuardianRoleConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, user, student};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, student) REFERENCES students(school, adm) ON DELETE CASCADE',
  ];
}
