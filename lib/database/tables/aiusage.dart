import 'package:drift/drift.dart';
import 'schools.dart';

class AiUsage extends Table {
  @override
  String get tableName => 'aiusage';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get student => integer()();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get allocated => integer()();
  IntColumn get used => integer()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, student, year, term};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
