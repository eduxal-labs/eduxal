import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';
import 'users.dart';
import 'invoices.dart';

class Payments extends Table {
  @override
  String get tableName => 'payments';

  TextColumn get id => text()();
  // Nullable: links to an invoice; null means this is a direct payment.
  TextColumn get invoice => text().nullable().references(
    Invoices,
    #id,
    onDelete: KeyAction.cascade,
  )();
  // Required when invoice is null — identifies the school for direct payments.
  TextColumn get school =>
      text().nullable().references(Schools, #id, onDelete: KeyAction.cascade)();
  // Required when invoice is null — identifies the student for direct payments.
  IntColumn get student => integer().nullable()();
  RealColumn get amount => real()();
  IntColumn get method => integer()
      .map(const PaymentMethodConverter())
      .withDefault(const Constant(0))();
  TextColumn get reference => text().nullable()();
  // The member who recorded this payment (for cash accountability); null = system.
  TextColumn get recorder =>
      text().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  // Days since epoch; required for direct payments (when invoice is null).
  IntColumn get date => integer().nullable()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount > 0)',
    // Either a linked invoice OR (school + student + date) must be provided.
    'CHECK (invoice IS NOT NULL OR'
        ' (school IS NOT NULL AND student IS NOT NULL AND date IS NOT NULL))',
    // Composite FK for direct payments; SQLite skips enforcement when any FK
    // column is NULL, so this is a no-op for invoice-linked payments.
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
  ];
}
