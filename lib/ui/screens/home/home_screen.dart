import 'package:flutter/material.dart';

import '../../../client.dart';
import '../../../database/tables/enums.dart';
import '../../../models/membership.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import '../account/account_screen.dart';
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

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
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
                      color: cs.onSurfaceVariant.withValues(alpha: 0.2),
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
                  color: _roleColor(entry.role).withValues(alpha: 0.1),
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
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSchool(SchoolMembership membership, MembershipEntry entry) {
    // Placeholder — Task Group 3 will implement the real school dashboard.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${membership.school.name} → ${entry.role.name}')),
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
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top bar ──────────────────────────────────────────────
              _buildTopBar(theme, cs, user.user.id),

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

                    return _buildMembershipList(theme, cs, memberships, isWide);
                  },
                ),
              ),
            ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          // App name — soft, rounded, understated.
          Text(
            'eduxal',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.8,
            ),
          ),
          // System badge — only for system / super users.
          // Sits right after the wordmark like a role indicator, not a button.
          if (isPrivileged) ...[
            const SizedBox(width: 8),
            GestureDetector(
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      level == UserLevel.super_ ? 'super' : 'system',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                        letterSpacing: 0.4,
                        height: 1.2,
                      ),
                    ),
                  ],
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
  // Loading state — shimmer-like placeholders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState(ColorScheme cs) {
    final shimmer = cs.surfaceContainerHighest;
    final shimmerLight = cs.surfaceContainer;

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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 160,
                    height: 14,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmerLight,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 22,
                        decoration: BoxDecoration(
                          color: shimmerLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 60,
                        height: 22,
                        decoration: BoxDecoration(
                          color: shimmerLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 32,
                color: AppTheme.brandGreen.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text('No schools yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Your schools will appear here once you\'re added by a school administrator.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
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
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: memberships.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
          ),
          itemCount: memberships.length,
          itemBuilder: (context, index) {
            return _MembershipCard(
              membership: memberships[index],
              onTap: () => _onCardTap(memberships[index]),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Role colours
  // ─────────────────────────────────────────────────────────────────────────

  static Color _roleColor(MembershipRole role) {
    return switch (role) {
      MembershipRole.owner => AppTheme.brandIndigo,
      MembershipRole.teacher => const Color(0xFF1976D2),
      MembershipRole.staff => const Color(0xFF607D8B),
      MembershipRole.student => AppTheme.brandGreen,
      MembershipRole.guardian => const Color(0xFF009688),
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

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── School name + arrow ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      membership.school.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),

              // ── Motto ─────────────────────────────────────────────
              if (membership.school.motto != null) ...[
                const SizedBox(height: 4),
                Text(
                  membership.school.motto!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // ── Role chips ────────────────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 4,
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
// Role chip
// ═══════════════════════════════════════════════════════════════════════════════

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final MembershipRole role;

  @override
  Widget build(BuildContext context) {
    final color = _HomeScreenState._roleColor(role);
    final label = role.name[0].toUpperCase() + role.name.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
