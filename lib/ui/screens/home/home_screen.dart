import 'package:flutter/material.dart';

import '../../../client.dart';
import '../../../database/tables/enums.dart';
import '../../../models/membership.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edu_sheet.dart';
import '../../widgets/sync_indicator.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/user_avatar.dart';
import '../account/account_screen.dart';
import '../school_dashboard/school_dashboard_screen.dart';
import '../system/system_dashboard_screen.dart';

/// Home screen — the user's school membership picker.
///
/// WhatsApp/YouTube-inspired: warm sentence-case copy, borderless cards with
/// subtle surface tint, circular avatars, comfortable 12px radius, soft
/// loading placeholders. Warm slate surfaces in dark mode.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Account menu
  // ─────────────────────────────────────────────────────────────────────────

  void _openAccountMenu() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const AccountScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Entry picker bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _onCardTap(SchoolMembership membership) {
    if (membership.hasSingleEntry) {
      _navigateToSchool(membership, membership.entries.first);
      return;
    }

    _showEntryPicker(membership);
  }

  void _showEntryPicker(SchoolMembership membership) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    showEduSheet(
      context: context,
      title: membership.school.name,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Choose your role at this school',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              ...membership.entries.map((entry) {
                final roleColor = _roleColor(entry.role);
                IconData icon = Icons.help_outline;
                String title = '';
                String? subtitle;
                Widget? leadingWidget;

                switch (entry) {
                  case OwnerEntry():
                    icon = Icons.shield_outlined;
                    title = 'Owner';
                  case TeacherEntry(:final subjectCount):
                    icon = Icons.school_outlined;
                    title = 'Teacher';
                    subtitle =
                        '$subjectCount subject${subjectCount == 1 ? '' : 's'} this term';
                  case StaffEntry():
                    icon = Icons.badge_outlined;
                    title = 'Staff';
                  case StudentEntry():
                    icon = Icons.person_outline;
                    title = 'Student';
                  case GuardianEntry(:final ward):
                    icon = Icons.family_restroom_outlined;
                    title = 'Guardian';
                    subtitle = ward.name;
                    leadingWidget = StudentAvatar(
                      schoolId: membership.school.id,
                      adm: ward.adm,
                      name: ward.name,
                      radius: 20,
                    );
                }

                return _EntryOptionCard(
                  icon: icon,
                  leadingWidget: leadingWidget,
                  title: title,
                  subtitle: subtitle,
                  roleColor: roleColor,
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToSchool(membership, entry);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _navigateToSchool(SchoolMembership membership, MembershipEntry entry) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SchoolDashboardScreen(membership: membership, initialEntry: entry),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = cache.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > AppTheme.kTabletBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: SlideTransition(
          position: _slideUp,
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top bar ──────────────────────────────────────────────
                _buildTopBar(theme, cs, user.user.id),

                // ── System dashboard card (privileged users only) ────────
                if (user.user.level == UserLevel.system ||
                    user.user.level == UserLevel.super_)
                  _buildSystemCard(cs, user.user.level),

                // ── Section header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 10),
                  child: Text(
                    'MEMBERSHIPS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 1.1,
                      height: 1.0,
                    ),
                  ),
                ),

                // ── Body ────────────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<List<SchoolMembership>>(
                    stream: membershipsDao.watchMemberships(user.user.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState(cs);
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(theme, cs, snapshot.error);
                      }

                      final memberships = snapshot.data ?? [];

                      if (memberships.isEmpty) {
                        return _buildEmptyState(theme, cs);
                      }

                      return _buildMembershipList(
                        theme,
                        cs,
                        memberships,
                        isWide,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top bar — no AppBar, custom layout
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme, ColorScheme cs, String userId) {
    final level = cache.currentUser?.user.level;
    final isPrivileged = level == UserLevel.system || level == UserLevel.super_;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // App name — a whisper, not a shout. Light and architectural.
          Text(
            'eduxal',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
            ),
          ),
          // System badge — only for system / super users.
          if (isPrivileged) ...[
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => const SystemDashboardScreen(),
                      transitionsBuilder: (_, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  );
                },
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    border: Border.all(
                      color: isDark
                          ? cs.outline.withValues(alpha: 0.5)
                          : cs.outlineVariant,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        level == UserLevel.super_ ? 'SUPER' : 'SYSTEM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                          letterSpacing: 1.0,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          // Sync status dot — tiny, unobtrusive.
          const SyncIndicator(),
          const SizedBox(width: 6),
          // Avatar button.
          UserAvatar(userId: userId, radius: 19, onTap: _openAccountMenu),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // System dashboard card — prominent entry point for system / super users
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSystemCard(ColorScheme cs, UserLevel level) {
    final isDark = cs.brightness == Brightness.dark;
    final isSuper = level == UserLevel.super_;
    final accentColor = isSuper
        ? const Color(0xFFAB47BC)
        : AppTheme.brandIndigo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, _, _) => const SystemDashboardScreen(),
                transitionsBuilder: (_, animation, _, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  accentColor.withValues(alpha: isDark ? 0.06 : 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              border: Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.4 : 0.25),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: isDark
                        ? accentColor.withValues(alpha: 0.9)
                        : accentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSuper
                            ? 'Full platform access'
                            : 'Manage schools, users & roles',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: accentColor.withValues(alpha: isDark ? 0.7 : 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading state — delegates to _LoadingShimmer widget with sweep animation
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState(ColorScheme cs) {
    return const _LoadingShimmer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    final level = cache.currentUser?.user.level;
    final isPrivileged = level == UserLevel.system || level == UserLevel.super_;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isPrivileged ? 'No school memberships' : 'No schools yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPrivileged
                  ? 'You can manage all schools from the System Dashboard above.'
                  : 'Schools will appear here once you\'re added by an administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.1,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorState(ThemeData theme, ColorScheme cs, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: cs.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('Something went wrong', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Membership list
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMembershipList(
    ThemeData theme,
    ColorScheme cs,
    List<SchoolMembership> memberships,
    bool isWide,
  ) {
    if (isWide) {
      return _buildGrid(theme, cs, memberships);
    }
    return _buildList(theme, cs, memberships);
  }

  Widget _buildList(
    ThemeData theme,
    ColorScheme cs,
    List<SchoolMembership> memberships,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: memberships.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _MembershipCard(
          membership: memberships[index],
          onTap: () => _onCardTap(memberships[index]),
        );
      },
    );
  }

  Widget _buildGrid(
    ThemeData theme,
    ColorScheme cs,
    List<SchoolMembership> memberships,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 16.0;
          const double maxItemWidth = 400.0;

          int crossAxisCount = (constraints.maxWidth / maxItemWidth).ceil();
          if (crossAxisCount < 1) crossAxisCount = 1;

          // Subtract a tiny amount to prevent floating point inaccuracies
          // from causing the last item in a row to wrap prematurely.
          final double itemWidth =
              ((constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
                  crossAxisCount) -
              0.1;

          return Wrap(
            alignment: WrapAlignment.start,
            spacing: spacing,
            runSpacing: spacing,
            children: memberships.map((membership) {
              return SizedBox(
                width: itemWidth,
                child: _MembershipCard(
                  membership: membership,
                  onTap: () => _onCardTap(membership),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Role colours
  // ─────────────────────────────────────────────────────────────────────────

  static Color _roleColor(MembershipRole role) {
    return switch (role) {
      MembershipRole.owner => AppTheme.brandIndigo,
      MembershipRole.teacher => const Color(
        0xFF42A5F5,
      ), // brighter blue for dark legibility
      MembershipRole.staff => const Color(0xFF78909C), // brighter blue-grey
      MembershipRole.student => AppTheme.brandGreen,
      MembershipRole.guardian => const Color(0xFF26A69A), // brighter teal
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Entry option card
// ═══════════════════════════════════════════════════════════════════════════════

class _EntryOptionCard extends StatefulWidget {
  const _EntryOptionCard({
    required this.icon,
    this.leadingWidget,
    required this.title,
    required this.subtitle,
    required this.roleColor,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final Widget? leadingWidget;
  final String title;
  final String? subtitle;
  final Color roleColor;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_EntryOptionCard> createState() => _EntryOptionCardState();
}

class _EntryOptionCardState extends State<_EntryOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    final base = AppTheme.nestedBg(widget.isDark, widget.cs);
    if (_pressed) {
      return Color.alphaBlend(
        widget.roleColor.withValues(alpha: widget.isDark ? 0.12 : 0.08),
        base,
      );
    }
    if (_hovered) {
      return Color.alphaBlend(
        widget.roleColor.withValues(alpha: widget.isDark ? 0.07 : 0.05),
        base,
      );
    }
    return base;
  }

  Color get _borderColor => _pressed || _hovered
      ? widget.roleColor.withValues(alpha: 0.40)
      : AppTheme.borderColor(widget.isDark, widget.cs);

  double get _accentAlpha => _pressed ? 1.0 : (_hovered ? 0.78 : 0.50);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _pressed = true);
            _ctrl.forward();
          },
          onTapUp: (_) {
            setState(() => _pressed = false);
            _ctrl.reverse();
            widget.onTap();
          },
          onTapCancel: () {
            setState(() => _pressed = false);
            _ctrl.reverse();
          },
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(color: _borderColor),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 3,
                      color: widget.roleColor.withValues(alpha: _accentAlpha),
                    ),
                    const SizedBox(width: 12),
                    // ── Role icon / custom leading widget
                    Align(
                      alignment: Alignment.center,
                      child:
                          widget.leadingWidget ??
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.roleColor.withValues(
                                alpha: widget.isDark ? 0.16 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kCardRadius,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 20,
                              color: widget.roleColor.withValues(alpha: 0.9),
                            ),
                          ),
                    ),
                    const SizedBox(width: 12),
                    // ── Label + subtitle
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: widget.cs.onSurface,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: widget.cs.onSurfaceVariant.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // ── Animated chevron
                    AnimatedSlide(
                      offset: _hovered || _pressed
                          ? const Offset(0.25, 0)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Center(
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: widget.roleColor.withValues(
                              alpha: _pressed || _hovered ? 0.80 : 0.35,
                            ),
                          ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Membership card
// ═══════════════════════════════════════════════════════════════════════════════

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.membership, required this.onTap});

  final SchoolMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: isDark
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── School name + arrow ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      membership.school.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                ],
              ),

              // ── Motto ─────────────────────────────────────────────
              if (membership.school.motto != null) ...[
                const SizedBox(height: 4),
                Text(
                  membership.school.motto!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),

              // ── Role chips ────────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: membership.roles.map((role) {
                  return _RoleChip(role: role);
                }).toList(),
              ),

              // ── Guardian ward info ────────────────────────────────
              for (final entry in membership.entries)
                if (entry case GuardianEntry(:final ward))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Guardian of ${ward.name}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loading shimmer — sweep animation
// ═══════════════════════════════════════════════════════════════════════════════

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
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
    final isDark = cs.brightness == Brightness.dark;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainer;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    border: Border.all(
                      color: isDark
                          ? cs.outline.withValues(alpha: 0.5)
                          : cs.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBar(160, 14, baseColor, highlightColor),
                      const SizedBox(height: 8),
                      _shimmerBar(100, 10, baseColor, highlightColor),
                      const Spacer(),
                      Row(
                        children: [
                          _shimmerBar(52, 22, baseColor, highlightColor),
                          const SizedBox(width: 8),
                          _shimmerBar(60, 22, baseColor, highlightColor),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Role chip
// ═══════════════════════════════════════════════════════════════════════════════

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final MembershipRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final color = _HomeScreenState._roleColor(role);
    final label = role.name[0].toUpperCase() + role.name.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? color.withValues(alpha: 0.95) : color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
