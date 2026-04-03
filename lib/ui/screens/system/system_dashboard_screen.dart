import 'package:flutter/material.dart' hide Action;

import '../../../client.dart';
import '../../../database/tables/enums.dart';
import '../../../database/tables/curriculum_subjects.dart';
import '../../../models/permissions.dart';
import '../../../models/system_permissions.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edu_sheet.dart';
import '../../widgets/edu_tab_bar.dart';
import '../../widgets/sync_indicator.dart';
import '../../widgets/user_avatar.dart';
import '../account/account_screen.dart';
import '../notifications/notifications_page.dart';
import 'home/system_stats_section.dart';
import 'roles/roles_section.dart';
import 'schools/schools_section.dart';
import 'settings/subjects_section.dart';
import 'notifications/notifications_section.dart';
import 'plans/plans_section.dart';

import 'users/invite_user_sheet.dart';
import 'users/users_section.dart';
import 'schools/create_school_sheet.dart';
import 'roles/create_role_sheet.dart';
import 'members/members_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab index constants — mobile (7 tabs: Home, Users, Members, Schools, Roles, Settings, Notifications)
// ─────────────────────────────────────────────────────────────────────────────

const int _kMobileTabHome = 0;
const int _kMobileTabMembers = 2;
const int _kMobileTabSettings = 5;
const int _kMobileTabNotifications = 6;

// Desktop tab indices (6 tabs: Users, Members, Schools, Roles, Settings, Notifications)
const int _kDesktopTabUsers = 0;
const int _kDesktopTabMembers = 1;
const int _kDesktopTabSchools = 2;
const int _kDesktopTabRoles = 3;

/// The fully-functional system dashboard screen.
///
/// **Mobile** (width < [AppTheme.kMobileBreakpoint]):
/// - Icon-only [EduTabBar] with 7 tabs: Home, Users, Members, Schools, Roles, Settings, Notifications.
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

  /// Tracks the current layout mode. Updated via LayoutBuilder so that
  /// crossing the breakpoint does NOT tear down the widget tree (preserving
  /// any pushed routes like role detail, school detail, etc.).
  bool _isMobile = false;

  /// Scaffold key — used for scaffold access.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Mobile tab controller (6 tabs: Home, Users, Members, Schools, Roles, Settings).
  late final TabController _mobileTabController;

  /// Desktop tab controller (Users=0, Members=1, Schools=2, Roles=3, Settings=4).
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

    // Only super_ users get full access immediately — no DB query needed.
    // System users fall through to role-based permission loading below.
    if (user.user.level == UserLevel.super_) {
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
    showEduSheet(
      context: context,
      builder: (_) => AddMemberSheet(permissions: _permissions),
      maxWidth: 480,
    );
  }

  // ── FAB logic (mobile only) ────────────────────────────────────────────────

  bool get _showFab {
    final tab = _mobileTabController.index;
    // FAB on: Users, Members, Schools, Roles (not Home, Settings, or Notifications).
    if (tab == _kMobileTabHome ||
        tab == _kMobileTabSettings ||
        tab == _kMobileTabNotifications) {
      return false;
    }
    return _permissions.can(Resource.users, Action.create) ||
        _permissions.can(Resource.users, Action.assign) ||
        _permissions.can(Resource.schools, Action.create) ||
        _permissions.can(Resource.roles, Action.create);
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
        showEduSheet(
          context: context,
          builder: (_) => InviteUserSheet(permissions: _permissions),
          maxWidth: 480,
        );
      case _FabAction.addMember:
        _openAddMemberModal();
      case _FabAction.createSchool:
        showEduSheet(
          context: context,
          builder: (_) => CreateSchoolSheet(permissions: _permissions),
          maxWidth: 520,
        );
      case _FabAction.createRole:
        showEduSheet(
          context: context,
          builder: (_) => CreateRoleSheet(permissions: _permissions),
          maxWidth: 480,
        );
      case _FabAction.createPlan:
        openCreatePlan(context, _permissions);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newIsMobile = constraints.maxWidth < AppTheme.kMobileBreakpoint;
        if (newIsMobile != _isMobile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isMobile = newIsMobile);
          });
        }
        return GestureDetector(
          onTap: _collapseFab,
          child: _buildLayout(context, newIsMobile),
        );
      },
    );
  }

  // ── Unified layout — single Scaffold, swappable chrome ─────────────────────

  Widget _buildLayout(BuildContext context, bool isMobile) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surfaceContainerLowest,
      body: isMobile
          ? _buildMobileBody(context, cs)
          : _buildDesktopBody(context, cs),
      floatingActionButton: isMobile && _showFab ? _buildFab(context) : null,
    );
  }

  // ── Mobile layout ──────────────────────────────────────────────────────────

  Widget _buildMobileBody(BuildContext context, ColorScheme cs) {
    return SafeArea(
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
                const SyncIndicator(),
                const SizedBox(width: 6),
                _UserMenuAnchor(cs: cs, openUpward: false),
              ],
            ),
          ),
          // ── Icon-only tab bar ────────────────────────────────────────
          EduTabBar(
            controller: _mobileTabController,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            tabs: const [
              EduTab(icon: Icons.bar_chart_rounded),
              EduTab(icon: Icons.people_outline_rounded),
              EduTab(icon: Icons.shield_outlined),
              EduTab(icon: Icons.school_outlined),
              EduTab(icon: Icons.verified_user_outlined),
              EduTab(icon: Icons.settings_outlined),
              EduTab(icon: Icons.notifications_outlined),
            ],
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
                    _SettingsTabBody(permissions: _permissions),
                    NotificationsSection(accountId: cache.currentUser?.user.id),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Expandable FAB (mobile) ────────────────────────────────────────────────

  Widget _buildFab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tab = _mobileTabController.index;

    final canInvite = _permissions.can(Resource.users, Action.create);
    final canAddMember = _permissions.can(Resource.users, Action.update);
    final canCreateSchool = _permissions.can(Resource.schools, Action.create);
    final canCreateRole = _permissions.can(Resource.roles, Action.create);
    // Members tab (index 2) — only the addMember action is relevant.
    if (tab == _kMobileTabMembers) {
      if (!canAddMember) return const SizedBox.shrink();
      return FloatingActionButton.small(
        heroTag: 'fab_system_members',
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
        heroTag: 'fab_system_single',
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
          heroTag: 'fab_system_main',
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

  Widget _buildDesktopBody(BuildContext context, ColorScheme cs) {
    return SlideTransition(
      position: _slideUp,
      child: FadeTransition(
        opacity: _fadeIn,
        child: _DesktopBody(
          tabController: _desktopTabController,
          permissions: _permissions,
          accountId: cache.currentUser?.user.id,
          onInviteUser: _permissions.can(Resource.users, Action.create)
              ? () => showEduSheet(
                  context: context,
                  builder: (_) => InviteUserSheet(permissions: _permissions),
                  maxWidth: 480,
                )
              : null,
          onAddMember: _permissions.can(Resource.users, Action.update)
              ? _openAddMemberModal
              : null,
          onCreateSchool: _permissions.can(Resource.schools, Action.create)
              ? () => showEduSheet(
                  context: context,
                  builder: (_) => CreateSchoolSheet(permissions: _permissions),
                  maxWidth: 520,
                )
              : null,
          onCreateRole: _permissions.can(Resource.roles, Action.create)
              ? () => showEduSheet(
                  context: context,
                  builder: (_) => CreateRoleSheet(permissions: _permissions),
                  maxWidth: 480,
                )
              : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tab body — inner Plans / Subjects tabs
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTabBody extends StatefulWidget {
  const _SettingsTabBody({required this.permissions});

  final SystemPermissions permissions;

  @override
  State<_SettingsTabBody> createState() => _SettingsTabBodyState();
}

class _SettingsTabBodyState extends State<_SettingsTabBody>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTabController;
  final ValueNotifier<CurriculumType> _curriculum = ValueNotifier(
    CurriculumType.cbc,
  );

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 2, vsync: this);
    _innerTabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_innerTabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _innerTabController.removeListener(_handleTabChange);
    _innerTabController.dispose();
    _curriculum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isPlans = _innerTabController.index == 0;
    final isSubjects = _innerTabController.index == 1;

    final canCreatePlan = widget.permissions.can(Resource.plans, Action.create);
    final canCreateSubject = widget.permissions.can(
      Resource.subjects,
      Action.create,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: EduTabBar(
                  controller: _innerTabController,
                  isScrollable: true,
                  tabs: const [
                    EduTab(label: 'Plans'),
                    EduTab(label: 'Subjects'),
                  ],
                ),
              ),
              if (isSubjects) ...[
                const SizedBox(width: 8),
                _buildCurriculumToggle(cs, isDark),
              ],
              if ((isPlans && canCreatePlan) ||
                  (isSubjects && canCreateSubject)) ...[
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'fab_settings_add',
                  backgroundColor: AppTheme.statusActive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onPressed: () {
                    if (isPlans) {
                      openCreatePlan(context, widget.permissions);
                    } else if (isSubjects) {
                      _showCreateSubject(context);
                    }
                  },
                  tooltip: isPlans ? 'New Plan' : 'New Subject',
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: [
              PlansSection(permissions: widget.permissions),
              SubjectsSection(
                permissions: widget.permissions,
                curriculumNotifier: _curriculum,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurriculumToggle(ColorScheme cs, bool isDark) {
    return ValueListenableBuilder<CurriculumType>(
      valueListenable: _curriculum,
      builder: (context, current, _) {
        return Container(
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E2A3A)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTogglePill('CBC', CurriculumType.cbc, current, cs, isDark),
              _buildTogglePill(
                '8-4-4',
                CurriculumType.eightFourFour,
                current,
                cs,
                isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTogglePill(
    String label,
    CurriculumType type,
    CurriculumType selected,
    ColorScheme cs,
    bool isDark,
  ) {
    final isSelected = type == selected;
    return GestureDetector(
      onTap: () => _curriculum.value = type,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? cs.surface : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showCreateSubject(BuildContext context) {
    showEduSheet(
      context: context,
      title: 'New Subject',
      maxWidth: 420,
      builder: (_) => CreateSubjectSheet(curriculum: _curriculum.value),
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
  });

  final TabController tabController;
  final SystemPermissions permissions;
  final String? accountId;
  final VoidCallback? onInviteUser;
  final VoidCallback? onAddMember;
  final VoidCallback? onCreateSchool;
  final VoidCallback? onCreateRole;

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
              const SyncIndicator(),
              const SizedBox(width: 6),
              _UserMenuAnchor(cs: cs, openUpward: false),
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
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            // Stack lets the pill anchor left and grow rightward while the
            // + button is independently pinned to the far right. The pill's
            // right edge is constrained to never overlap the button (8 gap +
            // 32 button width = 40 px from the right).
            child: SizedBox(
              height: 38,
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
                        child: EduTabBar(
                          controller: tabController,
                          isScrollable: true,
                          padding: EdgeInsets.zero,
                          tabs: const [
                            EduTab(label: 'Users'),
                            EduTab(label: 'Members'),
                            EduTab(label: 'Schools'),
                            EduTab(label: 'Roles'),
                            EduTab(label: 'Settings'),
                            EduTab(label: 'Notifications'),
                          ],
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
                          _kDesktopTabUsers => onInviteUser,
                          _kDesktopTabMembers => onAddMember,
                          _kDesktopTabSchools => onCreateSchool,
                          _kDesktopTabRoles => onCreateRole,
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
              _SettingsTabBody(permissions: permissions),
              NotificationsSection(accountId: accountId),
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

enum _FabAction { inviteUser, addMember, createSchool, createRole, createPlan }

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
    final isDark = cs.brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1A2536) : cs.surface,
      borderRadius: BorderRadius.circular(10),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () => onTap(action),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: isDark
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 8),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User menu — anchor, overlay, card
// ─────────────────────────────────────────────────────────────────────────────

enum _UserMenuAction { account, notifications, logout }

class _UserMenuAnchor extends StatefulWidget {
  const _UserMenuAnchor({required this.cs, this.openUpward = true});
  final ColorScheme cs;

  /// When true the card opens above-right of the avatar (sidebar footer).
  /// When false the card opens below-left of the avatar (mobile top bar).
  final bool openUpward;

  @override
  State<_UserMenuAnchor> createState() => _UserMenuAnchorState();
}

class _UserMenuAnchorState extends State<_UserMenuAnchor> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => _UserMenuOverlay(
        link: _link,
        openUpward: widget.openUpward,
        onDismiss: _close,
        onAction: _handleAction,
      ),
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _handleAction(_UserMenuAction action) {
    _close();
    if (!mounted) return;
    switch (action) {
      case _UserMenuAction.account:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
      case _UserMenuAction.notifications:
        final accountId = cache.currentUser?.user.id;
        if (accountId != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NotificationsPage(accountId: accountId),
            ),
          );
        }
      case _UserMenuAction.logout:
        client.logOut();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: cache.currentUser?.user.name ?? '',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: StreamBuilder<int>(
            stream: logsDao.watchFailedLogCount(
              cache.currentUser?.user.id ?? '',
            ),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    userId: cache.currentUser?.user.id ?? '',
                    radius: 15,
                  ),
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: cs.error,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: cs.onError,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The overlay itself — barrier + positioned card
// ─────────────────────────────────────────────────────────────────────────────

class _UserMenuOverlay extends StatefulWidget {
  const _UserMenuOverlay({
    required this.link,
    required this.openUpward,
    required this.onDismiss,
    required this.onAction,
  });

  final LayerLink link;
  final bool openUpward;
  final VoidCallback onDismiss;
  final ValueChanged<_UserMenuAction> onAction;

  @override
  State<_UserMenuOverlay> createState() => _UserMenuOverlayState();
}

class _UserMenuOverlayState extends State<_UserMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    final dy = widget.openUpward ? 0.08 : -0.08;
    _slide = Tween<Offset>(
      begin: Offset(0, dy),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  void _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = widget.openUpward
        ? const Offset(-200, -10) // above-right
        : const Offset(-200, 40); // below-left

    return Stack(
      children: [
        // Full-screen dismiss barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismiss,
          ),
        ),
        // Positioned card.
        CompositedTransformFollower(
          link: widget.link,
          offset: offset,
          showWhenUnlinked: false,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: _UserMenuCard(
                onAction: (a) {
                  _dismiss();
                  widget.onAction(a);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The menu card — full custom layout with header tint, filled rows, dividers
// ─────────────────────────────────────────────────────────────────────────────

class _UserMenuCard extends StatelessWidget {
  const _UserMenuCard({required this.onAction});
  final ValueChanged<_UserMenuAction> onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final user = cache.currentUser?.user;

    // Palette — deliberately richer than the app surface to feel elevated.
    final cardBg = isDark ? const Color(0xFF18222E) : const Color(0xFFFFFFFF);
    final headerBg = isDark ? const Color(0xFF0F1822) : const Color(0xFFF4F6F8);
    final borderColor = isDark
        ? const Color(0xFF2A3848)
        : const Color(0xFFE2E6EA);
    final divColor = isDark ? const Color(0xFF243040) : const Color(0xFFEAECEF);
    final itemHover = isDark
        ? const Color(0xFF1E2C3C)
        : const Color(0xFFF0F2F5);
    final labelColor = isDark
        ? const Color(0xFFDDE4ED)
        : const Color(0xFF17191C);
    final subColor = isDark ? const Color(0xFF6A7E94) : const Color(0xFF8A929C);
    final iconColor = isDark
        ? const Color(0xFF7A94AB)
        : const Color(0xFF6B7280);
    const logoutRed = Color(0xFFD94F4F);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
              blurRadius: isDark ? 24 : 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header — tinted, no hover ────────────────────────────
              Container(
                color: headerBg,
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Row(
                  children: [
                    UserAvatar(userId: user?.id ?? '', radius: 19),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '\u2014',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.phone ?? '\u2014',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: subColor,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ───────────────────────────────────────────────
              Container(height: 1, color: divColor),

              // ── Action items ──────────────────────────────────────────
              _SysMenuItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Account',
                iconColor: iconColor,
                labelColor: labelColor,
                hoverColor: itemHover,
                onTap: () => onAction(_UserMenuAction.account),
              ),
              _SysMenuItem(
                icon: Icons.notifications_none_outlined,
                label: 'Notifications',
                iconColor: iconColor,
                labelColor: labelColor,
                hoverColor: itemHover,
                onTap: () => onAction(_UserMenuAction.notifications),
              ),

              // ── Divider ───────────────────────────────────────────────
              Container(height: 1, color: divColor),

              // ── Log out ───────────────────────────────────────────────
              _SysMenuItem(
                icon: Icons.logout_outlined,
                label: 'Log out',
                iconColor: logoutRed,
                labelColor: logoutRed,
                hoverColor: logoutRed.withValues(alpha: 0.07),
                onTap: () => onAction(_UserMenuAction.logout),
                bottomPad: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Single menu row with ink hover feedback.
class _SysMenuItem extends StatelessWidget {
  const _SysMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    required this.hoverColor,
    required this.onTap,
    this.bottomPad = false,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final Color hoverColor;
  final VoidCallback onTap;
  final bool bottomPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 2, 6, bottomPad ? 4 : 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return hoverColor;
            }
            return Colors.transparent;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: labelColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
