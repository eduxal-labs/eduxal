// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_dao.dart';

// ignore_for_file: type=lint
mixin _$UsersDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  $SchoolsTable get schools => attachedDatabase.schools;
  $RolesTable get roles => attachedDatabase.roles;
  $ScopesTable get scopes => attachedDatabase.scopes;
  UsersDaoManager get managers => UsersDaoManager(this);
}

class UsersDaoManager {
  final _$UsersDaoMixin _db;
  UsersDaoManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$ScopesTableTableManager get scopes =>
      $$ScopesTableTableManager(_db.attachedDatabase, _db.scopes);
}
