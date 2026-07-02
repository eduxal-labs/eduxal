import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/status_indicator.dart';

import 'school_detail_screen.dart';

/// The Schools data section of the system dashboard.
///
/// Shows a reactive list of all schools from [SchoolsDao.watchAllSchools],
/// with client-side search (name / motto) and status filter.
///
/// On **mobile** this is the body of the Schools tab.
/// On **desktop** this is the content inside the Schools tab of the data area.
class SchoolsSection extends StatefulWidget {
  const SchoolsSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<SchoolsSection> createState() => _SchoolsSectionState();
}

class _SchoolsSectionState extends State<SchoolsSection> {
  // ── Filter state ───────────────────────────────────────────────────────────

  final _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<SchoolStatus> _statusFilter = {};
  bool _filterExpanded = false;

  // ── Search debounce ────────────────────────────────────────────────────────

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<SchoolsData> _applyFilters(List<SchoolsData> all) {
    var list = all;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.motto?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_statusFilter.isNotEmpty) {
      list = list.where((s) => _statusFilter.contains(s.status)).toList();
    }

    return list;
  }

  bool get _hasActiveFilters => _statusFilter.isNotEmpty;

  void _clearFilters() => setState(() => _statusFilter.clear());

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _trashSchool(SchoolsData school) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Trash School',
      message:
          'Set ${school.name} to Deleted status? '
          'This is a soft delete — the record can be restored later.',
      confirmLabel: 'Trash',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await schoolsDao.updateSchoolStatus(
        school.id,
        SchoolStatus.deleted,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${school.name} moved to trash')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to trash school: $e')));
      }
    }
  }

  Future<void> _purgeSchool(SchoolsData school) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Purge School',
      message:
          'Permanently delete ${school.name}?\n\n'
          'This action is irreversible and will permanently remove this record.',
      confirmLabel: 'Purge',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await schoolsDao.purgeSchool(school.id, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${school.name} permanently deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to purge school: $e')));
      }
    }
  }

  void _openDetail(SchoolsData school) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SchoolDetailScreen(school: school, permissions: widget.permissions),
      ),
    );
  }

  Future<void> _setStatus(
    SchoolsData school,
    SchoolStatus status,
    String label,
  ) async {
    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await schoolsDao.updateSchoolStatus(
        school.id,
        status,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${school.name} $label')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  // ── Build row actions for a school ─────────────────────────────────────────

  List<_RowAction> _buildActions(SchoolsData school) {
    final actions = <_RowAction>[];
    final canUpdate = widget.permissions.can(Resource.schools, Action.update);
    final canDelete = widget.permissions.can(Resource.schools, Action.delete);

    if (canUpdate &&
        (school.status == SchoolStatus.trial ||
            school.status == SchoolStatus.suspended)) {
      actions.add(
        _RowAction(
          icon: Icons.check_circle_outline_rounded,
          label: 'Activate',
          onTap: () => _setStatus(school, SchoolStatus.active, 'activated'),
        ),
      );
    }

    if (canUpdate &&
        (school.status == SchoolStatus.active ||
            school.status == SchoolStatus.trial)) {
      actions.add(
        _RowAction(
          icon: Icons.block_rounded,
          label: 'Suspend',
          onTap: () => _setStatus(school, SchoolStatus.suspended, 'suspended'),
        ),
      );
    }

    if (canUpdate &&
        (school.status == SchoolStatus.suspended ||
            school.status == SchoolStatus.deleted)) {
      actions.add(
        _RowAction(
          icon: Icons.restore_rounded,
          label: 'Restore',
          onTap: () => _setStatus(school, SchoolStatus.active, 'restored'),
        ),
      );
    }

    if (canDelete && school.status != SchoolStatus.deleted) {
      actions.add(
        _RowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          isDestructive: true,
          onTap: () => _trashSchool(school),
        ),
      );
    }

    if (widget.permissions.can(Resource.schools, Action.purge) &&
        school.status == SchoolStatus.deleted) {
      actions.add(
        _RowAction(
          icon: Icons.delete_forever_rounded,
          label: 'Purge',
          isDestructive: true,
          onTap: () => _purgeSchool(school),
        ),
      );
    }

    return actions;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<SchoolsData>>(
      stream: schoolsDao.watchAllSchools(),
      builder: (context, snapshot) {
        final rawSchools = snapshot.data ?? [];
        // Per AGENT.md §17a: only Super users see deleted records.
        final allSchools = widget.permissions.canSeeDeleted
            ? rawSchools
            : rawSchools
                  .where((s) => s.status != SchoolStatus.deleted)
                  .toList();
        final filtered = _applyFilters(allSchools);

        return Column(
          children: [
            // ── Toolbar ──────────────────────────────────────────────────
            _Toolbar(
              searchController: _searchController,
              filterExpanded: _filterExpanded,
              hasActiveFilters: _hasActiveFilters,
              onToggleFilter: () =>
                  setState(() => _filterExpanded = !_filterExpanded),
              cs: cs,
            ),

            // ── Filter panel ─────────────────────────────────────────────
            if (_filterExpanded)
              _FilterPanel(
                statusFilter: _statusFilter,
                showDeleted: widget.permissions.canSeeDeleted,
                hasActiveFilters: _hasActiveFilters,
                onStatusToggle: (s) => setState(
                  () => _statusFilter.contains(s)
                      ? _statusFilter.remove(s)
                      : _statusFilter.add(s),
                ),
                onClear: _clearFilters,
                cs: cs,
              ),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No schools found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty || _hasActiveFilters
                                ? 'No schools match your filters.'
                                : 'Create a school to get started.',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (context, index) {
                        final school = filtered[index];
                        return _SchoolRow(
                          school: school,
                          onTap: () => _openDetail(school),
                          actions: _buildActions(school),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RowAction — lightweight action descriptor
// ─────────────────────────────────────────────────────────────────────────────

class _RowAction {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

// ─────────────────────────────────────────────────────────────────────────────
// _SchoolRow — flat data-table row with status-tinted accent
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolRow extends StatefulWidget {
  const _SchoolRow({
    required this.school,
    required this.onTap,
    required this.actions,
  });

  final SchoolsData school;
  final VoidCallback onTap;
  final List<_RowAction> actions;

  @override
  State<_SchoolRow> createState() => _SchoolRowState();
}

class _SchoolRowState extends State<_SchoolRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

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

  /// Returns the accent colour for a given [SchoolStatus].
  Color _accentColor() {
    return switch (widget.school.status) {
      SchoolStatus.trial => const Color(0xFF42A5F5), // blue
      SchoolStatus.active => const Color(0xFF26A69A), // green / teal
      SchoolStatus.suspended => const Color(0xFFFFB300), // amber
      SchoolStatus.cancelled => const Color(0xFFFF7043), // orange
      SchoolStatus.deleted => const Color(0xFFEF5350), // red
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final accentColor = _accentColor();

    // ── Background states ──────────────────────────────────────────────
    final idleBg = isDark
        ? accentColor.withValues(alpha: 0.06)
        : accentColor.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.12);

    final currentBg = _isPressed
        ? pressBg
        : _isHovered
        ? hoverBg
        : idleBg;

    // ── Logo with status ring + status dot ─────────────────────────────
    final logo = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius + 2),
            border: Border.all(
              color: accentColor.withValues(
                alpha: _isHovered || _isPressed ? 0.7 : 0.35,
              ),
              width: 1.5,
            ),
          ),
          child: _SchoolLogo(schoolId: widget.school.id, cs: cs),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: SchoolStatusDot(
            status: widget.school.status,
            backgroundColor: currentBg,
          ),
        ),
      ],
    );

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
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: currentBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? accentColor.withValues(alpha: isDark ? 0.35 : 0.25)
                      : cs.outline.withValues(alpha: isDark ? 0.10 : 0.08),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Status accent bar ───────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 4 : 3,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Content ─────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              // Logo
                              logo,
                              const SizedBox(width: 12),

                              // Name + motto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.school.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    if (widget.school.motto != null &&
                                        widget.school.motto!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.school.motto!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: cs.onSurfaceVariant.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Joined date
                              const SizedBox(width: 8),
                              Text(
                                _formatRelativeDate(
                                  widget.school.created.toInt(),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),

                              // Actions
                              if (widget.actions.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                isDesktop
                                    ? _InlineActions(
                                        actions: widget.actions,
                                        isHovered: _isHovered,
                                      )
                                    : _MobileActions(actions: widget.actions),
                              ],

                              const SizedBox(width: 4),

                              // ── Animated chevron ────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(_isHovered ? 0.15 : 0.0, 0),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isHovered ? 0.8 : 0.35,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _isHovered
                                        ? accentColor
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InlineActions — desktop: row of icon buttons shown on hover
// ─────────────────────────────────────────────────────────────────────────────

class _InlineActions extends StatelessWidget {
  const _InlineActions({required this.actions, required this.isHovered});

  final List<_RowAction> actions;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map((a) => _InlineActionButton(action: a, isRowHovered: isHovered))
            .toList(),
      ),
    );
  }
}

class _InlineActionButton extends StatefulWidget {
  const _InlineActionButton({required this.action, required this.isRowHovered});

  final _RowAction action;
  final bool isRowHovered;

  @override
  State<_InlineActionButton> createState() => _InlineActionButtonState();
}

class _InlineActionButtonState extends State<_InlineActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = widget.action.isDestructive
        ? cs.error
        : cs.onSurfaceVariant;
    final effectiveAlpha = (_isHovered || widget.isRowHovered) ? 1.0 : 0.0;

    return Tooltip(
      message: widget.action.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.action.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered
                  ? baseColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: effectiveAlpha,
              child: Icon(widget.action.icon, size: 16, color: baseColor),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MobileActions — mobile: three-dot → compact popup menu
// ─────────────────────────────────────────────────────────────────────────────

class _MobileActions extends StatelessWidget {
  const _MobileActions({required this.actions});

  final List<_RowAction> actions;

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    final cs = Theme.of(context).colorScheme;

    // Single action — render directly as an icon button
    if (actions.length == 1) {
      final action = actions.first;
      final color = action.isDestructive ? cs.error : cs.onSurfaceVariant;
      return Tooltip(
        message: action.label,
        waitDuration: const Duration(milliseconds: 400),
        child: SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: Icon(action.icon, size: 18, color: color),
            onPressed: action.onTap,
          ),
        ),
      );
    }

    // Multiple actions — three-dot → compact positioned popup menu
    final key = GlobalKey();
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: key,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
        tooltip: 'More actions',
        onPressed: () => _showPopupMenu(context, key),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.filterExpanded,
    required this.hasActiveFilters,
    required this.onToggleFilter,
    required this.cs,
  });

  final TextEditingController searchController;
  final bool filterExpanded;
  final bool hasActiveFilters;
  final VoidCallback onToggleFilter;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Search field.
          Expanded(
            child: Container(
              height: 42,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  filled: false,
                  hintText: 'Search schools...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),
          // Filter toggle.
          _ToolbarIcon(
            icon: hasActiveFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            active: filterExpanded || hasActiveFilters,
            onTap: onToggleFilter,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active ? cs.primary.withValues(alpha: 0.10) : cs.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: active
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
            border: Border.all(
              color: active
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel — status names only (no badges)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.statusFilter,
    required this.showDeleted,
    required this.hasActiveFilters,
    required this.onStatusToggle,
    required this.onClear,
    required this.cs,
  });

  final Set<SchoolStatus> statusFilter;
  final bool showDeleted;
  final bool hasActiveFilters;
  final void Function(SchoolStatus) onStatusToggle;
  final VoidCallback onClear;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final statuses = [
      (SchoolStatus.trial, 'Trial'),
      (SchoolStatus.active, 'Active'),
      (SchoolStatus.cancelled, 'Cancelled'),
      (SchoolStatus.suspended, 'Suspended'),
      if (showDeleted) (SchoolStatus.deleted, 'Deleted'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: statuses.map((e) {
                  final selected = statusFilter.contains(e.$1);
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: () => onStatusToggle(e.$1),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary.withValues(
                                  alpha: isDark ? 0.18 : 0.12,
                                )
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? cs.primary.withValues(
                                    alpha: isDark ? 0.55 : 0.4,
                                  )
                                : isDark
                                ? cs.outline.withValues(alpha: 0.5)
                                : cs.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          e.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onClear,
              child: Text(
                'Clear filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List shimmer — loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ListShimmer extends StatefulWidget {
  const _ListShimmer();

  @override
  State<_ListShimmer> createState() => _ListShimmerState();
}

class _ListShimmerState extends State<_ListShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainer;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 52,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Rounded rect logo placeholder.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
                        end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
                        colors: [baseColor, highlightColor, baseColor],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBar(140, 12, baseColor, highlightColor),
                        const SizedBox(height: 6),
                        _shimmerBar(90, 10, baseColor, highlightColor),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerBar(
    double width,
    double height,
    Color baseColor,
    Color highlightColor,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
          end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// School logo widget — loads from FileCache, falls back to placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolLogo extends StatelessWidget {
  const _SchoolLogo({required this.schoolId, required this.cs});

  final String schoolId;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.logoPath(schoolId)),
      builder: (context, snapshot) {
        final file = snapshot.data;

        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: isDark
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: file != null
              ? Image.file(file, fit: BoxFit.cover)
              : Icon(
                  Icons.school_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(
                    alpha: isDark ? 0.55 : 0.4,
                  ),
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relative date helper
// ─────────────────────────────────────────────────────────────────────────────

String _formatRelativeDate(int? epochMs) {
  if (epochMs == null) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays < 1) return 'Today';
  if (diff.inDays == 1) return '1d ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
