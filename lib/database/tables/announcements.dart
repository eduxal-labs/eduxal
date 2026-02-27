import 'package:drift/drift.dart';
import 'schools.dart';
import 'users.dart';

class Announcements extends Table {
  @override
  String get tableName => 'announcements';

  TextColumn get id => text()();
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  // Nullable: null means the announcement targets all grades.
  IntColumn get grade => integer().nullable()();
  // Nullable: null means the announcement targets all streams of the grade.
  IntColumn get stream => integer().nullable()();
  // Bitmask: bit 0 = Students (1), bit 1 = Parents (2),
  // bit 2 = Teachers (4), bit 3 = Staff (8). 0 = All (no filter).
  IntColumn get audience => integer()();
  // Nullable: set to null when the author user is deleted.
  // The announcement is preserved even if the author is deleted.
  TextColumn get author =>
      text().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
