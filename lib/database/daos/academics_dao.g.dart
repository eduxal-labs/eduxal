// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'academics_dao.dart';

// ignore_for_file: type=lint
mixin _$AcademicsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SchoolsTable get schools => attachedDatabase.schools;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  $UsersTable get users => attachedDatabase.users;
  $StudentsTable get students => attachedDatabase.students;
  $GradesTable get grades => attachedDatabase.grades;
  $ExamsTable get exams => attachedDatabase.exams;
  $ExamGradesTable get examGrades => attachedDatabase.examGrades;
  $PapersTable get papers => attachedDatabase.papers;
  $SubjectsTable get subjects => attachedDatabase.subjects;
  $TopicsTable get topics => attachedDatabase.topics;
  $MasteryTable get mastery => attachedDatabase.mastery;
  $AttendanceTable get attendance => attachedDatabase.attendance;
  $SubjectTeachersTable get subjectTeachers => attachedDatabase.subjectTeachers;
  $ClassTeachersTable get classTeachers => attachedDatabase.classTeachers;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LogsTable get logs => attachedDatabase.logs;
  AcademicsDaoManager get managers => AcademicsDaoManager(this);
}

class AcademicsDaoManager {
  final _$AcademicsDaoMixin _db;
  AcademicsDaoManager(this._db);
  $$SchoolsTableTableManager get schools =>
      $$SchoolsTableTableManager(_db.attachedDatabase, _db.schools);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$GradesTableTableManager get grades =>
      $$GradesTableTableManager(_db.attachedDatabase, _db.grades);
  $$ExamsTableTableManager get exams =>
      $$ExamsTableTableManager(_db.attachedDatabase, _db.exams);
  $$ExamGradesTableTableManager get examGrades =>
      $$ExamGradesTableTableManager(_db.attachedDatabase, _db.examGrades);
  $$PapersTableTableManager get papers =>
      $$PapersTableTableManager(_db.attachedDatabase, _db.papers);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
  $$MasteryTableTableManager get mastery =>
      $$MasteryTableTableManager(_db.attachedDatabase, _db.mastery);
  $$AttendanceTableTableManager get attendance =>
      $$AttendanceTableTableManager(_db.attachedDatabase, _db.attendance);
  $$SubjectTeachersTableTableManager get subjectTeachers =>
      $$SubjectTeachersTableTableManager(
        _db.attachedDatabase,
        _db.subjectTeachers,
      );
  $$ClassTeachersTableTableManager get classTeachers =>
      $$ClassTeachersTableTableManager(_db.attachedDatabase, _db.classTeachers);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
}
