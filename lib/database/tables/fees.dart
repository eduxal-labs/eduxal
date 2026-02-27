import 'package:drift/drift.dart';
import 'schools.dart';

class Fees extends Table {
  @override
  String get tableName => 'fees';

  TextColumn get id => text()();
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  BoolColumn get mandatory => boolean().withDefault(const Constant(true))();
  Int64Column get due => int64()(); // seconds since epoch
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
