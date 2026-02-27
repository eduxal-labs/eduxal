import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'plans.dart';

class Discounts extends Table {
  @override
  String get tableName => 'discounts';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get plan =>
      text().references(Plans, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  RealColumn get amount => real()();
  IntColumn get unit => integer()
      .map(const DiscountUnitConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, plan, year, term, grade};

  @override
  List<String> get customConstraints => [
    'CHECK (amount >= 0 AND (unit != 0 OR amount <= 100))',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
