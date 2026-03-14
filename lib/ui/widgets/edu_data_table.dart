import 'package:flutter/material.dart';

import '../../database/tables/enums.dart';
import '../theme/app_theme.dart';
import 'edu_filter_toolbar.dart';
import 'edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EduDataTableAction
// ─────────────────────────────────────────────────────────────────────────────

/// An action that can be performed on a data table row.
///
/// On desktop (≥600px), rendered as an inline icon button.
/// On mobile (<600px), rendered as a row in the bottom sheet opened by the
/// three-dot menu button.
class EduDataTableAction<T> {
  const EduDataTableAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;

  /// Called with the row item when the action is triggered.
  final void Function(T item) onTap;

  /// Explicit color override. If null, uses `onSurfaceVariant` (or `error` when
  /// [isDestructive] is true).
  final Color? color;

  /// Destructive actions render in `ColorScheme.error` on both desktop and
  /// mobile, and appear at the bottom of the action list.
  final bool isDestructive;
}

// ─────────────────────────────────────────────────────────────────────────────
// EduDataTableColumn
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a column definition in the data table.
class EduDataTableColumn {
  const EduDataTableColumn({
    required this.label,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final int flex;
  final Alignment alignment;
}

// ─────────────────────────────────────────────────────────────────────────────
// EduIdentityCell
// ─────────────────────────────────────────────────────────────────────────────

/// Helper widget for identity cells with level/status baked in.
///
/// Renders an avatar with an optional level badge and status color indicator.
class EduIdentityCell extends StatelessWidget {
  const EduIdentityCell({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.level,
    this.status,
    this.statusColor,
  });

  final Widget avatar;
  final String title;
  final String? subtitle;
  final UserLevel? level;
  final UserStatus? status;
  final Color? statusColor;

  Color _badgeColor() {
    if (statusColor != null) return statusColor!;
    return switch (status) {
      UserStatus.active => AppTheme.statusActive,
      UserStatus.suspended => AppTheme.statusSuspended,
      UserStatus.deleted => AppTheme.statusDeleted,
      UserStatus.invited => AppTheme.statusInvited,
      _ => AppTheme.statusActive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with optional level badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (level != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(1),
                  child: _buildLevelBadge(),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBadge() {
    final color = _badgeColor();
    return switch (level!) {
      UserLevel.normal => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      UserLevel.system => Icon(
        AppTheme.levelSystemIcon,
        size: 14,
        color: color,
      ),
      UserLevel.super_ => Icon(AppTheme.levelSuperIcon, size: 14, color: color),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EduDataTable
// ─────────────────────────────────────────────────────────────────────────────

/// A data-table-style list widget following the EduXal design system.
///
/// Supports either a freeform `rowBuilder` (legacy/custom layouts) or a
/// structured `columns` and `cellBuilder` (native columns support).
///
/// Optionally supports multi-select mode with checkboxes, an integrated
/// search & filter toolbar, and bulk actions on selected items.
class EduDataTable<T> extends StatelessWidget {
  const EduDataTable({
    super.key,
    required this.items,
    this.rowBuilder,
    this.headerBuilder,
    this.columns,
    this.cellBuilder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'No items',
    this.emptySubtitle,
    this.onItemTap,
    this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    // Selection
    this.selectable = false,
    this.selectedItems = const {},
    this.onSelectionChanged,
    this.itemSelectable,
    this.bulkActions,
    // Search & filters
    this.searchHint,
    this.searchController,
    this.onSearchChanged,
    this.filters,
    this.showSearch = false,
    this.onToggleSearch,
    this.showFilters = false,
    this.onToggleFilters,
  }) : assert(
         rowBuilder != null || (columns != null && cellBuilder != null),
         'Must provide either rowBuilder or both columns and cellBuilder',
       );

  /// The list of items to display.
  final List<T> items;

  /// Builds the freeform content of each row (excluding the action buttons).
  final Widget Function(BuildContext context, T item, bool isHovered)?
  rowBuilder;

  /// Optional header row rendered above the first data row (e.g. column labels).
  final Widget Function(BuildContext context)? headerBuilder;

  /// Definitions for native columns support. When provided alongside `cellBuilder`,
  /// automatically constructs the header row and aligns cells.
  final List<EduDataTableColumn>? columns;

  /// Builds a specific cell for native columns support. Called for each column.
  final Widget Function(
    BuildContext context,
    T item,
    int columnIndex,
    bool isHovered,
  )?
  cellBuilder;

  /// Icon shown in the empty state.
  final IconData emptyIcon;

  /// Primary text shown in the empty state.
  final String emptyTitle;

  /// Optional secondary text shown below [emptyTitle] in the empty state.
  final String? emptySubtitle;

  /// Called when the user taps a row (for navigation).
  final void Function(T item)? onItemTap;

  /// Produces the list of actions available for each row.
  final List<EduDataTableAction<T>> Function(T item)? actions;

  /// Outer padding around the full widget (header + rows).
  final EdgeInsets padding;

  // ── Selection ──────────────────────────────────────────────────────────────

  /// Whether to show selection checkboxes on each row.
  final bool selectable;

  /// The currently selected items.
  final Set<T> selectedItems;

  /// Called when the selection changes (items added or removed).
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Returns whether a specific item can be selected. Defaults to all items
  /// being selectable if not provided.
  final bool Function(T)? itemSelectable;

  /// Actions shown in the selection bar when items are selected.
  final List<EduDataTableAction<T>>? bulkActions;

  // ── Search & filters ───────────────────────────────────────────────────────

  /// Placeholder text for the search field.
  final String? searchHint;

  /// Controller for the search field. When non-null, the toolbar is rendered.
  final TextEditingController? searchController;

  /// Called when the search text changes.
  final ValueChanged<String>? onSearchChanged;

  /// Filter chip definitions for the toolbar.
  final List<EduFilterChipData>? filters;

  /// Whether the search field is currently expanded / visible.
  final bool showSearch;

  /// Called when the user toggles search visibility.
  final VoidCallback? onToggleSearch;

  /// Whether the filter chips are currently visible.
  final bool showFilters;

  /// Called when the user toggles filter visibility.
  final VoidCallback? onToggleFilters;

  // ── helpers ────────────────────────────────────────────────────────────────

  bool _isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Search & filter toolbar ─────────────────────────────────────
          if (searchController != null)
            EduFilterToolbar(
              searchController: searchController!,
              searchHint: searchHint ?? 'Search…',
              onSearchChanged: onSearchChanged,
              filters: filters ?? const [],
              showSearch: showSearch,
              onToggleSearch: onToggleSearch,
              showFilters: showFilters,
              onToggleFilters: onToggleFilters,
            ),

          // ── Selection bar ──────────────────────────────────────────────
          if (selectable && selectedItems.isNotEmpty)
            _SelectionBar<T>(
              selectedCount: selectedItems.length,
              totalCount: items.length,
              bulkActions: bulkActions ?? const [],
              onClearSelection: () => onSelectionChanged?.call({}),
              cs: cs,
            ),

          // ── Empty state or table content ───────────────────────────────
          if (items.isEmpty)
            _EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          else ...[
            // ── header ─────────────────────────────────────────────────────
            if (headerBuilder != null) ...[
              headerBuilder!(context),
              AppTheme.tableRowDivider(isDark, cs),
            ] else if (columns != null) ...[
              _DefaultHeaderRow(
                columns: columns!,
                selectable: selectable,
                allSelected:
                    selectedItems.length == items.length && items.isNotEmpty,
                onSelectAll: selectable
                    ? () {
                        if (selectedItems.length == items.length) {
                          onSelectionChanged?.call({});
                        } else {
                          final all = items
                              .where(
                                (item) => itemSelectable?.call(item) ?? true,
                              )
                              .toSet();
                          onSelectionChanged?.call(all);
                        }
                      }
                    : null,
                cs: cs,
              ),
              AppTheme.tableRowDivider(isDark, cs),
            ],

            // ── rows ───────────────────────────────────────────────────────
            ...List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = selectedItems.contains(item);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EduDataTableRow<T>(
                    item: item,
                    rowBuilder: rowBuilder,
                    columns: columns,
                    cellBuilder: cellBuilder,
                    actions: actions != null ? actions!(item) : const [],
                    onTap: onItemTap != null ? () => onItemTap!(item) : null,
                    isDesktop: _isDesktop(context),
                    // Selection
                    selectable: selectable,
                    isSelected: isSelected,
                    onSelectionToggled: selectable
                        ? () {
                            final newSet = Set<T>.from(selectedItems);
                            if (isSelected) {
                              newSet.remove(item);
                            } else {
                              newSet.add(item);
                            }
                            onSelectionChanged?.call(newSet);
                          }
                        : null,
                  ),
                  if (index < items.length - 1)
                    AppTheme.tableRowDivider(isDark, cs),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DefaultHeaderRow
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultHeaderRow extends StatelessWidget {
  const _DefaultHeaderRow({
    required this.columns,
    this.selectable = false,
    this.allSelected = false,
    this.onSelectAll,
    required this.cs,
  });

  final List<EduDataTableColumn> columns;
  final bool selectable;
  final bool allSelected;
  final VoidCallback? onSelectAll;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          if (selectable) ...[
            _Checkbox(isChecked: allSelected, onTap: onSelectAll, cs: cs),
            const SizedBox(width: 8),
          ],
          ...columns.map((col) {
            return Expanded(
              flex: col.flex,
              child: Align(
                alignment: col.alignment,
                child: Text(
                  col.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EduDataTableRow  (private, stateful — owns hover state)
// ─────────────────────────────────────────────────────────────────────────────

class _EduDataTableRow<T> extends StatefulWidget {
  const _EduDataTableRow({
    super.key,
    required this.item,
    this.rowBuilder,
    this.columns,
    this.cellBuilder,
    required this.actions,
    required this.isDesktop,
    this.onTap,
    // Selection
    this.selectable = false,
    this.isSelected = false,
    this.onSelectionToggled,
  });

  final T item;
  final Widget Function(BuildContext context, T item, bool isHovered)?
  rowBuilder;
  final List<EduDataTableColumn>? columns;
  final Widget Function(
    BuildContext context,
    T item,
    int columnIndex,
    bool isHovered,
  )?
  cellBuilder;
  final List<EduDataTableAction<T>> actions;
  final bool isDesktop;
  final VoidCallback? onTap;

  // Selection
  final bool selectable;
  final bool isSelected;
  final VoidCallback? onSelectionToggled;

  @override
  State<_EduDataTableRow<T>> createState() => _EduDataTableRowState<T>();
}

class _EduDataTableRowState<T> extends State<_EduDataTableRow<T>> {
  bool _isHovered = false;

  void _onHoverChanged(bool hovered) {
    if (_isHovered == hovered) return;
    setState(() => _isHovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoverColor = cs.primary.withValues(alpha: 0.04);
    final selectedColor = cs.primary.withValues(alpha: 0.06);

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: widget.isSelected
            ? selectedColor
            : (_isHovered ? hoverColor : Colors.transparent),
        child: InkWell(
          onTap: widget.onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent, // handled by AnimatedContainer
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                // ── selection checkbox ─────────────────────────────────────
                if (widget.selectable) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Checkbox(
                      isChecked: widget.isSelected,
                      onTap: widget.onSelectionToggled,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // ── row content ───────────────────────────────────────────
                Expanded(
                  child: widget.rowBuilder != null
                      ? widget.rowBuilder!(context, widget.item, _isHovered)
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: List.generate(widget.columns!.length, (
                              index,
                            ) {
                              final col = widget.columns![index];
                              return Expanded(
                                flex: col.flex,
                                child: Align(
                                  alignment: col.alignment,
                                  child: widget.cellBuilder!(
                                    context,
                                    widget.item,
                                    index,
                                    _isHovered,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                ),

                // ── actions ───────────────────────────────────────────────
                if (widget.actions.isNotEmpty)
                  widget.isDesktop
                      ? _DesktopActions<T>(
                          item: widget.item,
                          actions: widget.actions,
                          isRowHovered: _isHovered,
                        )
                      : _MobileMenuButton<T>(
                          item: widget.item,
                          actions: widget.actions,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SelectionBar
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionBar<T> extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.bulkActions,
    required this.onClearSelection,
    required this.cs,
  });

  final int selectedCount;
  final int totalCount;
  final List<EduDataTableAction<T>> bulkActions;
  final VoidCallback onClearSelection;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      child: Row(
        children: [
          Text(
            '$selectedCount selected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
          const Spacer(),
          // Bulk action buttons
          ...bulkActions.map((action) {
            final color =
                action.color ??
                (action.isDestructive ? cs.error : cs.onSurfaceVariant);
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: action.label,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    icon: Icon(action.icon, size: 16),
                    color: color,
                    padding: EdgeInsets.zero,
                    onPressed:
                        () {}, // bulk actions need custom handling by caller
                  ),
                ),
              ),
            );
          }),
          // Clear selection
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Clear selection',
              child: SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: cs.onSurfaceVariant,
                  padding: EdgeInsets.zero,
                  onPressed: onClearSelection,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Checkbox
// ─────────────────────────────────────────────────────────────────────────────

class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.isChecked,
    required this.onTap,
    required this.cs,
  });

  final bool isChecked;
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isChecked ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isChecked ? cs.primary : cs.outlineVariant,
            width: 1.5,
          ),
        ),
        child: isChecked
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DesktopActions  (inline icon buttons)
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopActions<T> extends StatelessWidget {
  const _DesktopActions({
    super.key,
    required this.item,
    required this.actions,
    required this.isRowHovered,
  });

  final T item;
  final List<EduDataTableAction<T>> actions;
  final bool isRowHovered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _DesktopActionButton<T>(
              item: item,
              action: action,
              isRowHovered: isRowHovered,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DesktopActionButton<T> extends StatefulWidget {
  const _DesktopActionButton({
    super.key,
    required this.item,
    required this.action,
    required this.isRowHovered,
  });

  final T item;
  final EduDataTableAction<T> action;
  final bool isRowHovered;

  @override
  State<_DesktopActionButton<T>> createState() =>
      _DesktopActionButtonState<T>();
}

class _DesktopActionButtonState<T> extends State<_DesktopActionButton<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final baseColor =
        widget.action.color ??
        (widget.action.isDestructive ? cs.error : cs.onSurfaceVariant);

    // Fade out when the row is not hovered; full opacity when hovered or
    // when the button itself is hovered.
    final effectiveAlpha = (_isHovered || widget.isRowHovered) ? 1.0 : 0.0;

    return Tooltip(
      message: widget.action.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.action.onTap(widget.item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered
                  ? baseColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: effectiveAlpha,
              child: Icon(widget.action.icon, size: 18, color: baseColor),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MobileMenuButton  (three-dot → bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _MobileMenuButton<T> extends StatelessWidget {
  const _MobileMenuButton({
    super.key,
    required this.item,
    required this.actions,
  });

  final T item;
  final List<EduDataTableAction<T>> actions;

  void _showSheet(BuildContext context) {
    showEduSheet<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── action rows ───────────────────────────────────────────────
              ...actions.map((action) {
                final color =
                    action.color ??
                    (action.isDestructive ? cs.error : cs.onSurface);
                return ListTile(
                  leading: Icon(action.icon, size: 20, color: color),
                  title: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: color,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    action.onTap(item);
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  minLeadingWidth: 20,
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: const Icon(Icons.more_vert),
      iconSize: 20,
      color: cs.onSurfaceVariant,
      onPressed: () => _showSheet(context),
      splashRadius: 20,
      tooltip: 'Actions',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
