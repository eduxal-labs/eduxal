import 'package:flutter/material.dart';

import '../../../client.dart';
import '../../../database/tables/enums.dart';
import '../../../models/app_notification.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsPage — standalone full-page notifications screen
// ─────────────────────────────────────────────────────────────────────────────

/// A dedicated full-page screen that displays all failed sync log entries for
/// the active account.
///
/// Navigated to from the user menu overlay on both the School Dashboard and
/// System Dashboard. Receives [accountId] to scope the notification stream.
///
/// Driven by a reactive [StreamBuilder] on [LogsDao.watchFailedLogs] so the
/// list updates in real-time without any manual refresh.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 8),
            // Live count badge next to title.
            StreamBuilder<int>(
              stream: logsDao.watchFailedLogCount(accountId),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return _CountBadge(count: count, cs: cs);
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: logsDao.watchFailedLogs(accountId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            );
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return _EmptyState(cs: cs);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 60,
              color: cs.outlineVariant.withValues(alpha: 0.65),
            ),
            itemBuilder: (context, i) {
              return _NotificationTile(notification: notifications[i], cs: cs);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count badge
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.cs});

  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.error.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1,
        ),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.error,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              'No sync issues.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.cs});

  final AppNotification notification;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Future: retry/dismiss interaction.
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action icon.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(
                  alpha: cs.brightness == Brightness.dark ? 0.35 : 0.5,
                ),
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
                border: cs.brightness == Brightness.dark
                    ? Border.all(
                        color: cs.error.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : null,
              ),
              child: Icon(
                _iconForAction(notification.action),
                size: 16,
                color: cs.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row — action name + operation badge.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ActionBadge(action: notification.action, cs: cs),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Subtitle — error message or attempt count.
                  Text(
                    notification.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                      letterSpacing: 0.1,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Resource identifier.
                  if (notification.resource.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        notification.resource,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Timestamp.
                  Text(
                    _relativeTime(notification.occurred),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action badge — replaces the old _OperationBadge
// ─────────────────────────────────────────────────────────────────────────────

/// Derives a short operation label and colour from a [SyncAction] value.
class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action, required this.cs});

  final SyncAction action;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(action);
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Maps a [SyncAction] to a short display label and colour based on the
  /// operation verb encoded in the action name.
  static (String, Color) _labelAndColor(SyncAction action) {
    final name = action.name; // e.g. "createSchool", "markAttendance"
    if (name.startsWith('create')) return ('Create', const Color(0xFF26A69A));
    if (name.startsWith('update')) return ('Update', const Color(0xFFFFB300));
    if (name.startsWith('delete')) return ('Delete', const Color(0xFFEF5350));
    if (name.startsWith('assign')) return ('Assign', const Color(0xFF42A5F5));
    if (name.startsWith('unassign')) {
      return ('Unassign', const Color(0xFF78909C));
    }
    if (name.startsWith('unenroll')) {
      return ('Unenroll', const Color(0xFF78909C));
    }
    if (name.startsWith('enroll')) return ('Enroll', const Color(0xFF42A5F5));
    if (name.startsWith('mark')) return ('Mark', const Color(0xFF7E57C2));
    if (name.startsWith('approve')) return ('Approve', const Color(0xFF66BB6A));
    // Fallback — should not occur with a well-defined SyncAction enum.
    return ('Action', const Color(0xFF90A4AE));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — icon mapping & relative time
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a representative icon for the given [SyncAction] based on the
/// domain entity the action targets.
IconData _iconForAction(SyncAction action) => switch (action) {
  // Schools
  SyncAction.createSchool ||
  SyncAction.updateSchool ||
  SyncAction.deleteSchool => Icons.school_outlined,
  // Teachers
  SyncAction.createTeacher ||
  SyncAction.updateTeacher ||
  SyncAction.deleteTeacher => Icons.person_outline_rounded,
  // Staff
  SyncAction.createStaff ||
  SyncAction.updateStaff ||
  SyncAction.deleteStaff => Icons.badge_outlined,
  // Owners
  SyncAction.createOwner ||
  SyncAction.deleteOwner => Icons.admin_panel_settings_outlined,
  // Students
  SyncAction.createStudent ||
  SyncAction.updateStudent ||
  SyncAction.deleteStudent ||
  SyncAction.enrollStudent ||
  SyncAction.unenrollStudent => Icons.face_outlined,
  // Guardians
  SyncAction.createGuardian ||
  SyncAction.updateGuardian ||
  SyncAction.deleteGuardian => Icons.family_restroom_outlined,
  // Departments
  SyncAction.createDepartment ||
  SyncAction.updateDepartment ||
  SyncAction.deleteDepartment => Icons.category_outlined,
  // Terms
  SyncAction.createTerm ||
  SyncAction.updateTerm ||
  SyncAction.deleteTerm => Icons.calendar_month_outlined,
  // Classes (class teachers, subjects, timetable)
  SyncAction.assignClassTeacher ||
  SyncAction.unassignClassTeacher => Icons.class_outlined,
  SyncAction.assignSubject || SyncAction.unassignSubject => Icons.book_outlined,
  SyncAction.createTimetableEntry ||
  SyncAction.updateTimetableEntry ||
  SyncAction.deleteTimetableEntry => Icons.table_chart_outlined,
  // Attendance
  SyncAction.markAttendance ||
  SyncAction.deleteAttendance => Icons.checklist_outlined,
  // Lessons
  SyncAction.createLesson ||
  SyncAction.deleteLesson => Icons.menu_book_outlined,
  // Exams & Papers
  SyncAction.createExam ||
  SyncAction.updateExam ||
  SyncAction.deleteExam => Icons.quiz_outlined,
  SyncAction.createPaper ||
  SyncAction.updatePaper ||
  SyncAction.deletePaper => Icons.description_outlined,
  // Grades & Mastery
  SyncAction.markGrades ||
  SyncAction.updateGrade ||
  SyncAction.deleteGrade => Icons.grade_outlined,
  SyncAction.updateMastery => Icons.star_outline_rounded,
  // Fees & Invoices
  SyncAction.createFee ||
  SyncAction.updateFee ||
  SyncAction.deleteFee => Icons.receipt_outlined,
  SyncAction.createInvoice ||
  SyncAction.updateInvoice ||
  SyncAction.deleteInvoice => Icons.receipt_long_outlined,
  // Payments
  SyncAction.createPayment ||
  SyncAction.updatePayment ||
  SyncAction.deletePayment ||
  SyncAction.approvePayment => Icons.payments_outlined,
  // Announcements
  SyncAction.createAnnouncement ||
  SyncAction.updateAnnouncement ||
  SyncAction.deleteAnnouncement => Icons.campaign_outlined,
  // Roles
  SyncAction.createRole ||
  SyncAction.updateRole ||
  SyncAction.deleteRole ||
  SyncAction.assignRole ||
  SyncAction.unassignRole => Icons.verified_user_outlined,
  // Users
  SyncAction.updateUser ||
  SyncAction.deleteUser => Icons.person_outline_rounded,
  // Settings
  SyncAction.updateSettings => Icons.settings_outlined,
  // Plans
  SyncAction.createPlan ||
  SyncAction.updatePlan ||
  SyncAction.deletePlan => Icons.subscriptions_outlined,
  // AI
  SyncAction.updateAiUsage => Icons.auto_awesome_outlined,
  // Subscriptions
  SyncAction.createSubscription ||
  SyncAction.updateSubscription ||
  SyncAction.deleteSubscription => Icons.card_membership_outlined,
  // Discounts
  SyncAction.createDiscount ||
  SyncAction.updateDiscount ||
  SyncAction.deleteDiscount => Icons.local_offer_outlined,
};

/// Returns a human-readable relative time string for [time].
String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  final d = diff.inDays;
  return '$d ${d == 1 ? 'day' : 'days'} ago';
}
