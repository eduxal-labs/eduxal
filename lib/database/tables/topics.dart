import 'package:drift/drift.dart';
import 'subjects.dart';

/// Global topic catalog. Grade-specific subdivisions of a subject.
/// Populated by System/Super users only.
class Topics extends Table {
  @override
  String get tableName => 'topics';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get subject =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  TextColumn get name => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  List<String> get customConstraints => ['UNIQUE (subject, grade, name)'];
}
