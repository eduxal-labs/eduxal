import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
// EduDataTable
// ─────────────────────────────────────────────────────────────────────────────

/// A data-table-style list widget following the EduXal design system.
///
/// Supports either a freeform `rowBuilder` (legacy/custom layouts) or a
/// structured `columns` and `cellBuilder` (native columns support).
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
      child: items.isEmpty
          ? _EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── header ──────────────────────────────────────────────────
                if (headerBuilder != null) ...[
                  headerBuilder!(context),
                  AppTheme.tableRowDivider(isDark, cs),
                ] else if (columns != null) ...[
                  _DefaultHeaderRow(columns: columns!),
                  AppTheme.tableRowDivider(isDark, cs),
                ],

                // ── rows ────────────────────────────────────────────────────
                ...List.generate(items.length, (index) {
                  final item = items[index];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EduDataTableRow<T>(
                        item: item,
                        rowBuilder: rowBuilder,
                        columns: columns,
                        cellBuilder: cellBuilder,
                        actions: actions != null ? actions!(item) : const [],
                        onTap: onItemTap != null
                            ? () => onItemTap!(item)
                            : null,
                        isDesktop: _isDesktop(context),
                      ),
                      if (index < items.length - 1)
                        AppTheme.tableRowDivider(isDark, cs),
                    ],
                  );
                }),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DefaultHeaderRow
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultHeaderRow extends StatelessWidget {
  const _DefaultHeaderRow({required this.columns});

  final List<EduDataTableColumn> columns;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: columns.map((col) {
          return Expanded(
            flex: col.flex,
            child: Align(
              alignment: col.alignment,
              child: Text(
                col.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
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

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered ? hoverColor : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent, // handled by AnimatedContainer
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                // ── row content ─────────────────────────────────────────────
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

                // ── actions ─────────────────────────────────────────────────
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.modalBg(isDark, cs),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── drag handle ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

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
