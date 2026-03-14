import 'package:drift/drift.dart';
import 'schools.dart';

class SubjectTeachers extends Table {
  @override
  String get tableName => 'subject_teachers';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get subject => integer()(); // FK → subjects.id (was smallint enum)
  TextColumn get teacher => text()();
  Int64Column get created => int64()();

  @override
  Set<Column> get primaryKey => {school, year, term, grade, stream, subject};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
    'FOREIGN KEY (subject)'
        ' REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
