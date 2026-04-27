// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enrollments_dao.dart';

// ignore_for_file: type=lint
mixin _$EnrollmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  $UsersTable get users => attachedDatabase.users;
  $StudentsTable get students => attachedDatabase.students;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  EnrollmentsDaoManager get managers => EnrollmentsDaoManager(this);
}

class EnrollmentsDaoManager {
  final _$EnrollmentsDaoMixin _db;
  EnrollmentsDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
