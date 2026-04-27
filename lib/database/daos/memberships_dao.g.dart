// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memberships_dao.dart';

// ignore_for_file: type=lint
mixin _$MembershipsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $UsersTable get users => attachedDatabase.users;
  $OwnersTable get owners => attachedDatabase.owners;
  $TeachersTable get teachers => attachedDatabase.teachers;
  $StaffTable get staff => attachedDatabase.staff;
  $StudentsTable get students => attachedDatabase.students;
  $GuardiansTable get guardians => attachedDatabase.guardians;
  $SubjectTeachersTable get subjectTeachers => attachedDatabase.subjectTeachers;
  $TermsTable get terms => attachedDatabase.terms;
  MembershipsDaoManager get managers => MembershipsDaoManager(this);
}

class MembershipsDaoManager {
  final _$MembershipsDaoMixin _db;
  MembershipsDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$OwnersTableTableManager get owners =>
      $$OwnersTableTableManager(_db.attachedDatabase, _db.owners);
  $$TeachersTableTableManager get teachers =>
      $$TeachersTableTableManager(_db.attachedDatabase, _db.teachers);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$GuardiansTableTableManager get guardians =>
      $$GuardiansTableTableManager(_db.attachedDatabase, _db.guardians);
  $$SubjectTeachersTableTableManager get subjectTeachers =>
      $$SubjectTeachersTableTableManager(
        _db.attachedDatabase,
        _db.subjectTeachers,
      );
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db.attachedDatabase, _db.terms);
}
