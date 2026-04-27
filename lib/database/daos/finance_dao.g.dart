// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_dao.dart';

// ignore_for_file: type=lint
mixin _$FinanceDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $FeesTable get fees => attachedDatabase.fees;
  $InvoicesTable get invoices => attachedDatabase.invoices;
  $UsersTable get users => attachedDatabase.users;
  $PaymentsTable get payments => attachedDatabase.payments;
  $PlansTable get plans => attachedDatabase.plans;
  $DiscountsTable get discounts => attachedDatabase.discounts;
  $StudentsTable get students => attachedDatabase.students;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  $TermsTable get terms => attachedDatabase.terms;
  FinanceDaoManager get managers => FinanceDaoManager(this);
}

class FinanceDaoManager {
  final _$FinanceDaoMixin _db;
  FinanceDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$FeesTableTableManager get fees =>
      $$FeesTableTableManager(_db.attachedDatabase, _db.fees);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db.attachedDatabase, _db.invoices);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db.attachedDatabase, _db.plans);
  $$DiscountsTableTableManager get discounts =>
      $$DiscountsTableTableManager(_db.attachedDatabase, _db.discounts);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db.attachedDatabase, _db.terms);
}
