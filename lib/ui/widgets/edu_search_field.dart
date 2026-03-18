import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated inline search field following the EduXal design system.
///
/// 32px height, kCardRadius, surfaceContainerHighest fill,
/// 13px text, search icon prefix, clear button suffix when not empty.
class EduSearchField extends StatelessWidget {
  const EduSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search…',
    this.onChanged,
    this.expanded = true,
    this.fillWidth = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool expanded; // animated width transition
  /// When true, no fixed width is applied — the parent controls the width.
  /// Use this when wrapping in [Expanded] or [Flexible].
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: fillWidth ? null : (expanded ? 220 : 0),
      height: 32,
      child: expanded
          ? Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.5 : 0.6,
                ),
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.3,
                  ),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  // Clear button — only visible when there's text
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, __) {
                      if (value.text.isEmpty) return const SizedBox(width: 8);
                      return GestureDetector(
                        onTap: () {
                          controller.clear();
                          onChanged?.call('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
