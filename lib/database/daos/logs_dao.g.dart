// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logs_dao.dart';

// ignore_for_file: type=lint
mixin _$LogsDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  LogsDaoManager get managers => LogsDaoManager(this);
}

class LogsDaoManager {
  final _$LogsDaoMixin _db;
  LogsDaoManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
