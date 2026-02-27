import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'exams.dart';

class Papers extends Table {
  @override
  String get tableName => 'papers';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get subject => integer()();
  // paper is nullable — indicates paper number (e.g. Paper 1, 2, 3).
  // NULL means single-paper subject; non-null allows multiple papers.
  // NOTE: paper is part of the composite PK but is nullable, which SQLite
  // allows. Drift does not support nullable columns in its primaryKey set,
  // so the PK is declared via tableConstraints instead (Drift uses rowid
  // internally for this table).
  IntColumn get paper => integer().nullable()();
  TextColumn get invigilator => text()();
  Int64Column get start => int64()(); // seconds since epoch
  Int64Column get end => int64()(); // seconds since epoch
  IntColumn get status => integer()
      .map(const PaperStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  // No Drift primaryKey override — paper is nullable so we cannot include it
  // in Drift's Set<Column>. The real composite PK is declared below, and
  // Drift will use SQLite's implicit rowid for data-class identity.
  @override
  List<String> get customConstraints => [
    'PRIMARY KEY (school, exam, subject, paper)',
    'CHECK (start < end)',
    'FOREIGN KEY (school, invigilator)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
  ];
}
