import 'package:drift/drift.dart';
import 'schools.dart';

class Mastery extends Table {
  @override
  String get tableName => 'mastery';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get student => integer()();
  IntColumn get grade => integer()();
  IntColumn get subject => integer()();
  IntColumn get topic => integer()();
  RealColumn get score => real()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, student, grade, subject, topic};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
  ];
}
