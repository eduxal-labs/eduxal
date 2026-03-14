import 'package:drift/drift.dart';
import 'exams.dart';

/// Junction table: which grades and streams participate in an exam.
/// No NULL streams — if exam spans all streams, one row per stream.
class ExamGrades extends Table {
  @override
  String get tableName => 'exam_grades';

  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();

  @override
  Set<Column> get primaryKey => {exam, grade, stream};
}
