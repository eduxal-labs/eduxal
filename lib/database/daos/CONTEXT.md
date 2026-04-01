# database/daos/ — Data Access Objects Context

> One DAO per domain group. Each DAO contains typed query, insert, update, delete, and `watch` (reactive stream) methods.
> All DAO files have a corresponding `.g.dart` generated file (Drift code-gen output — never edit manually).

## Overview

DAOs are the **only** way services and UI interact with the database. No raw SQL or direct table access outside this directory.

Each DAO extends `DatabaseAccessor<AppDatabase>` and is annotated with `@DriftAccessor(tables: [...])` listing the tables it queries.

## Files

| File | DAO Class | Domain | Status |
|---|---|---|---|
| `academics_dao.dart` | `AcademicsDao` | Grade-detail-level academic queries (students, subjects, class teachers, stream comparison) | ✅ Complete |
| `accounts_dao.dart` | `AccountsDao` | Auth session management | ✅ Complete |
| `announcements_dao.dart` | `AnnouncementsDao` | School announcements | ✅ Complete |
| `attendance_dao.dart` | `AttendanceDao` | Student attendance tracking | ✅ Complete |
| `departments_dao.dart` | `DepartmentsDao` | School departments | ✅ Complete |
| `enrollments_dao.dart` | `EnrollmentsDao` | Student grade/stream enrollments | ✅ Complete |
| `exams_grades_dao.dart` | `ExamsGradesDao` | Exams, papers, grades, mastery | ✅ Complete |
| `finance_dao.dart` | `FinanceDao` | Fees, invoices, payments, discounts | ✅ Complete |
| `logs_dao.dart` | `LogsDao` | Offline mutation queue (logs table) | ✅ Complete |
| `members_dao.dart` | `MembersDao` | CRUD for owners, teachers, staff, students, guardians + teacher assignment queries | ✅ Complete |
| `memberships_dao.dart` | `MembershipsDao` | Home screen membership assembly | ✅ Complete |
| `plans_dao.dart` | `PlansDao` | Subscription plans management | ✅ Complete |
| `roles_dao.dart` | `RolesDao` | System-level roles + permissions | ✅ Complete |
| `school_scopes_dao.dart` | `SchoolScopesDao` | School-scoped roles + scopes | ✅ Complete |
| `schools_dao.dart` | `SchoolsDao` | School CRUD + reactive streams | ✅ Complete |
| `settings_dao.dart` | `SettingsDao` | School settings (SchoolConfig JSON) | ✅ Complete |
| `subjects_dao.dart` | `SubjectsDao` | Subject-teacher assignments | ✅ Complete |
| `system_stats_dao.dart` | `SystemStatsDao` | System dashboard aggregate stats | ✅ Complete |
| `terms_dao.dart` | `TermsDao` | Academic year/term management | ✅ Complete |
| `timetable_dao.dart` | `TimetableDao` | Timetable + lessons | ✅ Complete |
| `users_dao.dart` | `UsersDao` | User CRUD + lookups | ✅ Complete |
| `ai_usage_dao.dart` | `AiUsageDao` | AI credit usage tracking per student | ✅ Complete |

## Key Methods by DAO

### `AcademicsDao`
- `watchStudentsForGrade({required String schoolId, required int year, required int term, required int grade, int? stream}) → Stream<List<GradeStudentRow>>` — Reactively watches enrolled students for a grade/stream, enriched with trajectory (from last 2 exams) and exam averages. Joins enrollments + students, then asyncMap computes grades data. Ordered by student name ascending.
- `watchStudentCount({required String schoolId, required int year, required int term, required int grade, int? stream}) → Stream<int>` — Simple reactive count of enrollments matching the filter.
- `watchSubjectsForGrade({required String schoolId, required int year, required int term, required int grade, int? stream}) → Stream<List<SubjectTeacherEntry>>` — Reactively watches subject-teacher assignments joined with users, enriched with stream-level and grade-level mastery averages via asyncMap.
- `watchClassTeachersForGrade({required String schoolId, required int year, required int term, required int grade, int? stream}) → Stream<List<ClassTeacherHistoryEntry>>` — Reactively watches class teacher assignments joined with users. Active first (end IS NULL), then by start descending.
- `computeStreamComparison({required String schoolId, required int year, required int term, required int grade, required List<({int code, String name})> streams}) → Future<List<StreamStats>>` — One-shot computation building StreamStats for each stream from enrollments, grades, exams, attendance, and mastery. Ordered by stream code.
- `watchExamsForGradeStream({required String schoolId, required int year, required int term, required int grade, required int streamCode}) → Stream<List<ExamWithPapers>>` — Reactively watches exams for a grade+stream, INCLUDING grade-wide exams (where `exam.stream IS NULL`). Joins with papers and teacher user. Ordered by exam start descending. Uses `ExamWithPapers` typedef imported from `exams_grades_dao.dart`.
- `computeAttendanceRate({required String schoolId, required int year, required int term, required int grade, required int stream}) → Future<double?>` — One-shot computation of attendance rate (0–100) for a specific stream. Returns `null` if no attendance data exists. Counts rows where `status == AttendanceStatus.present` over total rows.
- `computeStudentAttendance({required String schoolId, required int year, required int term, required int studentAdm}) → Future<({int present, int absent, int leave})>` — One-shot computation of attendance summary for a single student in a term. Returns named record with present/absent/leave counts.
- `computeStudentTrajectory({required String schoolId, required int studentAdm, required int grade}) → Future<({Trajectory trajectory, double? lastExamPercent, double? overallAverage})>` — One-shot computation of a single student's trajectory based on their exam performance across a grade. Compares average scores of the two most recent exams. Also returns last exam percentage and overall average across all exams.
- `batchComputeTrajectories({required String schoolId, required int grade, required List<int> studentAdms}) → Future<Map<int, ({Trajectory trajectory, double? lastExamPercent, double? overallAverage})>>` — Batch version of `computeStudentTrajectory`. Fetches all exams and grades for the grade in single queries, then groups and computes per-student in Dart. More efficient than calling the single-student version in a loop.
- `computeStreamSubjectMastery({required String schoolId, required int year, required int term, required int grade, required int stream, required int subject}) → Future<double?>` — One-shot computation of average mastery score for a specific (subject, stream) combination. Gets enrolled students in the stream, then averages all mastery rows (across all topics) for those students and the given subject. Returns `null` if no mastery data.
- `computeGradeSubjectMastery({required String schoolId, required int grade, required int subject}) → Future<double?>` — One-shot computation of average mastery score for a subject across ALL streams in a grade. Queries mastery rows by (school, grade, subject) without filtering by student enrollment. Returns `null` if no mastery data.
- `computeStreamMasteryAverage({required String schoolId, required int year, required int term, required int grade, required int stream}) → Future<double?>` — One-shot computation of average mastery across all subjects and topics for students in a stream. Used for the stream comparison card. Gets enrolled students, then averages all their mastery rows for the grade. Returns `null` if no mastery data.
- `computeExamTrend({required String schoolId, required int year, required int term, required int grade, required List<({int code, String name})> streams, int maxExams = 5}) → Future<Map<int, List<({String label, double percent})>>>` — One-shot computation of exam performance trends per stream. Returns a map keyed by stream code, each value a chronologically-ordered list of `(label, percent)` records for the last `maxExams` exams. Labels are abbreviated by type: "E1" for exam, "A1" for assignment, "As1" for assessment. For each exam, computes average student score (subject-level totals, paper IS NULL) for enrolled students in each stream. Used by the Comparisons tab trend chart.

### `AccountsDao`
- `getActiveAccount() → Future<Authenticated?>` — Joins `accounts` + `users` where `is_active = 1`. Returns domain model.
- `watchActiveAccount() → Stream<Authenticated?>` — Reactive version of above.
- `getAllAccounts() → Future<List<Authenticated>>` — All stored accounts joined with users.
- `upsertAccount(AccountsCompanion) → Future<void>` — Insert or replace account row.
- `setActiveAccount(String id) → Future<void>` — Deactivates all, activates the given id.
- `deleteAccount(String id) → Future<void>` — Removes account row by id.
- `updateLastSeq(String id, int seq) → Future<void>` — Updates the server sync sequence number after each successful `WatchChanges` delta.
- `updateTheme(String id, AppThemeMode theme) → Future<void>` — Updates theme preference.

### `UsersDao`
- `upsertUser(UsersCompanion) → Future<void>` — Insert or replace user row.
- `getUserById(String id) → Future<UsersData?>` — Single user lookup.
- `getUserByPhone(String phone) → Future<UsersData?>` — Lookup by phone number.
- `watchAllUsers() → Stream<List<UsersData>>` — Reactive list of all users.

### `LogsDao`
- `insertLog(LogsCompanion) → Future<void>` — Enqueue an action log entry (action, resource, payload, created).
- `getPendingLogs(String accountId) → Future<List<LogsData>>` — All pending entries for an account, oldest first.
- `getFailedLogs(String accountId) → Future<List<LogsData>>` — All failed entries for an account.
- `watchFailedLogs(String accountId) → Stream<List<AppNotification>>` — Failed logs as `AppNotification` objects for the notifications panel.
- `watchFailedLogCount(String accountId) → Stream<int>` — Reactive COUNT of failed logs for badge display.
- `deleteLog(int id) → Future<void>` — Remove a single synced/resolved log entry.
- `deleteLogs(List<int> ids) → Future<void>` — Remove multiple log entries by IDs.
- `markFailed(int id, String error) → Future<void>` — Mark a log as failed with error message and increment attempts.

**Removed methods (action-based redesign):**
- `collapseUpdateLogs` — no more column bitmask coalescing
- `supersedWithDelete` — no more delete-supersedes-insert logic

### `MembershipsDao`
- `watchMemberships(String userId) → Stream<List<SchoolMembership>>` — Assembles all five membership tables + schools into `SchoolMembership` list for the home screen.

> **Note:** `MembershipsDao` is intentionally **excluded** from `@DriftDatabase(daos: [...])` in `database.dart` to avoid a circular import. It imports `database.dart` for generated types but `database.dart` must not import `membership.dart` (even transitively). It is instantiated manually in `client.dart`.

### `MembersDao`
- `watchOwners(String schoolId) → Stream<List<OwnersData>>` — All owners for a school.
- `watchTeachers(String schoolId) → Stream<List<TeachersData>>` — All teachers for a school.
- `watchStaff(String schoolId) → Stream<List<StaffData>>` — All staff for a school.
- `watchStudents(String schoolId) → Stream<List<StudentsData>>` — All students for a school.
- `watchAllStudents(String schoolId) → Stream<List<StudentsData>>` — ALL students regardless of status, ordered by adm ascending.
- `watchStudent(String schoolId, int adm) → Stream<StudentsData?>` — Reactively watches a single student row. Returns `null` if not found.
- `searchStudents(String schoolId, String query) → Future<List<StudentsData>>` — Searches active students by name (case-insensitive LIKE) or admission number (exact match). Returns up to 50 results. One-shot, not a stream.
- `watchGuardians(String schoolId, int studentAdm) → Stream<List<GuardiansData>>` — Guardians for a specific student.
- `watchAllGuardians(String schoolId) → Stream<List<GuardiansData>>` — All guardians at school.
- `watchClassTeacherAssignments(String schoolId, String teacherUserId) → Stream<List<ClassTeacher>>` — All class_teachers rows for a teacher at a school, across all years/terms. Ordered by year desc, grade asc.
- `watchTeacherSubjects(String schoolId, String teacherUserId) → Stream<List<Subject>>` — All subjects rows assigned to a teacher at a school, across all years/terms. Ordered by year desc, grade asc.
- `watchUniqueGuardians(String schoolId) → Stream<List<({UsersData user, int wardCount})>>` — Deduped guardians with ward count.
- `watchGuardianWards(String schoolId, String guardianUserId) → Stream<List<({GuardiansData guardian, StudentsData? student})>>` — Guardian links with ward data.
- `isClassTeacherFor({schoolId, year, term, grade, stream, teacherUserId}) → Future<bool>` — Returns `true` if the teacher is the active class teacher for the given grade/stream (row in `class_teachers` with `end IS NULL`). Used by the attendance tab to restrict marking to class teachers only.
- `ownerExists(schoolId, userId) → Future<bool>`, `teacherExists(...)`, `staffExists(...)`, `guardianExists(...)` — Duplicate checks.
- **Mutation methods (action-based logging):**
  - `inviteAndAddOwner(newUser, owner, accountId)` — Creates invited user + owner row + single `SyncAction.createOwner` log with `CreateOwnerPayload`.
  - `addExistingUserAsOwner(owner, existingUser, accountId)` — Links existing user as owner + `SyncAction.createOwner` log. **Signature changed in C9:** now requires `UsersData existingUser` parameter.
  - `removeOwner(schoolId, userId, accountId)` — Deletes owner + `SyncAction.deleteOwner` log.
  - `inviteAndAddTeacher(newUser, teacher, accountId)` — Creates invited user + teacher + single `SyncAction.createTeacher` log with `CreateTeacherPayload`.
  - `addExistingUserAsTeacher(teacher, existingUser, accountId)` — Links existing user + `SyncAction.createTeacher` log. **Signature changed in C9:** now requires `UsersData existingUser`.
  - `updateTeacher(schoolId, userId, changes, accountId)` — Updates teacher + `SyncAction.updateTeacher` log with `UpdateTeacherPayload` (protobuf `has*()` semantics, no bitmask).
  - `removeTeacher(schoolId, userId, accountId)` — Deletes teacher + `SyncAction.deleteTeacher` log.
  - `inviteAndAddStaff(newUser, member, accountId)` — Creates invited user + staff + single `SyncAction.createStaff` log.
  - `addExistingUserAsStaff(member, existingUser, accountId)` — Links existing user + `SyncAction.createStaff` log. **Signature changed in C9:** now requires `UsersData existingUser`.
  - `updateStaff(schoolId, userId, changes, accountId)` — Updates staff + `SyncAction.updateStaff` log.
  - `removeStaff(schoolId, userId, accountId)` — Deletes staff + `SyncAction.deleteStaff` log.
  - `createStudent(student, accountId)` — Creates student + `SyncAction.createStudent` log with `CreateStudentPayload`.
  - `updateStudent(schoolId, adm, changes, accountId)` — Updates student + `SyncAction.updateStudent` log with `UpdateStudentPayload`.
  - `linkStudentToUser(schoolId, adm, userId, accountId)` — Convenience wrapper around `updateStudent`.
  - `inviteAndAddGuardian(newUser, guardian, accountId)` — Creates invited user + guardian + single `SyncAction.createGuardian` log.
  - `addExistingUserAsGuardian(guardian, existingUser, accountId)` — Links existing user + `SyncAction.createGuardian` log. **Signature changed in C9:** now requires `UsersData existingUser`.
  - `updateGuardian(schoolId, userId, studentAdm, changes, accountId)` — Updates guardian + `SyncAction.updateGuardian` log.
  - `removeGuardian(schoolId, userId, studentAdm, accountId)` — Deletes guardian + `SyncAction.deleteGuardian` log.
- **Key change in C9:** Invitation methods no longer write a separate `users` INSERT log. The user identity (phone, name, email) is embedded in the member payload (e.g. `CreateTeacherPayload.phone/name/email`). The server handles user lookup/creation from the payload. This eliminates the old two-log invitation pattern.

### `SchoolsDao`
- `watchSchools() → Stream<List<SchoolsData>>` — All schools (unordered).
- `watchAllSchools() → Stream<List<SchoolsData>>` — All schools ordered by name ascending.
- `watchOwnersForSchool(String schoolId) → Stream<List<({OwnersData owner, UsersData user})>>` — Owners joined with users.
- `getSchool(String id) → Future<SchoolsData?>` — Single school by id.
- `upsertSchool(SchoolsCompanion) → Future<void>` — Sync-sourced insert or replace (no log).
- **Mutation methods (action-based logging):**
  - `createSchool(school, ownerUser, accountId)` — Creates school + owner row + single `SyncAction.createSchool` log with `CreateSchoolPayload` (includes embedded owner identity). **Signature changed in C9:** takes `UsersData ownerUser` instead of `String ownerUserId`.
  - `updateSchoolDetails(schoolId, changes, accountId)` — Updates school + `SyncAction.updateSchool` log with `UpdateSchoolPayload` (protobuf `has*()` semantics, no bitmask).
  - `updateSchoolStatus(schoolId, status, accountId)` — Convenience wrapper around `updateSchoolDetails`.
  - `purgeSchool(schoolId, accountId)` — Deletes school + `SyncAction.deleteSchool` log.
  - `linkOwner(schoolId, ownerUser, accountId)` — Links existing user as owner + `SyncAction.createOwner` log. **Signature changed in C9:** takes `UsersData ownerUser` instead of `String userId`.
  - `isOwner(schoolId, userId) → Future<bool>` — Duplicate check.
  - `logLogoChange(schoolId, accountId)` — Placeholder for logo file sync (currently no-op).

### `TermsDao`
- `watchTerms(String schoolId) → Stream<List<Term>>` — All terms for a school, ordered year desc / term asc.
- `insertTerm(TermsCompanion) → Future<void>`
- `updateTerm(TermsCompanion) → Future<void>`
- `getCurrentTerm(String schoolId) → Future<Term?>` — Term where `start <= now <= end`.

### `SettingsDao`
- `watchSettings(String schoolId) → Stream<SettingsData?>` — Reactive settings row.
- `getSettings(String schoolId) → Future<SettingsData?>` — One-shot read.
- `updateSchoolConfig(String schoolId, SchoolConfig config) → Future<void>` — Serializes config to JSON and writes to `settings.data`.
- `updateMpesaConfig(String schoolId, MpesaConfig config) → Future<void>` — Writes to `settings.mpesa`.

### `DepartmentsDao`
- `watchDepartments(String schoolId) → Stream<List<DepartmentsData>>`
- `insertDepartment(...)`, `deleteDepartment(...)`

### `SubjectsDao`
- `watchSubjects(schoolId, year, term) → Stream<List<SubjectsData>>`
- `watchSubjectsForTeacher(schoolId, year, term, teacherId) → Stream<List<SubjectsData>>`
- `getSubjectsForClass(schoolId, year, term, grade, stream) → Future<List<({Subject subject, UsersData teacher})>>` — one-shot read of all subject assignments for a specific class, joined with teacher user data. Used by the exam creation form.
- `insertSubject(...)`, `deleteSubject(...)`

### `EnrollmentsDao`
- `watchEnrollments(schoolId, year, term) → Stream<List<EnrollmentsData>>`
- `insertEnrollment(...)`, `deleteEnrollment(...)`

### `AttendanceDao`
- `watchAttendance(schoolId, date, grade, stream) → Stream<List<AttendanceData>>`
- `upsertAttendance(...)` — Insert or update attendance record.
- `markAllPresent(schoolId, date, grade, stream, studentIds) → Future<void>`

### `ExamsGradesDao`
- `watchExams(schoolId, year, term) → Stream<List<ExamsData>>`
- `watchPapers(examId) → Stream<List<PapersData>>`
- `watchGrades(paperId) → Stream<List<GradesData>>`
- `upsertGrade(...)` — Insert or update a grade.
- `watchPaper({required String schoolId, required String examId, required int subject, required int? paperNum}) → Stream<Paper?>` — Watches a single paper row by composite key, emitting null if it is deleted. Used by `paper_detail_page.dart` to reactively update status chips and action buttons without requiring page re-entry.
- `watchMastery(schoolId, student, year, term) → Stream<List<MasteryData>>`
- `watchStudentGrades(String schoolId, int studentAdm) → Stream<List<Grade>>` — All grades for a specific student, ordered by created desc. Used by student detail page.
- `watchClassGrades({required String schoolId, required String examId}) → Stream<List<Grade>>` — All grades for an exam at a school. Used by class performance analytics.
- `computeClassAnalytics({required String schoolId, required String examId}) → Future<Map<int, PaperAnalytics>>` — Computes per-subject average scores and grade distributions for a whole exam. Groups by subject using subject-level totals (paper == null), falls back to all grades if none exist.
- `createExamBatch({required List<ExamBatchEntry> entries, required String accountId}) → Future<void>` — Creates multiple exams and their associated papers in a single Drift transaction. Writes one `SyncAction.createExam` log per exam and one `SyncAction.createPaper` log per paper. Used by the multi-grade exam creation UI. `ExamBatchEntry` typedef = `({ExamsCompanion exam, List<PapersCompanion> papers})`.
- `watchExamGroups({required String schoolId, required int year, required int term}) → Stream<List<ExamGroup>>` — Emits all exams for a term grouped by **exam name** into `ExamGroup` objects. Each group contains `ExamGradeEntry` per grade, each with `ExamStreamEntry` per stream (with papers). Sorted by start date descending (most recent first). Uses `asyncMap` to join teacher user data and papers. *(Changed from grouping by `(type, start, end)` to grouping by `exam.name` to fix bug where exams with same type+date-range but different names were incorrectly merged.)*
- `updateExamGroupDateRange({required String schoolId, required int year, required int term, required ExamType type, required int oldStart, required int oldEnd, required int newStart, required int newEnd, required String accountId}) → Future<void>` — Updates the date range for ALL exam rows sharing the same group key atomically. Writes one `SyncAction.updateExam` log per exam row. Used when extending an exam's date range from the paper creation sheet.
- `updateExamName({required List<String> examIds, required String name, required String accountId}) → Future<void>` — Updates the `name` field on all exam rows in `examIds` atomically in a single transaction. Writes one `SyncAction.updateExam` log entry per exam ID. Used by the edit-exam-name bottom sheet in `_ExamGroupDetailViewState`.
- `addGradeToExamGroup({required ExamGroup group, required int grade, required List<int?> streams, required List<PapersCompanion> papers, required String teacherId, required String accountId}) → Future<List<String>>` — Creates new exam rows (one per stream) for a new grade within an existing group, plus associated papers. Writes `SyncAction.createExam` and `SyncAction.createPaper` logs. Returns created exam IDs.
- `_generateExamId() → String` — Private helper generating unique exam IDs in format `ex_{timestamp_base36}_{random_hex4}`.

### `FinanceDao`
- `watchFees(schoolId, year, term) → Stream<List<FeesData>>`
- `watchInvoices(schoolId, ...) → Stream<List<InvoicesData>>`
- `watchPayments(invoiceId) → Stream<List<PaymentsData>>`
- `watchDiscounts(schoolId) → Stream<List<DiscountsData>>`
- Insert/update methods for each entity.

### `AnnouncementsDao`
- `watchAnnouncements(schoolId, ...) → Stream<List<AnnouncementsData>>`
- `insertAnnouncement(...)`, `updateAnnouncement(...)`, `deleteAnnouncement(...)`

### `TimetableDao`
- `watchClassTimetable(schoolId, year, term, grade, stream?) → Stream<List<TimetableEntry>>` — timetable for a specific class, joined with teacher and subject name.
- `watchTeacherTimetable(schoolId, year, term, teacherUserId) → Stream<List<TimetableData>>` — teacher's weekly schedule across all classes.
- `watchClassDayTimetable(schoolId, year, term, grade, stream, day) → Stream<List<TimetableEntry>>` — single-day view for mobile pager.
- `watchTermTimetable(schoolId, year, term) → Stream<List<TimetableEntry>>` — full term timetable across all classes.
- `watchHasTimetable(schoolId, year, term) → Stream<bool>` — reactively emits true when any timetable entry exists.
- `watchSchoolWideTimetable(schoolId, year, term) → Stream<List<SchoolWideTimetableEntry>>` — **NEW (TT-02):** all timetable entries for a school+year+term, joined with teacher display name (from `users`) and subject name (from `subjects` catalog). Ordered by day then start time. Used by `_SchoolWideMatrixTab` in the owner/admin timetable view. Returns a flat list; the UI groups into Day → Grade → Stream hierarchy.
- `watchClassLessons(schoolId, year, term, grade, stream, date) → Stream<List<LessonEntry>>` — lessons for a class on a specific date.
- `watchTeacherLessons(schoolId, year, term, teacherUserId, date) → Stream<List<Lesson>>` — teacher's lessons on a specific date.
- `watchClassTermLessons(schoolId, year, term, grade, stream) → Stream<List<LessonEntry>>` — all lessons for a class in a term.
- `watchAllLessons(schoolId, year, term) → Stream<List<LessonEntry>>` — **NEW (TT-01):** all lessons across ALL classes for the school in the term, joined with teacher and subject name. Ordered date desc, subject asc. Used by the Lessons tab in the owner/admin timetable view.
- `getSubjectTeachersForTerm(schoolId, year, term) → Future<List<SolverAssignment>>` — one-shot read of all `subject_teachers` rows for a term, enriched with subject name via left join on `subjects`. Primary input to the timetable solver.
- `getTermTimetableForDays(schoolId, year, term, days) → Future<List<TimetableEntry>>` — **NEW (Task 01):** one-shot read of all timetable entries for a term filtered to a specific list of `DayOfWeek` values. Inner-joins `users` for teacher data, left-outer-joins `subjects` for subject name. Ordered by day → grade → stream → start time. Used by the lesson-generation dialog to expand recurring timetable slots into concrete per-date lessons before the user confirms.
- `saveLessons({required List<LessonsCompanion> lessonsList, required String accountId}) → Future<void>` — **NEW (Task 01):** bulk-saves generated lessons in a single transaction. For each lesson, deletes any existing row matching `(school, year, term, grade, stream, date, subject)` first (handles teacher substitution cleanly), then inserts the new row and writes a `SyncAction.createLesson` log entry. Calls `sync.schedulePush()` after the transaction. Used by the lesson-generation dialog on confirmation.
- Insert/update methods.
- **`SchoolWideTimetableEntry`** — **NEW (TT-02)** data class defined in `timetable_dao.dart`; fields: `day: DayOfWeek`, `startTime: int`, `endTime: int`, `grade: int`, `stream: int`, `subjectId: int`, `subjectName: String`, `teacherId: String`, `teacherName: String`. Used by the school-wide cross-matrix timetable view.
- **`SolverAssignment`** — data class defined in `timetable_dao.dart`; fields: `school`, `year`, `term`, `grade`, `stream`, `subjectId`, `subjectName`, `teacherUserId`.
- **`TimetableEntry`** — data class: `slot: TimetableData`, `teacher: UsersData`, `subjectName: String`.
- **`LessonEntry`** — data class: `lesson: LessonsData`, `teacher: UsersData`, `subjectName: String`.

### `RolesDao`
- `watchSystemRoles() → Stream<List<RolesData>>` — Roles where `school IS NULL`.
- `watchRoleById(String id) → Stream<RolesData?>`
- `insertRole(...)`, `updateRole(...)`, `deleteRole(...)`
- `watchSystemScopes(String userId) → Stream<List<ScopesData>>` — System-level scopes.

### `SchoolScopesDao`
- `watchSchoolRoles(String schoolId) → Stream<List<RolesData>>` — Roles scoped to a school.
- `watchSchoolScopes(schoolId, userId) → Stream<List<ScopesData>>`
- `assignScope(...)`, `removeScope(...)`

### `PlansDao`
- `watchAllPlans() → Stream<List<PlansData>>`
- `insertPlan(...)`, `updatePlan(...)`, `deletePlan(...)`
- `watchSubscriptions(schoolId) → Stream<List<SubscriptionsData>>`
- `watchStudentSubscriptions(String schoolId, int studentAdm) → Stream<List<Subscription>>` — All subscriptions for a student at a school, ordered by created desc.
- `watchStudentTermSubscriptions(String schoolId, int studentAdm, int year, int term) → Stream<List<Subscription>>` — Subscriptions for a student in a specific term.
- `createSubscription({required SubscriptionsCompanion sub, required String accountId}) → Future<void>` — Inserts a subscription row and enqueues a log entry in one transaction.
- `updateSubscriptionStatus({required String schoolId, required String planId, required int year, required int term, required int studentAdm, required SubscriptionStatus status, required String accountId}) → Future<void>` — Updates status + timestamp and enqueues an update log with bitmask.

### `SystemStatsDao`
- `watchUserStats() → Stream<UserStats>`
- `watchSchoolStats() → Stream<SchoolStats>`
- `watchStudentStats() → Stream<StudentStats>`
- `watchTeacherStats() → Stream<TeacherStats>`
- `watchSubscriptionStats() → Stream<SubscriptionStats>`
- `watchRevenueStats() → Stream<RevenueStats>`
- `watchStudentPlanStats() → Stream<StudentPlanStats>`

### `AiUsageDao`
- `watchBySchoolTerm(schoolId, year, term)` → `Stream<List<AiUsageData>>` — all AI usage rows for a school term
- `watchStudent(schoolId, student, year, term)` → `Stream<AiUsageData?>` — single student's AI usage (reactive)
- `getStudent(schoolId, student, year, term)` → `Future<AiUsageData?>` — non-reactive single student lookup

## Global DAO Singletons

The following DAOs are instantiated as global `late final` variables in `client.dart` during `initializeClient()`:

```
accountsDao, usersDao, logsDao, schoolsDao, membershipsDao,
rolesDao, plansDao, settingsDao, systemStatsDao
```

Other DAOs are created locally where needed (e.g. inside service classes or screen states).

## Dependencies

- **Depends on:** `database/database.dart` (for `AppDatabase` + generated types), `database/tables/` (for table references), `models/` (for domain types like `SchoolMembership`, `Authenticated`, stat models)
- **Depended on by:** `services/`, `client.dart`, UI screens (via global singletons or local instantiation)

## Conventions

- DAO files are named by domain group: `members_dao.dart`, `finance_dao.dart`, `exams_grades_dao.dart`.
- Every DAO file has a corresponding `.g.dart` file generated by `build_runner`. Never edit `.g.dart` files.
- Reactive queries use Drift's `.watch()` / `.watchSingle()` and return `Stream<T>`.
- One-shot queries return `Future<T>`.
- Insert/update methods accept `Companion` objects (e.g. `UsersCompanion`).
- Mutations to synced tables must also write to the `logs` table inside the same transaction.
- Every DAO method that writes to the `logs` table calls `sync.schedulePush()` (fire-and-forget) immediately after the transaction completes. The `sync` global getter comes from `import '../../client.dart'`.
- **Action-based logging (post-C9):** Log entries use `SyncAction` enum + serialized protobuf payload bytes instead of the old `LogTable`/`LogOperation`/bitmask model. Each log is self-contained — the sync engine reads the payload bytes directly without querying other tables. Update payloads use protobuf `has*()` semantics instead of column bitmasks.
- **Invitation pattern (post-C9):** When creating a member for a new user, only a single log entry is written for the member action (e.g. `createTeacher`). The user's phone/name/email are embedded in the payload. The server handles user lookup/creation. No separate user INSERT log is written.
- **Signature changes (C9):** `addExistingUserAs*` methods now require a `UsersData existingUser` parameter (previously extracted user ID from the companion). `SchoolsDao.createSchool` takes `UsersData ownerUser` instead of `String ownerUserId`. `SchoolsDao.linkOwner` takes `UsersData ownerUser` instead of `String userId`.

## Callers Updated in C9

- `lib/services/members.dart` — `MemberCreationService` methods now pass `existingUser: existing` to all `addExistingUserAs*` calls.
- `lib/ui/screens/system/schools/create_school_sheet.dart` — `createSchool` calls now pass `ownerUser: UsersData` instead of `ownerUserId: String`. Fetches the created user row via `usersDao.getUser()` when a new user is invited.
- `lib/ui/screens/system/schools/school_detail_screen.dart` — `linkOwner` calls now pass `ownerUser: UsersData`. Fetches the created user row via `usersDao.getUser()` when a new user is invited.

## DAOs Updated in C11

- **`exams_grades_dao.dart`** — All 11 `LogsCompanion` calls updated to action-based model. `createExam` → `SyncAction.createExam` + `CreateExamPayload`; `updateExam` → `SyncAction.updateExam` + `UpdateExamPayload` (uses protobuf `has*()` semantics instead of bitmask); `deleteExam` → `SyncAction.deleteExam` + `DeleteExamPayload`; `createPaper` → `SyncAction.createPaper` + `CreatePaperPayload`; `updatePaper` → `SyncAction.updatePaper` + `UpdatePaperPayload`; `deletePaper` → `SyncAction.deletePaper` + `DeletePaperPayload`; `upsertGrade` (existing) → `SyncAction.updateGrade` + `UpdateGradePayload`; `upsertGrade` (new) → `SyncAction.markGrades` + `MarkGradesPayload` with single `GradeRecord`; `deleteGrade` → `SyncAction.deleteGrade` + `DeleteGradePayload`; `upsertMastery` (both insert and update paths) → `SyncAction.updateMastery` + `UpdateMasteryPayload`. Added `import 'package:fixnum/fixnum.dart'` for `Int64` conversion of paper `start`/`end` BigInt→fixnum.Int64. Added `import '../../proto/services/sync.pb.dart' as sync_pb`. Removed all `LogTable`, `LogOperation`, `ExamsColumn`, `PapersColumn`, `GradesColumn`, `MasteryColumn` references.
- **`finance_dao.dart`** — All 9 `LogsCompanion` calls updated to action-based model. `createFee` → `SyncAction.createFee` + `CreateFeePayload`; `updateFee` → `SyncAction.updateFee` + `UpdateFeePayload` (uses protobuf `has*()` semantics); `deleteFee` → `SyncAction.deleteFee` + `DeleteFeePayload`; `createInvoice` → `SyncAction.createInvoice` + `CreateInvoicePayload`; `updateInvoiceStatus` → `SyncAction.updateInvoice` + `UpdateInvoicePayload`; `recordPayment` → `SyncAction.createPayment` + `CreatePaymentPayload`; `upsertDiscount` (existing) → `SyncAction.updateDiscount` + `UpdateDiscountPayload`; `upsertDiscount` (new) → `SyncAction.createDiscount` + `CreateDiscountPayload`; `deleteDiscount` → `SyncAction.deleteDiscount` + `DeleteDiscountPayload`. Added `import 'package:fixnum/fixnum.dart'` for `Int64` conversion of fee/invoice `due` BigInt→fixnum.Int64. Added `import '../../proto/services/sync.pb.dart' as sync_pb`. Removed all `LogTable`, `LogOperation`, `FeesColumn`, `InvoicesColumn`, `DiscountsColumn` references. Removed unused `rowKey` variable from `upsertDiscount`.

## DAOs Updated in C10

- **`accounts_dao.dart`** — `updateName`, `updateEmail`, `deleteUserAccount` now use `SyncAction.updateUser` + `UpdateUserPayload`. No more `UsersColumn` bitmask or `LogTable`/`LogOperation` references. Added `import '../../proto/services/sync.pb.dart' as sync_pb`.
- **`departments_dao.dart`** — `createDepartment` → `SyncAction.createDepartment` + `CreateDepartmentPayload`; `updateDepartmentDescription` → `SyncAction.updateDepartment` + `UpdateDepartmentPayload`; `assignTeacherToDepartment` → `SyncAction.updateTeacher` + `UpdateTeacherPayload`; `assignStaffToDepartment` → `SyncAction.updateStaff` + `UpdateStaffPayload`; `deleteDepartment` → `SyncAction.deleteDepartment` + `DeleteDepartmentPayload`. Removed old supersede-pending-log cleanup queries (no longer needed in action-based model).
- **`terms_dao.dart`** — `createTerm` → `SyncAction.createTerm` + `CreateTermPayload`; `updateTerm` → `SyncAction.updateTerm` + `UpdateTermPayload`; `deleteTerm` → `SyncAction.deleteTerm` + `DeleteTermPayload`. Resource string format: `"Year YYYY Term T"`. Added `import 'package:fixnum/fixnum.dart'` for `Int64` conversion of `start`/`end` BigInt→Int64.
- **`subjects_dao.dart`** — `assignSubjectTeacher` → `SyncAction.assignSubject` + `AssignSubjectPayload` (covers both fresh insert and reassign); `removeSubjectAssignment` → `SyncAction.unassignSubject` + `UnassignSubjectPayload`; `assignClassTeacher` → logs `SyncAction.unassignClassTeacher` for old + `SyncAction.assignClassTeacher` for new; `removeClassTeacher` → `SyncAction.unassignClassTeacher` + `UnassignClassTeacherPayload`. Removed old supersede-pending-log cleanup queries.
- **`enrollments_dao.dart`** — `enrollStudent` → `SyncAction.enrollStudent` + `EnrollStudentPayload` (re-enrollment logs `SyncAction.unenrollStudent` for old class first); `unenrollStudent` → `SyncAction.unenrollStudent` + `UnenrollStudentPayload`. Resource string format: `"ADM {adm}"`. Removed old supersede-pending-log cleanup queries.

## DAOs Updated in C12

- **`attendance_dao.dart`** — All 3 `LogsCompanion` call sites updated. `markAttendance` (single student) → `SyncAction.markAttendance` + `MarkAttendancePayload` with one `AttendanceRecord`. `markClassAttendance` rewritten: no longer delegates to `markAttendance` per-student; instead performs all local DB writes inline and emits a single `SyncAction.markAttendance` log with all `AttendanceRecord` entries in one payload. `deleteAttendanceRecord` → `SyncAction.deleteAttendance` + `DeleteAttendancePayload`. Removed old supersede-pending-log cleanup queries (no longer needed). Added `import '../../proto/services/sync.pb.dart' as sync_pb`.
- **`timetable_dao.dart`** — All 6 `LogsCompanion` call sites updated. `insertSlot` → `SyncAction.createTimetableEntry` + `CreateTimetableEntryPayload` (includes `end` field if present). `insertSlots` → same action per slot. `deleteSlot` → `SyncAction.deleteTimetableEntry` + `DeleteTimetableEntryPayload` (includes `subject`). `clearClassTimetable` → one `SyncAction.deleteTimetableEntry` log per existing entry. `insertLesson` → `SyncAction.createLesson` + `CreateLessonPayload`. `deleteLesson` → `SyncAction.deleteLesson` + `DeleteLessonPayload`. Removed all `LogTable`/`LogOperation`/rowKey references. Added `import '../../proto/services/sync.pb.dart' as sync_pb`.
- **`announcements_dao.dart`** — All 3 `LogsCompanion` calls updated. `createAnnouncement` → `SyncAction.createAnnouncement` + `CreateAnnouncementPayload`. `updateAnnouncement` → `SyncAction.updateAnnouncement` + `UpdateAnnouncementPayload` (uses protobuf `has*()` semantics instead of bitmask). `deleteAnnouncement` → `SyncAction.deleteAnnouncement` + `DeleteAnnouncementPayload`. Removed old supersede-pending-log cleanup queries and `AnnouncementsColumn` bitmask logic. Added `import '../../proto/services/sync.pb.dart' as sync_pb`.
- **`roles_dao.dart`** — All 5 `LogsCompanion` calls updated. `createRole` → `SyncAction.createRole` + `CreateRolePayload` (permissions converted via `utf8.encode`). `updateRole` → `SyncAction.updateRole` + `UpdateRolePayload` (permissions via `utf8.encode`). `assignUserToRole` → `SyncAction.assignRole` + `AssignRolePayload` (school omitted for system-level). `unassignUserFromRole` → `SyncAction.unassignRole` + `UnassignRolePayload`. `deleteRole` → `SyncAction.deleteRole` + `DeleteRolePayload`. Removed old supersede-pending-log cleanup queries and `RolesColumn` bitmask logic. Added `import 'dart:convert'` and `import '../../proto/services/sync.pb.dart' as sync_pb`.
- **`plans_dao.dart`** — All 5 `LogsCompanion` calls updated. `createPlan` → `SyncAction.createPlan` + `CreatePlanPayload`. `updatePlan` → `SyncAction.updatePlan` + `UpdatePlanPayload` (uses protobuf `has*()` semantics; status stored as `.index`). `purgePlan` → `SyncAction.deletePlan` + `DeletePlanPayload`. `createSubscription` → `SyncAction.createSubscription` + `CreateSubscriptionPayload`. `updateSubscriptionStatus` → `SyncAction.updateSubscription` + `UpdateSubscriptionPayload`. Removed all `LogTable`/`LogOperation`/`PlansColumn`/`SubscriptionsColumn` bitmask references. Added `import '../../proto/services/sync.pb.dart' as sync_pb`.
- **`settings_dao.dart`** — Both 2 `LogsCompanion` calls updated. `updateMpesa` → `SyncAction.updateSettings` + `UpdateSettingsPayload` (with `mpesa` field). `updateSchoolConfig` → `SyncAction.updateSettings` + `UpdateSettingsPayload` (with `data` field containing the merged JSON). Removed `SettingsColumn` bitmask logic and insert-vs-update `LogOperation` branching (now always `SyncAction.updateSettings`). Added `import '../../proto/services/sync.pb.dart' as sync_pb`.

## DAOs Updated in Schema v2 Migration

- **`academics_dao.dart`** — Import changed from `../tables/subjects.dart` to `../tables/subject_teachers.dart`. `@DriftAccessor` tables list changed `Subjects` → `SubjectTeachers`. In `watchSubjectsForGrade`: all `subjects.` Drift table accessor references changed to `subjectTeachers.`; `row.readTable(subjects)` → `row.readTable(subjectTeachers)`; mastery query inside the method no longer filters by `m.grade.equals(grade)` (mastery PK is now `(school, student, subject, topic)` — no `grade` column). In `computeStreamComparison`: removed `m.grade.equals(grade)` from the mastery WHERE clause. In `computeStreamSubjectMastery`: removed `m.grade.equals(grade)` from the mastery WHERE clause. In `computeGradeSubjectMastery`: removed `m.grade.equals(grade)` from the mastery WHERE clause. In `computeStreamMasteryAverage`: removed `m.grade.equals(grade)` from the mastery WHERE clause. Updated stale comments referencing the old mastery PK. **Note:** `subjectTeachers` accessor and `ExamsCompanion.name` errors are expected until `build_runner` regenerates `.g.dart` files.
- **`exams_grades_dao.dart`** — Import changed from `../tables/subjects.dart` to `../tables/subject_teachers.dart`. `@DriftAccessor` tables list changed `Subjects` → `SubjectTeachers`. In `watchMasteryForStudent`: removed `OrderingTerm.asc(m.grade)` from orderBy (mastery no longer has a `grade` column). In `watchMasteryForSubject`: removed `mastery.grade.equals(grade)` from the WHERE clause. In `upsertMastery`: removed `final grade = entry.grade.value`; removed `m.grade.equals(grade)` from both the lookup and update WHERE clauses; removed `grade: grade,` from both `UpdateMasteryPayload` constructions. In `createExam`: replaced `grade: exam.grade.value` with `name: exam.name.value` in `CreateExamPayload`; removed `stream` conditional assignment block. In `createExamBatch`: replaced `grade: e.grade.value` with `name: e.name.value` in `CreateExamPayload`; removed `stream` conditional assignment block. In `updateExam`: replaced `changes.stream` handling block with `changes.name` handling (`payload.name = changes.name.value`). In `addGradeToExamGroup`: removed `grade: Value(grade)` and `stream: Value(streamCode)` from `ExamsCompanion`; removed `grade:` and stream conditional from `CreateExamPayload`; loop variable renamed to `_` to suppress unused-variable warning. **Note:** `ExamsCompanion.name` errors are expected until `build_runner` regenerates `.g.dart` files.

## Last Updated
Task D2 — Added `isClassTeacherFor` method to `MembersDao` for teacher attendance marking restriction. Previous: Task C1 — Added `AiUsageDao` with `watchBySchoolTerm`, `watchStudent`, and `getStudent` methods for AI credit tracking.