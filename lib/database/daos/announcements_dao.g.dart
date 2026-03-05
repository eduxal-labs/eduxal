// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcements_dao.dart';

// ignore_for_file: type=lint
mixin _$AnnouncementsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $UsersTable get users => attachedDatabase.users;
  $AnnouncementsTable get announcements => attachedDatabase.announcements;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  AnnouncementsDaoManager get managers => AnnouncementsDaoManager(this);
}

class AnnouncementsDaoManager {
  final _$AnnouncementsDaoMixin _db;
  AnnouncementsDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db.attachedDatabase, _db.announcements);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
