import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide Action;
import '../../../../cache/file_cache.dart';
import '../../../../database/tables/enums.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pressable_row.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RowAction — describes a single action button on a member row
// ─────────────────────────────────────────────────────────────────────────────

class RowAction {
  const RowAction({
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
// UserDataRow — flat data-table row for user-based members
// (Owners, Teachers, Staff, Guardians)
// ─────────────────────────────────────────────────────────────────────────────

class UserDataRow extends StatefulWidget {
  const UserDataRow({
    super.key,
    required this.userId,
    required this.name,
    required this.subtitle,
    this.status,
    this.level,
    this.trailing,
    this.onTap,
    this.actions = const [],
  });

  final String userId;
  final String name;
  final String subtitle;
  final UserStatus? status;
  final UserLevel? level;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<RowAction> actions;

  @override
  State<UserDataRow> createState() => _UserDataRowState();
}

class _UserDataRowState extends State<UserDataRow>
    with TickerProviderStateMixin, PressableRowMixin {
  bool _isHovered = false;

  Color _statusColor() {
    switch (widget.status) {
      case UserStatus.active:
        return AppTheme.statusActive;
      case UserStatus.invited:
        return AppTheme.statusInvited;
      case UserStatus.suspended:
        return AppTheme.statusSuspended;
      case UserStatus.deleted:
        return AppTheme.statusDeleted;
      case null:
        return AppTheme.statusInvited;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final accentColor = _statusColor();

    // ── Background states ──────────────────────────────────────────────
    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);

    // ── Avatar with status ring ────────────────────────────────────────
    Widget avatar = Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: _isHovered ? 0.7 : 0.35),
          width: 1.5,
        ),
      ),
      child: UserAvatar(userId: widget.userId, radius: 15),
    );

    if (widget.status != null && widget.level != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -1,
            right: -1,
            child: StatusIndicator(
              status: widget.status!,
              level: widget.level!,
              backgroundColor: _isHovered ? hoverBg : idleBg,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: buildPressable(
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered
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
                      width: _isHovered ? 4 : 3,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: _isHovered ? 1.0 : 0.7,
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
                            // Avatar
                            avatar,
                            const SizedBox(width: 12),

                            // Name + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (widget.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle,
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

                            // Trailing chip
                            if (widget.trailing != null) ...[
                              const SizedBox(width: 8),
                              widget.trailing!,
                            ],

                            // Actions
                            if (widget.actions.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              isDesktop
                                  ? InlineActions(
                                      actions: widget.actions,
                                      isHovered: _isHovered,
                                    )
                                  : MobileActions(actions: widget.actions),
                            ],

                            const SizedBox(width: 4),

                            // ── Animated chevron ────────────────────
                            if (widget.onTap != null)
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlatRow — flat data-table row for non-user rows (Students)
// ─────────────────────────────────────────────────────────────────────────────

class FlatRow extends StatefulWidget {
  const FlatRow({
    super.key,
    required this.leading,
    required this.name,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.actions = const [],
  });

  final Widget leading;
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<RowAction> actions;

  @override
  State<FlatRow> createState() => _FlatRowState();
}

class _FlatRowState extends State<FlatRow>
    with TickerProviderStateMixin, PressableRowMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    // Accent color — teal for students (distinct from primary indigo)
    final accentColor = isDark
        ? const Color(0xFF4DB6AC) // teal 300
        : const Color(0xFF00897B); // teal 600

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: buildPressable(
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered
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
                    // ── Accent bar ──────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHovered ? 4 : 3,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: _isHovered ? 1.0 : 0.7,
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
                            // Leading (avatar)
                            widget.leading,
                            const SizedBox(width: 12),

                            // Name + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (widget.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle,
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

                            // Trailing chip
                            if (widget.trailing != null) ...[
                              const SizedBox(width: 8),
                              widget.trailing!,
                            ],

                            // Actions
                            if (widget.actions.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              isDesktop
                                  ? InlineActions(
                                      actions: widget.actions,
                                      isHovered: _isHovered,
                                    )
                                  : MobileActions(actions: widget.actions),
                            ],

                            const SizedBox(width: 4),

                            // ── Animated chevron ────────────────────
                            if (widget.onTap != null)
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InlineActions — desktop: icon buttons that fade in on row hover
// ─────────────────────────────────────────────────────────────────────────────

class InlineActions extends StatelessWidget {
  const InlineActions({
    super.key,
    required this.actions,
    required this.isHovered,
  });

  final List<RowAction> actions;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map((a) => InlineActionButton(action: a, isRowHovered: isHovered))
            .toList(),
      ),
    );
  }
}

class InlineActionButton extends StatefulWidget {
  const InlineActionButton({
    super.key,
    required this.action,
    required this.isRowHovered,
  });

  final RowAction action;
  final bool isRowHovered;

  @override
  State<InlineActionButton> createState() => _InlineActionButtonState();
}

class _InlineActionButtonState extends State<InlineActionButton> {
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
// MobileActions — mobile: three-dot → popup menu
// ─────────────────────────────────────────────────────────────────────────────

class MobileActions extends StatelessWidget {
  const MobileActions({super.key, required this.actions});

  final List<RowAction> actions;

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

    // Single action — render it directly as an icon button (no three-dot)
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
// MemberStudentAvatar — student avatar with initials fallback
// ─────────────────────────────────────────────────────────────────────────────

class MemberStudentAvatar extends StatefulWidget {
  const MemberStudentAvatar({
    super.key,
    required this.schoolId,
    required this.adm,
    required this.name,
    required this.status,
  });

  final String schoolId;
  final int adm;
  final String name;
  final StudentStatus status;

  @override
  State<MemberStudentAvatar> createState() => _MemberStudentAvatarState();
}

class _MemberStudentAvatarState extends State<MemberStudentAvatar> {
  late Future<File?> _future;
  late String _path;

  @override
  void initState() {
    super.initState();
    _path = FileCache.studentImagePath(widget.schoolId, widget.adm);
    _future = FileCache.get(_path);
    FileCacheNotifier.of(_path).addListener(_onFileChanged);
  }

  @override
  void didUpdateWidget(MemberStudentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPath = FileCache.studentImagePath(widget.schoolId, widget.adm);
    if (newPath != _path) {
      FileCacheNotifier.of(_path).removeListener(_onFileChanged);
      _path = newPath;
      _future = FileCache.get(_path);
      FileCacheNotifier.of(_path).addListener(_onFileChanged);
    }
  }

  @override
  void dispose() {
    FileCacheNotifier.of(_path).removeListener(_onFileChanged);
    super.dispose();
  }

  void _onFileChanged() {
    setState(() {
      _future = FileCache.get(_path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(widget.name);

    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: 16,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        return CircleAvatar(
          radius: 16,
          backgroundColor: cs.surfaceContainerHighest,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SmallChip — small status / role chip
// ─────────────────────────────────────────────────────────────────────────────

class SmallChip extends StatelessWidget {
  const SmallChip({super.key, required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlatMemberList — search bar + scrollable list with dividers
// ─────────────────────────────────────────────────────────────────────────────

class FlatMemberList extends StatelessWidget {
  const FlatMemberList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.searchController,
    this.searchHint,
    this.onSearchChanged,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search bar — always visible ────────────────────────────────
        if (searchController != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              height: 38,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController!,
                builder: (context, value, _) {
                  return TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: searchHint ?? 'Search…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 6),
                        child: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      suffixIcon: value.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                searchController!.clear();
                                onSearchChanged?.call('');
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 38,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(
                            alpha: isDark ? 0.2 : 0.3,
                          ),
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                        borderSide: BorderSide(
                          color: cs.primary.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      isDense: true,
                    ),
                  );
                },
              ),
            ),
          ),

        // ── List content ───────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 80),
            itemCount: itemCount,
            separatorBuilder: (_, __) => AppTheme.tableRowDivider(isDark, cs),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyTab — empty state placeholder
// ─────────────────────────────────────────────────────────────────────────────

class EmptyTab extends StatelessWidget {
  const EmptyTab({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
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
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LoadingIndicator — centered spinner
// ─────────────────────────────────────────────────────────────────────────────

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DetailRow — label + value row for detail views
// ─────────────────────────────────────────────────────────────────────────────

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.cs,
  });

  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
