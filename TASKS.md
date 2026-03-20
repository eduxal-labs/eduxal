# TASKS.md

## Feature: AI Usage Tracking (Client)

### Overview

The AI usage tracking backend tasks (B1, B2) have been moved to `../ledger/TASKS.md`. This file tracks only the remaining client-side (eduxal) tasks.

### What already exists

| Layer | Component | Status |
|---|---|---|
| SQL schema | `aiusage` table — PK `(school, student, year, term)`, columns: `allocated`, `used` | ✅ Exists |
| Drift table | `AiUsage` in `lib/database/tables/aiusage.dart` | ✅ Exists |
| Drift codegen | `AiUsageData`, `AiUsageCompanion`, `$AiUsageTable` | ✅ Generated |
| Sync proto (push) | `UpdateAiUsagePayload` — 6 fields (school, student, year, term, allocated, used) | ✅ Generated |
| Sync proto (watch) | `AiUsageInsert` at `InsertData` tag 24 — identical 6 fields | ✅ Generated |
| SyncAction enum | `updateAiUsage(70)` in `lib/database/tables/enums.dart` | ✅ Exists |
| Delta writer | `_applyAiUsage()` handles incoming `SyncDelta` for table 24 — upsert via `insertOnConflictUpdate` | ✅ Exists |
| AppDatabase | `AiUsage` registered in tables list + cleared in `deleteAllData()` | ✅ Exists |
| DAO | **None** — no query/watch methods for `aiusage` | ❌ Missing |
| Client service | **None** — no service-layer methods for AI usage | ❌ Missing |

---

### Task C1: Add AI usage DAO methods on client (eduxal)

**Files to create:** `lib/database/daos/ai_usage_dao.dart`
**Files to modify:** `lib/database/database.dart` (register DAO)
**Context files to read:** `lib/database/tables/aiusage.dart`, `lib/database/database.dart`
**Depends on:** none (client-only, does not depend on backend tasks)
**Parallel group:** P1

**Specification:**

Create a DAO for the `aiusage` table so the UI can display AI credit usage per student.

**`lib/database/daos/ai_usage_dao.dart`:**

```dart
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/aiusage.dart';

part 'ai_usage_dao.g.dart';

@DriftAccessor(tables: [AiUsage])
class AiUsageDao extends DatabaseAccessor<AppDatabase>
    with _$AiUsageDaoMixin {
  AiUsageDao(super.db);

  /// Watch all AI usage rows for a school in a given term.
  Stream<List<AiUsageData>> watchBySchoolTerm(
    String schoolId,
    int year,
    int term,
  ) {
    return (select(aiUsage)
          ..where((t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term)))
        .watch();
  }

  /// Watch a single student's AI usage for a term.
  Stream<AiUsageData?> watchStudent(
    String schoolId,
    int student,
    int year,
    int term,
  ) {
    return (select(aiUsage)
          ..where((t) =>
              t.school.equals(schoolId) &
              t.student.equals(student) &
              t.year.equals(year) &
              t.term.equals(term)))
        .watchSingleOrNull();
  }

  /// Get a single student's current AI usage (non-reactive).
  Future<AiUsageData?> getStudent(
    String schoolId,
    int student,
    int year,
    int term,
  ) {
    return (select(aiUsage)
          ..where((t) =>
              t.school.equals(schoolId) &
              t.student.equals(student) &
              t.year.equals(year) &
              t.term.equals(term)))
        .getSingleOrNull();
  }
}
```

**Register in `lib/database/database.dart`:**
1. Add import: `import 'daos/ai_usage_dao.dart';`
2. Add `AiUsageDao` to the `@DriftDatabase(... daos: [...])` annotation (if using annotation-based) OR instantiate it as a late field.
3. Run `dart run build_runner build` to generate `ai_usage_dao.g.dart`.

**Update after completion:**
- [x] Create `lib/database/daos/ai_usage_dao.dart`
- [x] Register DAO in `lib/database/database.dart`
- [x] Run `dart run build_runner build` — codegen succeeds
- [x] Verify no analysis errors
- [x] Update `lib/database/CONTEXT.md` if it exists
- [x] Mark this task `[x]`
- [x] git commit: `feat: add AiUsageDao with watch/query methods for AI credit tracking`
