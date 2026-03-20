import '../database/tables/enums.dart';

/// A thin display model wrapping a failed log row from the offline action queue.
///
/// The notifications panel reads all `logs` rows with `status = failed` and
/// maps each one to an [AppNotification] for display purposes.
///
/// This class has no dependency on Drift generated types — it works with the
/// plain enum and primitive values extracted from the raw row.
class AppNotification {
  const AppNotification({
    required this.logId,
    required this.action,
    required this.resource,
    required this.errorMessage,
    required this.attempts,
    required this.occurred,
  });

  /// The auto-incremented primary key of the `logs` row.
  final int logId;

  /// Which action failed.
  final SyncAction action;

  /// Human-readable resource identifier (school name, user phone, etc.).
  final String resource;

  /// The error message returned by the server on the last attempt.
  final String? errorMessage;

  /// How many times the sync engine has attempted this action.
  final int attempts;

  /// When this log entry was originally created.
  final DateTime occurred;

  // ─────────────────────────────────────────────────────────────────────────
  // Display helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Human-readable title for the notification row.
  ///
  /// Example: "Sync failed — Create Teacher"
  String get title => 'Sync failed \u2014 ${_actionName(action)}';

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

  /// Maps a [SyncAction] value to a short human-readable name for display in
  /// notification titles.
  static String _actionName(SyncAction action) => switch (action) {
    SyncAction.createSchool => 'Create School',
    SyncAction.updateSchool => 'Update School',
    SyncAction.deleteSchool => 'Delete School',
    SyncAction.createTeacher => 'Create Teacher',
    SyncAction.updateTeacher => 'Update Teacher',
    SyncAction.deleteTeacher => 'Delete Teacher',
    SyncAction.createStaff => 'Create Staff',
    SyncAction.updateStaff => 'Update Staff',
    SyncAction.deleteStaff => 'Delete Staff',
    SyncAction.createOwner => 'Create Owner',
    SyncAction.deleteOwner => 'Delete Owner',
    SyncAction.createStudent => 'Create Student',
    SyncAction.updateStudent => 'Update Student',
    SyncAction.deleteStudent => 'Delete Student',
    SyncAction.enrollStudent => 'Enroll Student',
    SyncAction.unenrollStudent => 'Unenroll Student',
    SyncAction.createGuardian => 'Create Guardian',
    SyncAction.updateGuardian => 'Update Guardian',
    SyncAction.deleteGuardian => 'Delete Guardian',
    SyncAction.createDepartment => 'Create Department',
    SyncAction.updateDepartment => 'Update Department',
    SyncAction.deleteDepartment => 'Delete Department',
    SyncAction.createTerm => 'Create Term',
    SyncAction.updateTerm => 'Update Term',
    SyncAction.deleteTerm => 'Delete Term',
    SyncAction.assignClassTeacher => 'Assign Class Teacher',
    SyncAction.unassignClassTeacher => 'Unassign Class Teacher',
    SyncAction.assignSubject => 'Assign Subject',
    SyncAction.unassignSubject => 'Unassign Subject',
    SyncAction.createTimetableEntry => 'Create Timetable Entry',
    SyncAction.updateTimetableEntry => 'Update Timetable Entry',
    SyncAction.deleteTimetableEntry => 'Delete Timetable Entry',
    SyncAction.markAttendance => 'Mark Attendance',
    SyncAction.deleteAttendance => 'Delete Attendance',
    SyncAction.createLesson => 'Create Lesson',
    SyncAction.deleteLesson => 'Delete Lesson',
    SyncAction.createExam => 'Create Exam',
    SyncAction.updateExam => 'Update Exam',
    SyncAction.deleteExam => 'Delete Exam',
    SyncAction.createPaper => 'Create Paper',
    SyncAction.updatePaper => 'Update Paper',
    SyncAction.deletePaper => 'Delete Paper',
    SyncAction.markGrades => 'Mark Grades',
    SyncAction.updateGrade => 'Update Grade',
    SyncAction.deleteGrade => 'Delete Grade',
    SyncAction.updateMastery => 'Update Mastery',
    SyncAction.createFee => 'Create Fee',
    SyncAction.updateFee => 'Update Fee',
    SyncAction.deleteFee => 'Delete Fee',
    SyncAction.createInvoice => 'Create Invoice',
    SyncAction.updateInvoice => 'Update Invoice',
    SyncAction.deleteInvoice => 'Delete Invoice',
    SyncAction.createPayment => 'Create Payment',
    SyncAction.updatePayment => 'Update Payment',
    SyncAction.deletePayment => 'Delete Payment',
    SyncAction.approvePayment => 'Approve Payment',
    SyncAction.createAnnouncement => 'Create Announcement',
    SyncAction.updateAnnouncement => 'Update Announcement',
    SyncAction.deleteAnnouncement => 'Delete Announcement',
    SyncAction.createRole => 'Create Role',
    SyncAction.updateRole => 'Update Role',
    SyncAction.deleteRole => 'Delete Role',
    SyncAction.assignRole => 'Assign Role',
    SyncAction.unassignRole => 'Unassign Role',
    SyncAction.updateUser => 'Update User',
    SyncAction.deleteUser => 'Delete User',
    SyncAction.updateSettings => 'Update Settings',
    SyncAction.createPlan => 'Create Plan',
    SyncAction.updatePlan => 'Update Plan',
    SyncAction.deletePlan => 'Delete Plan',
    SyncAction.updateAiUsage => 'Update AI Usage',
    SyncAction.createSubscription => 'Create Subscription',
    SyncAction.updateSubscription => 'Update Subscription',
    SyncAction.deleteSubscription => 'Delete Subscription',
    SyncAction.createDiscount => 'Create Discount',
    SyncAction.updateDiscount => 'Update Discount',
    SyncAction.deleteDiscount => 'Delete Discount',
    SyncAction.createSubject => 'Create Subject',
    SyncAction.updateSubject => 'Update Subject',
    SyncAction.deleteSubject => 'Delete Subject',
    SyncAction.createTopic => 'Create Topic',
    SyncAction.updateTopic => 'Update Topic',
    SyncAction.deleteTopic => 'Delete Topic',
    SyncAction.createStream => 'Create Stream',
    SyncAction.updateStream => 'Update Stream',
    SyncAction.deleteStream => 'Delete Stream',
    SyncAction.createMpesa => 'Configure M-Pesa',
    SyncAction.updateMpesa => 'Update M-Pesa',
    SyncAction.deleteMpesa => 'Remove M-Pesa',
    SyncAction.addExamGrade => 'Add Exam Grade',
    SyncAction.removeExamGrade => 'Remove Exam Grade',
    SyncAction.uploadScheme => 'Upload Marking Scheme',
    SyncAction.deleteScheme => 'Delete Marking Scheme',
    SyncAction.uploadAnswerSheet => 'Upload Answer Sheet',
    SyncAction.deleteAnswerSheet => 'Delete Answer Sheet',
  };
}
