import 'package:flutter/material.dart' hide Action;

import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../plans/plans_section.dart';
import 'subjects_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SystemSettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page system settings screen pushed from the system dashboard app bar
/// gear icon or user menu.
///
/// Contains two tabbed sections:
/// - **Plans:** Subscription plan management via [PlansSection].
/// - **Subjects:** Global subject catalog + topic management via
///   [SubjectsSection].
///
/// Uses a cupertino-inspired segmented control for tab switching instead of a
/// traditional Material [TabBar].
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key, required this.permissions});

  /// Pre-loaded permissions for the current user. Must be computed by the
  /// caller — only [UserLevel.super_] receives [SystemPermissions.superUser()];
  /// system users receive their actual scoped permissions.
  final SystemPermissions permissions;

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  int _selectedTab = 0;
  final ValueNotifier<CurriculumType> _curriculumNotifier = ValueNotifier(
    CurriculumType.cbc,
  );

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
    _curriculumNotifier.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTheme.kMobileBreakpoint;
    final maxWidth = isDesktop ? 780.0 : double.infinity;

    final permissions = widget.permissions;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    // ── Segmented control ─────────────────────────────────
                    _SegmentedControl(
                      selectedIndex: _selectedTab,
                      onChanged: (i) => setState(() => _selectedTab = i),
                      tabs: const ['Plans', 'Subjects'],
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    // ── Tab content ───────────────────────────────────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: _selectedTab == 0
                            ? KeyedSubtree(
                                key: const ValueKey('plans'),
                                child: PlansSection(permissions: permissions),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('subjects'),
                                child: SubjectsSection(
                                  permissions: permissions,
                                  curriculumNotifier: _curriculumNotifier,
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

// ─────────────────────────────────────────────────────────────────────────────
// Segmented control — cupertino-inspired tab switcher
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
    required this.tabs,
    required this.cs,
    required this.isDark,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> tabs;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: isDark
            ? Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.25),
                width: 0.5,
              )
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          return Stack(
            children: [
              // ── Sliding indicator ─────────────────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? cs.surface : cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: isDark
                        ? Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                            width: 0.5,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.06,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.08 : 0.02,
                        ),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Tab labels ────────────────────────────────────────────
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = index == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(index),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              index == 0
                                  ? Icons.credit_card_outlined
                                  : Icons.menu_book_outlined,
                              size: 14,
                              color: isSelected
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: isSelected
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                letterSpacing: 0.1,
                              ),
                              child: Text(tabs[index]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
