import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/app_notification.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsSection — standalone notifications tab content widget
// ─────────────────────────────────────────────────────────────────────────────

/// Full notifications UI: reactive list of failed sync log entries displayed
/// as inline tab content (not inside a Drawer).
///
/// Accepts [accountId] to scope the notification stream to the active account.
/// Can be used as tab content in both mobile and desktop system dashboard
/// layouts.
///
/// The original [NotificationsPanel] (Drawer variant) is kept intact for
/// potential reuse elsewhere.
class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key, required this.accountId});

  final String? accountId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (accountId == null) {
      return Center(
        child: Text(
          'No active account.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              // Live count badge.
              StreamBuilder<List<AppNotification>>(
                stream: logsDao.watchFailedLogs(accountId!),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return _CountBadge(count: count, cs: cs);
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),
        // ── Reactive list ────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppNotification>>(
            stream: logsDao.watchFailedLogs(accountId!),
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
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 52,
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
                itemBuilder: (context, i) {
                  return _NotificationTile(
                    notification: notifications[i],
                    cs: cs,
                  );
                },
              );
            },
          ),
        ),
      ],
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
// Notification tile — with retry/delete action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification, required this.cs});

  final AppNotification notification;
  final ColorScheme cs;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _retrying = false;
  bool _deleting = false;

  AppNotification get notification => widget.notification;
  ColorScheme get cs => widget.cs;

  // ── Retry: reset status to pending and trigger a push ──────────────────

  Future<void> _retryLog() async {
    if (_retrying || _deleting) return;
    setState(() => _retrying = true);
    try {
      await logsDao.retryLog(notification.logId);
      // Trigger a push cycle so the sync engine picks up the retried log.
      sync.schedulePush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Queued for retry'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  // ── Delete: confirm then permanently remove the log entry ──────────────

  Future<void> _deleteLog() async {
    if (_retrying || _deleting) return;

    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete notification?',
      message:
          'This will permanently remove this failed sync action. '
          'For create actions, the local data will also be reverted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await logsDao.deleteLogAndRevert(notification.logId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  ? Border.all(color: cs.error.withValues(alpha: 0.2), width: 1)
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
                // Title row — action name + action type badge.
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
                // Resource identifier (if non-empty).
                if (notification.resource.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
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
                ],
                const SizedBox(height: 6),
                // Bottom row — timestamp + action buttons.
                Row(
                  children: [
                    // Timestamp.
                    Expanded(
                      child: Text(
                        _relativeTime(notification.occurred),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    // Retry / Delete action buttons.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Retry button.
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: _retrying
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                  ),
                                )
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  icon: Icon(
                                    Icons.refresh,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                                  iconSize: 28,
                                  tooltip: 'Retry',
                                  onPressed: _deleting ? null : _retryLog,
                                ),
                        ),
                        const SizedBox(width: 4),
                        // Delete button.
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: _deleting
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: cs.error,
                                  ),
                                )
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: cs.error,
                                  ),
                                  iconSize: 28,
                                  tooltip: 'Delete',
                                  onPressed: _retrying ? null : _deleteLog,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a representative icon for the given [SyncAction] value based on
  /// the domain group the action belongs to.
  static IconData _iconForAction(SyncAction action) => switch (action) {
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
    SyncAction.assignSubject ||
    SyncAction.unassignSubject => Icons.book_outlined,
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
    // Roles & Scopes
    SyncAction.createRole ||
    SyncAction.updateRole ||
    SyncAction.deleteRole => Icons.verified_user_outlined,
    SyncAction.assignRole ||
    SyncAction.unassignRole => Icons.lock_outline_rounded,
    // Users
    SyncAction.inviteUser => Icons.person_add_alt_1_rounded,
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
    // Subjects (global catalog)
    SyncAction.createSubject ||
    SyncAction.updateSubject ||
    SyncAction.deleteSubject => Icons.menu_book_outlined,
    // Topics (global catalog)
    SyncAction.createTopic ||
    SyncAction.updateTopic ||
    SyncAction.deleteTopic => Icons.list_outlined,
    // Streams (per-school)
    SyncAction.createStream ||
    SyncAction.updateStream ||
    SyncAction.deleteStream => Icons.linear_scale_outlined,
    // M-Pesa (per-school)
    SyncAction.createMpesa ||
    SyncAction.updateMpesa ||
    SyncAction.deleteMpesa => Icons.payments_outlined,
    // Exam Grades (junction)
    SyncAction.addExamGrade ||
    SyncAction.removeExamGrade => Icons.grade_outlined,
    // File sync — marking schemes & answer sheets
    SyncAction.uploadScheme ||
    SyncAction.deleteScheme => Icons.description_outlined,
    SyncAction.uploadAnswerSheet ||
    SyncAction.deleteAnswerSheet => Icons.photo_library_outlined,
  };

  /// Returns a human-readable relative time string for [time].
  static String _relativeTime(DateTime time) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Action badge
// ─────────────────────────────────────────────────────────────────────────────

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

  (String, Color) _labelAndColor(SyncAction action) {
    final name = action.name;
    if (action == SyncAction.inviteUser) {
      return ('Invite', const Color(0xFF26A69A));
    }
    if (name.startsWith('create')) return ('Create', const Color(0xFF26A69A));
    if (name.startsWith('update')) return ('Update', const Color(0xFFFFB300));
    if (name.startsWith('delete')) return ('Delete', cs.error);
    if (name.startsWith('unassign')) {
      return ('Unassign', const Color(0xFFEF5350));
    }
    if (name.startsWith('assign')) return ('Assign', const Color(0xFF42A5F5));
    if (name.startsWith('unenroll')) return ('Unenroll', cs.error);
    if (name.startsWith('enroll')) return ('Enroll', const Color(0xFF26A69A));
    if (name.startsWith('mark')) return ('Mark', const Color(0xFFFFB300));
    if (name.startsWith('approve')) {
      return ('Approve', const Color(0xFF66BB6A));
    }
    if (name.startsWith('upload')) return ('Upload', const Color(0xFF42A5F5));
    return ('Action', const Color(0xFF90A4AE));
  }
}
