import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/schools.dart';

part 'schools_dao.g.dart';

/// DAO for the [Schools] table.
///
/// Provides reactive streams and one-shot reads for school data. All writes go
/// through [upsertSchool] — the sync engine is responsible for calling this
/// whenever the server pushes a school delta.
@DriftAccessor(tables: [Schools])
class SchoolsDao extends DatabaseAccessor<AppDatabase> with _$SchoolsDaoMixin {
  SchoolsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the full list of schools stored locally whenever any school row
  /// changes.
  ///
  /// The list is unordered — callers should sort as needed for display.
  Stream<List<SchoolsData>> watchSchools() {
    return select(schools).watch();
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns the school with the given [id], or [null] if not found locally.
  Future<SchoolsData?> getSchool(String id) {
    return (select(schools)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new school row, or replaces an existing row with the same [id].
  ///
  /// Called by the sync engine when the server pushes a school insert or
  /// update delta.
  Future<void> upsertSchool(SchoolsCompanion school) {
    return into(schools).insertOnConflictUpdate(school);
  }
}
