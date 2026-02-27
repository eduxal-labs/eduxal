import 'package:drift/drift.dart';
import 'enums.dart';

class Plans extends Table {
  @override
  String get tableName => 'plans';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get amount => real()();
  IntColumn get levels => integer()(); // bitmask of grade levels
  IntColumn get status => integer()
      .map(const PlanStatusConverter())
      .withDefault(const Constant(0))();
  TextColumn get features => text().nullable()(); // JSON features map
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (amount >= 0)'];
}
