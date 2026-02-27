import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'fees.dart';

class Invoices extends Table {
  @override
  String get tableName => 'invoices';

  TextColumn get id => text()();
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  // Nullable: links to a predefined fee; null means this is a custom invoice.
  TextColumn get fee =>
      text().nullable().references(Fees, #id, onDelete: KeyAction.cascade)();
  // Required when fee is null — describes the custom charge.
  TextColumn get description => text().nullable()();
  IntColumn get student => integer()();
  RealColumn get amount => real()();
  IntColumn get status => integer()
      .map(const InvoiceStatusConverter())
      .withDefault(const Constant(0))();
  // Null inherits due date from the linked fee; required when fee is null.
  Int64Column get due => int64().nullable()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    // Either a fee is referenced, or a custom description + due date must be supplied.
    'CHECK (fee IS NOT NULL OR (description IS NOT NULL AND due IS NOT NULL))',
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
  ];
}
