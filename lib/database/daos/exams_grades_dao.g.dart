// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exams_grades_dao.dart';

// ignore_for_file: type=lint
mixin _$ExamsGradesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $ExamsTable get exams => attachedDatabase.exams;
  $PapersTable get papers => attachedDatabase.papers;
  $PaperSubmissionsTable get paperSubmissions =>
      attachedDatabase.paperSubmissions;
  $GradesTable get grades => attachedDatabase.grades;
  $SubjectsTable get subjects => attachedDatabase.subjects;
  $TopicsTable get topics => attachedDatabase.topics;
  $MasteryTable get mastery => attachedDatabase.mastery;
  $UsersTable get users => attachedDatabase.users;
  $StudentsTable get students => attachedDatabase.students;
  $TeachersTable get teachers => attachedDatabase.teachers;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  $SubjectTeachersTable get subjectTeachers => attachedDatabase.subjectTeachers;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  ExamsGradesDaoManager get managers => ExamsGradesDaoManager(this);
}

class ExamsGradesDaoManager {
  final _$ExamsGradesDaoMixin _db;
  ExamsGradesDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$ExamsTableTableManager get exams =>
      $$ExamsTableTableManager(_db.attachedDatabase, _db.exams);
  $$PapersTableTableManager get papers =>
      $$PapersTableTableManager(_db.attachedDatabase, _db.papers);
  $$PaperSubmissionsTableTableManager get paperSubmissions =>
      $$PaperSubmissionsTableTableManager(
        _db.attachedDatabase,
        _db.paperSubmissions,
      );
  $$GradesTableTableManager get grades =>
      $$GradesTableTableManager(_db.attachedDatabase, _db.grades);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
  $$MasteryTableTableManager get mastery =>
      $$MasteryTableTableManager(_db.attachedDatabase, _db.mastery);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$TeachersTableTableManager get teachers =>
      $$TeachersTableTableManager(_db.attachedDatabase, _db.teachers);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
  $$SubjectTeachersTableTableManager get subjectTeachers =>
      $$SubjectTeachersTableTableManager(
        _db.attachedDatabase,
        _db.subjectTeachers,
      );
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
