import 'package:drift/drift.dart';

// ============================================================
// Theme Enum — for the client-only `accounts` table
// ============================================================

/// User's preferred theme mode. Stored as smallint in `accounts.theme`.
/// Named [AppThemeMode] to avoid clashing with Flutter's own [ThemeMode] enum.
enum AppThemeMode {
  system, // 0 — follows OS light/dark setting
  light, // 1 — always light
  dark, // 2 — always dark
}

class AppThemeModeConverter extends TypeConverter<AppThemeMode, int> {
  const AppThemeModeConverter();
  @override
  AppThemeMode fromSql(int v) => AppThemeMode.values[v];
  @override
  int toSql(AppThemeMode v) => v.index;
}

// ============================================================
// Domain Enums — one per smallint enum column in the schema
// ============================================================

/// User privilege level. Stored as smallint in `users.level`.
enum UserLevel {
  normal, // 0
  system, // 1
  super_, // 2  (trailing underscore avoids clash with Dart keyword 'super')
}

class UserLevelConverter extends TypeConverter<UserLevel, int> {
  const UserLevelConverter();
  @override
  UserLevel fromSql(int fromDb) => UserLevel.values[fromDb];
  @override
  int toSql(UserLevel value) => value.index;
}

/// User account lifecycle state. Stored as smallint in `users.status`.
enum UserStatus {
  invited, // 0
  active, // 1
  suspended, // 2
  deleted, // 3
}

class UserStatusConverter extends TypeConverter<UserStatus, int> {
  const UserStatusConverter();
  @override
  UserStatus fromSql(int fromDb) => UserStatus.values[fromDb];
  @override
  int toSql(UserStatus value) => value.index;
}

/// School lifecycle state. Stored as smallint in `schools.status`.
enum SchoolStatus {
  trial, // 0
  active, // 1
  cancelled, // 2
  suspended, // 3
  deleted, // 4
}

class SchoolStatusConverter extends TypeConverter<SchoolStatus, int> {
  const SchoolStatusConverter();
  @override
  SchoolStatus fromSql(int fromDb) => SchoolStatus.values[fromDb];
  @override
  int toSql(SchoolStatus value) => value.index;
}

/// Student lifecycle state. Stored as smallint in `students.status`.
enum StudentStatus {
  active, // 0
  expelled, // 1
  graduated, // 2
  transferred, // 3
  withdrawn, // 4
  deleted, // 5
}

class StudentStatusConverter extends TypeConverter<StudentStatus, int> {
  const StudentStatusConverter();
  @override
  StudentStatus fromSql(int fromDb) => StudentStatus.values[fromDb];
  @override
  int toSql(StudentStatus value) => value.index;
}

/// Biological sex. Stored as smallint in `students.gender`.
enum Gender {
  male, // 0
  female, // 1
}

class GenderConverter extends TypeConverter<Gender, int> {
  const GenderConverter();
  @override
  Gender fromSql(int fromDb) => Gender.values[fromDb];
  @override
  int toSql(Gender value) => value.index;
}

/// Guardian's relationship to the student. Stored as smallint in `guardians.relationship`.
enum GuardianRelationship {
  father, // 0
  mother, // 1
  brother, // 2
  sister, // 3
  guardian, // 4
}

class GuardianRelationshipConverter
    extends TypeConverter<GuardianRelationship, int> {
  const GuardianRelationshipConverter();
  @override
  GuardianRelationship fromSql(int fromDb) =>
      GuardianRelationship.values[fromDb];
  @override
  int toSql(GuardianRelationship value) => value.index;
}

/// Guardian's involvement level with the student. Stored as smallint in `guardians.role`.
enum GuardianRole {
  primary, // 0
  secondary, // 1
  sponsor, // 2
}

class GuardianRoleConverter extends TypeConverter<GuardianRole, int> {
  const GuardianRoleConverter();
  @override
  GuardianRole fromSql(int fromDb) => GuardianRole.values[fromDb];
  @override
  int toSql(GuardianRole value) => value.index;
}

/// Teacher employment state. Stored as smallint in `teachers.status`.
enum TeacherStatus {
  active, // 0
  resigned, // 1
  transferred, // 2
  fired, // 3
  retired, // 4
}

class TeacherStatusConverter extends TypeConverter<TeacherStatus, int> {
  const TeacherStatusConverter();
  @override
  TeacherStatus fromSql(int fromDb) => TeacherStatus.values[fromDb];
  @override
  int toSql(TeacherStatus value) => value.index;
}

/// Staff employment state. Stored as smallint in `staff.status`.
enum StaffStatus {
  active, // 0
  resigned, // 1
  transferred, // 2
  fired, // 3
  retired, // 4
}

class StaffStatusConverter extends TypeConverter<StaffStatus, int> {
  const StaffStatusConverter();
  @override
  StaffStatus fromSql(int fromDb) => StaffStatus.values[fromDb];
  @override
  int toSql(StaffStatus value) => value.index;
}

/// Attendance record state.
/// NOTE: The schema assigns values starting at 1 (Present=1, Absent=2, Leave=3),
/// so this enum stores an explicit [value] and cannot use Dart's default index mapping.
/// Stored as smallint in `attendance.status`.
enum AttendanceStatus {
  present(1),
  absent(2),
  leave(3);

  const AttendanceStatus(this.value);
  final int value;
}

class AttendanceStatusConverter extends TypeConverter<AttendanceStatus, int> {
  const AttendanceStatusConverter();
  @override
  AttendanceStatus fromSql(int fromDb) =>
      AttendanceStatus.values.firstWhere((e) => e.value == fromDb);
  @override
  int toSql(AttendanceStatus value) => value.value;
}

/// Day of the week. Stored as smallint in `timetable.day`.
enum DayOfWeek {
  sunday, // 0
  monday, // 1
  tuesday, // 2
  wednesday, // 3
  thursday, // 4
  friday, // 5
  saturday, // 6
}

class DayOfWeekConverter extends TypeConverter<DayOfWeek, int> {
  const DayOfWeekConverter();
  @override
  DayOfWeek fromSql(int fromDb) => DayOfWeek.values[fromDb];
  @override
  int toSql(DayOfWeek value) => value.index;
}

/// Exam format. Stored as smallint in `exams.type`.
enum ExamType {
  exam, // 0
  assignment, // 1
  assessment, // 2
}

class ExamTypeConverter extends TypeConverter<ExamType, int> {
  const ExamTypeConverter();
  @override
  ExamType fromSql(int fromDb) => ExamType.values[fromDb];
  @override
  int toSql(ExamType value) => value.index;
}

/// Paper sitting state. Stored as smallint in `papers.status`.
enum PaperStatus {
  pending, // 0
  progress, // 1
  done, // 2
  marked, // 3
}

class PaperStatusConverter extends TypeConverter<PaperStatus, int> {
  const PaperStatusConverter();
  @override
  PaperStatus fromSql(int fromDb) => PaperStatus.values[fromDb];
  @override
  int toSql(PaperStatus value) => value.index;
}

/// Invoice payment state. Stored as smallint in `invoices.status`.
enum InvoiceStatus {
  pending, // 0
  partial, // 1
  paid, // 2
  overdue, // 3
  cancelled, // 4
}

class InvoiceStatusConverter extends TypeConverter<InvoiceStatus, int> {
  const InvoiceStatusConverter();
  @override
  InvoiceStatus fromSql(int fromDb) => InvoiceStatus.values[fromDb];
  @override
  int toSql(InvoiceStatus value) => value.index;
}

/// Payment channel. Stored as smallint in `payments.method`.
enum PaymentMethod {
  cash, // 0
  cheque, // 1
  mpesa, // 2
  bank, // 3
}

class PaymentMethodConverter extends TypeConverter<PaymentMethod, int> {
  const PaymentMethodConverter();
  @override
  PaymentMethod fromSql(int fromDb) => PaymentMethod.values[fromDb];
  @override
  int toSql(PaymentMethod value) => value.index;
}

/// Subscription plan lifecycle state. Stored as smallint in `plans.status`.
enum PlanStatus {
  pending, // 0
  active, // 1
  suspended, // 2
  deleted, // 3
}

class PlanStatusConverter extends TypeConverter<PlanStatus, int> {
  const PlanStatusConverter();
  @override
  PlanStatus fromSql(int fromDb) => PlanStatus.values[fromDb];
  @override
  int toSql(PlanStatus value) => value.index;
}

/// Student subscription lifecycle state. Stored as smallint in `subscriptions.status`.
enum SubscriptionStatus {
  pending, // 0
  active, // 1
  cancelled, // 2
  deleted, // 3
}

class SubscriptionStatusConverter
    extends TypeConverter<SubscriptionStatus, int> {
  const SubscriptionStatusConverter();
  @override
  SubscriptionStatus fromSql(int fromDb) => SubscriptionStatus.values[fromDb];
  @override
  int toSql(SubscriptionStatus value) => value.index;
}

/// Discount value unit. Stored as smallint in `discounts.unit`.
enum DiscountUnit {
  percentage, // 0
  amount, // 1
}

class DiscountUnitConverter extends TypeConverter<DiscountUnit, int> {
  const DiscountUnitConverter();
  @override
  DiscountUnit fromSql(int fromDb) => DiscountUnit.values[fromDb];
  @override
  int toSql(DiscountUnit value) => value.index;
}

// ============================================================
// Log Enums — for the client-only `logs` table
// ============================================================

/// Which backend table was mutated. Values 0–29 are fixed — do not reorder.
enum LogTable {
  users(0),
  schools(1),
  owners(2),
  students(3),
  guardians(4),
  departments(5),
  teachers(6),
  staff(7),
  terms(8),
  classTeachers(9),
  enrollments(10),
  subjects(11),
  attendance(12),
  timetable(13),
  lessons(14),
  exams(15),
  papers(16),
  grades(17),
  fees(18),
  invoices(19),
  payments(20),
  announcements(21),
  mastery(22),
  aiusage(23),
  settings(24),
  roles(25),
  scopes(26),
  plans(27),
  subscriptions(28),
  discounts(29);

  const LogTable(this.value);
  final int value;
}

class LogTableConverter extends TypeConverter<LogTable, int> {
  const LogTableConverter();
  @override
  LogTable fromSql(int fromDb) =>
      LogTable.values.firstWhere((e) => e.value == fromDb);
  @override
  int toSql(LogTable value) => value.value;
}

/// The type of mutation recorded in a log entry.
enum LogOperation {
  insert, // 0
  update, // 1
  delete, // 2
}

class LogOperationConverter extends TypeConverter<LogOperation, int> {
  const LogOperationConverter();
  @override
  LogOperation fromSql(int fromDb) => LogOperation.values[fromDb];
  @override
  int toSql(LogOperation value) => value.index;
}

/// Whether a log entry is awaiting replay or has permanently failed.
enum LogStatus {
  pending, // 0
  failed, // 1
}

class LogStatusConverter extends TypeConverter<LogStatus, int> {
  const LogStatusConverter();
  @override
  LogStatus fromSql(int fromDb) => LogStatus.values[fromDb];
  @override
  int toSql(LogStatus value) => value.index;
}

// ============================================================
// Column Bitset Enums — one per synced table that has updatable columns.
//
// Each variant's [bit] is the zero-indexed bit position used to build the
// `logs.columns` bitmask for UPDATE entries.
//
// Setting a bit:   mask |= (1 << XxxColumn.foo.bit);
// Checking a bit:  mask & (1 << XxxColumn.foo.bit) != 0;
//
// Only non-PK, mutable columns are listed. PK columns identify the row and
// are never changed via an UPDATE.
// ============================================================

/// Updatable columns of the `users` table.
enum UsersColumn {
  phone(0),
  email(1),
  name(2),
  level(3),
  status(4),
  updated(5);

  const UsersColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `schools` table.
enum SchoolsColumn {
  name(0),
  motto(1),
  phone(2),
  email(3),
  county(4),
  domain(5),
  established(6),
  status(7),
  updated(8);

  const SchoolsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `students` table.
enum StudentsColumn {
  user(0),
  name(1),
  dob(2),
  gender(3),
  documents(4),
  admitted(5),
  status(6),
  updated(7);

  const StudentsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `guardians` table.
enum GuardiansColumn {
  relationship(0),
  role(1),
  updated(2);

  const GuardiansColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `departments` table.
enum DepartmentsColumn {
  description(0),
  updated(1);

  const DepartmentsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `teachers` table.
enum TeachersColumn {
  hired(0),
  role(1),
  department(2),
  status(3),
  updated(4);

  const TeachersColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `staff` table.
enum StaffColumn {
  idnumber(0),
  role(1),
  department(2),
  status(3),
  updated(4);

  const StaffColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `terms` table.
enum TermsColumn {
  start(0),
  end(1),
  updated(2);

  const TermsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `class_teachers` table.
enum ClassTeachersColumn {
  end(0);

  const ClassTeachersColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `subjects` table.
enum SubjectsColumn {
  teacher(0);

  const SubjectsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `attendance` table.
enum AttendanceColumn {
  status(0),
  updated(1);

  const AttendanceColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `timetable` table.
enum TimetableColumn {
  teacher(0),
  start(1),
  end(2),
  updated(3);

  const TimetableColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `lessons` table.
enum LessonsColumn {
  updated(0);

  const LessonsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `exams` table.
enum ExamsColumn {
  stream(0),
  personalized(1),
  type(2),
  start(3),
  end(4),
  teacher(5),
  updated(6);

  const ExamsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `papers` table.
enum PapersColumn {
  invigilator(0),
  start(1),
  end(2),
  status(3),
  updated(4);

  const PapersColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `grades` table.
enum GradesColumn {
  score(0),
  total(1),
  updated(2);

  const GradesColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `fees` table.
enum FeesColumn {
  title(0),
  description(1),
  amount(2),
  mandatory(3),
  due(4),
  updated(5);

  const FeesColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `invoices` table.
enum InvoicesColumn {
  fee(0),
  description(1),
  amount(2),
  status(3),
  due(4),
  updated(5);

  const InvoicesColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `payments` table.
enum PaymentsColumn {
  amount(0),
  method(1),
  reference(2),
  recorder(3),
  date(4),
  updated(5);

  const PaymentsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `announcements` table.
enum AnnouncementsColumn {
  title(0),
  content(1),
  grade(2),
  stream(3),
  audience(4),
  author(5),
  updated(6);

  const AnnouncementsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `mastery` table.
enum MasteryColumn {
  score(0),
  updated(1);

  const MasteryColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `aiusage` table.
enum AiusageColumn {
  allocated(0),
  used(1),
  updated(2);

  const AiusageColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `settings` table.
enum SettingsColumn {
  data(0),
  mpesa(1),
  updated(2);

  const SettingsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `roles` table.
enum RolesColumn {
  name(0),
  description(1),
  permissions(2),
  updated(3);

  const RolesColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `plans` table.
enum PlansColumn {
  name(0),
  description(1),
  amount(2),
  levels(3),
  status(4),
  features(5),
  updated(6);

  const PlansColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `subscriptions` table.
enum SubscriptionsColumn {
  invoice(0),
  discount(1),
  status(2),
  updated(3);

  const SubscriptionsColumn(this.bit);
  final int bit;
}

/// Updatable columns of the `discounts` table.
enum DiscountsColumn {
  amount(0),
  unit(1),
  updated(2);

  const DiscountsColumn(this.bit);
  final int bit;
}

// NOTE: OwnersColumn, EnrollmentsColumn, and ScopesColumn are intentionally
// omitted — these tables have no updatable columns (insert/delete only).
// A log UPDATE entry will never be generated for them.
