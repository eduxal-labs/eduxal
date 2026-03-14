import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Detail page header with avatar and metadata chips.
class EduDetailHeader extends StatelessWidget {
  const EduDetailHeader({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.chips = const [],
    this.actions,
  });

  final Widget avatar; // UserAvatar or school logo
  final String title;
  final String? subtitle;
  final List<Widget> chips; // EduDetailChip list
  final List<Widget>? actions; // trailing action buttons

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

/// A small metadata chip for detail headers.
class EduDetailChip extends StatelessWidget {
  const EduDetailChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
