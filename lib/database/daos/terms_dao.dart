import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/terms.dart';

part 'terms_dao.g.dart';

/// DAO for the [Terms] table.
///
/// Terms are the fundamental temporal unit of the application — every academic
/// record (enrollments, subjects, attendance, exams, fees, etc.) is scoped to
/// a `(school, year, term)` triple.
///
/// All local mutations write a corresponding entry to the [Logs] table inside
/// the same transaction so the sync engine can replay them to the server.
@DriftAccessor(tables: [Terms, Logs])
class TermsDao extends DatabaseAccessor<AppDatabase> with _$TermsDaoMixin {
  TermsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the full list of terms for [schoolId] whenever any row in [Terms]
  /// changes, ordered by year descending then term ascending.
  ///
  /// The most recent academic year appears first; within a year terms are in
  /// chronological order (Term 1, Term 2, Term 3).
  ///
  /// Binds directly to the dashboard term selector — the stream is kept alive
  /// for the duration of the school session.
  Stream<List<Term>> watchTerms(String schoolId) {
    return (select(terms)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.year),
            (t) => OrderingTerm.asc(t.term),
          ]))
        .watch();
  }

  /// Emits the current active term for [schoolId].
  ///
  /// "Active" means `start ≤ now ≤ end` using seconds-since-epoch stored in
  /// `terms.start` and `terms.end`.  Emits `null` when no such term exists
  /// (e.g. between terms or before the first term is created).
  ///
  /// The dashboard uses this to default to the right term on first entry.
  Stream<Term?> watchActiveTerm(String schoolId) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return (select(terms)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.start.isSmallerOrEqualValue(nowSeconds) &
                t.end.isBiggerOrEqualValue(nowSeconds),
          )
          ..limit(1))
        .watchSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns all terms for [schoolId], ordered by year desc, term asc.
  Future<List<Term>> getTerms(String schoolId) {
    return (select(terms)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.year),
            (t) => OrderingTerm.asc(t.term),
          ]))
        .get();
  }

  /// Returns the current active term for [schoolId], or `null` if none exists.
  ///
  /// "Active" means `start ≤ now ≤ end` (seconds since epoch).
  Future<Term?> getActiveTerm(String schoolId) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return (select(terms)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.start.isSmallerOrEqualValue(nowSeconds) &
                t.end.isBiggerOrEqualValue(nowSeconds),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns a single term by its composite primary key, or `null` if not found.
  Future<Term?> getTerm({
    required String schoolId,
    required int year,
    required int termNumber,
  }) {
    return (select(terms)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(termNumber),
        ))
        .getSingleOrNull();
  }

  /// Returns the most recent term for [schoolId] by year desc, term desc —
  /// useful as a fallback when no term is currently active.
  Future<Term?> getMostRecentTerm(String schoolId) {
    return (select(terms)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.year),
            (t) => OrderingTerm.desc(t.term),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Sync-sourced writes
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a term row from a server-pushed delta.
  ///
  /// Does **not** write a log entry — the mutation originated on the server.
  Future<void> upsertTerm(TermsCompanion term) {
    return into(terms).insertOnConflictUpdate(term);
  }

  // ---------------------------------------------------------------------------
  // Local mutation writes
  // ---------------------------------------------------------------------------

  /// Creates a new term and writes an INSERT log entry, both in a single
  /// transaction.
  ///
  /// The composite row_key written to the log is `"{schoolId}|{year}|{term}"`.
  ///
  /// [accountId] is the currently active account's user id.
  ///
  /// Throws if a term with the same `(school, year, term)` triple already exists
  /// — the caller should verify uniqueness before invoking this method.
  Future<void> createTerm({
    required TermsCompanion term,
    required String accountId,
  }) {
    return transaction(() async {
      await into(terms).insert(term);

      final schoolId = term.school.value;
      final year = term.year.value;
      final termNumber = term.term.value;
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.terms),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$year|$termNumber'),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
  }

  /// Updates mutable fields on an existing term and writes an UPDATE log entry
  /// with the correct [TermsColumn] bitmask, both in a single transaction.
  ///
  /// Only columns whose [Value] is present in [changes] are updated.
  /// The `updated` field in [changes] must be set to the current timestamp
  /// (seconds since epoch) by the caller.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateTerm({
    required String schoolId,
    required int year,
    required int termNumber,
    required TermsCompanion changes,
    required String accountId,
  }) {
    return transaction(() async {
      await (update(terms)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(termNumber),
          ))
          .write(changes);

      int mask = 0;
      if (changes.start.present) mask |= (1 << TermsColumn.start.bit);
      if (changes.end.present) mask |= (1 << TermsColumn.end.bit);
      if (changes.updated.present) mask |= (1 << TermsColumn.updated.bit);

      if (mask == 0) return; // nothing tracked

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.terms),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$year|$termNumber'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
  }

  /// Deletes a term row and writes a DELETE log entry before the deletion, both
  /// in a single transaction.
  ///
  /// Deleting a term cascades to enrollments, subjects, attendance, class
  /// teachers, exams, fees, etc. (enforced by SQLite FK ON DELETE CASCADE).
  /// The caller must confirm this intent in the UI before calling.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> deleteTerm({
    required String schoolId,
    required int year,
    required int termNumber,
    required String accountId,
  }) {
    return transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Log before delete so the sync engine can replay it.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.terms),
          op: const Value(LogOperation.delete),
          rowKey: Value('$schoolId|$year|$termNumber'),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );

      await (delete(terms)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(termNumber),
          ))
          .go();
    });
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` if a term with the given `(school, year, termNumber)` PK
  /// already exists in the local database.
  ///
  /// Used by the creation form to show an inline duplicate error before
  /// attempting the insert.
  Future<bool> termExists({
    required String schoolId,
    required int year,
    required int termNumber,
  }) async {
    final row = await getTerm(
      schoolId: schoolId,
      year: year,
      termNumber: termNumber,
    );
    return row != null;
  }

  /// Returns all distinct academic years that have at least one term for
  /// [schoolId], ordered descending (most recent first).
  ///
  /// Used to populate the year selector in the term picker dropdown.
  Future<List<int>> getDistinctYears(String schoolId) async {
    final yearExpr = terms.year;
    final query = selectOnly(terms, distinct: true)
      ..addColumns([yearExpr])
      ..where(terms.school.equals(schoolId))
      ..orderBy([OrderingTerm.desc(yearExpr)]);

    final rows = await query.get();
    return rows.map((r) => r.read(yearExpr)!).toList();
  }
}
