// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roles_dao.dart';

// ignore_for_file: type=lint
mixin _$RolesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  $ScopesTable get scopes => attachedDatabase.scopes;
  RolesDaoManager get managers => RolesDaoManager(this);
}

class RolesDaoManager {
  final _$RolesDaoMixin _db;
  RolesDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
  $$ScopesTableTableManager get scopes =>
      $$ScopesTableTableManager(_db.attachedDatabase, _db.scopes);
}
