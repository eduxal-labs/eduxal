import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

class Attendance extends Table {
  @override
  String get tableName => 'attendance';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get student => integer()();
  IntColumn get date => integer()(); // days since epoch
  IntColumn get status => integer().map(const AttendanceStatusConverter())();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {
    school,
    year,
    term,
    grade,
    stream,
    student,
    date,
  };

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, year, term, grade, stream, student)'
        ' REFERENCES enrollments(school, year, term, grade, stream, student)'
        ' ON DELETE CASCADE',
  ];
}
