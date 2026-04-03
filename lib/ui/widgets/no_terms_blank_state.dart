import 'package:flutter/material.dart';

import '../../models/membership.dart';
import '../theme/app_theme.dart';
import 'create_term_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NoTermsBlankState
//
// Shown when the school has zero terms in the local database.
//
// Behaviour by role:
//   - Owner:   Shows a prominent "Create First Term" CTA.
//   - Teacher / Staff / Admin: Shows a softer "no terms yet" message without
//     a CTA (they can't create terms).
//   - Student / Guardian: Shows a minimal informational state.
// ─────────────────────────────────────────────────────────────────────────────

class NoTermsBlankState extends StatelessWidget {
  const NoTermsBlankState({
    super.key,
    required this.schoolId,
    required this.role,
    this.canCreateTerm = false,
    this.onTermCreated,
  });

  /// The school this blank state is for — passed to the creation modal.
  final String schoolId;

  /// The active membership role — determines which copy and CTA to show.
  final MembershipRole role;

  /// Whether the current user has permission to create terms at this school.
  /// When true, shows the prominent "Create First Term" CTA and owner-style
  /// copy. When false, shows a softer informational state.
  final bool canCreateTerm;

  /// Called after a term is successfully created. The parent (dashboard shell)
  /// uses this to update the [ActiveTermContext] immediately.
  final VoidCallback? onTermCreated;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isOwner = canCreateTerm;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppTheme.kMobileBreakpoint;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48.0 : 32.0,
              vertical: 48.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Illustration ───────────────────────────────────────
                  _Illustration(isDark: isDark, cs: cs, isOwner: isOwner),

                  const SizedBox(height: 28),

                  // ── Headline ───────────────────────────────────────────
                  Text(
                    isOwner ? 'Set up your first term' : 'No terms yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isWide ? 21 : 19,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Body copy (role-specific) ──────────────────────────
                  Text(
                    _bodyCopyForRole(role, isOwner),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      height: 1.55,
                    ),
                  ),

                  // ── CTA (owner only) ───────────────────────────────────
                  if (isOwner) ...[
                    const SizedBox(height: 28),
                    _CreateTermButton(
                      schoolId: schoolId,
                      onTermCreated: onTermCreated,
                      isDark: isDark,
                      cs: cs,
                    ),
                  ],

                  // ── Info pills (non-owner) ─────────────────────────────
                  if (!isOwner) ...[
                    const SizedBox(height: 28),
                    _InfoPills(cs: cs, isDark: isDark),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Returns role-specific body copy for the no-terms blank state.
String _bodyCopyForRole(MembershipRole role, bool canCreateTerm) {
  if (canCreateTerm) {
    return 'Academic records — classes, subjects, grades, '
        'fees and attendance — are all scoped to a term. '
        'Create your first term to unlock the full dashboard.';
  }
  return switch (role) {
    MembershipRole.owner =>
      'Academic records — classes, subjects, grades, '
          'fees and attendance — are all scoped to a term. '
          'Create your first term to unlock the full dashboard.',
    MembershipRole.teacher =>
      'No terms have been created yet. '
          'Contact the school administrator to get started.',
    MembershipRole.student =>
      'The school hasn\'t set up terms yet. Check back later.',
    MembershipRole.guardian =>
      'The school hasn\'t set up the academic calendar yet.',
    MembershipRole.staff =>
      'No academic terms configured. Contact the school owner.',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Geometric illustration — a stacked set of layered cards suggesting structure
// ─────────────────────────────────────────────────────────────────────────────

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.isDark,
    required this.cs,
    required this.isOwner,
  });

  final bool isDark;
  final ColorScheme cs;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    // Two palette tiers for the layered cards.
    final cardBack = isDark ? const Color(0xFF1A2535) : const Color(0xFFF0F2F5);
    final cardMid = isDark ? const Color(0xFF1E2C3C) : const Color(0xFFF7F8FA);
    final cardFront = isDark ? const Color(0xFF243040) : cs.surface;

    final borderColor = isDark
        ? const Color(0xFF2D3E52)
        : cs.outlineVariant.withValues(alpha: 0.5);

    return SizedBox(
      width: 200,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Back card (offset up-left, smallest) ──────────────────────
          Positioned(
            top: 0,
            left: 16,
            child: _Card(
              width: 160,
              height: 96,
              color: cardBack,
              border: borderColor,
              radius: 10,
              shadow: isDark ? 0.25 : 0.06,
            ),
          ),

          // ── Mid card ──────────────────────────────────────────────────
          Positioned(
            top: 14,
            left: 8,
            child: _Card(
              width: 176,
              height: 96,
              color: cardMid,
              border: borderColor,
              radius: 10,
              shadow: isDark ? 0.30 : 0.07,
            ),
          ),

          // ── Front card — contains the icon ────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Card(
              width: 200,
              height: 100,
              color: cardFront,
              border: borderColor,
              radius: 10,
              shadow: isDark ? 0.35 : 0.08,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container with accent tint
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.15 : 0.09),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      isOwner
                          ? Icons.add_circle_outline_rounded
                          : Icons.event_note_outlined,
                      size: 20,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 9),
                  // Three shimmer lines — content placeholders
                  _ShimmerLine(
                    width: 96,
                    height: 6,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 5),
                  _ShimmerLine(
                    width: 64,
                    height: 5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.08),
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

// Minimal flat card widget.
class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.height,
    required this.color,
    required this.border,
    required this.radius,
    required this.shadow,
    this.child,
  });

  final double width;
  final double height;
  final Color color;
  final Color border;
  final double radius;
  final double shadow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadow),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child != null ? Center(child: child) : null,
    );
  }
}

// Placeholder content shimmer line.
class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({
    required this.width,
    required this.height,
    required this.color,
  });
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create term CTA button — owner only
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTermButton extends StatelessWidget {
  const _CreateTermButton({
    required this.schoolId,
    required this.onTermCreated,
    required this.isDark,
    required this.cs,
  });

  final String schoolId;
  final VoidCallback? onTermCreated;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary CTA
        SizedBox(
          height: 44,
          child: Material(
            color: accent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => _openModal(context),
              borderRadius: BorderRadius.circular(9),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.07),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.28 : 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Create First Term',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary hint
        Text(
          'You can add more terms later from the term selector.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Future<void> _openModal(BuildContext context) async {
    final created = await showCreateTermModal(
      context: context,
      schoolId: schoolId,
    );
    if (created != null) {
      onTermCreated?.call();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info pills — non-owner: three feature teasers shown when no terms exist
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPills extends StatelessWidget {
  const _InfoPills({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final pillBg = accent.withValues(alpha: isDark ? 0.10 : 0.07);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _Pill(
          icon: Icons.menu_book_outlined,
          label: 'Subjects',
          color: accent,
          bg: pillBg,
          cs: cs,
        ),
        _Pill(
          icon: Icons.fact_check_outlined,
          label: 'Attendance',
          color: accent,
          bg: pillBg,
          cs: cs,
        ),
        _Pill(
          icon: Icons.assignment_outlined,
          label: 'Exams',
          color: accent,
          bg: pillBg,
          cs: cs,
        ),
        _Pill(
          icon: Icons.account_balance_outlined,
          label: 'Fees',
          color: accent,
          bg: pillBg,
          cs: cs,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.75)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
