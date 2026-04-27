// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schools_dao.dart';

// ignore_for_file: type=lint
mixin _$SchoolsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $UsersTable get users => attachedDatabase.users;
  $OwnersTable get owners => attachedDatabase.owners;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  SchoolsDaoManager get managers => SchoolsDaoManager(this);
}

class SchoolsDaoManager {
  final _$SchoolsDaoMixin _db;
  SchoolsDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$OwnersTableTableManager get owners =>
      $$OwnersTableTableManager(_db.attachedDatabase, _db.owners);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
