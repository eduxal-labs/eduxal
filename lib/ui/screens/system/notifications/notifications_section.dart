import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/app_notification.dart';
import '../../../theme/app_theme.dart';

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
                separatorBuilder: (_, _) => Divider(
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
// Notification tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.cs});

  final AppNotification notification;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table icon.
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
              _iconForTable(notification.table),
              size: 16,
              color: cs.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row — table name + operation badge.
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
                    _OperationBadge(operation: notification.operation, cs: cs),
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
                // Timestamp.
                Text(
                  _relativeTime(notification.occurred),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a representative icon for the given [LogTable] value.
  static IconData _iconForTable(LogTable table) => switch (table) {
    LogTable.users => Icons.person_outline_rounded,
    LogTable.schools => Icons.school_outlined,
    LogTable.owners => Icons.admin_panel_settings_outlined,
    LogTable.students => Icons.face_outlined,
    LogTable.guardians => Icons.family_restroom_outlined,
    LogTable.departments => Icons.category_outlined,
    LogTable.teachers => Icons.person_outline_rounded,
    LogTable.staff => Icons.badge_outlined,
    LogTable.terms => Icons.calendar_month_outlined,
    LogTable.classTeachers => Icons.class_outlined,
    LogTable.enrollments => Icons.how_to_reg_outlined,
    LogTable.subjects => Icons.book_outlined,
    LogTable.attendance => Icons.checklist_outlined,
    LogTable.timetable => Icons.table_chart_outlined,
    LogTable.lessons => Icons.menu_book_outlined,
    LogTable.exams => Icons.quiz_outlined,
    LogTable.papers => Icons.description_outlined,
    LogTable.grades => Icons.grade_outlined,
    LogTable.fees => Icons.receipt_outlined,
    LogTable.invoices => Icons.receipt_long_outlined,
    LogTable.payments => Icons.payments_outlined,
    LogTable.announcements => Icons.campaign_outlined,
    LogTable.mastery => Icons.star_outline_rounded,
    LogTable.aiusage => Icons.auto_awesome_outlined,
    LogTable.settings => Icons.settings_outlined,
    LogTable.roles => Icons.verified_user_outlined,
    LogTable.scopes => Icons.lock_outline_rounded,
    LogTable.plans => Icons.subscriptions_outlined,
    LogTable.subscriptions => Icons.card_membership_outlined,
    LogTable.discounts => Icons.local_offer_outlined,
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
// Operation badge
// ─────────────────────────────────────────────────────────────────────────────

class _OperationBadge extends StatelessWidget {
  const _OperationBadge({required this.operation, required this.cs});

  final LogOperation operation;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final label = switch (operation) {
      LogOperation.insert => 'Insert',
      LogOperation.update => 'Update',
      LogOperation.delete => 'Delete',
    };
    final isDark = cs.brightness == Brightness.dark;
    final color = switch (operation) {
      LogOperation.insert => const Color(0xFF26A69A),
      LogOperation.update => const Color(0xFFFFB300),
      LogOperation.delete => cs.error,
    };

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
}
