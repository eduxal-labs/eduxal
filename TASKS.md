# TASKS.md

## Feature: AI Usage Tracking & Gemini Model Update

### Overview

Two issues identified after the AI-Powered Exam Marking feature (Tasks S1–S5) was completed:

1. **Gemini model version:** The backend hardcodes `gemini-2.5-pro` in the API URL. The project owner expects the latest model. Update to `gemini-2.5-flash` (or whichever model the owner confirms — flag for confirmation).
2. **AI usage tracking is missing:** The `aiusage` table exists in the schema and the full sync plumbing is wired (proto messages, delta writer, Drift table), but the backend `AiMarkingService.mark_paper()` handler **only writes grades** — it never increments `aiusage.used` or appends a changelog entry for the `aiusage` table. This means clients never receive AI usage updates after marking.

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
| Backend handler | `AiMarkingService.mark_paper()` writes grades but does NOT update `aiusage` | ❌ Missing |
| Backend handler | No pre-check of remaining allocation before marking | ❌ Missing |

### Dependency Graph

```
B1 (Gemini model) ─── no deps, standalone
B2 (Backend aiusage) ─── no deps, standalone
B1 and B2 can run in parallel.
C1 (Client DAO) ─── no deps on backend tasks
C1 is client-only, can run in parallel with B1/B2.
```

---

### Task B1: Update Gemini model version in backend

**Files to modify:** `src/ai/gemini.rs` (in the `ledger` project)
**Depends on:** none
**Parallel group:** P1

**Specification:**

The current URL in `src/ai/gemini.rs` is:
```
const URL: &str = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent";
```

**Confirmed by project owner:** Use **Gemini 3.1 Pro** (`gemini-3.1-pro-preview`).

Update the `URL` constant to:
```
const URL: &str = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview:generateContent";
```

> **Note:** Gemini 3.1 Pro is currently a Preview model. Preview models may have more restrictive
> rate limits and will be deprecated with at least 2 weeks notice. If Google changes the model
> string (e.g. adds a date suffix like `gemini-3.1-pro-preview-06-2026`), update this constant.
> Alternatively, use `gemini-pro-latest` to always point to the newest Pro release automatically.

**Update after completion:**
- [x] Confirm model choice with project owner — **Gemini 3.1 Pro**
- [ ] Update `URL` constant in `src/ai/gemini.rs`
- [ ] `cargo build` succeeds
- [ ] Mark this task `[x]`
- [ ] git commit: `fix: update Gemini model to gemini-3.1-pro-preview`

---

### Task B2: Add AI usage tracking to backend `mark_paper` handler

**Files to modify:** `src/services/ai_marking.rs`, `src/db/database/tables/actions.rs` (or equivalent — in the `ledger` project)
**Depends on:** none
**Parallel group:** P1

**Specification:**

After the Gemini API returns scores and the handler writes grades to the `grades` table, it must ALSO update the `aiusage` table for each student that was marked.

#### Step 1 — Upsert `aiusage` row per student

For each student in the marking batch, after writing the grade:

```sql
INSERT INTO aiusage (school, student, year, term, allocated, used, created, updated)
VALUES (?, ?, ?, ?, 0, 1, unixepoch('now'), unixepoch('now'))
ON CONFLICT (school, student, year, term)
DO UPDATE SET used = used + 1, updated = unixepoch('now');
```

This requires knowing `year` and `term` for the exam. The `MarkPaperRequest` has `school` and `exam` but not `year`/`term` directly. The handler must look up the exam's `year` and `term` from the `exams` table:

```sql
SELECT year, term FROM exams WHERE id = ? AND school = ?;
```

#### Step 2 — Append changelog entry for `aiusage`

After each upsert, append a changelog record so `watchChanges` streams the update to all clients:

```rust
// TBL_AIUSAGE = 24 (matches InsertData tag 24 and delta_writer case 24)
append_log(log_user, TBL_AIUSAGE as u8, OP_UPDATE, 0)?;
```

The `rowKey` format for the watch stream delta must be: `"{school}|{student}|{year}|{term}"` — pipe-delimited composite PK, matching the client's `_applyAiUsage()` parser.

#### Step 3 — Pre-check allocation (optional but recommended)

Before calling Gemini, optionally check if each student has remaining allocation:

```sql
SELECT allocated, used FROM aiusage WHERE school = ? AND student = ? AND year = ? AND term = ?;
```

If `used >= allocated` AND `allocated > 0`, skip that student and log a warning. If the row doesn't exist (first time), proceed — the insert in Step 1 will create it with `used = 1, allocated = 0`. A zero `allocated` means "unlimited" (no cap set by admin yet).

#### Step 4 — Wire into the spawned task

In `src/services/ai_marking.rs`, inside the `tokio::spawn` block that runs after Gemini returns, after the grade-writing loop, add the aiusage upsert loop. The function signature for the helper:

```rust
fn write_ai_usage(
    school: &str,
    student: i32,
    year: i32,
    term: i16,
) -> Result<()> {
    // 1. Upsert aiusage row (INSERT ON CONFLICT UPDATE used = used + 1)
    // 2. append_log(Id::system(), TBL_AIUSAGE, OP_UPDATE, 0)
    // 3. Return Ok(())
}
```

Also add the exam lookup at the start of the spawned task:

```rust
// Inside tokio::spawn, before the grade loop:
let (year, term) = fetch_exam_year_term(&school, &exam)?;
// Then after each grade write:
write_ai_usage(&school, score.adm, year, term)?;
```

**Backend constants to add:**
```rust
const TBL_AIUSAGE: u8 = 24;  // matches InsertData tag 24 and delta_writer case 24
```

**Update after completion:**
- [ ] Add `write_ai_usage` helper function
- [ ] Add `fetch_exam_year_term` helper function
- [ ] Wire both into the `mark_paper` spawned task
- [ ] Add `TBL_AIUSAGE` constant
- [ ] `cargo build` succeeds
- [ ] Test: after AI marking, verify `aiusage` row exists with `used > 0`
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: track AI usage per student in aiusage table after marking`

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
- [ ] Create `lib/database/daos/ai_usage_dao.dart`
- [ ] Register DAO in `lib/database/database.dart`
- [ ] Run `dart run build_runner build` — codegen succeeds
- [ ] Verify no analysis errors
- [ ] Update `lib/database/CONTEXT.md` if it exists
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: add AiUsageDao with watch/query methods for AI credit tracking`
