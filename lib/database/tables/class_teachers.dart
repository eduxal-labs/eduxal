import 'package:drift/drift.dart';
import 'schools.dart';

class ClassTeachers extends Table {
  @override
  String get tableName => 'class_teachers';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  TextColumn get teacher => text()();
  IntColumn get start => integer()(); // days since epoch
  IntColumn get end =>
      integer().nullable()(); // null = currently active teacher

  // created is a bigint (seconds since epoch) — no updated column on this table
  Int64Column get created => int64()();

  @override
  Set<Column> get primaryKey => {school, year, term, grade, stream, teacher};

  @override
  List<String> get customConstraints => [
    'CHECK (end IS NULL OR start < end)',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
