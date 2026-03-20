import 'package:drift/drift.dart';
import 'schools.dart';
import 'exams.dart';

class SchemePages extends Table {
  @override
  String get tableName => 'scheme_pages';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get subject => integer()();
  IntColumn get paper => integer().nullable()();
  IntColumn get page => integer()();
  TextColumn get key => text()(); // S3 object key
  Int64Column get created => int64()();

  // paper is nullable in the composite PK — same pattern as papers/grades.
  // Drift does not support nullable columns in primaryKey, so use
  // customConstraints.
  @override
  List<String> get customConstraints => [
    'PRIMARY KEY (school, exam, subject, paper, page)',
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
