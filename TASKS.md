# EduXal — Task Board

> Tasks are ordered by dependency and priority. Execute top-to-bottom.
> Server tasks are in `../ledger/TASKS.md` — complete those first before starting client tasks.
> Proto changes are done on the server side; the client only regenerates Dart stubs from `../ledger/protos/`.

---

### Task C00: Commit current uncommitted progress in meaningful chunks

**Specification:**

Before starting the schema restructuring, all uncommitted work must be committed in logical, meaningful chunks. There are 33 changed/new files spanning multiple domains. Commit them in this order:

#### Commit 1: `db: add PaperSubmissions table and remove overly restrictive exam indexes`

Stage and commit:
```
lib/database/tables/papers.dart
lib/database/database.dart
lib/database/database.g.dart
schema.sql
```

This commit covers:
- New `PaperSubmissions` client-only table for storing answer image file paths
- Registration of `PaperSubmissions` in `AppDatabase` tables list and `deleteAllData`
- Schema version bump (3 → 5) with migration steps: dropping `uq_exams_allstream_type` and `uq_exams_stream_type` unique indexes, creating `paper_submissions` table
- Updated `schema.sql` removing those same unique indexes
- Regenerated `database.g.dart`

#### Commit 2: `feat: add exam batch creation, paper watching, and subject class queries`

Stage and commit:
```
lib/database/daos/exams_grades_dao.dart
lib/database/daos/exams_grades_dao.g.dart
lib/database/daos/subjects_dao.dart
lib/models/exam_group.dart
```

This commit covers:
- `ExamBatchEntry` typedef and `createExamBatch` for multi-grade exam creation
- `watchPaper` single-paper reactive stream
- Paper analytics and grade management additions in `ExamsGradesDao`
- `getSubjectsForClass` query in `SubjectsDao`
- New `ExamGroup` domain model for grouping exam rows by shared attributes

#### Commit 3: `feat: add log retry/revert support and sync engine robustness`

Stage and commit:
```
lib/database/daos/logs_dao.dart
lib/sync/delta_writer.dart
lib/sync/sync_engine.dart
```

This commit covers:
- `retryLog` and `deleteAndRevertLog` methods in `LogsDao` for failed action management
- `DeltaWriter`: FK-safe flushing (PRAGMA foreign_keys OFF/ON), improved null parsing, unknown table fallback logging
- `SyncEngine`: exponential backoff with jitter on reconnect, adaptive push interval, flush timer for idle delta batches, guard flag preventing duplicate reconnects

#### Commit 4: `ui: overhaul exams/grades screen, paper detail, and exam creation`

Stage and commit:
```
lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart
lib/ui/screens/school_dashboard/exams/exam_creation_page.dart
lib/ui/screens/school_dashboard/academics/paper_detail_page.dart
lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart
lib/ui/screens/school_dashboard/academics/grade_detail_page.dart
```

This commit covers:
- Major overhaul of exams/grades screen (11k+ line diff)
- New exam creation page with multi-grade support
- Enhanced paper detail page with answer submission and grading
- Updated exams tab and grade detail page

#### Commit 5: `ui: enhance notifications, system dashboard, and member screens`

Stage and commit:
```
lib/ui/screens/notifications/notifications_page.dart
lib/ui/screens/system/notifications/notifications_panel.dart
lib/ui/screens/system/schools/school_detail_screen.dart
lib/ui/screens/system/system_dashboard_screen.dart
lib/ui/screens/system/users/users_section.dart
lib/ui/screens/school_dashboard/members/members_page.dart
lib/ui/screens/school_dashboard/announcements/announcements_screen.dart
lib/ui/screens/school_dashboard/finance/finance_screen.dart
lib/ui/screens/school_dashboard/roles/school_roles_screen.dart
```

This commit covers:
- Overhauled notifications page with retry/revert actions for failed logs
- Enhanced system notifications panel
- System dashboard and school detail additions
- Users section improvements
- Minor fixes/additions to members, announcements, finance, and roles screens

#### Commit 6: `docs: update CONTEXT.md files and AGENT.md`

Stage and commit:
```
AGENT.md
lib/database/CONTEXT.md
lib/database/daos/CONTEXT.md
lib/models/CONTEXT.md
lib/ui/screens/school_dashboard/CONTEXT.md
lib/ui/widgets/CONTEXT.md
```

This commit covers:
- Updated AGENT.md with latest architectural decisions
- Updated all CONTEXT.md files to reflect new files and changed exports

#### Commit 7: `chore: update dependencies`

Stage and commit:
```
pubspec.lock
```

This commit covers:
- Updated dependency lock file

#### After all commits, stage and commit the current TASKS.md separately:

#### Commit 8: `docs: add schema restructuring v2 task list`

Stage and commit:
```
TASKS.md
```

**Execution notes:**
- Use `git add <files> && git commit -m "<message>"` for each chunk.
- Do NOT use `git add .` — stage only the listed files per commit.
- Verify each commit with `git log --oneline -1` after committing.
- If any file has unsaved buffer changes, save before staging.

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Context: What Changed and Why

These tasks implement the "Schema Restructuring v2" changes on the Flutter/Drift client side.
The server `TASKS.md` covers migration SQL, proto file edits, and Rust code updates.
The client tasks below cover Drift table definitions, DAOs, models, services, sync engine, enums, and AGENT.md updates.

### Summary of all changes:

1. **`subjects` table renamed to `subject_teachers`** — was a junction table mapping teachers to subjects in a class.
2. **New global `subjects` table** — auto-incrementing integer PK, stores the subject catalog (e.g. "Mathematics", "English"). Replaces `CbcSubject`/`EightFourFourSubject` enum-to-int mapping. System/Super-only.
3. **New global `topics` table** — auto-inc PK, unique on `(subject, grade, name)`. Grade-specific subdivisions of a subject. System/Super-only.
4. **New `streams` table** — per-school, per-grade stream definitions. Replaces grades/streams from old `settings.data` JSON.
5. **New `mpesa` table** — per-school M-Pesa Daraja API config. PK = school id. Replaces old `settings.mpesa` JSON.
6. **`settings` table removed** — no longer needed.
7. **New `exam_grades` junction table** — replaces `exams.grade` + `exams.stream`. No NULL streams.
8. **`exams` table modified** — `grade`/`stream` columns removed, `name` column added.
9. **`papers` table modified** — optional `topic` column added (FK → `topics.id`).
10. **`mastery` table modified** — `grade` column removed, `subject`/`topic` now FK to new global tables.
11. **All `subject smallint` columns** across ~6 tables changed to `subject integer` referencing `subjects.id`.
12. **New `Resource.subjects` (index 18)** in the permission model.
13. **New `SyncAction` values** for subjects, topics, streams, mpesa, exam_grades.
14. **Migration approach:** No incremental migration — clean database restart. Update initial schema code in place.

---

### Task C01: Regenerate Dart proto stubs from updated server protos

**Files to create/modify:** `lib/proto/` (generated files)
**Context files to read:** `../ledger/protos/services/sync.proto`, `../ledger/protos/types/role.proto`

**Specification:**

After the server proto files are updated (server Tasks S04–S07), regenerate Dart stubs:

```sh
protoc --dart_out=grpc:lib/proto \
  -I../ledger/protos \
  ../ledger/protos/services/sync.proto \
  ../ledger/protos/services/authentication.proto \
  ../ledger/protos/types/role.proto \
  ../ledger/protos/types/user.proto \
  ../ledger/protos/types/member.proto \
  ../ledger/protos/types/verification.proto
```

Verify the generated files compile. Key changes to expect in generated code:
- `SubjectInsert` renamed to `SubjectTeacherInsert` (oneof field 12)
- New `SubjectInsert`, `TopicInsert`, `StreamInsert`, `MpesaInsert`, `ExamGradeInsert` messages
- `ExamInsert` no longer has `grade`/`stream`, has `name` instead
- `PaperInsert` has new `topic` field
- `MasteryInsert` no longer has `grade`
- `SettingsInsert` removed (field 25 reserved)
- New oneof fields 31–35 in `InsertData`
- New payload messages for all new actions
- `Resource` enum has `SUBJECTS = 18`
- `ExamGradeEntry` helper message

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C02: Rename `subjects.dart` → `subject_teachers.dart` and update Drift table

**Files to create/modify:** `lib/database/tables/subject_teachers.dart` (new), delete `lib/database/tables/subjects.dart` (old)
**Context files to read:** `lib/database/tables/subjects.dart`

**Specification:**

1. Delete `lib/database/tables/subjects.dart`.
2. Create `lib/database/tables/subject_teachers.dart`:

```dart
import 'package:drift/drift.dart';
import 'schools.dart';

class SubjectTeachers extends Table {
  @override
  String get tableName => 'subject_teachers';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get subject => integer()(); // FK → subjects.id (was smallint enum)
  TextColumn get teacher => text()();
  Int64Column get created => int64()();

  @override
  Set<Column> get primaryKey => {school, year, term, grade, stream, subject};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
    'FOREIGN KEY (subject)'
        ' REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
```

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md` if it exists
- [ ] Mark this task `[x]`

---

### Task C03: Create new `subjects.dart` Drift table (global catalog)

**Files to create:** `lib/database/tables/subjects.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'curriculum_subjects.dart';

/// Global subject catalog. Populated by System/Super users only.
/// NOT the same as the old `subjects` table (which is now `subject_teachers`).
class Subjects extends Table {
  @override
  String get tableName => 'subjects';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get curriculum =>
      integer().map(const CurriculumTypeConverter())();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();
}
```

Note: The `CurriculumTypeConverter` already exists in `curriculum_subjects.dart`.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C04: Create `topics.dart` Drift table

**Files to create:** `lib/database/tables/topics.dart`

**Specification:**

```dart
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
  List<String> get customConstraints => [
    'UNIQUE (subject, grade, name)',
  ];
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C05: Create `streams.dart` Drift table

**Files to create:** `lib/database/tables/streams.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'schools.dart';

/// Per-school stream definitions. Links a named stream to a grade.
class Streams extends Table {
  @override
  String get tableName => 'streams';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  TextColumn get name => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, grade, stream};
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C06: Create `mpesa.dart` Drift table

**Files to create:** `lib/database/tables/mpesa.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'schools.dart';

/// M-Pesa environment mode.
enum MpesaEnv {
  sandbox, // 0
  production, // 1
}

class MpesaEnvConverter extends TypeConverter<MpesaEnv, int> {
  const MpesaEnvConverter();
  @override
  MpesaEnv fromSql(int fromDb) => MpesaEnv.values[fromDb];
  @override
  int toSql(MpesaEnv value) => value.index;
}

/// Per-school M-Pesa Daraja API integration configuration.
class Mpesa extends Table {
  @override
  String get tableName => 'mpesa';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get consumerKey => text()();
  TextColumn get consumerSecret => text()();
  TextColumn get passkey => text()();
  TextColumn get shortcode => text()();
  IntColumn get env =>
      integer().map(const MpesaEnvConverter()).withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school};
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C07: Create `exam_grades.dart` Drift table

**Files to create:** `lib/database/tables/exam_grades.dart`

**Specification:**

```dart
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
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C08: Update `exams.dart` — add `name`, remove `grade` and `stream`

**Files to modify:** `lib/database/tables/exams.dart`
**Context files to read:** `lib/database/tables/exams.dart`

**Specification:**

Replace the current `Exams` table definition:

```dart
import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

class Exams extends Table {
  @override
  String get tableName => 'exams';

  TextColumn get id => text()();
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  BoolColumn get personalized => boolean().withDefault(const Constant(false))();
  IntColumn get type => integer().map(const ExamTypeConverter())();
  IntColumn get start => integer()(); // days since epoch
  IntColumn get end => integer()(); // days since epoch
  TextColumn get teacher => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (start < end)',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
  ];
}
```

Key changes: `grade` and `stream` columns removed, `name` column added.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C09: Update `papers.dart` — add optional `topic`

**Files to modify:** `lib/database/tables/papers.dart`
**Context files to read:** `lib/database/tables/papers.dart`

**Specification:**

Add a nullable `topic` column to the `Papers` table and add the FK constraint.

After `paper` column:
```dart
  IntColumn get topic => integer().nullable()(); // FK → topics.id
```

Add to `customConstraints` list:
```dart
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
    'FOREIGN KEY (topic) REFERENCES topics(id) ON DELETE SET NULL',
```

Also change `subject` column — it was `integer()` already but had no FK. Now it FKs to `subjects.id`. Remove the old implicit subject usage and ensure the FK is in customConstraints.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C10: Update `mastery.dart` — remove `grade`, FK to subjects and topics

**Files to modify:** `lib/database/tables/mastery.dart`
**Context files to read:** `lib/database/tables/mastery.dart`

**Specification:**

Replace entirely:

```dart
import 'package:drift/drift.dart';
import 'schools.dart';
import 'subjects.dart';
import 'topics.dart';

class Mastery extends Table {
  @override
  String get tableName => 'mastery';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get student => integer()();
  IntColumn get subject =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get topic =>
      integer().references(Topics, #id, onDelete: KeyAction.cascade)();
  RealColumn get score => real()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, student, subject, topic};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
  ];
}
```

Key: `grade` column removed. PK is now `(school, student, subject, topic)`.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C11: Update `grades.dart` — change subject type, add FK

**Files to modify:** `lib/database/tables/grades.dart`
**Context files to read:** `lib/database/tables/grades.dart`

**Specification:**

The `subject` column type stays `integer()` (it was already integer in Drift even when schema said smallint). Add a FK constraint to the customConstraints:

```dart
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C12: Update `lessons.dart` and `timetable.dart` — update FK references

**Files to modify:** `lib/database/tables/lessons.dart`, `lib/database/tables/timetable.dart`
**Context files to read:** Both files

**Specification:**

In both files, find any FK reference to `subjects(...)` and change to `subject_teachers(...)`.

In `lessons.dart`, the custom constraint:
```dart
'FOREIGN KEY (school, year, term, grade, stream, subject) REFERENCES subject_teachers(school, year, term, grade, stream, subject) ON DELETE RESTRICT'
```

In `timetable.dart`, the custom constraint:
```dart
'FOREIGN KEY (school, year, term, grade, stream, subject, teacher) REFERENCES subject_teachers(school, year, term, grade, stream, subject, teacher) ON DELETE CASCADE ON UPDATE CASCADE'
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C13: Delete `settings.dart` Drift table

**Files to delete:** `lib/database/tables/settings.dart`

**Specification:**

Delete the file entirely. The `settings` table is removed from the schema.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C14: Update `enums.dart` — add new SyncAction values, add MpesaEnv reference

**Files to modify:** `lib/database/tables/enums.dart`
**Context files to read:** `lib/database/tables/enums.dart`

**Specification:**

1. In the `SyncAction` enum, mark value 66 (`updateSettings`) as deprecated and add new values at the end:

```dart
  // Settings — DEPRECATED (table removed)
  @Deprecated('Settings table removed in schema v2')
  updateSettings(66),
```

Add new values after `deleteDiscount(76)`:

```dart
  // Subjects (global catalog)
  createSubject(77),
  updateSubject(78),
  deleteSubject(79),
  // Topics (global catalog)
  createTopic(80),
  updateTopic(81),
  deleteTopic(82),
  // Streams (per-school)
  createStream(83),
  updateStream(84),
  deleteStream(85),
  // M-Pesa (per-school)
  createMpesa(86),
  updateMpesa(87),
  deleteMpesa(88),
  // Exam Grades (junction)
  addExamGrade(89),
  removeExamGrade(90);
```

Total enum values: 91 (0–90).

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C15: Update `database.dart` — register new tables, remove Settings

**Files to modify:** `lib/database/database.dart`
**Context files to read:** `lib/database/database.dart`

**Specification:**

1. Add imports for new table files:
   - `tables/subject_teachers.dart`
   - `tables/topics.dart`
   - `tables/streams.dart`
   - `tables/mpesa.dart`
   - `tables/exam_grades.dart`

2. Remove import for `tables/settings.dart`.

3. In the `@DriftDatabase(tables: [...])` annotation:
   - Remove `Settings`
   - Replace old `Subjects` with `SubjectTeachers`
   - Add: `Subjects` (the new global one), `Topics`, `Streams`, `Mpesa`, `ExamGrades`

4. Update `MigrationStrategy.onCreate`:
   - Remove any raw SQL for `settings` indexes/triggers
   - Remove the `exams_stream_consistency_check` trigger
   - Update `grades_enrollment_check` trigger to JOIN through `exam_grades`
   - Update `grades_enrollment_check_update` trigger similarly
   - Add unique index: `CREATE UNIQUE INDEX uq_subjects_name_curriculum ON subjects(name, curriculum)`
   - Add unique index: `CREATE UNIQUE INDEX uq_topics_subject_grade_name ON topics(subject, grade, name)`
   - Add index: `CREATE INDEX idx_topics_subject ON topics(subject)`
   - Add index: `CREATE INDEX idx_streams_school ON streams(school, grade)`
   - Add index: `CREATE INDEX idx_exam_grades_grade ON exam_grades(grade, stream)`
   - Rename `subjects_class_teacher_idx` → `subject_teachers_class_teacher_idx` referencing `subject_teachers`
   - Rename `idx_subjects_school_teacher` → `idx_subject_teachers_school_teacher` referencing `subject_teachers`
   - Update `papers_within_exam_range` trigger if it references `exams.grade`/`exams.stream`

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C16: Update `delta_writer.dart` — handle new/renamed InsertData variants

**Files to modify:** `lib/sync/delta_writer.dart`
**Context files to read:** `lib/sync/delta_writer.dart`

**Specification:**

After proto stubs are regenerated (Task C01), update the `DeltaWriter` to handle:

1. Renamed: `InsertData.subject` (old) → `InsertData.subjectTeacher` (new, field 12 of oneof). The `SubjectTeacherInsert` maps to the `subject_teachers` table.

2. Removed: `InsertData.settings` (field 25) — remove the case that handled `SettingsInsert`.

3. New cases to add:
   - `InsertData.subjectCatalog` (field 31) → upsert into `subjects` table
   - `InsertData.topic` (field 32) → upsert into `topics` table
   - `InsertData.stream` (field 33) → upsert into `streams` table
   - `InsertData.mpesa` (field 34) → upsert into `mpesa` table
   - `InsertData.examGrade` (field 35) → upsert into `exam_grades` table

4. Update the `ExamInsert` handler — no longer has `grade`/`stream` fields, now has `name`.

5. Update the `PaperInsert` handler — now has optional `topic` field.

6. Update the `MasteryInsert` handler — no longer has `grade` field.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C17: Update `curriculum_subjects.dart` — deprecate enum-to-int approach

**Files to modify:** `lib/database/tables/curriculum_subjects.dart`

**Specification:**

The `CbcSubject` and `EightFourFourSubject` enums are no longer used as database column values — subjects are now rows in the `subjects` table with auto-inc integer IDs. However, these enums and their labels may still be useful as a reference/seed list.

1. Add a comment at the top of the file:
```dart
// NOTE: CbcSubject and EightFourFourSubject enums are no longer used as
// database column values. Subjects are now rows in the global `subjects` table.
// These enums are retained as a reference for seeding the subjects table
// and for label display. The CurriculumType enum and its converter ARE still
// actively used by the new `subjects` table.
```

2. Keep `CurriculumType` and `CurriculumTypeConverter` — these are actively used.
3. Keep `CbcSubject` and `EightFourFourSubject` with their labels — useful for seeding.
4. Keep `KenyaCounty` and its converter — unrelated to this change, still used.
5. Remove `CbcSubjectConverter` and `EightFourFourSubjectConverter` — no longer needed since subjects are no longer stored as enum int values.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C18: Update models — `permissions.dart` add `Resource.subjects`

**Files to modify:** `lib/models/permissions.dart`
**Context files to read:** `lib/models/permissions.dart`

**Specification:**

Add `subjects` to the `Resource` enum at index 18 (after `ai`):

```dart
enum Resource {
  users,        // 0
  schools,      // 1
  owners,       // 2
  teachers,     // 3
  staff,        // 4
  students,     // 5
  departments,  // 6
  classes,      // 7
  attendance,   // 8
  lessons,      // 9
  exams,        // 10
  grades,       // 11
  fees,         // 12
  payments,     // 13
  announcements,// 14
  roles,        // 15
  plans,        // 16
  ai,           // 17
  subjects,     // 18  — global subject/topic catalog
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C19: Update DAOs — rename and add new DAOs as needed

**Files to modify:** Relevant DAO files in `lib/database/daos/`
**Context files to read:** `lib/database/daos/` directory listing

**Specification:**

1. Find any DAO that references the old `Subjects` Drift table (the class, not the table name) and update to `SubjectTeachers`.

2. Find any DAO that references `Settings` and remove those methods.

3. Find any DAO query referencing `exams.grade` or `exams.stream` and update to JOIN through `exam_grades`.

4. Find any DAO query referencing `mastery.grade` and remove that column from the query.

5. Add DAO methods for new tables if needed:
   - `subjects` (global catalog): `watchSubjects()`, `watchSubjectsByCurriculum(CurriculumType)`, insert/update/delete
   - `topics`: `watchTopicsBySubjectAndGrade(int subjectId, int grade)`, insert/update/delete
   - `streams`: `watchStreamsBySchoolAndGrade(String schoolId, int grade)`, insert/update/delete
   - `mpesa`: `watchMpesa(String schoolId)`, insert/update/delete
   - `exam_grades`: CRUD as part of exam operations

These can be added to existing domain-grouped DAOs or new ones as appropriate.

**Update after completion:**
- [ ] Update relevant `CONTEXT.md` files
- [ ] Mark this task `[x]`

---

### Task C20: Update `AGENT.md` — reflect all schema changes

**Files to modify:** `AGENT.md`

**Specification:**

Update the following sections:

1. **§5 Database Design** — mention the new tables (`subjects`, `topics`, `streams`, `mpesa`, `exam_grades`) and the rename (`subjects` → `subject_teachers`). Note `settings` table is removed.

2. **§7a SyncAction Enum** — update to show 91 values (0–90) including the new ones. Mark `updateSettings(66)` as deprecated.

3. **§4 Folder Structure** — no structural change needed, but note new table files.

4. **§13 Division of Labour** — no change needed.

5. **§17a Resource & Action Design** — add `Resource.subjects` (index 18) to the Resource table:
   | 19 | Subjects | `subjects`, `topics` | System/Super-only catalog management |

   Add to Action Context Per Resource table:
   | Subjects | Create, Read, Update, Delete |

6. **§14 gRPC Proto Files** — update `sync.pb.dart` and `sync.pbgrpc.dart` notes to reflect new Insert messages, renamed `SubjectTeacherInsert`, removed `SettingsInsert`, new payload messages.

7. **§12 Pending / Undecided Items** — no new items from this change.

8. **§2 Tech Stack** — no change.

9. **§5.1 Overview** — update table count: the total is now 30 backend tables minus `settings` (29) plus `subjects`, `topics`, `streams`, `mpesa`, `exam_grades` = **34 synced backend tables** plus 2 client-only (`accounts`, `logs`). Update the count accordingly.

10. **§16 Sync Strategy - Current Network Boundary** — no change (sync actions are already covered).

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C21: Run `build_runner` and fix compilation errors

**Specification:**

```sh
dart run build_runner build --delete-conflicting-outputs
```

Fix any compilation errors:
- Missing imports due to renamed/deleted files
- Type mismatches from changed column types
- References to removed `Settings` table/data class
- References to old `SubjectsData` (now `SubjectTeachersData`)
- References to removed `exams.grade`/`exams.stream`/`mastery.grade`

After fixing:
```sh
flutter analyze
```

Ensure zero errors. Warnings about the deprecated `updateSettings` are acceptable.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C22: Update `client.dart` and services — remove settings references

**Files to modify:** `lib/client.dart`, any service file referencing settings
**Context files to read:** `lib/client.dart`

**Specification:**

1. Search for any reference to `Settings`, `SettingsData`, `UpdateSettingsPayload`, or `settings` table across all service files.
2. Remove those references.
3. If `client.dart` or any service exposes a `updateSettings` method, remove it.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C23: Update `schema.sql` — apply all changes to the client reference schema

**Files to modify:** `schema.sql` (project root)

**Specification:**

The `schema.sql` at the project root serves as the client-side reference for the database schema. Apply ALL the same changes that were applied to the server migration SQL:

1. Add `subjects` (global catalog) and `topics` tables
2. Rename old `subjects` → `subject_teachers`, change subject column type
3. Add `streams`, `mpesa` tables
4. Remove `settings` table
5. Modify `exams` — add `name`, remove `grade`/`stream`
6. Add `exam_grades` junction table
7. Modify `papers` — add `topic`, change `subject` type
8. Modify `grades` — change `subject` type, add FK
9. Modify `mastery` — remove `grade`, change `subject`/`topic` types, add FKs
10. Modify `lessons`/`timetable` — change `subject` type, update FK refs
11. Update all affected triggers
12. Update all affected indexes

This file must match the server migration SQL exactly (minus client-only `accounts` and `logs` tables which stay as-is).

**Update after completion:**
- [ ] Mark this task `[x]`

---