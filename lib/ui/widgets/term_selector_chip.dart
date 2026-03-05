import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../models/active_term_context.dart';
import '../theme/app_theme.dart';
import 'create_term_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TermSelectorChip
//
// A compact, tappable chip that sits in the AppBar (or top bar row).
// Tapping opens a dropdown overlay listing all available terms for the school,
// grouped by year. The currently selected term is highlighted.
//
// Desktop (sidebar layouts): anchored below-right of itself.
// Mobile (tab layout):       anchored below-left of itself.
//
// Architecture:
//   - Reads [ActiveTermContext] passed in directly (not via InheritedWidget)
//     so it can be used in both sidebar and tab topbar contexts without
//     requiring a BuildContext that is a descendant of [ActiveTermProvider].
//   - Uses a raw [OverlayEntry] for the dropdown — exactly like _UserMenuAnchor
//     in the dashboard shell — so it is not clipped by any parent widget.
// ─────────────────────────────────────────────────────────────────────────────

class TermSelectorChip extends StatefulWidget {
  const TermSelectorChip({
    super.key,
    required this.termContext,

    /// When true the dropdown opens downward-right (sidebar).
    /// When false it opens downward-left (mobile top bar).
    this.alignRight = true,

    /// When true, only the calendar icon is shown (no label, no chevron).
    /// Used in the narrow 64 px icon rail where there is no room for text.
    this.compact = false,
  });

  final ActiveTermContext termContext;
  final bool alignRight;
  final bool compact;

  @override
  State<TermSelectorChip> createState() => _TermSelectorChipState();
}

class _TermSelectorChipState extends State<TermSelectorChip> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  // ── Overlay lifecycle ─────────────────────────────────────────────────────

  void _open() {
    if (_entry != null) return;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => _TermDropdown(
        link: _link,
        termContext: widget.termContext,
        alignRight: widget.alignRight,
        onDismiss: _close,
        onTermSelected: (term) {
          widget.termContext.setTerm(term);
          _close();
        },
        onCreateTap: () async {
          _close();
          if (!mounted) return;
          await showCreateTermModal(
            context: context,
            schoolId: widget.termContext.schoolId,
          );
          // The Drift stream feeding ActiveTermContext.updateTerms will
          // automatically pick up the new term — no manual refresh needed.
        },
      ),
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return CompositedTransformTarget(
      link: _link,
      child: ListenableBuilder(
        listenable: widget.termContext,
        builder: (context, _) {
          final label = widget.termContext.currentTermLabel;
          final hasTerms = widget.termContext.hasTerms;

          return Tooltip(
            message: hasTerms ? 'Switch academic term' : 'No terms configured',
            preferBelow: true,
            waitDuration: const Duration(milliseconds: 500),
            child: GestureDetector(
              onTap: _open,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: hasTerms
                      ? accent.withValues(alpha: isDark ? 0.12 : 0.07)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: widget.compact
                    ? Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: hasTerms
                            ? accent.withValues(alpha: 0.8)
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 12,
                            color: hasTerms
                                ? accent.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasTerms ? label : 'No terms',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: hasTerms
                                  ? accent
                                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.expand_more,
                            size: 13,
                            color: hasTerms
                                ? accent.withValues(alpha: 0.65)
                                : cs.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown overlay — barrier + anchored card
// ─────────────────────────────────────────────────────────────────────────────

class _TermDropdown extends StatefulWidget {
  const _TermDropdown({
    required this.link,
    required this.termContext,
    required this.alignRight,
    required this.onDismiss,
    required this.onTermSelected,
    required this.onCreateTap,
  });

  final LayerLink link;
  final ActiveTermContext termContext;
  final bool alignRight;
  final VoidCallback onDismiss;
  final ValueChanged<Term> onTermSelected;
  final VoidCallback onCreateTap;

  @override
  State<_TermDropdown> createState() => _TermDropdownState();
}

class _TermDropdownState extends State<_TermDropdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
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
        // ── Transparent barrier ───────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const SizedBox.expand(),
          ),
        ),

        // ── Anchored dropdown card ────────────────────────────────────
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: widget.alignRight
              ? Alignment.bottomLeft
              : Alignment.bottomRight,
          followerAnchor: widget.alignRight
              ? Alignment.topLeft
              : Alignment.topRight,
          offset: const Offset(0, 6),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _TermDropdownCard(
                termContext: widget.termContext,
                onTermSelected: widget.onTermSelected,
                onCreateTap: widget.onCreateTap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown card — grouped term list + "Add term" footer
// ─────────────────────────────────────────────────────────────────────────────

class _TermDropdownCard extends StatelessWidget {
  const _TermDropdownCard({
    required this.termContext,
    required this.onTermSelected,
    required this.onCreateTap,
  });

  final ActiveTermContext termContext;
  final ValueChanged<Term> onTermSelected;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF18222E) : cs.surface;
    final borderColor = isDark
        ? const Color(0xFF2A3848)
        : cs.outlineVariant.withValues(alpha: 0.55);
    final divColor = isDark ? const Color(0xFF243040) : const Color(0xFFEAECEF);
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    // Group terms by year.
    final grouped = _groupByYear(termContext.allTerms);
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        constraints: const BoxConstraints(maxHeight: 360),
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
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
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
              // ── Term list ─────────────────────────────────────────────
              if (termContext.hasTerms)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final year in years) ...[
                          // Year header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                            child: Text(
                              year.toString(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          // Terms in this year
                          for (final term in grouped[year]!)
                            _TermRow(
                              term: term,
                              isSelected: termContext.isSelected(term),
                              accent: accent,
                              cs: cs,
                              isDark: isDark,
                              onTap: () => onTermSelected(term),
                            ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Text(
                    'No terms yet.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ),

              // ── Divider + Add term footer ─────────────────────────────
              Container(height: 1, color: divColor),
              _AddTermRow(
                accent: accent,
                cs: cs,
                isDark: isDark,
                onTap: onCreateTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Groups [terms] by year (descending key order handled by caller).
  Map<int, List<Term>> _groupByYear(List<Term> terms) {
    final result = <int, List<Term>>{};
    for (final t in terms) {
      result.putIfAbsent(t.year, () => []).add(t);
    }
    // Sort terms within each year by term number ascending.
    for (final list in result.values) {
      list.sort((a, b) => a.term.compareTo(b.term));
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single term row inside the dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.term,
    required this.isSelected,
    required this.accent,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final Term term;
  final bool isSelected;
  final Color accent;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoverColor = isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return isSelected
                  ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
                  : hoverColor;
            }
            return Colors.transparent;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: isDark ? 0.12 : 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                // Dot indicator for selected state
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent
                        : cs.onSurfaceVariant.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Term ${term.term}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected
                          ? accent
                          : cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check, size: 13, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Add term" footer row
// ─────────────────────────────────────────────────────────────────────────────

class _AddTermRow extends StatelessWidget {
  const _AddTermRow({
    required this.accent,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final Color accent;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return accent.withValues(alpha: 0.07);
            }
            return Colors.transparent;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 14,
                  color: accent.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 9),
                Text(
                  'Add term',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: accent.withValues(alpha: 0.85),
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
