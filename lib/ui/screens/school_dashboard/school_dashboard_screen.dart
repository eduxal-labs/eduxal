import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../client.dart';
import '../../../database/database.dart';
import '../../../database/daos/school_scopes_dao.dart';
import '../../../database/daos/terms_dao.dart';
import '../../../models/active_term_context.dart';
import '../../../models/membership.dart';
import '../../../models/permissions.dart';
import '../../../models/school_context.dart';
import '../../../models/school_permissions.dart';
import '../../theme/app_theme.dart';
import '../../widgets/active_term_provider.dart';

import '../../widgets/edu_sheet.dart';
import '../../widgets/no_terms_blank_state.dart';
import '../../widgets/term_selector_chip.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/user_avatar.dart';
import '../account/account_screen.dart';
import '../notifications/notifications_page.dart';
import 'academics/academics_screen.dart';
import 'exams/exams_grades_screen.dart';
import 'members/members_page.dart';
import '../../widgets/sync_indicator.dart';
import 'announcements/announcements_screen.dart';
import 'finance/finance_screen.dart';
import 'roles/school_roles_screen.dart';
import 'settings/school_settings_screen.dart';

import 'overview/overview_screen.dart';
import 'progress/progress_screen.dart';
import 'timetable/timetable_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Three layout tiers
//   < kMobileBreakpoint   (< 600)   → pill tabs, icon-only
//   600 – kDesktopBreakpoint (1200) → icon rail sidebar (64 px, no labels)
//   > kDesktopBreakpoint  (> 1200)  → full labelled sidebar (232 px)
// ─────────────────────────────────────────────────────────────────────────────

/// Layout mode — drives which navigation chrome is shown around the
/// persistent content area. Switching modes does NOT tear down the content
/// widget tree, so any pushed routes (exam detail, paper detail, etc.)
/// survive a window resize across breakpoints.
enum _LayoutMode { full, rail, mobile }

// ─────────────────────────────────────────────────────────────────────────────
// Nav item descriptor
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard navigation — allows child widgets (e.g. overview cards) to
// programmatically switch the active tab by label name.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardNavigation extends InheritedWidget {
  const DashboardNavigation({
    super.key,
    required this.navigateToTab,
    required super.child,
  });

  /// Switches the dashboard to the tab matching [label].
  final void Function(String label) navigateToTab;

  /// Look up the nearest [DashboardNavigation], or `null` if none exists.
  static DashboardNavigation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DashboardNavigation>();
  }

  /// Convenience — navigate to [label] if a [DashboardNavigation] is in scope.
  static void goToTab(BuildContext context, String label) {
    maybeOf(context)?.navigateToTab(label);
  }

  @override
  bool updateShouldNotify(DashboardNavigation oldWidget) =>
      navigateToTab != oldWidget.navigateToTab;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry-point widget
// ─────────────────────────────────────────────────────────────────────────────

class SchoolDashboardScreen extends StatefulWidget {
  const SchoolDashboardScreen({
    super.key,
    required this.membership,
    required this.initialEntry,
  });

  final SchoolMembership membership;
  final MembershipEntry initialEntry;

  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen>
    with WidgetsBindingObserver {
  SchoolContext? _schoolContext;
  ActiveTermContext? _activeTermContext;
  bool _isLoading = true;

  // Subscription that keeps _activeTermContext in sync with the Drift stream.
  StreamSubscription<List<Term>>? _termsSub;

  // Subscription that keeps permissions reactive — re-computes when
  // scopes or roles change via sync deltas.
  StreamSubscription<SchoolPermissions>? _permissionsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final user = cache.currentUser?.user;
    if (user == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final schoolId = widget.membership.school.id;

    // ── 1. Load permissions via DAO ──────────────────────────────────────────
    final scopesDao = SchoolScopesDao(db);
    final permissions = await scopesDao.getAggregatedPermissions(
      schoolId,
      user.id,
      user.level,
    );
    debugPrint(
      '[SchoolDashboard] Aggregated permissions: ${permissions.permissions}',
    );

    // ── 2. Load terms for the initial ActiveTermContext ──────────────────────
    final termsDao = TermsDao(db);
    final initialTerms = await termsDao.getTerms(schoolId);
    final initialTerm =
        await termsDao.getActiveTerm(schoolId) ??
        await termsDao.getMostRecentTerm(schoolId);

    if (!mounted) return;

    // ── 3. Build session objects ─────────────────────────────────────────────
    final schoolContext = SchoolContext(
      membership: widget.membership,
      permissions: permissions,
      initialEntry: widget.initialEntry,
    );

    final activeTermContext = ActiveTermContext(
      schoolId: schoolId,
      allTerms: initialTerms,
      initialTerm: initialTerm,
    );

    // ── 4. Subscribe to reactive streams ─────────────────────────────────────
    // Keep ActiveTermContext up-to-date as terms are created/updated/deleted.
    _termsSub = termsDao.watchTerms(schoolId).listen((newTerms) {
      if (mounted) _activeTermContext?.updateTerms(newTerms);
    });

    // Keep permissions up-to-date when scopes/roles change via sync deltas.
    _permissionsSub = scopesDao
        .watchAggregatedPermissions(schoolId, user.id, user.level)
        .listen((newPermissions) {
          if (!mounted || _schoolContext == null) return;
          if (_schoolContext!.permissions == newPermissions) return;

          debugPrint(
            '[SchoolDashboard] Permissions changed via watch stream — '
            'rebuilding SchoolContext',
          );

          final oldEntry = _schoolContext!.currentEntry.value;
          _schoolContext!.dispose();

          setState(() {
            _schoolContext = SchoolContext(
              membership: widget.membership,
              permissions: newPermissions,
              initialEntry: oldEntry,
            );
          });
        });

    setState(() {
      _schoolContext = schoolContext;
      _activeTermContext = activeTermContext;
      _isLoading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadPermissions();
    }
  }

  /// Re-fetches permissions from the DB on app foreground resume as a
  /// fallback in case the watch stream missed an update.
  Future<void> _reloadPermissions() async {
    if (_schoolContext == null) return;
    final user = cache.currentUser?.user;
    if (user == null) return;

    final schoolId = widget.membership.school.id;
    final scopesDao = SchoolScopesDao(db);
    final newPermissions = await scopesDao.getAggregatedPermissions(
      schoolId,
      user.id,
      user.level,
    );

    if (!mounted || _schoolContext == null) return;
    if (_schoolContext!.permissions == newPermissions) return;

    debugPrint(
      '[SchoolDashboard] Permissions changed on resume — '
      'rebuilding SchoolContext',
    );

    final oldEntry = _schoolContext!.currentEntry.value;
    _schoolContext!.dispose();

    setState(() {
      _schoolContext = SchoolContext(
        membership: widget.membership,
        permissions: newPermissions,
        initialEntry: oldEntry,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionsSub?.cancel();
    _termsSub?.cancel();
    _activeTermContext?.dispose();
    _schoolContext?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _schoolContext == null || _activeTermContext == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        body: const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      );
    }
    return ActiveTermProvider(
      termContext: _activeTermContext!,
      child: _DashboardShell(
        schoolContext: _schoolContext!,
        activeTermContext: _activeTermContext!,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard shell — owns the TabController and selected-index state
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardShell extends StatefulWidget {
  const _DashboardShell({
    required this.schoolContext,
    required this.activeTermContext,
  });
  final SchoolContext schoolContext;
  final ActiveTermContext activeTermContext;

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<_NavItem> _currentItems = [];
  int _selectedIndex = 0;
  late MembershipRole _currentRole;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentRole = widget.schoolContext.currentEntry.value.role;
    _currentItems = _itemsForRole(
      _currentRole,
      widget.schoolContext.permissions,
    );
    _tabController = TabController(length: _currentItems.length, vsync: this)
      ..addListener(_onTabChanged);
    widget.schoolContext.currentEntry.addListener(_onEntryChanged);
  }

  @override
  void dispose() {
    widget.schoolContext.currentEntry.removeListener(_onEntryChanged);
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolContext != widget.schoolContext) {
      // SchoolContext was replaced (e.g. permissions changed via watch stream
      // or app foreground resume) — re-wire the currentEntry listener and
      // recompute nav items with the new permissions.
      oldWidget.schoolContext.currentEntry.removeListener(_onEntryChanged);
      widget.schoolContext.currentEntry.addListener(_onEntryChanged);

      final newRole = widget.schoolContext.currentEntry.value.role;
      final newItems = _itemsForRole(newRole, widget.schoolContext.permissions);
      final newIndex = _selectedIndex.clamp(0, newItems.length - 1);

      _tabController
        ..removeListener(_onTabChanged)
        ..dispose();
      _tabController = TabController(
        length: newItems.length,
        initialIndex: newIndex,
        vsync: this,
      )..addListener(_onTabChanged);

      setState(() {
        _currentRole = newRole;
        _currentItems = newItems;
        _selectedIndex = newIndex;
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_selectedIndex != _tabController.index) {
      setState(() => _selectedIndex = _tabController.index);
    }
  }

  void _onEntryChanged() {
    final newRole = widget.schoolContext.currentEntry.value.role;
    final newItems = _itemsForRole(newRole, widget.schoolContext.permissions);

    // Preserve tab index when switching entries within the same role
    // (e.g. guardian Ward A → Ward B). Only reset to 0 on role change.
    final int newIndex;
    if (newRole == _currentRole) {
      newIndex = _selectedIndex.clamp(0, newItems.length - 1);
    } else {
      newIndex = 0;
    }

    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _tabController = TabController(
      length: newItems.length,
      initialIndex: newIndex,
      vsync: this,
    )..addListener(_onTabChanged);
    setState(() {
      _currentRole = newRole;
      _currentItems = newItems;
      _selectedIndex = newIndex;
    });
  }

  void _selectIndex(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _tabController.animateTo(index);
  }

  /// Navigate to the tab whose [_NavItem.label] matches [label].
  /// Used by child widgets (e.g. overview "View All" links) via
  /// [DashboardNavigation.goToTab].
  void _navigateToTab(String label) {
    final index = _currentItems.indexWhere((item) => item.label == label);
    if (index != -1) _selectIndex(index);
  }

  // ── nav items per role ─────────────────────────────────────────────────────

  List<_NavItem> _itemsForRole(MembershipRole role, SchoolPermissions perms) {
    return switch (role) {
      MembershipRole.owner => const [
        _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
        _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
        _NavItem(label: 'Exams', icon: Icons.assignment_outlined),
        _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
        _NavItem(label: 'Finance', icon: Icons.account_balance_outlined),
        _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
        _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
        _NavItem(label: 'Roles', icon: Icons.admin_panel_settings_outlined),
        _NavItem(label: 'Settings', icon: Icons.settings_outlined),
      ],
      MembershipRole.teacher => [
        // ── Always visible (core) ────────────────────────────────
        const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
        const _NavItem(
          label: 'Timetable',
          icon: Icons.calendar_view_week_outlined,
        ),

        // ── Permission-gated (visible only with proper role/scope) ──
        if (perms.canAny(Resource.exams, [Action.read]))
          const _NavItem(label: 'Exams', icon: Icons.assignment_outlined),
        if (perms.canAny(Resource.classes, [Action.read]))
          const _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
        if (perms.canAny(Resource.students, [Action.read]) ||
            perms.canAny(Resource.teachers, [Action.read]) ||
            perms.canAny(Resource.staff, [Action.read]) ||
            perms.canAny(Resource.owners, [Action.read]))
          const _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
        if (perms.canAny(Resource.fees, [Action.read]) ||
            perms.canAny(Resource.payments, [Action.read]))
          const _NavItem(
            label: 'Finance',
            icon: Icons.account_balance_outlined,
          ),
        if (perms.canAny(Resource.announcements, [Action.read]))
          const _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
        if (perms.canAny(Resource.roles, [Action.read]))
          const _NavItem(
            label: 'Roles',
            icon: Icons.admin_panel_settings_outlined,
          ),
      ],
      MembershipRole.staff => [
        const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
        if (perms.canAny(Resource.classes, [Action.read]))
          const _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
        if (perms.canAny(Resource.exams, [Action.read]))
          const _NavItem(label: 'Exams', icon: Icons.assignment_outlined),
        if (perms.canAny(Resource.departments, [Action.read]) ||
            perms.canAny(Resource.owners, [Action.read]) ||
            perms.canAny(Resource.teachers, [Action.read]) ||
            perms.canAny(Resource.staff, [Action.read]) ||
            perms.canAny(Resource.students, [Action.read]))
          const _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
        if (perms.canAny(Resource.fees, [Action.read]) ||
            perms.canAny(Resource.payments, [Action.read]))
          const _NavItem(
            label: 'Finance',
            icon: Icons.account_balance_outlined,
          ),
        if (perms.canAny(Resource.announcements, [Action.read]))
          const _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
        if (perms.canAny(Resource.classes, [Action.read]))
          const _NavItem(
            label: 'Timetable',
            icon: Icons.calendar_view_week_outlined,
          ),
        if (perms.canAny(Resource.roles, [Action.read]))
          const _NavItem(
            label: 'Roles',
            icon: Icons.admin_panel_settings_outlined,
          ),
      ],
      MembershipRole.student => const [
        _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
        _NavItem(label: 'Grades', icon: Icons.bar_chart_outlined),
        _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
        _NavItem(label: 'Finance', icon: Icons.receipt_long_outlined),
        _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
      ],
      MembershipRole.guardian => const [
        _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
        _NavItem(label: 'Progress', icon: Icons.bar_chart_outlined),
        _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
        _NavItem(label: 'Finance', icon: Icons.receipt_long_outlined),
        _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
      ],
    };
  }

  // ── build — single Scaffold, layout mode drives navigation chrome ─────────
  //
  // A single Scaffold persists across all breakpoints. The LayoutBuilder
  // computes `mode` inline — the navigation chrome (sidebar / rail / tabs) is
  // swapped but the content area widget tree is NEVER torn down. This ensures
  // that any Navigator.push-based detail pages survive a window resize.

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: widget.schoolContext.currentEntry,
      builder: (context, currentEntry, _) {
        // Build content OUTSIDE LayoutBuilder so it's stable across resizes
        final content = DashboardNavigation(
          navigateToTab: _navigateToTab,
          child: KeyedSubtree(
            key: ValueKey('dashboard-content-${currentEntry.role}'),
            child: _buildContentArea(context, currentEntry),
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final mode = w >= AppTheme.kDesktopBreakpoint
                ? _LayoutMode.full
                : w >= AppTheme.kMobileBreakpoint
                ? _LayoutMode.rail
                : _LayoutMode.mobile;
            return _buildLayout(context, currentEntry, mode, content);
          },
        );
      },
    );
  }

  // ── Unified layout — single Scaffold, swappable chrome ─────────────────────

  Widget _buildLayout(
    BuildContext ctx,
    MembershipEntry currentEntry,
    _LayoutMode mode,
    Widget content,
  ) {
    final cs = Theme.of(ctx).colorScheme;
    final isMobile = mode == _LayoutMode.mobile;

    // Build the sidebar/rail widget — zero-width SizedBox for mobile
    Widget navigationChrome;
    switch (mode) {
      case _LayoutMode.full:
        navigationChrome = _FullSidebar(
          schoolContext: widget.schoolContext,
          currentEntry: currentEntry,
          items: _currentItems,
          selectedIndex: _selectedIndex,
          onItemSelected: _selectIndex,
          onRoleSwitchTap: () => _showRoleSwitcherSheet(ctx),
          activeTermContext: widget.activeTermContext,
        );
      case _LayoutMode.rail:
        navigationChrome = _IconRail(
          schoolContext: widget.schoolContext,
          currentEntry: currentEntry,
          items: _currentItems,
          selectedIndex: _selectedIndex,
          onItemSelected: _selectIndex,
          onRoleSwitchTap: () => _showRoleSwitcherSheet(ctx),
          activeTermContext: widget.activeTermContext,
        );
      case _LayoutMode.mobile:
        navigationChrome = const SizedBox.shrink();
    }

    // Wrap content the same way for desktop/rail (padded card); raw for mobile
    final wrappedContent = isMobile
        ? Expanded(child: content)
        : Expanded(child: _wrapSidebarContent(cs, content));

    // The Row is always present. For mobile, navigationChrome is zero-width.
    final mainRow = Row(children: [navigationChrome, wrappedContent]);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMobile)
              _TabLayoutTopBar(
                schoolContext: widget.schoolContext,
                currentEntry: currentEntry,
                activeTermContext: widget.activeTermContext,
                onRoleSwitchTap: widget.schoolContext.canSwitch
                    ? () => _showRoleSwitcherSheet(ctx)
                    : null,
              ),
            if (isMobile)
              _UnifiedMobileTabBar(
                items: _currentItems,
                controller: _tabController,
              ),
            Expanded(child: mainRow),
          ],
        ),
      ),
    );
  }

  /// Wraps the content area with the padding + rounded card used by both
  /// sidebar and rail layouts.
  Widget _wrapSidebarContent(ColorScheme cs, Widget content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(color: cs.surface, child: content),
      ),
    );
  }

  // ── Shared content placeholder panel ──────────────────────────────────────

  // ── Main content area — blank-state guard + content panel ─────────────────
  //
  // Academic sections (everything except Overview and Settings) are gated
  // behind the existence of at least one term. When no terms exist the
  // dashboard shows the NoTermsBlankState instead of the section content.
  //
  // Non-academic sections (Overview, Settings, etc.) are always shown.

  static const _kAcademicNavLabels = {
    'Academics',
    'Exams',
    'Timetable',
    'Grades',
    'Progress',
  };

  bool _isAcademicSection(_NavItem item) =>
      _kAcademicNavLabels.contains(item.label);

  Widget _buildContentArea(BuildContext context, MembershipEntry entry) {
    return ValueListenableBuilder<Term?>(
      valueListenable: widget.activeTermContext.termNotifier,
      builder: (context, currentTerm, _) {
        final item = _currentItems[_selectedIndex];

        // If the active section is academic and there are no terms, show blank state.
        if (_isAcademicSection(item) && !widget.activeTermContext.hasTerms) {
          return NoTermsBlankState(
            schoolId: widget.schoolContext.membership.school.id,
            role: entry.role,
            canCreateTerm:
                entry.role == MembershipRole.owner ||
                widget.schoolContext.permissions.can(
                  Resource.schools,
                  Action.update,
                ),
          );
        }

        return _buildContentPanel(context, item, entry, currentTerm);
      },
    );
  }

  Widget _buildContentPanel(
    BuildContext context,
    _NavItem item,
    MembershipEntry entry,
    Term? currentTerm,
  ) {
    // ── Overview — role-based landing page ─────────────────────────────────
    if (item.label == 'Overview') {
      return OverviewScreen(schoolContext: widget.schoolContext);
    }

    // ── Progress — student / guardian ward academic progress ──────────────
    if (item.label == 'Progress') {
      return ProgressScreen(schoolContext: widget.schoolContext);
    }

    // ── Grades — student's own academic grades (reuses ProgressScreen) ────
    if (item.label == 'Grades') {
      return ProgressScreen(schoolContext: widget.schoolContext);
    }

    // ── Academics (Departments, Subjects, Classes, Exams) ─────────────────
    // Visible to Owner and Staff who have access; exposed under the 'Academics'
    // nav label for owners.
    if (item.label == 'Academics') {
      return AcademicsScreen(schoolContext: widget.schoolContext);
    }

    // ── Exams & Grades (Teacher view) ─────────────────────────────────────
    // Teachers reach the full grading hierarchy directly via the
    // 'Exams & Grades' nav item — no Academics wrapper needed.
    if (item.label == 'Exams') {
      return ExamsGradesScreen(schoolContext: widget.schoolContext);
    }

    // ── Members — unified page for all school member types ────────────────
    // Five tabs: Owners, Teachers, Staff, Students, Guardians.
    // Context-aware FAB adapts per active tab.
    if (item.label == 'Members') {
      return MembersPage(schoolContext: widget.schoolContext);
    }

    // ── Roles — school role & permission management ───────────────────────
    // Directly replaces the old Settings nav item. Renders SchoolRolesScreen.
    if (item.label == 'Roles') {
      return SchoolRolesScreen(schoolContext: widget.schoolContext);
    }

    // ── Finance — fees, invoices, payments, discounts ─────────────────────
    // Owners/Staff see full financial management with 4 tabs.
    // Guardians see a read-only per-ward statement.
    if (item.label == 'Finance') {
      return FinanceScreen(schoolContext: widget.schoolContext);
    }

    // ── Announcements — school-wide communications feed ───────────────────
    // Owners/Staff see full feed with compose FAB. Teachers/Students/Guardians
    // see a read-only feed filtered by their audience bitmask and class.
    if (item.label == 'Announcements') {
      return AnnouncementsScreen(schoolContext: widget.schoolContext);
    }

    // ── Timetable — weekly schedule grid + rules configuration ────────────
    // Owners see full management with rules config and generation CTA.
    // Teachers see their personal weekly schedule across all classes.
    // Students/Guardians see the class timetable for their enrolled class.
    if (item.label == 'Timetable') {
      return TimetableScreen(schoolContext: widget.schoolContext);
    }

    // ── Settings — owner school profile & details editor ──────────────────
    // Owners can edit school name, motto, contact details, county, logo, etc.
    if (item.label == 'Settings') {
      return SchoolSettingsScreen(schoolContext: widget.schoolContext);
    }

    // ── Default placeholder ────────────────────────────────────────────────
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Role switcher sheet ────────────────────────────────────────────────────

  void _showRoleSwitcherSheet(BuildContext context) {
    if (widget.schoolContext.membership.entries.length <= 1) return;
    showEduSheet(
      context: context,
      builder: (_) => _RoleSwitcherSheet(
        schoolContext: widget.schoolContext,
        onEntrySelected: (entry) {
          widget.schoolContext.switchEntry(entry);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full labelled sidebar — 232 px, school identity + nav items + user footer
// ─────────────────────────────────────────────────────────────────────────────

class _FullSidebar extends StatelessWidget {
  const _FullSidebar({
    required this.schoolContext,
    required this.currentEntry,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onRoleSwitchTap,
    required this.activeTermContext,
  });

  final SchoolContext schoolContext;
  final MembershipEntry currentEntry;
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onRoleSwitchTap;
  final ActiveTermContext activeTermContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final school = schoolContext.membership.school;

    return Container(
      width: 232,
      height: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(
            color: isLight
                ? cs.outlineVariant.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top actions row ────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: 'Back to Home',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: const EdgeInsets.all(8),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // ── School identity block ──────────────────────────────────────
          GestureDetector(
            onTap: schoolContext.canSwitch ? onRoleSwitchTap : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.brandIndigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        school.name.isNotEmpty
                            ? school.name[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandIndigo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          school.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        _RoleBadge(
                          role: currentEntry.role,
                          canSwitch: schoolContext.canSwitch,
                          cs: cs,
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Term selector chip ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TermSelectorChip(
              termContext: activeTermContext,
              alignRight: true,
              canCreateTerm:
                  currentEntry.role == MembershipRole.owner ||
                  schoolContext.permissions.can(
                    Resource.schools,
                    Action.update,
                  ),
            ),
          ),

          Divider(
            height: 1,
            thickness: isLight ? 0.5 : 1,
            color: cs.outlineVariant.withValues(alpha: isLight ? 0.45 : 0.3),
          ),

          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final isLight2 = isLight;
                final accent = isLight2
                    ? AppTheme.brandIndigo
                    : AppTheme.brandIndigoDark;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onItemSelected(index),
                      overlayColor: WidgetStateProperty.all(
                        cs.onSurface.withValues(alpha: 0.04),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: isLight2 ? 0.08 : 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              items[index].icon,
                              size: 18,
                              color: isSelected
                                  ? accent
                                  : cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                items[index].label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? accent
                                      : cs.onSurfaceVariant,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── User footer ────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: isLight ? 0.5 : 1,
            color: cs.outlineVariant.withValues(alpha: isLight ? 0.45 : 0.3),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  // Sync status dot + Avatar
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SyncIndicator(),
                      const SizedBox(width: 4),
                      _UserMenuAnchor(cs: cs),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon rail — 64 px wide, icon-only with tooltips
// ─────────────────────────────────────────────────────────────────────────────

class _IconRail extends StatelessWidget {
  const _IconRail({
    required this.schoolContext,
    required this.currentEntry,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onRoleSwitchTap,
    required this.activeTermContext,
  });

  final SchoolContext schoolContext;
  final MembershipEntry currentEntry;
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onRoleSwitchTap;
  final ActiveTermContext activeTermContext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Container(
      width: 64,
      height: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(
            color: isLight
                ? cs.outlineVariant.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Back button ───────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _RailIconBtn(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back to Home',
                cs: cs,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── School initial — tappable for role switch ─────────────────
          Tooltip(
            message: schoolContext.canSwitch
                ? 'Switch role — ${schoolContext.membership.school.name}'
                : schoolContext.membership.school.name,
            preferBelow: false,
            child: GestureDetector(
              onTap: schoolContext.canSwitch ? onRoleSwitchTap : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.brandIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        schoolContext.membership.school.name.isNotEmpty
                            ? schoolContext.membership.school.name[0]
                                  .toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandIndigo,
                        ),
                      ),
                      // Tiny switcher indicator dot in the corner
                      if (schoolContext.canSwitch)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppTheme.brandIndigo,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── Term selector chip (compact, rotated label) ───────────────
          Tooltip(
            message: activeTermContext.hasTerms
                ? activeTermContext.currentTermLabel
                : 'No terms',
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 400),
            child: TermSelectorChip(
              termContext: activeTermContext,
              alignRight: true,
              compact: true,
              canCreateTerm:
                  currentEntry.role == MembershipRole.owner ||
                  schoolContext.permissions.can(
                    Resource.schools,
                    Action.update,
                  ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Divider ───────────────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Divider(
              height: 1,
              thickness: isLight ? 0.5 : 1,
              color: cs.outlineVariant.withValues(alpha: isLight ? 0.4 : 0.3),
            ),
          ),

          const SizedBox(height: 8),

          // ── Nav icons ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final accent = isLight
                    ? AppTheme.brandIndigo
                    : AppTheme.brandIndigoDark;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 10,
                  ),
                  child: Tooltip(
                    message: items[index].label,
                    preferBelow: false,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onItemSelected(index),
                        overlayColor: WidgetStateProperty.all(
                          cs.onSurface.withValues(alpha: 0.04),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          width: 44,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent.withValues(
                                    alpha: isLight ? 0.10 : 0.16,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            items[index].icon,
                            size: 19,
                            color: isSelected
                                ? accent
                                : cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Bottom: notifications + user avatar ───────────────────────
          SizedBox(
            width: 32,
            child: Divider(
              height: 1,
              thickness: isLight ? 0.5 : 1,
              color: cs.outlineVariant.withValues(alpha: isLight ? 0.4 : 0.3),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  // Sync status dot
                  const SyncIndicator(),
                  const SizedBox(height: 6),
                  // User avatar — opens user menu
                  _UserMenuAnchor(cs: cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small icon-button used inside the rail
class _RailIconBtn extends StatelessWidget {
  const _RailIconBtn({
    required this.icon,
    required this.tooltip,
    required this.cs,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          overlayColor: WidgetStateProperty.all(
            cs.onSurface.withValues(alpha: 0.05),
          ),
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(
              icon,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tablet / mobile top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TabLayoutTopBar extends StatelessWidget {
  const _TabLayoutTopBar({
    required this.schoolContext,
    required this.currentEntry,
    required this.activeTermContext,
    this.onRoleSwitchTap,
  });

  final SchoolContext schoolContext;
  final MembershipEntry currentEntry;
  final ActiveTermContext activeTermContext;
  final VoidCallback? onRoleSwitchTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back
          IconButton(
            icon: Icon(Icons.chevron_left, size: 24, color: cs.onSurface),
            tooltip: 'Back to Home',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // School name + role badge — centred between the two icon buttons.
          Expanded(
            child: GestureDetector(
              onTap: onRoleSwitchTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    schoolContext.membership.school.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  _RoleBadge(
                    role: currentEntry.role,
                    canSwitch: onRoleSwitchTap != null,
                    cs: cs,
                    onTap: null, // parent GestureDetector handles it
                  ),
                ],
              ),
            ),
          ),

          // Term selector chip — right of school identity (compact icon-only on mobile)
          TermSelectorChip(
            termContext: activeTermContext,
            alignRight: false,
            compact: true,
          ),

          const SizedBox(width: 4),

          // Sync status dot — tiny, unobtrusive.
          const SyncIndicator(),
          const SizedBox(width: 4),

          // User avatar — opens user menu (anchors downward on mobile)
          _UserMenuAnchor(cs: cs, openUpward: false),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill tab strip — icon-only, fills full pill width (mobile only, < 600 px)
// ─────────────────────────────────────────────────────────────────────────────

class _UnifiedMobileTabBar extends StatelessWidget {
  const _UnifiedMobileTabBar({required this.items, required this.controller});

  final List<_NavItem> items;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isScrollable = items.length > 5;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
        splashBorderRadius: BorderRadius.circular(8),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
        labelPadding: EdgeInsets.symmetric(horizontal: isScrollable ? 16 : 0),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        tabs: items.map((item) => Tab(height: 38, text: item.label)).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill tab strip — icon-only for rail/sidebar layouts
// ─────────────────────────────────────────────────────────────────────────────

class _PillTabStrip extends StatelessWidget {
  const _PillTabStrip({
    required this.items,
    required this.controller,
    required this.isDark,
    required this.cs,
  });

  final List<_NavItem> items;
  final TabController controller;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.5),
        borderRadius: BorderRadius.circular(8),
        border: isDark
            ? Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        splashBorderRadius: BorderRadius.circular(6),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
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
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelPadding: EdgeInsets.zero,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        // Icon-only: each tab fills its equal share, icon is centred.
        tabs: items
            .map((item) => Tab(height: 28, icon: Icon(item.icon, size: 17)))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role badge — compact inline chip with optional switcher arrow
// ─────────────────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.role,
    required this.canSwitch,
    required this.cs,
    this.onTap,
  });

  final MembershipRole role;
  final bool canSwitch;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = cs.brightness == Brightness.light;
    final accent = isLight ? AppTheme.brandIndigo : AppTheme.brandIndigoDark;
    final bg = accent.withValues(alpha: isLight ? 0.08 : 0.14);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labelFor(role),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: accent,
                letterSpacing: 0.8,
              ),
            ),
            if (canSwitch) ...[
              const SizedBox(width: 2),
              Icon(Icons.unfold_more, size: 11, color: accent),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(MembershipRole role) => switch (role) {
    MembershipRole.owner => 'OWNER',
    MembershipRole.teacher => 'TEACHER',
    MembershipRole.staff => 'STAFF',
    MembershipRole.student => 'STUDENT',
    MembershipRole.guardian => 'GUARDIAN',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// User menu anchor — avatar + LayerLink → custom overlay popup
// ─────────────────────────────────────────────────────────────────────────────

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
              final cs = Theme.of(context).colorScheme;
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
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  Future<void> _dismiss() async {
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
    return Stack(
      children: [
        // Transparent barrier — taps outside dismiss the menu.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // Anchored card.
        // openUpward=true  (sidebar footer): card rises above-right of avatar.
        // openUpward=false (mobile top bar):  card drops below-left of avatar.
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: widget.openUpward
              ? Alignment.topRight
              : Alignment.bottomRight,
          followerAnchor: widget.openUpward
              ? Alignment.bottomLeft
              : Alignment.topRight,
          offset: widget.openUpward ? const Offset(8, -8) : const Offset(0, 8),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _UserMenuCard(
                onAction: (action) {
                  _dismiss();
                  // Small delay so the animation closes before navigation.
                  Future.microtask(() => widget.onAction(action));
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
                            user?.name ?? '—',
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
                            user?.phone ?? '—',
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
              _MenuItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Account',
                iconColor: iconColor,
                labelColor: labelColor,
                hoverColor: itemHover,
                onTap: () => onAction(_UserMenuAction.account),
              ),
              _MenuItem(
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
              _MenuItem(
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
class _MenuItem extends StatelessWidget {
  const _MenuItem({
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
    // Outer padding creates the horizontal inset so the highlight never
    // touches the card edges — matching the screenshot's contained row look.
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

enum _UserMenuAction { account, notifications, logout }

// ─────────────────────────────────────────────────────────────────────────────
// Role switcher bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RoleSwitcherSheet extends StatelessWidget {
  const _RoleSwitcherSheet({
    required this.schoolContext,
    required this.onEntrySelected,
  });

  final SchoolContext schoolContext;
  final ValueChanged<MembershipEntry> onEntrySelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final entries = schoolContext.membership.entries;
    final currentEntry = schoolContext.currentEntry.value;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Switch role',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            // Entries
            ...entries.map((entry) {
              final isCurrent = entry == currentEntry;
              final (icon, title, subtitle) = _entryMeta(entry);
              final accent = isLight
                  ? AppTheme.brandIndigo
                  : AppTheme.brandIndigoDark;

              return InkWell(
                onTap: () => onEntrySelected(entry),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  color: isCurrent
                      ? accent.withValues(alpha: isLight ? 0.05 : 0.10)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      if (entry is GuardianEntry)
                        StudentAvatar(
                          schoolId: schoolContext.membership.school.id,
                          adm: entry.ward.adm,
                          name: entry.ward.name,
                          radius: 18,
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? accent.withValues(alpha: 0.12)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            size: 17,
                            color: isCurrent
                                ? accent
                                : cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: isCurrent ? accent : cs.onSurface,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: accent,
                        )
                      else
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  (IconData, String, String) _entryMeta(MembershipEntry entry) {
    return switch (entry) {
      OwnerEntry() => (Icons.shield_outlined, 'Owner', ''),
      TeacherEntry(:final subjectCount) => (
        Icons.school_outlined,
        'Teacher',
        subjectCount > 0
            ? '$subjectCount subject${subjectCount == 1 ? '' : 's'}'
            : 'No subjects this term',
      ),
      StaffEntry(:final staff) => (
        Icons.badge_outlined,
        'Staff',
        [
          if (staff.role case final r?) r,
          if (staff.department case final d?) d,
        ].join(' · '),
      ),
      StudentEntry() => (Icons.person_outline, 'Student', ''),
      GuardianEntry(:final ward) => (
        Icons.family_restroom_outlined,
        'Guardian',
        ward.name,
      ),
    };
  }
}
