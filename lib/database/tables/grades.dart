import 'package:drift/drift.dart';
import 'schools.dart';

/// Grades for exam papers or subject-level totals.
///
/// The composite PK is (school, exam, student, subject, paper) where [paper]
/// is nullable. SQLite allows NULL in composite PKs (each NULL is treated as
/// distinct), but Drift cannot include nullable columns in its [primaryKey]
/// set. The PK is therefore declared via [tableConstraints] so Drift uses the
/// implicit rowid internally while the correct SQLite PK is still enforced.
class Grades extends Table {
  @override
  String get tableName => 'grades';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get exam => text()();
  IntColumn get student => integer()();
  IntColumn get subject => integer()();

  /// Null means this is a subject-level total grade.
  /// Non-null matches a specific [Papers.paper] row.
  IntColumn get paper => integer().nullable()();

  RealColumn get score => real()();
  IntColumn get total => integer()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  // [paper] is nullable so it cannot be included in Drift's primaryKey set.
  // The composite PK and all FKs are expressed as table-level constraints.
  @override
  List<String> get customConstraints => [
    'PRIMARY KEY (school, exam, student, subject, paper)',
    'CHECK (total > 0 AND score >= 0 AND score <= total)',
    'FOREIGN KEY (exam) REFERENCES exams(id) ON DELETE CASCADE',
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
    // Only enforced when paper IS NOT NULL — SQLite skips FK checks when any
    // FK column is NULL. A null-paper grade is a subject-level aggregate not
    // tied to a specific papers row.
    'FOREIGN KEY (school, exam, subject, paper)'
        ' REFERENCES papers(school, exam, subject, paper) ON DELETE CASCADE',
  ];
}
