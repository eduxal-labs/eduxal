import 'package:flutter/material.dart';

import '../../../client.dart';
import '../../../database/tables/enums.dart';
import '../../../models/system_permissions.dart';
import '../../theme/app_theme.dart';
import 'notifications/notifications_section.dart';
import 'home/system_stats_section.dart';
import 'roles/roles_section.dart';
import 'schools/schools_section.dart';
import 'plans/plans_section.dart';

import 'users/invite_user_sheet.dart';
import 'users/users_section.dart';
import 'schools/create_school_sheet.dart';
import 'roles/create_role_sheet.dart';
import 'members/members_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab index constants
// ─────────────────────────────────────────────────────────────────────────────

const int _kTabHome = 0;
const int _kTabMembers = 2;
const int _kTabNotifications = 5;
const int _kTabPlans = 6;

/// The fully-functional system dashboard screen.
///
/// **Mobile** (width < [AppTheme.kMobileBreakpoint]):
/// - Icon-only [TabBar] with 7 tabs: Home, Users, Members, Schools, Roles,
///   Notifications, Plans.
/// - Inline back-button row above the tab bar.
/// - Expandable FAB (create actions) on tabs that support creation.
///
/// **Desktop** (width >= [AppTheme.kMobileBreakpoint]):
/// - Single [Column]: stats section at top, sticky tab bar, data
///   sections below.
/// - App bar: same title. No FAB.
///
/// [SystemPermissions] are loaded once on first build from the active user's
/// system-scoped roles and passed down to all child sections.
class SystemDashboardScreen extends StatefulWidget {
  const SystemDashboardScreen({super.key});

  @override
  State<SystemDashboardScreen> createState() => _SystemDashboardScreenState();
}

class _SystemDashboardScreenState extends State<SystemDashboardScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  /// Permissions loaded once when the screen mounts.
  SystemPermissions _permissions = SystemPermissions.none();

  /// FAB expanded state (mobile only).
  bool _fabExpanded = false;

  /// Scaffold key — used for scaffold access.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Mobile tab controller (7 tabs).
  late final TabController _mobileTabController;

  /// Desktop tab controller (Users=0, Members=1, Schools=2, Roles=3).
  late final TabController _desktopTabController;

  /// Entrance animation.
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 7, vsync: this);
    _mobileTabController.addListener(_onMobileTabChanged);
    _desktopTabController = TabController(length: 6, vsync: this);

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

    _loadPermissions();
  }

  @override
  void dispose() {
    _mobileTabController.removeListener(_onMobileTabChanged);
    _mobileTabController.dispose();
    _entranceController.dispose();
    _desktopTabController.dispose();
    super.dispose();
  }

  void _onMobileTabChanged() {
    if (_mobileTabController.indexIsChanging) return;
    _collapseFab();
    // Trigger rebuild so FAB visibility updates.
    setState(() {});
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<void> _loadPermissions() async {
    final user = cache.currentUser;
    if (user == null) return;

    // super_ and system users get full access immediately — no DB query needed.
    if (user.user.level == UserLevel.super_ ||
        user.user.level == UserLevel.system) {
      setState(() {
        _permissions = SystemPermissions.superUser();
      });
      return;
    }

    // Normal users: load their system-scoped roles.
    final rolePerms = await usersDao.getSystemPermissions(user.user.id);
    if (!mounted) return;
    setState(() {
      _permissions = SystemPermissions.forUser(user.user.level, rolePerms);
    });
  }

  // ── Add Member modal ──────────────────────────────────────────────────────

  void _openAddMemberModal() {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 480,
            child: AddMemberSheet(permissions: _permissions),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddMemberSheet(permissions: _permissions),
      );
    }
  }

  // ── FAB logic (mobile only) ────────────────────────────────────────────────

  bool get _showFab {
    final tab = _mobileTabController.index;
    // FAB on: Users, Members, Schools, Roles, Plans.
    if (tab == _kTabHome || tab == _kTabNotifications) {
      return false;
    }
    return _permissions.can('users.create') ||
        _permissions.can('users.update') ||
        _permissions.can('schools.create') ||
        _permissions.can('roles.create') ||
        _permissions.can('plans.create');
  }

  void _toggleFab() => setState(() => _fabExpanded = !_fabExpanded);

  void _collapseFab() {
    if (_fabExpanded) setState(() => _fabExpanded = false);
  }

  void _onFabAction(_FabAction action) {
    _collapseFab();
    final user = cache.currentUser;
    if (user == null) return;
    switch (action) {
      case _FabAction.inviteUser:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => InviteUserSheet(permissions: _permissions),
        );
      case _FabAction.addMember:
        _openAddMemberModal();
      case _FabAction.createSchool:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => CreateSchoolSheet(permissions: _permissions),
        );
      case _FabAction.createRole:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => CreateRoleSheet(permissions: _permissions),
        );
      // createPlan FAB action deferred until Task 11 extracts CreatePlanSheet.
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppTheme.kMobileBreakpoint;

    return GestureDetector(
      onTap: _collapseFab,
      child: isMobile ? _buildMobile(context) : _buildDesktop(context),
    );
  }

  // ── Mobile layout ──────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Column(
          children: [
            // ── Inline back-button row (stable, not animated) ────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 24,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'System',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // ── Icon-only tab bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 36,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.7 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: isDark
                      ? Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: TabBar(
                  controller: _mobileTabController,
                  isScrollable: false,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: isDark
                        ? Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                            width: 1,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.12 : 0.04,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: cs.onSurface,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  labelPadding: EdgeInsets.zero,
                  tabs: const [
                    Tab(icon: Icon(Icons.bar_chart_rounded, size: 18)),
                    Tab(icon: Icon(Icons.people_outline_rounded, size: 18)),
                    Tab(icon: Icon(Icons.shield_outlined, size: 18)),
                    Tab(icon: Icon(Icons.school_outlined, size: 18)),
                    Tab(icon: Icon(Icons.verified_user_outlined, size: 18)),
                    Tab(icon: Icon(Icons.notifications_none_rounded, size: 18)),
                    Tab(icon: Icon(Icons.credit_card_outlined, size: 18)),
                  ],
                ),
              ),
            ),
            // ── Animated tab content ─────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideUp,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: TabBarView(
                    controller: _mobileTabController,
                    children: [
                      SystemStatsSection(permissions: _permissions),
                      UsersSection(permissions: _permissions),
                      MembersSection(permissions: _permissions),
                      SchoolsSection(permissions: _permissions),
                      RolesSection(permissions: _permissions),
                      NotificationsSection(
                        accountId: cache.currentUser?.user.id,
                      ),
                      PlansSection(permissions: _permissions),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFab ? _buildFab(context) : null,
    );
  }

  // ── Expandable FAB (mobile) ────────────────────────────────────────────────

  Widget _buildFab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tab = _mobileTabController.index;

    final canInvite = _permissions.can('users.create');
    final canAddMember = _permissions.can('users.update');
    final canCreateSchool = _permissions.can('schools.create');
    final canCreateRole = _permissions.can('roles.create');
    final canCreatePlan = _permissions.can('plans.create');

    // Plans tab (index 6) — only the createPlan action is relevant.
    if (tab == _kTabPlans) {
      if (!canCreatePlan) return const SizedBox.shrink();
      return FloatingActionButton.small(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => openCreatePlan(context, _permissions),
        child: const Icon(Icons.add_rounded, size: 20),
      );
    }

    // Members tab (index 2) — only the addMember action is relevant.
    if (tab == _kTabMembers) {
      if (!canAddMember) return const SizedBox.shrink();
      return FloatingActionButton.small(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _onFabAction(_FabAction.addMember),
        child: const Icon(Icons.add_rounded, size: 20),
      );
    }

    final actions = [
      if (canInvite)
        _FabSubButton(
          icon: Icons.person_add_outlined,
          label: 'Invite user',
          action: _FabAction.inviteUser,
          onTap: _onFabAction,
          cs: cs,
        ),
      if (canCreateSchool)
        _FabSubButton(
          icon: Icons.add_business_outlined,
          label: 'Create school',
          action: _FabAction.createSchool,
          onTap: _onFabAction,
          cs: cs,
        ),
      if (canCreateRole)
        _FabSubButton(
          icon: Icons.add_moderator_outlined,
          label: 'Create role',
          action: _FabAction.createRole,
          onTap: _onFabAction,
          cs: cs,
        ),
    ];

    // If only one permission is held, FAB taps directly (no expand).
    if (actions.length == 1) {
      return FloatingActionButton.small(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _onFabAction(
          canInvite
              ? _FabAction.inviteUser
              : canCreateSchool
              ? _FabAction.createSchool
              : _FabAction.createRole,
        ),
        child: const Icon(Icons.add_rounded, size: 20),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Sub-FABs — staggered, only visible when expanded.
        ...actions.asMap().entries.map((entry) {
          return AnimatedSlide(
            offset: _fabExpanded ? Offset.zero : const Offset(0, 0.3),
            duration: Duration(milliseconds: (180 + entry.key * 40)),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _fabExpanded ? 1.0 : 0.0,
              duration: Duration(milliseconds: (160 + entry.key * 40)),
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: entry.value,
              ),
            ),
          );
        }),
        // Main FAB — icon rotates 45° when expanded.
        FloatingActionButton.small(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: _toggleFab,
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0.0, // 45°
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: const Icon(Icons.add_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  // ── Desktop layout ─────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: _DesktopBody(
            tabController: _desktopTabController,
            permissions: _permissions,
            accountId: cache.currentUser?.user.id,
            onInviteUser: _permissions.can('users.create')
                ? () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: SizedBox(
                        width: 480,
                        child: InviteUserSheet(permissions: _permissions),
                      ),
                    ),
                  )
                : null,
            onAddMember: _permissions.can('users.update')
                ? _openAddMemberModal
                : null,
            onCreateSchool: _permissions.can('schools.create')
                ? () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: SizedBox(
                        width: 520,
                        child: CreateSchoolSheet(permissions: _permissions),
                      ),
                    ),
                  )
                : null,
            onCreateRole: _permissions.can('roles.create')
                ? () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: SizedBox(
                        width: 480,
                        child: CreateRoleSheet(permissions: _permissions),
                      ),
                    ),
                  )
                : null,
            onCreatePlan: _permissions.can('plans.create')
                ? () => openCreatePlan(context, _permissions)
                : null,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop body — fixed stats panel + sticky tab bar + scrollable tab content
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({
    required this.tabController,
    required this.permissions,
    this.accountId,
    this.onInviteUser,
    this.onAddMember,
    this.onCreateSchool,
    this.onCreateRole,
    this.onCreatePlan,
  });

  final TabController tabController;
  final SystemPermissions permissions;
  final String? accountId;
  final VoidCallback? onInviteUser;
  final VoidCallback? onAddMember;
  final VoidCallback? onCreateSchool;
  final VoidCallback? onCreateRole;
  final VoidCallback? onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Fixed two-panel layout (D5): stats panel is non-scrollable at ~37%
    // height, tab bar is pinned, and only each tab body scrolls.
    return Column(
      children: [
        // ── Inline back-button row ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'System',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        // ── Top panel: stats section (expandable — no fixed height cap) ──
        SystemStatsSection(permissions: permissions),
        // ── Pinned tab bar ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            // Stack lets the pill anchor left and grow rightward while the
            // + button is independently pinned to the far right. The pill's
            // right edge is constrained to never overlap the button (8 gap +
            // 32 button width = 40 px from the right).
            child: SizedBox(
              height: 36,
              child: Stack(
                children: [
                  // ── Pill: anchored left, shrinks to content, max right = 40px from edge ──
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: 40,
                    child: UnconstrainedBox(
                      alignment: Alignment.centerLeft,
                      constrainedAxis: Axis.vertical,
                      clipBehavior: Clip.hardEdge,
                      child: ConstrainedBox(
                        // Never wider than the available space (Stack width − 40).
                        constraints: const BoxConstraints(
                          maxWidth: double.infinity,
                        ),
                        child: AnimatedBuilder(
                          animation: tabController,
                          builder: (context, _) {
                            // Measure natural tab widths to know when to stop shrinking.
                            return LayoutBuilder(
                              builder: (context, bc) {
                                return Container(
                                  height: 36,
                                  constraints: BoxConstraints(
                                    maxWidth: bc.maxWidth,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withValues(
                                          alpha:
                                              cs.brightness == Brightness.dark
                                              ? 0.7
                                              : 0.5,
                                        ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: cs.brightness == Brightness.dark
                                        ? Border.all(
                                            color: cs.outlineVariant.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: TabBar(
                                    controller: tabController,
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.start,
                                    splashBorderRadius: BorderRadius.circular(
                                      6,
                                    ),
                                    dividerColor: Colors.transparent,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    indicator: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: cs.brightness == Brightness.dark
                                          ? Border.all(
                                              color: cs.outlineVariant
                                                  .withValues(alpha: 0.4),
                                              width: 1,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha:
                                                cs.brightness == Brightness.dark
                                                ? 0.12
                                                : 0.04,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    labelColor: cs.onSurface,
                                    unselectedLabelColor: cs.onSurfaceVariant,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    labelStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                    unselectedLabelStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.2,
                                    ),
                                    tabs: const [
                                      Tab(text: 'Users'),
                                      Tab(text: 'Members'),
                                      Tab(text: 'Schools'),
                                      Tab(text: 'Roles'),
                                      Tab(text: 'Notifications'),
                                      Tab(text: 'Plans'),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // ── + button: pinned to the far right ──
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: tabController,
                      builder: (context, _) {
                        final index = tabController.index;
                        final VoidCallback? action = switch (index) {
                          0 => onInviteUser,
                          1 => onAddMember,
                          2 => onCreateSchool,
                          3 => onCreateRole,
                          5 => onCreatePlan,
                          _ => null,
                        };

                        if (action == null) return const SizedBox(width: 32);

                        return Material(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: action,
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.add_rounded,
                                color: cs.onPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Bottom panel: independently scrollable tab content ──────────
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              UsersSection(permissions: permissions),
              MembersSection(permissions: permissions),
              SchoolsSection(permissions: permissions),
              RolesSection(permissions: permissions),
              NotificationsSection(accountId: accountId),
              PlansSection(permissions: permissions),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB sub-button
// ─────────────────────────────────────────────────────────────────────────────

enum _FabAction { inviteUser, addMember, createSchool, createRole }

class _FabSubButton extends StatelessWidget {
  const _FabSubButton({
    required this.icon,
    required this.label,
    required this.action,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final _FabAction action;
  final void Function(_FabAction) onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label chip to the left of the mini-FAB.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: cs.brightness == Brightness.dark
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mini FAB.
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () => onTap(action),
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}
