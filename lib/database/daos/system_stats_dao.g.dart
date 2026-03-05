// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_stats_dao.dart';

// ignore_for_file: type=lint
mixin _$SystemStatsDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
  $SchoolsTable get schools => attachedDatabase.schools;
  $StudentsTable get students => attachedDatabase.students;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  $TermsTable get terms => attachedDatabase.terms;
  $PlansTable get plans => attachedDatabase.plans;
  $FeesTable get fees => attachedDatabase.fees;
  $InvoicesTable get invoices => attachedDatabase.invoices;
  $SubscriptionsTable get subscriptions => attachedDatabase.subscriptions;
  $TeachersTable get teachers => attachedDatabase.teachers;
  $PaymentsTable get payments => attachedDatabase.payments;
  SystemStatsDaoManager get managers => SystemStatsDaoManager(this);
}

class SystemStatsDaoManager {
  final _$SystemStatsDaoMixin _db;
  SystemStatsDaoManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db.attachedDatabase, _db.terms);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db.attachedDatabase, _db.plans);
  $$FeesTableTableManager get fees =>
      $$FeesTableTableManager(_db.attachedDatabase, _db.fees);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db.attachedDatabase, _db.invoices);
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db.attachedDatabase, _db.subscriptions);
  $$TeachersTableTableManager get teachers =>
      $$TeachersTableTableManager(_db.attachedDatabase, _db.teachers);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
}
