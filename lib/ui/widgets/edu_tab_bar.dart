import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EduTabBar — The single source of truth for tab aesthetics.
//
// Replaces all raw Material TabBar usage in inner pages (Academics, Roles,
// Members, etc.) with a consistent, elevated, shadow-based indicator style
// that matches the mobile pill-strip navigation — adapted for labelled tabs.
//
// Supports two modes:
//   • Text labels (default inner-page tabs)
//   • Icon-only (mobile top-level nav — though that still uses _PillTabStrip
//     internally; this component is available if consolidation is desired)
//
// Design mandate compliance:
//   ✓ No borders on the indicator — subtle shadow instead
//   ✓ Slightly tinted background container with subtle elevation
//   ✓ BorderRadius.circular(8–10), slim text (w400 / w500)
//   ✓ No underline indicator anywhere
//   ✓ Desktop & mobile mouse drag and scroll wheel support
// ─────────────────────────────────────────────────────────────────────────────

/// A tab descriptor for [EduTabBar].
///
/// Provide either [label] for text tabs or [icon] for icon-only tabs.
/// Both can be provided simultaneously if desired.
class EduTab {
  const EduTab({this.label, this.icon, this.count});

  /// Text label shown in the tab.
  final String? label;

  /// Icon shown in the tab (used for icon-only mode).
  final IconData? icon;

  /// Optional numeric badge count shown next to the label.
  final int? count;
}

/// A polished, elevated tab bar used by all inner pages across the school
/// dashboard. This is the **only** tab component that inner pages should use.
///
/// It renders a tinted background strip with an elevated, shadow-based
/// indicator that slides between tabs — matching the tactile, borderless
/// design language of the app.
///
/// Usage:
/// ```dart
/// EduTabBar(
///   controller: _tabController,
///   tabs: const [
///     EduTab(label: 'Permissions'),
///     EduTab(label: 'Assigned Users'),
///   ],
/// )
/// ```
class EduTabBar extends StatefulWidget {
  const EduTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.isScrollable = true,
    this.height,
    this.padding,
    this.onTap,
  });

  /// The [TabController] driving this tab bar.
  final TabController controller;

  /// Tab descriptors — one per tab.
  final List<EduTab> tabs;

  /// Whether the tab bar scrolls horizontally. Defaults to `true`.
  final bool isScrollable;

  /// Override the strip height. Defaults to 38 for text tabs, 36 for icon-only.
  final double? height;

  /// Outer padding around the strip container. Defaults to horizontal 16, vertical 8.
  final EdgeInsetsGeometry? padding;

  /// Optional callback when a tab is tapped.
  final ValueChanged<int>? onTap;

  @override
  State<EduTabBar> createState() => _EduTabBarState();
}

class _EduTabBarState extends State<EduTabBar> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _tabKeys;

  @override
  void initState() {
    super.initState();
    _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    widget.controller.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveTab(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant EduTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleTabChange);
      widget.controller.addListener(_handleTabChange);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveTab(animate: false);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTabChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted || !widget.isScrollable) return;
    _scrollToActiveTab(animate: true);
  }

  void _scrollToActiveTab({bool animate = true}) {
    if (!mounted || !widget.isScrollable) return;
    final index = widget.controller.index;
    if (index >= 0 && index < _tabKeys.length) {
      final keyContext = _tabKeys[index].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bool iconOnly =
        widget.tabs.every((t) => t.label == null && t.icon != null);
    final double stripHeight = widget.height ?? (iconOnly ? 36.0 : 38.0);

    Widget strip = Container(
      height: stripHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TabBar(
        controller: widget.controller,
        isScrollable: widget.isScrollable,
        tabAlignment:
            widget.isScrollable ? TabAlignment.start : TabAlignment.fill,
        splashBorderRadius: BorderRadius.circular(8),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
              blurRadius: 1,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        onTap: widget.onTap,
        tabs: List.generate(widget.tabs.length, (i) {
          final tab = widget.tabs[i];
          final key = i < _tabKeys.length ? _tabKeys[i] : null;

          if (iconOnly) {
            return KeyedSubtree(
              key: key,
              child: Tab(
                height: stripHeight - 8,
                icon: Icon(tab.icon, size: 17),
              ),
            );
          }

          final labelWidget = Text(tab.label ?? '');
          final badgeWidget = tab.count != null && tab.count! > 0
              ? Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(
                      alpha: isDark ? 0.25 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tab.count}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                )
              : null;

          if (tab.icon != null || badgeWidget != null) {
            return KeyedSubtree(
              key: key,
              child: Tab(
                height: stripHeight - 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tab.icon != null) ...[
                      Icon(tab.icon, size: 15),
                      const SizedBox(width: 6),
                    ],
                    labelWidget,
                    ?badgeWidget,
                  ],
                ),
              ),
            );
          }

          return KeyedSubtree(
            key: key,
            child: Tab(height: stripHeight - 8, text: tab.label ?? ''),
          );
        }),
      ),
    );

    if (widget.isScrollable) {
      return Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && _scrollController.hasClients) {
            final delta = event.scrollDelta.dy != 0
                ? event.scrollDelta.dy
                : event.scrollDelta.dx;
            final newOffset = (_scrollController.offset + delta).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            _scrollController.jumpTo(newOffset);
          }
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: widget.padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: strip,
          ),
        ),
      );
    }

    strip = Align(alignment: Alignment.centerLeft, child: strip);

    return Padding(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: strip,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EduTabBarBottom — PreferredSizeWidget variant for AppBar.bottom usage.
//
// Identical aesthetics to EduTabBar but implements PreferredSizeWidget so it
// can be passed directly to AppBar(bottom: ...). Used in detail screens that
// have an AppBar with embedded tabs (e.g. DepartmentDetailScreen).
// ─────────────────────────────────────────────────────────────────────────────

class EduTabBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const EduTabBarBottom({
    super.key,
    required this.controller,
    required this.tabs,
    this.isScrollable = true,
    this.height,
    this.padding,
    this.onTap,
  });

  /// The [TabController] driving this tab bar.
  final TabController controller;

  /// Tab descriptors — one per tab.
  final List<EduTab> tabs;

  /// Whether the tab bar scrolls horizontally. Defaults to `false` (fill).
  final bool isScrollable;

  /// Override the strip height. Defaults to 38 for text tabs, 36 for icon-only.
  final double? height;

  /// Defaults to `EdgeInsets.fromLTRB(16, 4, 16, 10)` — slightly more bottom
  /// padding to breathe below the AppBar.
  final EdgeInsetsGeometry? padding;

  /// Optional callback when a tab is tapped.
  final ValueChanged<int>? onTap;

  double get _stripHeight {
    final bool iconOnly = tabs.every((t) => t.label == null && t.icon != null);
    return height ?? (iconOnly ? 36.0 : 38.0);
  }

  @override
  Size get preferredSize {
    final effectivePadding =
        (padding ?? const EdgeInsets.fromLTRB(16, 4, 16, 10)).resolve(
          TextDirection.ltr,
        );
    return Size.fromHeight(
      _stripHeight + effectivePadding.top + effectivePadding.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EduTabBar(
      controller: controller,
      tabs: tabs,
      isScrollable: isScrollable,
      height: height,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 4, 16, 10),
      onTap: onTap,
    );
  }
}
