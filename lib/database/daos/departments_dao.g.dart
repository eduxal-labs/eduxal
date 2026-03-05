// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'departments_dao.dart';

// ignore_for_file: type=lint
mixin _$DepartmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $DepartmentsTable get departments => attachedDatabase.departments;
  $UsersTable get users => attachedDatabase.users;
  $TeachersTable get teachers => attachedDatabase.teachers;
  $StaffTable get staff => attachedDatabase.staff;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  DepartmentsDaoManager get managers => DepartmentsDaoManager(this);
}

class DepartmentsDaoManager {
  final _$DepartmentsDaoMixin _db;
  DepartmentsDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$DepartmentsTableTableManager get departments =>
      $$DepartmentsTableTableManager(_db.attachedDatabase, _db.departments);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$TeachersTableTableManager get teachers =>
      $$TeachersTableTableManager(_db.attachedDatabase, _db.teachers);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
