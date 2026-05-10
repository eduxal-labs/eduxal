import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  TERM BUTTON — single animated pill button with indigo highlight
// ═════════════════════════════════════════════════════════════════════════════

class TermButton extends StatelessWidget {
  const TermButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgSelected = indigo.withValues(alpha: isDark ? 0.18 : 0.10);
    final bgUnselected =
        isDark ? const Color(0xFF1E2C3C) : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final borderSelected = indigo.withValues(alpha: isDark ? 0.55 : 0.45);
    final borderUnselected =
        cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 28,
      decoration: BoxDecoration(
        color: isSelected ? bgSelected : bgUnselected,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? borderSelected : borderUnselected,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return indigo.withValues(alpha: 0.06);
            }
            return Colors.transparent;
          }),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? indigo
                    : cs.onSurfaceVariant.withValues(
                        alpha: enabled ? 0.65 : 0.3,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TERM BUTTON GROUP — vertical stack of Term 1 / Term 2 / Term 3
// ═════════════════════════════════════════════════════════════════════════════

class TermButtonGroup extends StatelessWidget {
  const TermButtonGroup({
    super.key,
    required this.selected,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.enabled,
    required this.onChanged,
  });

  final int? selected;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final bool enabled;
  final ValueChanged<int> onChanged;

  static const _labels = ['Term 1', 'Term 2', 'Term 3'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_labels.length, (i) {
        final termNumber = i + 1;
        return Padding(
          padding: EdgeInsets.only(bottom: i < _labels.length - 1 ? 4 : 0),
          child: TermButton(
            label: _labels[i],
            isSelected: selected == termNumber,
            isDark: isDark,
            cs: cs,
            indigo: indigo,
            enabled: enabled,
            onTap: () => onChanged(termNumber),
          ),
        );
      }),
    );
  }
}
