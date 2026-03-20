import 'package:drift/drift.dart';
import 'schools.dart';
import 'exams.dart';

/// Client mirror of the server-side `answer_pages` table.
///
/// Stores per-student answer sheet page metadata received via the watch stream.
/// Each row represents a single page image for a student's exam paper.
/// The S3 object key allows the sync engine to derive a GET URL for download.
///
/// PK: (school, exam, student, subject, paper, page) — paper is nullable to
/// support single-paper subjects (paper=NULL). Drift does not support nullable
/// columns in [primaryKey], so the constraint is declared via
/// [customConstraints] instead.
class AnswerPages extends Table {
  @override
  String get tableName => 'answer_pages';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();

  /// Student admission number.
  IntColumn get student => integer()();

  /// FK → subjects.id
  IntColumn get subject => integer()();

  /// Paper number (1, 2, 3…) or NULL for single-paper subjects.
  IntColumn get paper => integer().nullable()();

  /// 0-based page index within this student's answer sheet for the paper.
  IntColumn get page => integer()();

  /// S3 object key for the answer page image. Used to derive a presigned GET
  /// URL when downloading via [FileCache.download].
  TextColumn get key => text()();

  /// Server-side creation timestamp (milliseconds since epoch).
  Int64Column get created => int64()();

  @override
  List<String> get customConstraints => [
    'PRIMARY KEY (school, exam, student, subject, paper, page)',
    'FOREIGN KEY (school, student) REFERENCES students(school, adm) ON DELETE CASCADE',
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
