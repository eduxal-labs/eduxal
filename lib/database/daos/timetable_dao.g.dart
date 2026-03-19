// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable_dao.dart';

// ignore_for_file: type=lint
mixin _$TimetableDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $TimetableTable get timetable => attachedDatabase.timetable;
  $LessonsTable get lessons => attachedDatabase.lessons;
  $SubjectsTable get subjects => attachedDatabase.subjects;
  $SubjectTeachersTable get subjectTeachers => attachedDatabase.subjectTeachers;
  $UsersTable get users => attachedDatabase.users;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  TimetableDaoManager get managers => TimetableDaoManager(this);
}

class TimetableDaoManager {
  final _$TimetableDaoMixin _db;
  TimetableDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$TimetableTableTableManager get timetable =>
      $$TimetableTableTableManager(_db.attachedDatabase, _db.timetable);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db.attachedDatabase, _db.lessons);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
  $$SubjectTeachersTableTableManager get subjectTeachers =>
      $$SubjectTeachersTableTableManager(
        _db.attachedDatabase,
        _db.subjectTeachers,
      );
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
