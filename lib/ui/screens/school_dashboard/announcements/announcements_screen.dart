import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../theme/app_theme.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Entry point
// ═════════════════════════════════════════════════════════════════════════════

/// Top-level entry point for the Announcements section.
///
/// Role dispatch:
/// - **Owner / Staff:** Full feed with compose FAB. Can create, edit, delete.
/// - **Teacher / Student / Guardian:** Read-only feed filtered by audience
///   bitmask and (for students/guardians) by grade/stream.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
    }

    final entry = schoolContext.currentEntry.value;

    return switch (entry) {
      OwnerEntry() => _AdminFeed(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      StaffEntry() => _AdminFeed(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      TeacherEntry() =>
        schoolContext.permissions.canAny(Resource.announcements, [
              Action.create,
              Action.update,
              Action.delete,
            ])
            ? _AdminFeed(schoolContext: schoolContext, termContext: termCtx)
            : _RoleFeed(
                schoolContext: schoolContext,
                termContext: termCtx,
                audienceBit: AudienceBits.teachers,
              ),
      StudentEntry() => _RoleFeed(
        schoolContext: schoolContext,
        termContext: termCtx,
        audienceBit: AudienceBits.students,
      ),
      GuardianEntry() => _RoleFeed(
        schoolContext: schoolContext,
        termContext: termCtx,
        audienceBit: AudienceBits.guardians,
      ),
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ADMIN FEED — Owner / Staff (full access, compose FAB)
// ═════════════════════════════════════════════════════════════════════════════

class _AdminFeed extends StatefulWidget {
  const _AdminFeed({required this.schoolContext, required this.termContext});

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_AdminFeed> createState() => _AdminFeedState();
}

class _AdminFeedState extends State<_AdminFeed> {
  late final AnnouncementsDao _dao;
  final SchoolConfig _config = SchoolConfig.defaults();

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = AnnouncementsDao(db);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // settings table removed in schema v2 — config no longer persisted here
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final entry = widget.schoolContext.currentEntry.value;
    final canCreate =
        entry is OwnerEntry ||
        widget.schoolContext.permissions.can(
          Resource.announcements,
          Action.create,
        );
    final canEdit =
        entry is OwnerEntry ||
        widget.schoolContext.permissions.can(
          Resource.announcements,
          Action.update,
        );
    final canDelete =
        entry is OwnerEntry ||
        widget.schoolContext.permissions.can(
          Resource.announcements,
          Action.delete,
        );

    return Stack(
      children: [
        StreamBuilder<List<AnnouncementWithAuthor>>(
          stream: _dao.watchAllAnnouncements(_schoolId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final items = snap.data ?? [];

            if (items.isEmpty) {
              return _EmptyState(
                icon: Icons.campaign_outlined,
                label: 'No announcements yet',
                sublabel: canCreate
                    ? 'Tap + to broadcast the first message'
                    : 'Nothing here yet',
                cs: cs,
              );
            }

            return _AnnouncementList(
              items: items,
              cs: cs,
              isDark: isDark,
              canEdit: canEdit,
              canDelete: canDelete,
              dao: _dao,
              config: _config,
              schoolContext: widget.schoolContext,
            );
          },
        ),

        // Compose FAB — only visible if user has create permission.
        if (canCreate)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.small(
              heroTag: 'fab_announcements_compose',
              onPressed: () => _showComposeSheet(
                context,
                dao: _dao,
                schoolId: _schoolId,
                config: _config,
              ),
              tooltip: 'Compose',
              elevation: 4,
              highlightElevation: 6,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, size: 20),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ROLE FEED — Teacher / Student / Guardian (read-only, filtered)
// ═════════════════════════════════════════════════════════════════════════════

class _RoleFeed extends StatefulWidget {
  const _RoleFeed({
    required this.schoolContext,
    required this.termContext,
    required this.audienceBit,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final int audienceBit;

  @override
  State<_RoleFeed> createState() => _RoleFeedState();
}

class _RoleFeedState extends State<_RoleFeed> {
  late final AnnouncementsDao _dao;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = AnnouncementsDao(db);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<AnnouncementWithAuthor>>(
      stream: _dao.watchAnnouncementsForAudience(
        _schoolId,
        audienceBit: widget.audienceBit,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final items = snap.data ?? [];

        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.campaign_outlined,
            label: 'No announcements',
            sublabel: 'Nothing here for you yet',
            cs: cs,
          );
        }

        return _AnnouncementList(
          items: items,
          cs: cs,
          isDark: isDark,
          canEdit: false,
          canDelete: false,
          dao: _dao,
          config: SchoolConfig.defaults(),
          schoolContext: widget.schoolContext,
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT LIST — the chronological feed (data-table style)
// ═════════════════════════════════════════════════════════════════════════════

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({
    required this.items,
    required this.cs,
    required this.isDark,
    required this.canEdit,
    required this.canDelete,
    required this.dao,
    required this.config,
    required this.schoolContext,
  });

  final List<AnnouncementWithAuthor> items;
  final ColorScheme cs;
  final bool isDark;
  final bool canEdit;
  final bool canDelete;
  final AnnouncementsDao dao;
  final SchoolConfig config;
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
      itemCount: items.length * 2 - 1,
      itemBuilder: (context, i) {
        if (i.isOdd) {
          return AppTheme.tableRowDivider(isDark, cs);
        }
        final item = items[i ~/ 2];
        return _AnnouncementRow(
          item: item,
          cs: cs,
          isDark: isDark,
          canEdit: canEdit,
          canDelete: canDelete,
          dao: dao,
          config: config,
          schoolContext: schoolContext,
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT ROW — a single row in the data-table feed
// ═════════════════════════════════════════════════════════════════════════════

class _AnnouncementRow extends StatefulWidget {
  const _AnnouncementRow({
    required this.item,
    required this.cs,
    required this.isDark,
    required this.canEdit,
    required this.canDelete,
    required this.dao,
    required this.config,
    required this.schoolContext,
  });

  final AnnouncementWithAuthor item;
  final ColorScheme cs;
  final bool isDark;
  final bool canEdit;
  final bool canDelete;
  final AnnouncementsDao dao;
  final SchoolConfig config;
  final SchoolContext schoolContext;

  @override
  State<_AnnouncementRow> createState() => _AnnouncementRowState();
}

class _AnnouncementRowState extends State<_AnnouncementRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  AnnouncementWithAuthor get item => widget.item;
  ColorScheme get cs => widget.cs;
  bool get isDark => widget.isDark;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final audienceTags = _buildAudienceTags();
    final gradeTags = _buildGradeTags();
    final allTags = [...audienceTags, ...gradeTags];

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = cs.primary.withValues(alpha: 0.08);
    final pressBg = cs.primary.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () => _showDetailSheet(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _isPressed
                    ? pressBg
                    : _isHovered
                    ? hoverBg
                    : idleBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? cs.outline.withValues(alpha: isDark ? 0.18 : 0.15)
                      : cs.outline.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Author avatar ────────────────────────────────────
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          _authorInitial(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Main content ─────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title + date row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimestamp(item.created),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Body preview
                          Text(
                            item.content,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.65,
                              ),
                              height: 1.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Audience tags
                          if (allTags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(spacing: 5, runSpacing: 4, children: allTags),
                          ],
                        ],
                      ),
                    ),

                    // ── Desktop actions ──────────────────────────────────
                    if ((widget.canEdit || widget.canDelete) && isDesktop) ...[
                      const SizedBox(width: 4),
                      _RowActions(
                        isHovered: _isHovered,
                        onEdit: widget.canEdit
                            ? () => _showEditSheet(context)
                            : null,
                        onDelete: widget.canDelete
                            ? () => _confirmDelete(context)
                            : null,
                        cs: cs,
                      ),
                    ],

                    // ── Mobile three-dot ─────────────────────────────────
                    if ((widget.canEdit || widget.canDelete) && !isDesktop)
                      _MobileRowMenu(
                        cs: cs,
                        isDark: isDark,
                        onEdit: widget.canEdit
                            ? () => _showEditSheet(context)
                            : null,
                        onDelete: widget.canDelete
                            ? () => _confirmDelete(context)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _authorInitial() {
    final name = item.authorName;
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  List<Widget> _buildAudienceTags() {
    final audience = item.audience;
    if (audience == 0) {
      return [
        _Tag(label: 'Everyone', color: cs.primary, cs: cs, isDark: isDark),
      ];
    }
    final tags = <Widget>[];
    for (final entry in AudienceBits.labels.entries) {
      if ((audience & entry.key) != 0) {
        tags.add(
          _Tag(label: entry.value, color: cs.tertiary, cs: cs, isDark: isDark),
        );
      }
    }
    return tags;
  }

  List<Widget> _buildGradeTags() {
    final grade = item.grade;
    if (grade == null) return [];

    final label = _gradeLabel(grade);
    final tags = <Widget>[
      _Tag(label: label, color: cs.secondary, cs: cs, isDark: isDark),
    ];

    if (item.stream != null) {
      tags.add(
        _Tag(
          label: 'Stream ${item.stream}',
          color: cs.secondary,
          cs: cs,
          isDark: isDark,
        ),
      );
    }
    return tags;
  }

  void _showDetailSheet(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (_) => _DetailSheet(item: item, cs: cs, isDark: isDark),
    );
  }

  void _showEditSheet(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (_) => _ComposeSheet(
        dao: widget.dao,
        schoolId: item.school,
        config: widget.config,
        existing: item,
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete announcement?',
      message:
          'This cannot be undone. The announcement will be removed for all users.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final user = cache.currentUser;
    if (user == null) return;
    await widget.dao.deleteAnnouncement(id: item.id, accountId: user.user.id);
  }
}

// ─── Desktop inline action buttons ───────────────────────────────────────────

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.isHovered,
    required this.onEdit,
    required this.onDelete,
    required this.cs,
  });

  final bool isHovered;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          _ActionBtn(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: cs.onSurfaceVariant,
            isRowHovered: isHovered,
            onTap: onEdit!,
          ),
        if (onDelete != null)
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: cs.error,
            isRowHovered: isHovered,
            onTap: onDelete!,
          ),
      ],
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isRowHovered,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isRowHovered;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveAlpha = (_isHovered || widget.isRowHovered) ? 1.0 : 0.0;
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: effectiveAlpha,
              child: Icon(widget.icon, size: 16, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mobile three-dot menu ────────────────────────────────────────────────────

class _MobileRowMenu extends StatelessWidget {
  const _MobileRowMenu({
    required this.cs,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Future<void> _showPopupMenu(BuildContext context, GlobalKey key) async {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonRect =
        renderBox.localToGlobal(Offset.zero, ancestor: overlay) &
        renderBox.size;
    final screenSize = MediaQuery.sizeOf(context);
    final screenRect = Offset.zero & screenSize;
    final position = RelativeRect.fromRect(buttonRect, screenRect);

    final actions = [
      if (onEdit != null)
        (
          icon: Icons.edit_outlined,
          label: 'Edit',
          isDestructive: false,
          onTap: onEdit!,
        ),
      if (onDelete != null)
        (
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          isDestructive: true,
          onTap: onDelete!,
        ),
    ];

    await showMenu<int>(
      context: context,
      position: position,
      color: AppTheme.overlayBg(isDark, cs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        side: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      items: [
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  actions[i].icon,
                  size: 16,
                  color: actions[i].isDestructive
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  actions[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: actions[i].isDestructive ? cs.error : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).then((index) {
      if (index != null) actions[index].onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuKey = GlobalKey();
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: menuKey,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
        tooltip: 'More actions',
        onPressed: () => _showPopupMenu(context, menuKey),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAG — small audience / grade chip
// ═════════════════════════════════════════════════════════════════════════════

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final Color color;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DETAIL SHEET — full announcement view
// ═════════════════════════════════════════════════════════════════════════════

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.item,
    required this.cs,
    required this.isDark,
  });

  final AnnouncementWithAuthor item;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Content.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author + time.
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            (item.authorName ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.authorName ?? 'Deleted user',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTimestampFull(item.created),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Title.
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Full content.
                  Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),

                  // Audience tags.
                  if (item.audience != 0 || item.grade != null) ...[
                    const SizedBox(height: 20),
                    Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      height: 1,
                    ),
                    const SizedBox(height: 14),
                    _DetailSection(
                      label: 'Audience',
                      cs: cs,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (item.audience == 0)
                            _Tag(
                              label: 'Everyone',
                              color: cs.primary,
                              cs: cs,
                              isDark: isDark,
                            )
                          else
                            for (final entry in AudienceBits.labels.entries)
                              if ((item.audience & entry.key) != 0)
                                _Tag(
                                  label: entry.value,
                                  color: cs.tertiary,
                                  cs: cs,
                                  isDark: isDark,
                                ),
                          if (item.grade != null)
                            _Tag(
                              label: _gradeLabel(item.grade!),
                              color: cs.secondary,
                              cs: cs,
                              isDark: isDark,
                            ),
                          if (item.stream != null)
                            _Tag(
                              label: 'Stream ${item.stream}',
                              color: cs.secondary,
                              cs: cs,
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.label,
    required this.cs,
    required this.child,
  });

  final String label;
  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COMPOSE SHEET — create or edit an announcement
// ═════════════════════════════════════════════════════════════════════════════

void _showComposeSheet(
  BuildContext context, {
  required AnnouncementsDao dao,
  required String schoolId,
  required SchoolConfig config,
  AnnouncementWithAuthor? existing,
}) {
  showEduSheet(
    context: context,
    builder: (_) => _ComposeSheet(
      dao: dao,
      schoolId: schoolId,
      config: config,
      existing: existing,
    ),
  );
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({
    required this.dao,
    required this.schoolId,
    required this.config,
    this.existing,
  });

  final AnnouncementsDao dao;
  final String schoolId;
  final SchoolConfig config;
  final AnnouncementWithAuthor? existing;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  // Audience — bitmask built from checkboxes.
  bool _audienceStudents = false;
  bool _audienceGuardians = false;
  bool _audienceTeachers = false;
  bool _audienceStaff = false;
  bool _audienceAll = true;

  // Grade/stream targeting.
  int? _selectedGrade;
  int? _selectedStream;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  List<int> get _gradeOptions {
    final grades = <int>[];
    for (final curriculum in widget.config.curricula) {
      for (final gc in curriculum.grades) {
        if (!grades.contains(gc.grade)) grades.add(gc.grade);
      }
    }
    grades.sort();
    return grades;
  }

  List<GradeStream> get _streamOptions {
    if (_selectedGrade == null) return [];
    for (final curriculum in widget.config.curricula) {
      for (final gc in curriculum.grades) {
        if (gc.grade == _selectedGrade) return gc.streams;
      }
    }
    return [];
  }

  @override
  void initState() {
    super.initState();

    final ex = widget.existing;
    _titleCtrl = TextEditingController(text: ex?.title ?? '');
    _contentCtrl = TextEditingController(text: ex?.content ?? '');

    if (ex != null) {
      final aud = ex.audience;
      if (aud == 0) {
        _audienceAll = true;
      } else {
        _audienceAll = false;
        _audienceStudents = (aud & AudienceBits.students) != 0;
        _audienceGuardians = (aud & AudienceBits.guardians) != 0;
        _audienceTeachers = (aud & AudienceBits.teachers) != 0;
        _audienceStaff = (aud & AudienceBits.staff) != 0;
      }
      _selectedGrade = ex.grade;
      _selectedStream = ex.stream;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  int _buildAudienceMask() {
    if (_audienceAll) return 0;
    int mask = 0;
    if (_audienceStudents) mask |= AudienceBits.students;
    if (_audienceGuardians) mask |= AudienceBits.guardians;
    if (_audienceTeachers) mask |= AudienceBits.teachers;
    if (_audienceStaff) mask |= AudienceBits.staff;
    // If no specific audience checked but not 'all', treat as all.
    if (mask == 0) return 0;
    return mask;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = cache.currentUser;
      if (user == null) return;
      final accountId = user.user.id;
      final audience = _buildAudienceMask();

      if (_isEditing) {
        await widget.dao.updateAnnouncement(
          id: widget.existing!.id,
          accountId: accountId,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          audience: audience,
          grade: Value(_selectedGrade),
          stream: Value(_selectedStream),
        );
      } else {
        final id = _generateId();
        await widget.dao.createAnnouncement(
          id: id,
          schoolId: widget.schoolId,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          audience: audience,
          grade: _selectedGrade,
          stream: _selectedStream,
          authorId: accountId,
          accountId: accountId,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save announcement')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // EduSheet already handles: background colour, border radius, drag handle,
    // and keyboard inset padding. This widget provides ONLY the form content.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header: title + publish/spinner ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? 'Edit Announcement' : 'New Announcement',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                )
              else
                TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    _isEditing ? 'Update' : 'Publish',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              // Close button aligned with EduSheet title row convention.
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        // Thin divider beneath the header row.
        Container(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.3)),

        // ── Form body ────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field.
                  _SheetField(
                    controller: _titleCtrl,
                    label: 'Title',
                    hint: 'Announcement title',
                    cs: cs,
                    isDark: isDark,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 14),

                  // Content field — multiline.
                  _SheetField(
                    controller: _contentCtrl,
                    label: 'Content',
                    hint: 'Write your message...',
                    cs: cs,
                    isDark: isDark,
                    maxLines: 6,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 18),

                  // ── Audience targeting ───────────────────────────────
                  _SectionLabel(label: 'Audience', cs: cs),
                  const SizedBox(height: 8),

                  _AudienceCheckbox(
                    label: 'Everyone',
                    value: _audienceAll,
                    cs: cs,
                    onChanged: (v) {
                      setState(() {
                        _audienceAll = v ?? true;
                        if (_audienceAll) {
                          _audienceStudents = false;
                          _audienceGuardians = false;
                          _audienceTeachers = false;
                          _audienceStaff = false;
                        }
                      });
                    },
                  ),
                  if (!_audienceAll) ...[
                    _AudienceCheckbox(
                      label: 'Students',
                      value: _audienceStudents,
                      cs: cs,
                      onChanged: (v) =>
                          setState(() => _audienceStudents = v ?? false),
                    ),
                    _AudienceCheckbox(
                      label: 'Guardians',
                      value: _audienceGuardians,
                      cs: cs,
                      onChanged: (v) =>
                          setState(() => _audienceGuardians = v ?? false),
                    ),
                    _AudienceCheckbox(
                      label: 'Teachers',
                      value: _audienceTeachers,
                      cs: cs,
                      onChanged: (v) =>
                          setState(() => _audienceTeachers = v ?? false),
                    ),
                    _AudienceCheckbox(
                      label: 'Staff',
                      value: _audienceStaff,
                      cs: cs,
                      onChanged: (v) =>
                          setState(() => _audienceStaff = v ?? false),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ── Grade / stream targeting ─────────────────────────
                  _SectionLabel(label: 'Target class (optional)', cs: cs),
                  const SizedBox(height: 8),

                  // Grade dropdown.
                  _DropdownField<int?>(
                    label: 'Grade',
                    value: _selectedGrade,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All grades'),
                      ),
                      for (final g in _gradeOptions)
                        DropdownMenuItem(value: g, child: Text(_gradeLabel(g))),
                    ],
                    cs: cs,
                    isDark: isDark,
                    onChanged: (v) {
                      setState(() {
                        _selectedGrade = v;
                        _selectedStream = null;
                      });
                    },
                  ),

                  if (_selectedGrade != null && _streamOptions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DropdownField<int?>(
                      label: 'Stream',
                      value: _selectedStream,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All streams'),
                        ),
                        for (final s in _streamOptions)
                          DropdownMenuItem(value: s.code, child: Text(s.name)),
                      ],
                      cs: cs,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _selectedStream = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Form sub-components
// ═════════════════════════════════════════════════════════════════════════════

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.cs,
    required this.isDark,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ColorScheme cs;
  final bool isDark;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    // Use AppTheme.nestedBg equivalent: a step above modalBg so the field is
    // visible against the EduSheet background in both light and dark mode.
    final fillColor = isDark
        ? const Color(0xFF1A2536) // AppTheme.nestedBg dark value
        : cs.surfaceContainerHighest;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: isDark
              ? BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: isDark
              ? BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _AudienceCheckbox extends StatelessWidget {
  const _AudienceCheckbox({
    required this.label,
    required this.value,
    required this.cs,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ColorScheme cs;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: cs.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                width: 1.5,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Match _SheetField fill: nestedBg in dark, surfaceContainerHighest in light.
    final fillColor = isDark
        ? const Color(0xFF1A2536)
        : cs.surfaceContainerHighest;

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      dropdownColor: isDark ? const Color(0xFF1A2536) : cs.surface,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      icon: Icon(
        Icons.expand_more,
        size: 18,
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: isDark
              ? BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: isDark
              ? BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ELEVATED FAB
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY & NO-TERM STATES
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoTermState extends StatelessWidget {
  const _NoTermState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _EmptyState(
      icon: Icons.event_busy_outlined,
      label: 'No active term',
      sublabel: 'Create a term to get started with announcements',
      cs: cs,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═════════════════════════════════════════════════════════════════════════════

/// Generates a simple time-based unique id.
String _generateId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rand = math.Random().nextInt(0x7FFFFFFF);
  return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
}

/// Formats an epoch-seconds [BigInt] as a relative or short date string.
String _formatTimestamp(BigInt epochSeconds) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds.toInt() * 1000);
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return '${dt.day} ${_monthAbbr(dt.month)} ${dt.year}';
}

/// Formats an epoch-seconds [BigInt] as a full date + time string.
String _formatTimestampFull(BigInt epochSeconds) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds.toInt() * 1000);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_monthAbbr(dt.month)} ${dt.year} at $h:$m';
}

String _monthAbbr(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

/// Returns a human-readable grade label. Attempts CBC labels first, then
/// 8-4-4, then falls back to "Grade N".
String _gradeLabel(int grade) {
  return kCbcGradeLabels[grade] ??
      kEightFourFourGradeLabels[grade] ??
      'Grade $grade';
}
