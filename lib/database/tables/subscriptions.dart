import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'plans.dart';
import 'invoices.dart';

class Subscriptions extends Table {
  @override
  String get tableName => 'subscriptions';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get plan =>
      text().references(Plans, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get student => integer()();
  // Nullable: the invoice generated for this subscription; null until invoiced.
  TextColumn get invoice => text().nullable().references(
    Invoices,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Discount percentage applied to this subscription (0 = no discount).
  RealColumn get discount => real().withDefault(const Constant(0))();
  IntColumn get status => integer()
      .map(const SubscriptionStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, plan, year, term, student};

  @override
  List<String> get customConstraints => [
    'CHECK (discount >= 0 AND discount <= 100)',
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
