import 'package:drift/drift.dart';
import 'curriculum_subjects.dart';

/// Global subject catalog. Populated by System/Super users only.
/// NOT the same as the old `subjects` table (which is now `subject_teachers`).
class Subjects extends Table {
  @override
  String get tableName => 'subjects';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get curriculum => integer().map(const CurriculumTypeConverter())();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();
}
