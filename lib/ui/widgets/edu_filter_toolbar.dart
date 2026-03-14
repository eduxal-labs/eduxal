import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'edu_search_field.dart';

/// Data model for a filter chip in [EduFilterToolbar].
class EduFilterChipData {
  const EduFilterChipData({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;
}

/// Search + filter toolbar for data tables.
///
/// Renders: Row with search icon toggle, animated search field,
/// filter icon toggle. Below: collapsible filter chip rows.
class EduFilterToolbar extends StatelessWidget {
  const EduFilterToolbar({
    super.key,
    required this.searchController,
    this.searchHint = 'Search…',
    this.onSearchChanged,
    this.filters = const [],
    this.showSearch = false,
    this.onToggleSearch,
    this.onToggleFilters,
    this.showFilters = false,
  });

  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final List<EduFilterChipData> filters;
  final bool showSearch;
  final VoidCallback? onToggleSearch;
  final VoidCallback? onToggleFilters;
  final bool showFilters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top row: search toggle + search field + filter toggle ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Search toggle button
              _ToolbarIconButton(
                icon: Icons.search_rounded,
                isActive: showSearch,
                onTap: onToggleSearch,
                cs: cs,
              ),
              const SizedBox(width: 6),
              // Animated search field
              EduSearchField(
                controller: searchController,
                hint: searchHint,
                onChanged: onSearchChanged,
                expanded: showSearch,
              ),
              const Spacer(),
              // Filter toggle button (only if filters provided)
              if (filters.isNotEmpty)
                _ToolbarIconButton(
                  icon: Icons.filter_list_rounded,
                  isActive: showFilters,
                  onTap: onToggleFilters,
                  cs: cs,
                ),
            ],
          ),
        ),
        // ── Collapsible filter chips ──
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filters
                  .map((f) => _EduFilterChip(data: f, cs: cs, isDark: isDark))
                  .toList(),
            ),
          ),
          crossFadeState: showFilters && filters.isNotEmpty
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// Small icon button for the toolbar.
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: isActive
            ? cs.primary
            : cs.onSurfaceVariant.withValues(alpha: 0.6),
        padding: EdgeInsets.zero,
        splashRadius: 16,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          ),
          backgroundColor: isActive ? cs.primary.withValues(alpha: 0.08) : null,
        ),
      ),
    );
  }
}

/// Individual filter chip in the toolbar.
class _EduFilterChip extends StatelessWidget {
  const _EduFilterChip({
    required this.data,
    required this.cs,
    required this.isDark,
  });

  final EduFilterChipData data;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final chipColor = data.activeColor ?? cs.primary;

    return GestureDetector(
      onTap: data.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: data.isSelected
              ? chipColor.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.4 : 0.5,
                ),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: data.isSelected
                ? chipColor.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          data.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: data.isSelected ? FontWeight.w500 : FontWeight.w400,
            color: data.isSelected ? chipColor : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
