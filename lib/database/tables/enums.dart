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

/// The semantic action type for the action-based sync model.
///
/// Each value represents a single, self-contained operation that the client
/// can push to the server. Values are fixed — do not reorder or renumber.
enum SyncAction {
  // Schools
  createSchool(0),
  updateSchool(1),
  deleteSchool(2),
  // Teachers
  createTeacher(3),
  updateTeacher(4),
  deleteTeacher(5),
  // Staff
  createStaff(6),
  updateStaff(7),
  deleteStaff(8),
  // Owners
  createOwner(9),
  deleteOwner(10),
  // Students
  createStudent(11),
  updateStudent(12),
  deleteStudent(13),
  enrollStudent(14),
  unenrollStudent(15),
  // Guardians
  createGuardian(16),
  updateGuardian(17),
  deleteGuardian(18),
  // Departments
  createDepartment(19),
  updateDepartment(20),
  deleteDepartment(21),
  // Terms
  createTerm(22),
  updateTerm(23),
  deleteTerm(24),
  // Classes
  assignClassTeacher(25),
  unassignClassTeacher(26),
  assignSubject(27),
  unassignSubject(28),
  createTimetableEntry(29),
  updateTimetableEntry(30),
  deleteTimetableEntry(31),
  // Attendance
  markAttendance(32),
  deleteAttendance(33),
  // Lessons
  createLesson(34),
  deleteLesson(35),
  // Exams
  createExam(36),
  updateExam(37),
  deleteExam(38),
  createPaper(39),
  updatePaper(40),
  deletePaper(41),
  // Grades
  markGrades(42),
  updateGrade(43),
  deleteGrade(44),
  updateMastery(45),
  // Fees
  createFee(46),
  updateFee(47),
  deleteFee(48),
  createInvoice(49),
  updateInvoice(50),
  deleteInvoice(51),
  // Payments
  createPayment(52),
  updatePayment(53),
  deletePayment(54),
  approvePayment(55),
  // Announcements
  createAnnouncement(56),
  updateAnnouncement(57),
  deleteAnnouncement(58),
  // Roles
  createRole(59),
  updateRole(60),
  deleteRole(61),
  assignRole(62),
  unassignRole(63),
  // Users
  updateUser(64),
  deleteUser(65),
  // Settings — DEPRECATED (table removed)
  // ignore: deprecated_member_use_from_same_package
  @Deprecated('Settings table removed in schema v2')
  updateSettings(66),
  // Plans
  createPlan(67),
  updatePlan(68),
  deletePlan(69),
  // AI
  updateAiUsage(70),
  // Subscriptions
  createSubscription(71),
  updateSubscription(72),
  deleteSubscription(73),
  // Discounts
  createDiscount(74),
  updateDiscount(75),
  deleteDiscount(76),
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
  // Exam Grades — DEPRECATED (table removed, grade/stream moved to papers)
  // ignore: deprecated_member_use_from_same_package
  @Deprecated('ExamGrades removed — grade/stream moved to papers')
  addExamGrade(89),
  // ignore: deprecated_member_use_from_same_package
  @Deprecated('ExamGrades removed — grade/stream moved to papers')
  removeExamGrade(90),
  // Scheme pages (marking scheme file sync)
  uploadScheme(91),
  deleteScheme(92),
  // Answer pages (student answer sheet file sync)
  uploadAnswerSheet(93),
  deleteAnswerSheet(94);

  const SyncAction(this.value);
  final int value;
}

class SyncActionConverter extends TypeConverter<SyncAction, int> {
  const SyncActionConverter();
  @override
  SyncAction fromSql(int fromDb) =>
      SyncAction.values.firstWhere((e) => e.value == fromDb);
  @override
  int toSql(SyncAction value) => value.value;
}
