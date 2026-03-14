import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

class Timetable extends Table {
  @override
  String get tableName => 'timetable';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get subject => integer()();
  TextColumn get teacher => text()();
  IntColumn get day => integer().map(const DayOfWeekConverter())();
  IntColumn get start => integer()(); // seconds since midnight
  IntColumn get end => integer()(); // seconds since midnight
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {
    school,
    year,
    term,
    grade,
    stream,
    day,
    subject,
    start,
  };

  @override
  List<String> get customConstraints => [
    'CHECK (start < end)',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    // FK on the (subject, teacher) 7-column tuple enforces that the timetable
    // teacher matches the assigned subject teacher.
    // ON UPDATE CASCADE keeps timetable in sync if the teacher is reassigned.
    'FOREIGN KEY (school, year, term, grade, stream, subject, teacher)'
        ' REFERENCES subject_teachers(school, year, term, grade, stream, subject, teacher)'
        ' ON DELETE CASCADE ON UPDATE CASCADE',
  ];
}
