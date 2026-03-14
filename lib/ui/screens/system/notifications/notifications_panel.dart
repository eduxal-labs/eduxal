import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/app_notification.dart';
import '../../../theme/app_theme.dart';

/// Right-side [Drawer] that shows all failed sync log entries for [accountId].
///
/// Opened by tapping the notification bell icon in the system dashboard app bar
/// via [Scaffold.openEndDrawer]. The panel is driven by a reactive
/// [StreamBuilder] on [LogsDao.watchFailedLogs] so the list updates in
/// real-time without any manual refresh.
class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    // Panel takes 85% of screen width on mobile, capped at 380px on desktop.
    final panelWidth = (width * 0.85).clamp(0.0, 380.0);

    return Drawer(
      width: panelWidth,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeader(cs: cs),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
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

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    itemCount: notifications.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NotificationCard(
                          notification: notifications[i],
                          cs: cs,
                          accountId: accountId,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel header
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
      child: Row(
        children: [
          Text(
            'Sync Errors',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          // Close button.
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
          ),
        ],
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
// Notification card — elevated, self-bounded, with retry + delete
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.notification,
    required this.cs,
    required this.accountId,
  });

  final AppNotification notification;
  final ColorScheme cs;
  final String accountId;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _retrying = false;
  bool _deleting = false;

  ColorScheme get cs => widget.cs;
  bool get _isDark => cs.brightness == Brightness.dark;

  Future<void> _onRetry() async {
    if (_retrying || _deleting) return;
    setState(() => _retrying = true);
    try {
      await logsDao.retryLog(widget.notification.logId);
      // Kick the sync engine so it picks up the re-queued action immediately.
      client.syncEngine.schedulePush();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _onDelete() async {
    if (_retrying || _deleting) return;
    setState(() => _deleting = true);
    try {
      await logsDao.deleteLogAndRevert(widget.notification.logId);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;

    return Container(
      decoration: BoxDecoration(
        color: _isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: _isDark
              ? cs.error.withValues(alpha: 0.22)
              : cs.error.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Main content ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action icon container.
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(
                      alpha: _isDark ? 0.32 : 0.45,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: cs.error.withValues(alpha: _isDark ? 0.25 : 0.18),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _iconForAction(n.action),
                    size: 15,
                    color: cs.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row — action name + badge.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _ActionBadge(action: n.action, cs: cs),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Error / attempt subtitle.
                      Text(
                        n.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                          letterSpacing: 0.1,
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Resource key badge.
                      if (n.resource.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh.withValues(
                              alpha: _isDark ? 1.0 : 0.6,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            n.resource,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'monospace',
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.75,
                              ),
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      // Timestamp.
                      Text(
                        _relativeTime(n.occurred),
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

          // ── Divider ────────────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 1,
            color: _isDark
                ? cs.outlineVariant.withValues(alpha: 0.25)
                : cs.outlineVariant.withValues(alpha: 0.4),
          ),

          // ── Action row ─────────────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: Row(
              children: [
                // Retry button.
                Expanded(
                  child: _CardActionButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    color: cs.primary,
                    cs: cs,
                    loading: _retrying,
                    disabled: _deleting,
                    onTap: _onRetry,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.kRadius - 1),
                    ),
                  ),
                ),
                // Vertical divider.
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _isDark
                      ? cs.outlineVariant.withValues(alpha: 0.25)
                      : cs.outlineVariant.withValues(alpha: 0.4),
                ),
                // Delete button.
                Expanded(
                  child: _CardActionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    color: cs.error,
                    cs: cs,
                    loading: _deleting,
                    disabled: _retrying,
                    onTap: _onDelete,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(AppTheme.kRadius - 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card action button (Retry / Delete)
// ─────────────────────────────────────────────────────────────────────────────

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.cs,
    required this.loading,
    required this.disabled,
    required this.onTap,
    required this.borderRadius,
  });

  final String label;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveAlpha = (loading || disabled) ? 0.38 : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (loading || disabled) ? null : onTap,
        borderRadius: borderRadius,
        child: Center(
          child: loading
              ? SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: color.withValues(alpha: 0.65),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 13,
                      color: color.withValues(alpha: effectiveAlpha),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: effectiveAlpha),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    if (name.startsWith('create')) return ('Create', const Color(0xFF26A69A));
    if (name.startsWith('update')) return ('Update', const Color(0xFFFFB300));
    if (name.startsWith('delete')) return ('Delete', cs.error);
    if (name.startsWith('unassign'))
      return ('Unassign', const Color(0xFFAB47BC));
    if (name.startsWith('assign')) return ('Assign', const Color(0xFF42A5F5));
    if (name.startsWith('unenroll')) return ('Unenroll', cs.error);
    if (name.startsWith('enroll')) return ('Enroll', const Color(0xFF26A69A));
    if (name.startsWith('mark')) return ('Mark', const Color(0xFFFFB300));
    if (name.startsWith('approve')) return ('Approve', const Color(0xFF66BB6A));
    return ('Action', const Color(0xFF90A4AE));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — icon mapping & relative time
// ─────────────────────────────────────────────────────────────────────────────

IconData _iconForAction(SyncAction action) => switch (action) {
  SyncAction.createSchool ||
  SyncAction.updateSchool ||
  SyncAction.deleteSchool => Icons.school_outlined,
  SyncAction.createTeacher ||
  SyncAction.updateTeacher ||
  SyncAction.deleteTeacher => Icons.person_outline_rounded,
  SyncAction.createStaff ||
  SyncAction.updateStaff ||
  SyncAction.deleteStaff => Icons.badge_outlined,
  SyncAction.createOwner ||
  SyncAction.deleteOwner => Icons.admin_panel_settings_outlined,
  SyncAction.createStudent ||
  SyncAction.updateStudent ||
  SyncAction.deleteStudent ||
  SyncAction.enrollStudent ||
  SyncAction.unenrollStudent => Icons.face_outlined,
  SyncAction.createGuardian ||
  SyncAction.updateGuardian ||
  SyncAction.deleteGuardian => Icons.family_restroom_outlined,
  SyncAction.createDepartment ||
  SyncAction.updateDepartment ||
  SyncAction.deleteDepartment => Icons.category_outlined,
  SyncAction.createTerm ||
  SyncAction.updateTerm ||
  SyncAction.deleteTerm => Icons.calendar_month_outlined,
  SyncAction.assignClassTeacher ||
  SyncAction.unassignClassTeacher => Icons.class_outlined,
  SyncAction.assignSubject || SyncAction.unassignSubject => Icons.book_outlined,
  SyncAction.createTimetableEntry ||
  SyncAction.updateTimetableEntry ||
  SyncAction.deleteTimetableEntry => Icons.table_chart_outlined,
  SyncAction.markAttendance ||
  SyncAction.deleteAttendance => Icons.checklist_outlined,
  SyncAction.createLesson ||
  SyncAction.deleteLesson => Icons.menu_book_outlined,
  SyncAction.createExam ||
  SyncAction.updateExam ||
  SyncAction.deleteExam => Icons.quiz_outlined,
  SyncAction.createPaper ||
  SyncAction.updatePaper ||
  SyncAction.deletePaper => Icons.description_outlined,
  SyncAction.markGrades ||
  SyncAction.updateGrade ||
  SyncAction.deleteGrade => Icons.grade_outlined,
  SyncAction.updateMastery => Icons.star_outline_rounded,
  SyncAction.createFee ||
  SyncAction.updateFee ||
  SyncAction.deleteFee => Icons.receipt_outlined,
  SyncAction.createInvoice ||
  SyncAction.updateInvoice ||
  SyncAction.deleteInvoice => Icons.receipt_long_outlined,
  SyncAction.createPayment ||
  SyncAction.updatePayment ||
  SyncAction.deletePayment ||
  SyncAction.approvePayment => Icons.payments_outlined,
  SyncAction.createAnnouncement ||
  SyncAction.updateAnnouncement ||
  SyncAction.deleteAnnouncement => Icons.campaign_outlined,
  SyncAction.createRole ||
  SyncAction.updateRole ||
  SyncAction.deleteRole => Icons.verified_user_outlined,
  SyncAction.assignRole ||
  SyncAction.unassignRole => Icons.lock_outline_rounded,
  SyncAction.updateUser ||
  SyncAction.deleteUser => Icons.person_outline_rounded,
  SyncAction.updateSettings => Icons.settings_outlined,
  SyncAction.createPlan ||
  SyncAction.updatePlan ||
  SyncAction.deletePlan => Icons.subscriptions_outlined,
  SyncAction.updateAiUsage => Icons.auto_awesome_outlined,
  SyncAction.createSubscription ||
  SyncAction.updateSubscription ||
  SyncAction.deleteSubscription => Icons.card_membership_outlined,
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
  SyncAction.addExamGrade || SyncAction.removeExamGrade => Icons.grade_outlined,
};

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
