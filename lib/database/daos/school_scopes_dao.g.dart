// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'school_scopes_dao.dart';

// ignore_for_file: type=lint
mixin _$SchoolScopesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $ScopesTable get scopes => attachedDatabase.scopes;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  $TeachersTable get teachers => attachedDatabase.teachers;
  $StaffTable get staff => attachedDatabase.staff;
  $OwnersTable get owners => attachedDatabase.owners;
  SchoolScopesDaoManager get managers => SchoolScopesDaoManager(this);
}

class SchoolScopesDaoManager {
  final _$SchoolScopesDaoMixin _db;
  SchoolScopesDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$ScopesTableTableManager get scopes =>
      $$ScopesTableTableManager(_db.attachedDatabase, _db.scopes);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
  $$TeachersTableTableManager get teachers =>
      $$TeachersTableTableManager(_db.attachedDatabase, _db.teachers);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$OwnersTableTableManager get owners =>
      $$OwnersTableTableManager(_db.attachedDatabase, _db.owners);
}
