import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bordered section container following the EduXal design system.
///
/// Renders: Container with surfaceContainer fill, kCardRadius,
/// 0.5px border, thin dividers between children.
class EduSectionCard extends StatelessWidget {
  const EduSectionCard({
    super.key,
    required this.children,
    this.title,
    this.trailing,
  });

  final List<Widget> children;
  final String? title; // optional section header
  final Widget? trailing; // optional trailing widget in header

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) _buildHeader(cs),
          // Interleave thin dividers between children
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0 || title != null)
              Divider(
                height: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            title!.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
