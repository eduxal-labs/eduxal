import 'package:drift/drift.dart';
import 'schools.dart';

class Lessons extends Table {
  @override
  String get tableName => 'lessons';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get date => integer()(); // days since epoch
  IntColumn get subject => integer()();
  TextColumn get teacher => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {
    school,
    year,
    term,
    grade,
    stream,
    date,
    subject,
    teacher,
  };

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
    // RESTRICT prevents deleting a subject that still has recorded lessons.
    'FOREIGN KEY (school, year, term, grade, stream, subject)'
        ' REFERENCES subjects(school, year, term, grade, stream, subject)'
        ' ON DELETE RESTRICT',
  ];
}
