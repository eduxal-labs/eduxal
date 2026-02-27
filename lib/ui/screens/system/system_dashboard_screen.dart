import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Placeholder screen for the system dashboard.
///
/// Visible only to users with `UserLevel.system` or `UserLevel.super_`.
/// No real functionality until the project owner provides detailed
/// requirements (blocked on P9). This shell proves navigation works and
/// provides a file in place for future implementation.
class SystemDashboardScreen extends StatelessWidget {
  const SystemDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'System Dashboard',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: cs.onSurface,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // ── Empty state ──────────────────────────────────────────────
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.brandIndigo.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dashboard_customize_outlined,
                        size: 32,
                        color: AppTheme.brandIndigo.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'System Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Management tools for system administrators.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Hint cards — non-functional, just visual ────────
                    _PlaceholderTile(
                      icon: Icons.school_outlined,
                      label: 'Schools',
                      cs: cs,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _PlaceholderTile(
                      icon: Icons.people_outline_rounded,
                      label: 'Users',
                      cs: cs,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _PlaceholderTile(
                      icon: Icons.credit_card_outlined,
                      label: 'Plans',
                      cs: cs,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A non-functional hint tile suggesting a future dashboard section.
class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({
    required this.icon,
    required this.label,
    required this.cs,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
