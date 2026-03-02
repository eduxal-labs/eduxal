import '../database/tables/enums.dart';

/// A thin display model wrapping a failed [LogsData] row from the offline
/// mutation queue.
///
/// The notifications panel reads all `logs` rows with `status = failed` and
/// maps each one to an [AppNotification] for display purposes.
///
/// This class has no dependency on Drift generated types — it works with the
/// plain enum and primitive values extracted from the raw row.
class AppNotification {
  const AppNotification({
    required this.logId,
    required this.table,
    required this.operation,
    required this.rowKey,
    required this.errorMessage,
    required this.attempts,
    required this.occurred,
  });

  /// The auto-incremented primary key of the `logs` row.
  final int logId;

  /// Which synced table the failed mutation targeted.
  final LogTable table;

  /// Whether the mutation was an insert, update, or delete.
  final LogOperation operation;

  /// The "|"-delimited primary key value(s) of the row that was mutated.
  final String rowKey;

  /// The error message returned by the server on the last sync attempt.
  /// Null if the entry has never been attempted or no message was recorded.
  final String? errorMessage;

  /// How many times the sync engine has attempted to replay this mutation.
  final int attempts;

  /// When this log entry was originally created, derived from `logs.created`
  /// (milliseconds since Unix epoch converted to [DateTime]).
  final DateTime occurred;

  // ─────────────────────────────────────────────────────────────────────────
  // Display helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Human-readable title for the notification row.
  ///
  /// Example: "Sync failed — Users"
  String get title => 'Sync failed \u2014 ${_tableName(table)}';

  /// Human-readable subtitle for the notification row.
  ///
  /// Shows the error message if one was recorded, otherwise falls back to
  /// "Attempt {n}" so the user can see how many retries have occurred.
  String get subtitle => (errorMessage != null && errorMessage!.isNotEmpty)
      ? errorMessage!
      : 'Attempt $attempts';

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps a [LogTable] value to a short human-readable name for display in
  /// notification titles.
  static String _tableName(LogTable table) => switch (table) {
    LogTable.users => 'Users',
    LogTable.schools => 'Schools',
    LogTable.owners => 'Owners',
    LogTable.students => 'Students',
    LogTable.guardians => 'Guardians',
    LogTable.departments => 'Departments',
    LogTable.teachers => 'Teachers',
    LogTable.staff => 'Staff',
    LogTable.terms => 'Terms',
    LogTable.classTeachers => 'Class Teachers',
    LogTable.enrollments => 'Enrollments',
    LogTable.subjects => 'Subjects',
    LogTable.attendance => 'Attendance',
    LogTable.timetable => 'Timetable',
    LogTable.lessons => 'Lessons',
    LogTable.exams => 'Exams',
    LogTable.papers => 'Papers',
    LogTable.grades => 'Grades',
    LogTable.fees => 'Fees',
    LogTable.invoices => 'Invoices',
    LogTable.payments => 'Payments',
    LogTable.announcements => 'Announcements',
    LogTable.mastery => 'Mastery',
    LogTable.aiusage => 'AI Usage',
    LogTable.settings => 'Settings',
    LogTable.roles => 'Roles',
    LogTable.scopes => 'Scopes',
    LogTable.plans => 'Plans',
    LogTable.subscriptions => 'Subscriptions',
    LogTable.discounts => 'Discounts',
  };
}
