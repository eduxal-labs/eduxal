# TASKS.md

---

### [x] Task 19: Replace mobile top-level nav strip with an infinite-looping labelled tab strip
**Files to create/modify:**
- `lib/ui/screens/school_dashboard/school_dashboard_screen.dart` — replace `_PillTabStrip` usage with `_LoopingTabStrip`, remove the `Padding` wrapper around it, wire `_selectedIndex` to the new strip
- `lib/ui/widgets/looping_tab_strip.dart` — **create new file** — the self-contained `_LoopingTabStrip` widget (also exported as `LoopingTabStrip` for future reuse)

**Context files to read (if needed):** none — all necessary context is inlined below
**Depends on:** none
**Parallel group:** P1

---

### Background

The current `_PillTabStrip` on mobile is icon-only, fits all tabs in equal widths inside a rounded pill container, and is wrapped in `Padding(EdgeInsets.fromLTRB(16, 10, 16, 8))`. The owner role has 8 nav items — far too many to read as icon-only tabs on a 360–430 px screen.

The new strip must:
1. Show **text labels** (with the icon above, like a standard labelled tab)
2. Be **edge-to-edge** — zero horizontal margin/padding, flush with both sides of the screen
3. **Scroll infinitely in both directions** — like a ring with no beginning or end. Swiping right advances forward through tabs and wraps from the last back to the first. Swiping left goes backward and wraps from the first back to the last.
4. **Snap** to the nearest tab on scroll settle — no mid-tab resting positions
5. **Visually indicate** the selected tab with the same elevated indicator style used elsewhere in the app (`cs.surface` background, subtle box shadow, `BorderRadius.circular(8)`)
6. Tapping any visible tab selects it (and snaps the scroll to it)

The `TabController` that drives the `TabBarView` (the actual content pages) remains unchanged — the looping strip is a purely visual layer that calls `_selectIndex(i)` when the user picks a tab.

---

### How the infinite loop works

Flutter's `TabBar` does not support looping. We build a custom strip using a `ScrollController` + `ListView.builder` with a virtually infinite item count.

**Key idea:** seed the scroll position at a large middle offset so the user can scroll in either direction for a very long time before hitting a boundary. In practice, use `_kMultiplier = 500` virtual copies of the tab list on each side:

```
virtual item count  = tabCount * _kMultiplier * 2
initial index       = tabCount * _kMultiplier          (the "middle" copy)
initial offset      = initialIndex * tabWidth
```

Each virtual item renders `items[virtualIndex % tabCount]`. This creates the illusion of an infinite ring.

**Tab width:** Each tab is `screenWidth / min(tabCount, _kVisibleCount)` wide where `_kVisibleCount = 4` (so up to 4 tabs are visible at once; if there are fewer than 4 tabs they fill the full width equally). This means tabs always tile seamlessly — no gap at the edges.

**Snap on scroll end:** Use a `NotificationListener<ScrollEndNotification>` (or `ScrollController` listener checking `!position.isScrollingNotifier.value`). On settle, compute the nearest tab index from the current offset and animate to it with `_scrollCtrl.animateTo(nearestOffset, duration: 200ms, curve: Curves.easeOut)`.

**Keeping `_selectedIndex` in sync:** After snapping, call the parent's `onTabSelected(virtualIndex % tabCount)` callback.

**Programmatic tab selection (when `selectedIndex` changes from outside — e.g. role switch):** When the parent's `selectedIndex` prop changes, animate the scroll to the nearest virtual copy of that tab relative to the current scroll position. This avoids a jarring jump across the full multiplier distance — always pick the closest copy:

```dart
int _nearestVirtualIndex(int targetTab) {
  final currentVirtual = (_scrollCtrl.offset / _tabWidth).round();
  final base = (currentVirtual ~/ tabCount) * tabCount + targetTab;
  // Check base-tabCount, base, base+tabCount — pick closest to currentVirtual
  final candidates = [base - tabCount, base, base + tabCount];
  return candidates.reduce((a, b) =>
    (a - currentVirtual).abs() < (b - currentVirtual).abs() ? a : b);
}
```

---

### Visual design

The strip container:
- `height: 56` — taller than the old 36 px pill to accommodate icon + label stacked vertically
- Background: `cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.5)` — same tint as the old pill
- No border radius (edge-to-edge, flush with screen)
- No horizontal padding on the container itself
- A subtle top + bottom border: `Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5), bottom: BorderSide(...))`

Each tab cell:
- Width: `screenWidth / min(tabCount, 4)` — computed once, stored in state
- Content: icon (size 18) stacked above label (font size 10.5, `w400`, `letterSpacing: 0.2`) — use a `Column(mainAxisAlignment: center)` with `SizedBox(height: 3)` gap
- Selected tab: wrapped in a `Container` with `BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8), boxShadow: [...])` — inset `4 px` from each side of the cell (so `margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4)`)
- Unselected tab: plain, `cs.onSurfaceVariant.withValues(alpha: 0.65)` for both icon and label color
- Selected tab: `cs.onSurface` color for both icon and label
- Tap: `GestureDetector(onTap: ...)` — no ink splash (consistent with the rest of the app's `NoSplash` policy)
- The indicator background `Container` should use an `AnimatedContainer` for the color so selection feels instant but smooth

The selected-tab indicator does NOT slide/translate — it appears/disappears per cell as the scroll settles and `_selectedIndex` updates. This keeps the implementation simple and avoids complex interpolation on a looping scroll.

---

### Specification: `lib/ui/widgets/looping_tab_strip.dart`

Create a new file with:

```dart
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
```

**Widget signature:**
```dart
class LoopingTabStrip extends StatefulWidget {
  const LoopingTabStrip({
    super.key,
    required this.items,       // List<LoopingTabItem>
    required this.selectedIndex,
    required this.onTabSelected,
    this.height = 56.0,
  });

  final List<LoopingTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double height;
}

class LoopingTabItem {
  const LoopingTabItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
```

**State class `_LoopingTabStripState`:**

Fields:
```dart
late ScrollController _scrollCtrl;
late double _tabWidth;         // screenWidth / min(items.length, _kVisibleCount)
late int _virtualCount;        // items.length * _kMultiplier * 2
late int _initialVirtualIndex; // items.length * _kMultiplier
bool _isSnapping = false;      // guard to prevent re-entrant snaps

static const int _kMultiplier = 500;
static const int _kVisibleCount = 4;
```

`initState`:
- Compute `_virtualCount` and `_initialVirtualIndex`
- `_tabWidth` is not known yet (needs layout width) — initialise to `0`, compute in `LayoutBuilder` or `didChangeDependencies`
- `_scrollCtrl = ScrollController()` — offset is set after first frame via `WidgetsBinding.instance.addPostFrameCallback`

`didChangeDependencies` (or inside `LayoutBuilder`):
- Compute `_tabWidth = MediaQuery.sizeOf(context).width / min(items.length, _kVisibleCount)`
- If already initialised and width changed, recompute and jump to current selected tab

`didUpdateWidget`:
- If `oldWidget.selectedIndex != widget.selectedIndex`, animate to the nearest virtual copy of `widget.selectedIndex`

`dispose`:
- `_scrollCtrl.dispose()`

`_initialOffset`:
```dart
double get _initialOffset => _initialVirtualIndex * _tabWidth;
```

`_virtualIndexForTab(int tab)` → `_initialVirtualIndex + (tab - items.length ~/ 2)` — but use `_nearestVirtualIndex` instead for smooth programmatic selection.

`_nearestVirtualIndex(int targetTab)`:
```dart
int _nearestVirtualIndex(int targetTab) {
  if (_tabWidth == 0) return _initialVirtualIndex + targetTab;
  final currentVirtual = (_scrollCtrl.offset / _tabWidth).round()
      .clamp(0, _virtualCount - 1);
  final base = (currentVirtual ~/ items.length) * items.length + targetTab;
  final candidates = [base - items.length, base, base + items.length];
  return candidates.reduce((a, b) =>
      (a - currentVirtual).abs() < (b - currentVirtual).abs() ? a : b);
}
```

`_snapToNearest()` — called on scroll end:
```dart
void _snapToNearest() {
  if (_isSnapping || !_scrollCtrl.hasClients || _tabWidth == 0) return;
  final raw = _scrollCtrl.offset / _tabWidth;
  final nearest = raw.round().clamp(0, _virtualCount - 1);
  final tabIndex = nearest % items.length;
  final targetOffset = nearest * _tabWidth;

  if ((targetOffset - _scrollCtrl.offset).abs() < 0.5) {
    // Already snapped — just notify parent if needed
    if (tabIndex != widget.selectedIndex) widget.onTabSelected(tabIndex);
    return;
  }

  _isSnapping = true;
  _scrollCtrl
      .animateTo(targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut)
      .then((_) {
    _isSnapping = false;
    widget.onTabSelected(tabIndex);
  });
}
```

`build`:
```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  final screenWidth = MediaQuery.sizeOf(context).width;
  _tabWidth = screenWidth / min(items.length, _kVisibleCount);

  return Container(
    height: widget.height,
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.5),
      border: Border(
        top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
        bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
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
          final tabIndex = virtualIndex % items.length;
          final item = items[tabIndex];
          final isSelected = tabIndex == widget.selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final targetVirtual = _nearestVirtualIndex(tabIndex);
              final targetOffset = targetVirtual * _tabWidth;
              _scrollCtrl.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ).then((_) => widget.onTabSelected(tabIndex));
            },
            child: SizedBox(
              width: _tabWidth,
              height: widget.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
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
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
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
```

---

### Specification: changes to `school_dashboard_screen.dart`

**1. Add import:**
```dart
import '../../widgets/looping_tab_strip.dart';
```

**2. Remove the `Padding` wrapper around `_PillTabStrip`** and replace the entire block:
```dart
// REMOVE:
if (isMobile)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: _PillTabStrip(
      items: _currentItems,
      controller: _tabController,
      isDark: isDark,
      cs: cs,
    ),
  ),

// REPLACE WITH:
if (isMobile)
  LoopingTabStrip(
    items: _currentItems
        .map((e) => LoopingTabItem(label: e.label, icon: e.icon))
        .toList(),
    selectedIndex: _selectedIndex,
    onTabSelected: _selectIndex,
  ),
```

**3. `_PillTabStrip` class:** Leave it in the file (do not delete) — it may still be referenced or useful. Just stop using it in the mobile layout.

**4. No changes to `_tabController`, `_selectIndex`, `_currentItems`, or `TabBarView`** — those are untouched. The `LoopingTabStrip` calls `_selectIndex` which calls `setState(() => _selectedIndex = i)` and also updates `_tabController.index`. The `TabBarView` continues to respond correctly.

---

### Important implementation notes for the executor

1. **Post-frame callback for initial scroll offset:** In `initState`, do NOT set the scroll offset directly. Use `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _scrollCtrl.hasClients) { _scrollCtrl.jumpTo(_initialOffset + widget.selectedIndex * _tabWidth); } })` to ensure the `ScrollController` is attached before jumping.

2. **`_tabWidth` must be computed from layout, not `initState`:** `MediaQuery.sizeOf(context)` is not available in `initState`. Compute it inside `build` (which is fine — it's just a division). Store it as an instance variable so `_snapToNearest` and `_nearestVirtualIndex` can read it outside of `build`.

3. **Scroll physics:** Use `BouncingScrollPhysics()` — it gives a natural feel on both iOS and Android, and does not auto-snap itself (we handle snapping manually via `ScrollEndNotification`).

4. **`itemExtent` on `ListView.builder`:** Setting `itemExtent: _tabWidth` is critical for performance — it allows Flutter to skip layout for off-screen items. Without it, a virtual list of 8000+ items would be slow.

5. **Prevent `_tabWidth == 0` crashes:** Guard every division and offset computation with `if (_tabWidth == 0) return;` or an early return. The first frame may fire before `_tabWidth` is set.

6. **`didUpdateWidget` for programmatic selection:** When the role switches, `_DashboardShellState` rebuilds `LoopingTabStrip` with a new `items` list AND a new `selectedIndex` of `0`. Handle this in `didUpdateWidget`: if `items.length` changed, reinitialise `_virtualCount`, `_initialVirtualIndex`, and jump (not animate) to the new initial offset. Then animate to `selectedIndex` normally.

7. **`dart:math` import:** Use `import 'dart:math' show min;` at the top of `looping_tab_strip.dart` for the `min()` call.

---

### Update after completion
- [x] Mark this task `[x]` in `TASKS.md`
- [x] Commit: `git add -A && git commit -m "ui: infinite looping labelled tab strip for mobile nav"`
