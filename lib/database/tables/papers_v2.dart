import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

/// Server-side paper (migration 0007 — new schema).
///
/// Stored in `papers_v2` on the client to avoid a name collision with the
/// legacy [Papers] table. The server calls this table `papers` and syncs it
/// as table ID 39.
///
/// Each paper has a UUID primary key (server-generated). An assessment or
/// assignment created from the subject detail page may have [event] = NULL
/// (standalone paper not belonging to any exam event).
@DataClassName('PapersV2Data')
class PapersV2 extends Table {
  @override
  String get tableName => 'papers_v2';

  TextColumn get id => text()(); // server-generated ObjectId hex (PK)
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get event => text().nullable()(); // FK → events, NULL for standalone
  IntColumn get subject => integer()(); // FK → subjects
  IntColumn get grade => integer()();
  IntColumn get stream => integer().nullable()();
  IntColumn get type_ => integer()
      .map(const PaperV2TypeConverter())
      .named('type')();
  TextColumn get teacher => text()(); // FK → users
  TextColumn get name => text()();
  IntColumn get totalMarks => integer().named('total_marks')();
  IntColumn get durationMinutes => integer().named('duration_minutes')();
  IntColumn get date => integer()(); // days since epoch
  IntColumn get status => integer()
      .map(const PaperV2StatusConverter())
      .withDefault(const Constant(0))();
  TextColumn get pdfKey => text().named('pdf_key').nullable()();
  TextColumn get msKey => text().named('ms_key').nullable()();
  IntColumn get generationMode => integer()
      .named('generation_mode')
      .withDefault(const Constant(0))();
  TextColumn get instructions => text().nullable()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
