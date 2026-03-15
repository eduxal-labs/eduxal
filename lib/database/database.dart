import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/enums.dart';

import 'daos/accounts_dao.dart';
import 'daos/attendance_dao.dart';
import 'daos/logs_dao.dart';
import 'daos/terms_dao.dart';
import 'daos/plans_dao.dart';
import 'daos/roles_dao.dart';
import 'daos/schools_dao.dart';
import 'daos/system_stats_dao.dart';
import 'daos/members_dao.dart';
import 'daos/users_dao.dart';
import 'daos/departments_dao.dart';
import 'daos/subjects_dao.dart';
import 'daos/enrollments_dao.dart';
import 'daos/school_scopes_dao.dart';
import 'daos/exams_grades_dao.dart';
import 'daos/finance_dao.dart';
import 'daos/academics_dao.dart';
import 'daos/announcements_dao.dart';
import 'daos/timetable_dao.dart';
import 'daos/catalog_dao.dart';

import 'tables/users.dart';
import 'tables/schools.dart';
import 'tables/plans.dart';
import 'tables/roles.dart';
import 'tables/owners.dart';
import 'tables/departments.dart';
import 'tables/students.dart';
import 'tables/teachers.dart';
import 'tables/staff.dart';
import 'tables/guardians.dart';
import 'tables/terms.dart';
import 'tables/class_teachers.dart';
import 'tables/enrollments.dart';
import 'tables/subject_teachers.dart';
import 'tables/subjects.dart';
import 'tables/curriculum_subjects.dart';
import 'tables/topics.dart';
import 'tables/streams.dart';
import 'tables/mpesa.dart';

import 'tables/attendance.dart';
import 'tables/timetable.dart';
import 'tables/lessons.dart';
import 'tables/exams.dart';
import 'tables/papers.dart';
import 'tables/grades.dart';
import 'tables/fees.dart';
import 'tables/invoices.dart';
import 'tables/payments.dart';
import 'tables/announcements.dart';
import 'tables/mastery.dart';
import 'tables/aiusage.dart';

import 'tables/scopes.dart';
import 'tables/subscriptions.dart';
import 'tables/discounts.dart';
import 'tables/accounts.dart';
import 'tables/logs.dart';

part 'database.g.dart';

/// Global singleton — initialised in main.dart before runApp().
late final AppDatabase db;

@DriftDatabase(
  tables: [
    Users,
    Schools,
    Plans,
    Roles,
    Owners,
    Departments,
    Students,
    Teachers,
    Staff,
    Guardians,
    Terms,
    ClassTeachers,
    Enrollments,
    SubjectTeachers,
    Subjects,
    Topics,
    Streams,
    Mpesa,
    Attendance,
    Timetable,
    Lessons,
    Exams,
    Papers,
    PaperSubmissions,
    Grades,
    Fees,
    Invoices,
    Payments,
    Announcements,
    Mastery,
    AiUsage,

    Scopes,
    Subscriptions,
    Discounts,
    Accounts,
    Logs,
  ],
  // MembershipsDao is intentionally excluded here: it imports
  // lib/models/membership.dart, which in turn imports this file (database.dart)
  // to access the generated data classes. Listing MembershipsDao here would
  // create a circular import that breaks build_runner. The DAO still works
  // correctly — @DriftAccessor generates its mixin independently. Instantiate
  // it via `MembershipsDao(db)` directly wherever needed.
  //
  // SystemStatsDao is also excluded for the same reason — it imports
  // lib/models/system_stats.dart which has no circular dependency, but to
  // keep the pattern consistent and avoid any future issues, it is instantiated
  // directly wherever needed.
  daos: [
    AccountsDao,
    AttendanceDao,
    LogsDao,
    MembersDao,
    PlansDao,
    RolesDao,
    SchoolsDao,
    SystemStatsDao,
    TermsDao,
    UsersDao,
    DepartmentsDao,
    SubjectsDao,
    EnrollmentsDao,
    SchoolScopesDao,
    ExamsGradesDao,
    FinanceDao,
    AnnouncementsDao,
    TimetableDao,
    AcademicsDao,
    CatalogDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        LazyDatabase(() async {
          print('[DB] LazyDatabase callback START');
          final dir = await getApplicationDocumentsDirectory();
          print('[DB] Documents dir: ${dir.path}');
          final file = File(p.join(dir.path, 'eduxal.sqlite'));
          print('[DB] DB file: ${file.path}, exists: ${file.existsSync()}');
          final ndb = NativeDatabase(
            file,
            setup: (db) {
              print('[DB] NativeDatabase setup callback running');
              db.execute('PRAGMA busy_timeout = 10000');
              print('[DB] PRAGMA busy_timeout set');
            },
          );
          print('[DB] NativeDatabase created, returning');
          return ndb;
        }),
      );

  /// Opens an [AppDatabase] backed by the provided [executor].
  ///
  /// Intended for use in tests only — pass a `NativeDatabase.memory()` to get
  /// an isolated, in-memory database that is discarded when closed.
  ///
  /// ```dart
  /// final db = AppDatabase.forTesting(NativeDatabase.memory());
  /// ```
  AppDatabase.forTesting(super.executor);

  /// Deletes every row from every table in the database.
  ///
  /// Deletion order respects foreign-key constraints: child tables are cleared
  /// before parent tables so that `ON DELETE` / `RESTRICT` rules never fire.
  ///
  /// This is a full nuclear reset — use it on logout (when no accounts remain)
  /// or when the user explicitly requests a data wipe.
  Future<void> deleteAllData() async {
    // Temporarily disable FK enforcement so deletion order doesn't matter
    // for complex circular-ish references, then re-enable after.
    await customStatement('PRAGMA foreign_keys = OFF');

    await transaction(() async {
      // Leaf / deepest-child tables first, parents last.
      // ── Sync / client-only ──
      await delete(paperSubmissions).go();
      await delete(logs).go();

      // ── Grades / mastery (depend on exams, papers, students, enrollments) ──
      await delete(mastery).go();
      await delete(grades).go();

      // ── Papers (depend on exams) ──
      await delete(papers).go();

      // ── Exams (depend on schools, terms) ──
      await delete(exams).go();

      // ── Attendance / lessons / timetable (depend on enrollments, subjects, terms) ──
      await delete(attendance).go();
      await delete(lessons).go();
      await delete(timetable).go();

      // ── Subject teachers (depend on teachers, terms, schools) ──
      await delete(subjectTeachers).go();

      // ── Subjects / topics / streams / mpesa (global or school-scoped) ──
      await delete(topics).go();
      await delete(subjects).go();
      await delete(streams).go();
      await delete(mpesa).go();

      // ── Enrollments (depend on students, terms, schools) ──
      await delete(enrollments).go();

      // ── Class teachers (depend on teachers, terms, schools) ──
      await delete(classTeachers).go();

      // ── Finance (payments → invoices → fees / students) ──
      await delete(payments).go();
      await delete(invoices).go();
      await delete(fees).go();

      // ── Subscriptions / discounts (depend on plans, schools, students) ──
      await delete(subscriptions).go();
      await delete(discounts).go();

      // ── AI usage ──
      await delete(aiUsage).go();

      // ── Announcements ──
      await delete(announcements).go();

      // ── Scopes (depend on roles, users, schools) ──
      await delete(scopes).go();

      // ── Roles (depend on schools) ──
      await delete(roles).go();

      // ── Terms (depend on schools) ──
      await delete(terms).go();

      // ── Members (depend on users, schools, students) ──
      await delete(guardians).go();
      await delete(teachers).go();
      await delete(staff).go();
      await delete(owners).go();
      await delete(students).go();

      // ── Departments (depend on schools) ──
      await delete(departments).go();

      // ── Plans (standalone) ──
      await delete(plans).go();

      // ── Schools (referenced by many) ──
      await delete(schools).go();

      // ── Accounts (depend on users via FK CASCADE) ──
      await delete(accounts).go();

      // ── Users (top-level parent) ──
      await delete(users).go();
    });

    await customStatement('PRAGMA foreign_keys = ON');
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(accounts, accounts.lastSeq);
      }
      if (from < 3) {
        // Logs table schema changed: action-based model replaces mutation-based model.
        // Drop old logs and recreate — pending sync data is lost but that's acceptable.
        await m.deleteTable('logs');
        await m.createTable(logs);
      }
      if (from < 4) {
        // Remove overly restrictive unique indexes on exams — the text PK is
        // sufficient. Multiple exams of the same type per class/term are valid.
        await customStatement('DROP INDEX IF EXISTS uq_exams_allstream_type');
        await customStatement('DROP INDEX IF EXISTS uq_exams_stream_type');
      }
      if (from < 5) {
        // Add client-only paper_submissions table for persisting answer image paths.
        await m.createTable(paperSubmissions);
      }
      if (from < 6) {
        // Add theme column to accounts table (was added to the Drift schema
        // but never had a migration — databases created at schema 1–5 are
        // missing it, causing getActiveAccount() to fail silently).
        await customStatement(
          'ALTER TABLE accounts ADD COLUMN theme INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 7) {
        // Exam/paper schema redesign: add grade/stream to papers, drop exam_grades.
        await customStatement(
          'ALTER TABLE papers ADD COLUMN grade INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement('ALTER TABLE papers ADD COLUMN stream INTEGER');
        // Backfill grade/stream from exam_grades if the table exists
        await customStatement('''
          UPDATE papers SET
            grade = COALESCE((SELECT eg.grade FROM exam_grades eg WHERE eg.exam = papers.exam LIMIT 1), 0),
            stream = (SELECT eg.stream FROM exam_grades eg WHERE eg.exam = papers.exam LIMIT 1)
          WHERE EXISTS (SELECT 1 FROM exam_grades eg WHERE eg.exam = papers.exam)
        ''');
        await customStatement('DROP TABLE IF EXISTS exam_grades');
        await customStatement('DROP INDEX IF EXISTS idx_exam_grades_grade');

        // Recreate enrollment-check triggers to JOIN through papers instead of exam_grades
        await customStatement('DROP TRIGGER IF EXISTS grades_enrollment_check');
        await customStatement('''
          CREATE TRIGGER grades_enrollment_check
          BEFORE INSERT ON grades
          BEGIN
            SELECT RAISE(ABORT, 'student is not enrolled in a class that participates in this exam')
            WHERE NOT EXISTS (
              SELECT 1 FROM enrollments
              INNER JOIN exams ON exams.id = NEW.exam AND exams.school = NEW.school
              INNER JOIN papers p ON p.exam = exams.id AND p.school = exams.school
                                 AND p.subject = NEW.subject
              WHERE enrollments.school  = NEW.school
                AND enrollments.student = NEW.student
                AND enrollments.year    = exams.year
                AND enrollments.term    = exams.term
                AND enrollments.grade   = p.grade
                AND (p.stream IS NULL OR enrollments.stream = p.stream)
            );
          END
        ''');
        await customStatement(
          'DROP TRIGGER IF EXISTS grades_enrollment_check_update',
        );
        await customStatement('''
          CREATE TRIGGER grades_enrollment_check_update
          BEFORE UPDATE OF exam, student, school ON grades
          BEGIN
            SELECT RAISE(ABORT, 'student is not enrolled in a class that participates in this exam')
            WHERE NOT EXISTS (
              SELECT 1 FROM enrollments
              INNER JOIN exams ON exams.id = NEW.exam AND exams.school = NEW.school
              INNER JOIN papers p ON p.exam = exams.id AND p.school = exams.school
                                 AND p.subject = NEW.subject
              WHERE enrollments.school  = NEW.school
                AND enrollments.student = NEW.student
                AND enrollments.year    = exams.year
                AND enrollments.term    = exams.term
                AND enrollments.grade   = p.grade
                AND (p.stream IS NULL OR enrollments.stream = p.stream)
            );
          END
        ''');
      }
    },
    onCreate: (m) async {
      // 1. Create all Drift-managed tables.
      await m.createAll();

      // 2. Enable FK enforcement (SQLite disables it by default).
      await customStatement('PRAGMA foreign_keys = ON');

      // 3. Create triggers and indexes (idempotent — safe to re-run).
      await _createTriggersAndIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Creates all triggers and indexes using IF NOT EXISTS so the statements
  /// are safe to run on both fresh databases and databases that already have
  /// some or all of these objects.
  Future<void> _createTriggersAndIndexes() async {
    // ----------------------------------------------------------------
    // Triggers
    // ----------------------------------------------------------------

    // Prevents mixing null-paper (subject-level) and numbered-paper grades
    // for the same student+subject within the same exam on INSERT.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS grades_paper_mix_check
        BEFORE INSERT ON grades
        BEGIN
          SELECT RAISE(ABORT, 'cannot add a numbered-paper grade: a subject-level grade already exists for this student in this exam')
          WHERE NEW.paper IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM grades
            WHERE school = NEW.school AND exam = NEW.exam AND student = NEW.student
              AND subject = NEW.subject AND paper IS NULL
          );
          SELECT RAISE(ABORT, 'cannot add a subject-level grade: numbered-paper grades already exist for this student in this exam')
          WHERE NEW.paper IS NULL
          AND EXISTS (
            SELECT 1 FROM grades
            WHERE school = NEW.school AND exam = NEW.exam AND student = NEW.student
              AND subject = NEW.subject AND paper IS NOT NULL
          );
        END
      ''');

    // Ensures a grade can only be recorded for a student enrolled in a
    // grade/stream that participates in the exam (via papers), INSERT.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS grades_enrollment_check
        BEFORE INSERT ON grades
        BEGIN
          SELECT RAISE(ABORT, 'student is not enrolled in a class that participates in this exam')
          WHERE NOT EXISTS (
            SELECT 1 FROM enrollments
            INNER JOIN exams ON exams.id = NEW.exam AND exams.school = NEW.school
            INNER JOIN papers p ON p.exam = exams.id AND p.school = exams.school
                               AND p.subject = NEW.subject
            WHERE enrollments.school  = NEW.school
              AND enrollments.student = NEW.student
              AND enrollments.year    = exams.year
              AND enrollments.term    = exams.term
              AND enrollments.grade   = p.grade
              AND (p.stream IS NULL OR enrollments.stream = p.stream)
          );
        END
      ''');

    // Prevents UPDATE from introducing a paper-mix violation on grades.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS grades_paper_mix_check_update
        BEFORE UPDATE OF paper ON grades
        BEGIN
          SELECT RAISE(ABORT, 'cannot update to a numbered-paper grade: a subject-level grade already exists for this student in this exam')
          WHERE NEW.paper IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM grades
            WHERE school = NEW.school AND exam = NEW.exam AND student = NEW.student
              AND subject = NEW.subject AND paper IS NULL
              AND rowid IS NOT OLD.rowid
          );
          SELECT RAISE(ABORT, 'cannot update to a subject-level grade: numbered-paper grades already exist for this student in this exam')
          WHERE NEW.paper IS NULL
          AND EXISTS (
            SELECT 1 FROM grades
            WHERE school = NEW.school AND exam = NEW.exam AND student = NEW.student
              AND subject = NEW.subject AND paper IS NOT NULL
              AND rowid IS NOT OLD.rowid
          );
        END
      ''');

    // Prevents UPDATE from moving a grade to an exam the student is not
    // enrolled in (via papers).
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS grades_enrollment_check_update
        BEFORE UPDATE OF exam, student, school ON grades
        BEGIN
          SELECT RAISE(ABORT, 'student is not enrolled in a class that participates in this exam')
          WHERE NOT EXISTS (
            SELECT 1 FROM enrollments
            INNER JOIN exams ON exams.id = NEW.exam AND exams.school = NEW.school
            INNER JOIN papers p ON p.exam = exams.id AND p.school = exams.school
                               AND p.subject = NEW.subject
            WHERE enrollments.school  = NEW.school
              AND enrollments.student = NEW.student
              AND enrollments.year    = exams.year
              AND enrollments.term    = exams.term
              AND enrollments.grade   = p.grade
              AND (p.stream IS NULL OR enrollments.stream = p.stream)
          );
        END
      ''');

    // Ensures the invoice linked to a subscription (on INSERT) belongs to
    // the same student and school.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS subscriptions_invoice_check
        BEFORE INSERT ON subscriptions
        BEGIN
          SELECT RAISE(ABORT, 'invoice does not belong to this student or school')
          WHERE NEW.invoice IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM invoices
            WHERE id = NEW.invoice
              AND school = NEW.school
              AND student = NEW.student
          );
        END
      ''');

    // Same invoice-ownership check on UPDATE.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS subscriptions_invoice_check_update
        BEFORE UPDATE OF invoice ON subscriptions
        BEGIN
          SELECT RAISE(ABORT, 'invoice does not belong to this student or school')
          WHERE NEW.invoice IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM invoices
            WHERE id = NEW.invoice
              AND school = NEW.school
              AND student = NEW.student
          );
        END
      ''');

    // Prevents inserting a term whose date range overlaps any existing term
    // for the same school.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS terms_no_overlap
        BEFORE INSERT ON terms
        BEGIN
          SELECT RAISE(ABORT, 'term dates overlap with an existing term for this school')
          WHERE EXISTS (
            SELECT 1 FROM terms
            WHERE school = NEW.school
              AND start < NEW.end
              AND end   > NEW.start
          );
        END
      ''');

    // Same overlap check when a term's dates are updated.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS terms_no_overlap_update
        BEFORE UPDATE OF start, end ON terms
        BEGIN
          SELECT RAISE(ABORT, 'term dates overlap with an existing term for this school')
          WHERE EXISTS (
            SELECT 1 FROM terms
            WHERE school = NEW.school
              AND start < NEW.end
              AND end   > NEW.start
              AND NOT (year = OLD.year AND term = OLD.term)
          );
        END
      ''');

    // Ensures a paper is not scheduled outside its parent exam's date window
    // (INSERT). papers.start/end are seconds since epoch; exams.start/end
    // are days since epoch.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS papers_within_exam_range
        BEFORE INSERT ON papers
        BEGIN
          SELECT RAISE(ABORT, 'paper schedule falls outside the exam date range')
          WHERE NOT EXISTS (
            SELECT 1 FROM exams
            WHERE id = NEW.exam
              AND NEW.start >= start * 86400
              AND NEW.end   <= (end + 1) * 86400
          );
        END
      ''');

    // Same date-window check when a paper's schedule is updated.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS papers_within_exam_range_update
        BEFORE UPDATE OF start, end, exam ON papers
        BEGIN
          SELECT RAISE(ABORT, 'paper schedule falls outside the exam date range')
          WHERE NOT EXISTS (
            SELECT 1 FROM exams
            WHERE id = NEW.exam
              AND NEW.start >= start * 86400
              AND NEW.end   <= (end + 1) * 86400
          );
        END
      ''');

    // Ensures attendance is only recorded on dates that fall within the term
    // (INSERT). attendance.date is days since epoch; terms.start/end are
    // seconds since epoch.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS attendance_within_term
        BEFORE INSERT ON attendance
        BEGIN
          SELECT RAISE(ABORT, 'attendance date falls outside the term date range')
          WHERE NOT EXISTS (
            SELECT 1 FROM terms
            WHERE school = NEW.school AND year = NEW.year AND term = NEW.term
              AND NEW.date >= start / 86400
              AND NEW.date <= end   / 86400
          );
        END
      ''');

    // Same date-range check when an attendance record's date is updated.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS attendance_within_term_update
        BEFORE UPDATE OF date ON attendance
        BEGIN
          SELECT RAISE(ABORT, 'attendance date falls outside the term date range')
          WHERE NOT EXISTS (
            SELECT 1 FROM terms
            WHERE school = NEW.school AND year = NEW.year AND term = NEW.term
              AND NEW.date >= start / 86400
              AND NEW.date <= end   / 86400
          );
        END
      ''');

    // Ensures a lesson is only recorded on a date that falls within the
    // term (INSERT).
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS lessons_within_term
        BEFORE INSERT ON lessons
        BEGIN
          SELECT RAISE(ABORT, 'lesson date falls outside the term date range')
          WHERE NOT EXISTS (
            SELECT 1 FROM terms
            WHERE school = NEW.school AND year = NEW.year AND term = NEW.term
              AND NEW.date >= start / 86400
              AND NEW.date <= end   / 86400
          );
        END
      ''');

    // Same date-range check when a lesson's date is updated.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS lessons_within_term_update
        BEFORE UPDATE OF date ON lessons
        BEGIN
          SELECT RAISE(ABORT, 'lesson date falls outside the term date range')
          WHERE NOT EXISTS (
            SELECT 1 FROM terms
            WHERE school = NEW.school AND year = NEW.year AND term = NEW.term
              AND NEW.date >= start / 86400
              AND NEW.date <= end   / 86400
          );
        END
      ''');

    // When a department is deleted, only nullify the department column in
    // teachers (not school). A composite FK with ON DELETE SET NULL would
    // wipe both columns, so we use NO ACTION on the FK and handle it here.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS dept_delete_clear_teachers
        AFTER DELETE ON departments
        BEGIN
          UPDATE teachers SET department = NULL
          WHERE school = OLD.school AND department = OLD.name;
        END
      ''');

    // Same department-nullify behaviour for staff.
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS dept_delete_clear_staff
        AFTER DELETE ON departments
        BEGIN
          UPDATE staff SET department = NULL
          WHERE school = OLD.school AND department = OLD.name;
        END
      ''');

    // ----------------------------------------------------------------
    // Unique / partial indexes (cannot be expressed in Drift DSL)
    // ----------------------------------------------------------------

    // students: a user may only be linked to one student per school.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS students_school_user_idx'
      ' ON students(school, user) WHERE user IS NOT NULL',
    );

    // guardians: at most one primary guardian per student per school.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_guardians_primary'
      ' ON guardians(school, student) WHERE role = 0',
    );

    // class_teachers: at most one active (un-ended) teacher per class.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_class_teachers_active'
      ' ON class_teachers(school, year, term, grade, stream) WHERE end IS NULL',
    );

    // enrollments: a student can only be in one class per term.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_enrollments_student_term'
      ' ON enrollments(school, year, term, student)',
    );

    // subject_teachers: 7-column index gives SQLite a target for the
    // composite FK reference from timetable (subject + teacher pair).
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS subject_teachers_class_teacher_idx'
      ' ON subject_teachers(school, year, term, grade, stream, subject, teacher)',
    );

    // timetable: a teacher can only have one slot at a given time.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_timetable_teacher_slot'
      ' ON timetable(school, year, term, teacher, day, start)',
    );

    // timetable: a class can only have one subject at a given time.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_timetable_class_slot'
      ' ON timetable(school, year, term, grade, stream, day, start)',
    );

    // papers: at most one null-paper row per (school, exam, subject).
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS papers_subject_null_idx'
      ' ON papers(school, exam, subject) WHERE paper IS NULL',
    );

    // roles: school-scoped role names must be unique within a school.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS roles_school_name_idx'
      ' ON roles(school, name) WHERE school IS NOT NULL',
    );

    // roles: system-level (school=NULL) role names must be globally unique.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS roles_system_name_idx'
      ' ON roles(name) WHERE school IS NULL',
    );

    // scopes: a user may only hold a given role once at the system level.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS scopes_system_idx'
      ' ON scopes(user, role) WHERE school IS NULL',
    );

    // schools: subdomain routing requires unique non-null domains.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_domain'
      ' ON schools(domain) WHERE domain IS NOT NULL',
    );

    // accounts: at most one active account session at a time.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_accounts_active'
      ' ON accounts(is_active) WHERE is_active = 1',
    );

    // ----------------------------------------------------------------
    // Performance indexes
    // ----------------------------------------------------------------

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_users_status ON users(status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schools_status ON schools(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schools_county ON schools(county)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_owners_user ON owners(user)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_students_school_status ON students(school, status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_students_school_name ON students(school, name)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_guardians_school_student ON guardians(school, student)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_teachers_school_department ON teachers(school, department)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_teachers_school_status ON teachers(school, status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_staff_school ON staff(school)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_staff_school_department ON staff(school, department)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_staff_school_status ON staff(school, status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_class_teachers_school_teacher ON class_teachers(school, teacher)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_enrollments_school_student ON enrollments(school, student)',
    );

    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_subjects_name_curriculum ON subjects(name, curriculum)',
    );

    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_topics_subject_grade_name ON topics(subject, grade, name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_topics_subject ON topics(subject)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_streams_school ON streams(school, grade)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_subject_teachers_school_teacher ON subject_teachers(school, teacher)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attendance_school_term_student ON attendance(school, year, term, student)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_timetable_school_teacher ON timetable(school, teacher)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_lessons_school_teacher ON lessons(school, teacher)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_lessons_school_term_date ON lessons(school, year, term, date)',
    );

    // The old index referenced grade/stream columns that were removed in
    // schema v2 (Task C08). Drop it if it exists, then create the replacement.
    await customStatement('DROP INDEX IF EXISTS idx_exams_school_term_class');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_exams_school_term ON exams(school, year, term)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_exams_school_teacher ON exams(school, teacher)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_papers_school_exam_status ON papers(school, exam, status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_grades_school_student ON grades(school, student)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_fees_school_term_grade ON fees(school, year, term, grade)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_invoices_school_student ON invoices(school, student)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_invoices_school_term ON invoices(school, year, term)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_invoices_school_status ON invoices(school, status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_school_student ON payments(school, student)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_direct_date'
      ' ON payments(school, student, date) WHERE invoice IS NULL',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_announcements_school ON announcements(school)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_announcements_school_grade ON announcements(school, grade)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_scopes_school_role ON scopes(school, role)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_scopes_role ON scopes(role)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_plans_status ON plans(status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_school_student ON subscriptions(school, student)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_school_term ON subscriptions(school, year, term)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_discounts_school_term_grade ON discounts(school, year, term, grade)',
    );
  }
}
