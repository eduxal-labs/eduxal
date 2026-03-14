import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

class Exams extends Table {
  @override
  String get tableName => 'exams';

  TextColumn get id => text()();
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  BoolColumn get personalized => boolean().withDefault(const Constant(false))();
  IntColumn get type => integer().map(const ExamTypeConverter())();
  IntColumn get start => integer()(); // days since epoch
  IntColumn get end => integer()(); // days since epoch
  TextColumn get teacher => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (start < end)',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
  ];
}
