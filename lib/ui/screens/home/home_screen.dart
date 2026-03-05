import 'package:flutter/material.dart';

import '../../../client.dart';
import '../../../database/tables/enums.dart';
import '../../../models/membership.dart';
import '../../theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // School name.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    membership.school.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Choose how to enter this school',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Divider(indent: 20, endIndent: 20),

                // Entry list.
                ...membership.entries.map((entry) {
                  return _buildEntryTile(ctx, theme, cs, membership, entry);
                }),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntryTile(
    BuildContext sheetCtx,
    ThemeData theme,
    ColorScheme cs,
    SchoolMembership membership,
    MembershipEntry entry,
  ) {
    IconData icon;
    String title;
    String? subtitle;
    Widget? leading;

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
        leading = UserAvatar(userId: ward.user ?? '', radius: 18);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      onTap: () {
        Navigator.pop(sheetCtx);
        _navigateToSchool(membership, entry);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            if (leading != null)
              leading
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _roleColor(entry.role).withValues(
                    alpha: cs.brightness == Brightness.dark ? 0.18 : 0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: _roleColor(entry.role)),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
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
          // Avatar button.
          UserAvatar(userId: userId, radius: 19, onTap: _openAccountMenu),
        ],
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
              'No schools yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schools will appear here once you\'re added by an administrator.',
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
