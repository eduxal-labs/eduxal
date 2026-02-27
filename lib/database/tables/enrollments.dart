import 'package:drift/drift.dart';
import 'schools.dart';

class Enrollments extends Table {
  @override
  String get tableName => 'enrollments';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get student => integer()();
  Int64Column get created => int64()();

  @override
  Set<Column> get primaryKey => {school, year, term, grade, stream, student};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, student) REFERENCES students(school, adm) ON DELETE CASCADE',
    'FOREIGN KEY (school, year, term) REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
