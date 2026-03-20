import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/aiusage.dart';

part 'ai_usage_dao.g.dart';

@DriftAccessor(tables: [AiUsage])
class AiUsageDao extends DatabaseAccessor<AppDatabase> with _$AiUsageDaoMixin {
  AiUsageDao(super.db);

  /// Watch all AI usage rows for a school in a given term.
  Stream<List<AiUsageData>> watchBySchoolTerm(
    String schoolId,
    int year,
    int term,
  ) {
    return (select(aiUsage)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .watch();
  }

  /// Watch a single student's AI usage for a term.
  Stream<AiUsageData?> watchStudent(
    String schoolId,
    int student,
    int year,
    int term,
  ) {
    return (select(aiUsage)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.student.equals(student) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .watchSingleOrNull();
  }

  /// Get a single student's current AI usage (non-reactive).
  Future<AiUsageData?> getStudent(
    String schoolId,
    int student,
    int year,
    int term,
  ) {
    return (select(aiUsage)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.student.equals(student) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .getSingleOrNull();
  }
}
