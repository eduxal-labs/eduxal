import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../plans/plans_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SystemSettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page system settings screen pushed from the system dashboard app bar
/// gear icon.
///
/// Contains:
/// - **Plans section:** Reactive list from [PlansDao.watchAllPlans] with create,
///   edit, and soft-delete functionality (via standalone [PlansSection] widget).
/// - **Placeholder section** for additional system settings.
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTheme.kMobileBreakpoint;
    final maxWidth = isDesktop ? 720.0 : double.infinity;

    // Load permissions synchronously from cache for gating create/edit.
    final user = cache.currentUser;
    final permissions =
        (user != null &&
            (user.user.level == UserLevel.super_ ||
                user.user.level == UserLevel.system))
        ? SystemPermissions.superUser()
        : SystemPermissions.none();

    return Scaffold(
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
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
                  vertical: 16,
                ),
                children: [
                  // ── Plans section ───────────────────────────────────────────
                  PlansSection(permissions: permissions),

                  const SizedBox(height: 32),

                  // ── Placeholder for additional settings ─────────────────────
                  _SectionCard(
                    cs: cs,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 36,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Additional system settings will be added here.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, required this.cs});

  final Widget child;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
