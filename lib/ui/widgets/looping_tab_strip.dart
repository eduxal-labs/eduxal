import 'dart:math' show min;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoopingTabStrip
//
// An infinite-looping, snapping, labelled tab strip for mobile navigation.
// Renders icon + label tabs that tile seamlessly edge-to-edge with no margins.
// Scrolling in either direction wraps around like a ring.
//
// Does NOT use Flutter's TabBar or TabController internally — it is a pure
// custom scroll widget. The parent wires selectedIndex and onTabSelected to
// keep the TabController (which drives TabBarView) in sync.
// ─────────────────────────────────────────────────────────────────────────────

class LoopingTabItem {
  const LoopingTabItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class LoopingTabStrip extends StatefulWidget {
  const LoopingTabStrip({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height = 56.0,
  });

  final List<LoopingTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double height;

  @override
  State<LoopingTabStrip> createState() => _LoopingTabStripState();
}

class _LoopingTabStripState extends State<LoopingTabStrip> {
  late ScrollController _scrollCtrl;
  double _tabWidth = 0; // computed from layout; 0 until first build
  late int _virtualCount; // items.length * _kMultiplier * 2
  late int _initialVirtualIndex; // items.length * _kMultiplier
  bool _isSnapping = false; // guard against re-entrant snaps

  static const int _kMultiplier = 500;
  static const int _kVisibleCount = 4;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initVirtualCounts(widget.items.length);
    _scrollCtrl = ScrollController();
    // Schedule the initial jump after the first frame so the controller is
    // attached to the ListView before we try to set an offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollCtrl.hasClients && _tabWidth > 0) {
        _scrollCtrl.jumpTo(_initialOffset + widget.selectedIndex * _tabWidth);
      }
    });
  }

  void _initVirtualCounts(int tabCount) {
    _virtualCount = tabCount * _kMultiplier * 2;
    _initialVirtualIndex = tabCount * _kMultiplier;
  }

  @override
  void didUpdateWidget(LoopingTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the tab list itself changed (role switch), reinitialise virtual counts
    // and jump to the new initial position.
    if (oldWidget.items.length != widget.items.length) {
      _initVirtualCounts(widget.items.length);
      // Jump (not animate) to avoid traversing the old virtual list.
      if (_scrollCtrl.hasClients && _tabWidth > 0) {
        _scrollCtrl.jumpTo(_initialOffset + widget.selectedIndex * _tabWidth);
      }
      return;
    }

    // If only the selected index changed (programmatic tab selection from
    // parent), animate to the nearest virtual copy.
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateToTab(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  double get _initialOffset => _initialVirtualIndex * _tabWidth;

  /// Returns the virtual index of [targetTab] that is closest to the current
  /// scroll position. This avoids a jarring long-distance jump when selecting
  /// a tab programmatically while the user is mid-scroll.
  int _nearestVirtualIndex(int targetTab) {
    if (_tabWidth == 0) return _initialVirtualIndex + targetTab;
    final currentVirtual = (_scrollCtrl.offset / _tabWidth).round().clamp(
      0,
      _virtualCount - 1,
    );
    final base =
        (currentVirtual ~/ widget.items.length) * widget.items.length +
        targetTab;
    final candidates = [
      base - widget.items.length,
      base,
      base + widget.items.length,
    ];
    return candidates.reduce(
      (a, b) => (a - currentVirtual).abs() < (b - currentVirtual).abs() ? a : b,
    );
  }

  void _animateToTab(int tabIndex) {
    if (!_scrollCtrl.hasClients || _tabWidth == 0) return;
    final targetVirtual = _nearestVirtualIndex(tabIndex);
    final targetOffset = targetVirtual * _tabWidth;
    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Called when the ListView scroll settles. Snaps to the nearest tab and
  /// notifies the parent.
  void _snapToNearest() {
    if (_isSnapping || !_scrollCtrl.hasClients || _tabWidth == 0) return;

    final raw = _scrollCtrl.offset / _tabWidth;
    final nearest = raw.round().clamp(0, _virtualCount - 1);
    final tabIndex = nearest % widget.items.length;
    final targetOffset = nearest * _tabWidth;

    if ((targetOffset - _scrollCtrl.offset).abs() < 0.5) {
      // Already at a snapped position — just notify the parent if needed.
      if (tabIndex != widget.selectedIndex) {
        widget.onTabSelected(tabIndex);
      }
      return;
    }

    _isSnapping = true;
    _scrollCtrl
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .then((_) {
          _isSnapping = false;
          widget.onTabSelected(tabIndex);
        });
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Compute tab width here (safe — build is always on the main thread and
    // MediaQuery is available). Store as instance variable so helpers can
    // access it outside build.
    _tabWidth = screenWidth / min(widget.items.length, _kVisibleCount);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.5),
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _snapToNearest();
          return false;
        },
        child: ListView.builder(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _virtualCount,
          itemExtent: _tabWidth,
          itemBuilder: (context, virtualIndex) {
            final tabIndex = virtualIndex % widget.items.length;
            final item = widget.items[tabIndex];
            final isSelected = tabIndex == widget.selectedIndex;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_tabWidth == 0) return;
                final targetVirtual = _nearestVirtualIndex(tabIndex);
                final targetOffset = targetVirtual * _tabWidth;
                _scrollCtrl
                    .animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    )
                    .then((_) => widget.onTabSelected(tabIndex));
              },
              child: SizedBox(
                width: _tabWidth,
                height: widget.height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.16 : 0.07,
                                ),
                                blurRadius: 5,
                                offset: const Offset(0, 1.5),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.06 : 0.02,
                                ),
                                blurRadius: 1,
                                offset: const Offset(0, 0.5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: isSelected
                              ? cs.onSurface
                              : cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            letterSpacing: 0.2,
                            color: isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
