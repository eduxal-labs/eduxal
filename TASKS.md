# TASKS.md

> Timetable wizard polish (Stage 0 day selector, custom time picker, slot rows,
> constraint stage search/items/display, constraint entry dialog) plus a new
> Remainder Slots stage and a final general-polish pass.
>
> All tasks follow §0d self-sufficient format. Executors MUST read AGENT.md and
> BUG.md in full before starting any task.

---

## Execution Plan

```
Round 1 (sequential): TW-05 → TW-06 → TW-07 → TW-08 → TW-09
```

All tasks modify `timetable_screen.dart`. TW-08 also modifies
`timetable_rules.dart` and `timetable_generator.dart`. Each task depends on
the previous — do not start a task until the prior one is committed.

---

### Task TW-05: Stage 0 — Cohesive Day Selector, Custom Time Picker, Slot Row Redesign

**Files to modify:**
- `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
- `eduxal/lib/models/timetable_rules.dart`

**Context files to read:**
- `eduxal/AGENT.md` (§21 UI rules)
- `eduxal/BUG.md`
- `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`

**Depends on:** TW-04 (completed)

---

#### 1 — Cohesive day-selector group

Replace the current `_DayChip` `Wrap` with a connected segmented-button strip
using Flutter's built-in `ToggleButtons` widget. The strip must feel like a
single cohesive control — shared outer border, no gaps between segments, pill
endpoints.

```dart
ToggleButtons(
  isSelected: [
    _activeDays.contains(1), // Mon
    _activeDays.contains(2), // Tue
    _activeDays.contains(3), // Wed
    _activeDays.contains(4), // Thu
    _activeDays.contains(5), // Fri
    _activeDays.contains(6), // Sat
    _activeDays.contains(7), // Sun
  ],
  onPressed: (i) => _toggleDay(i + 1),
  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),   // 8
  borderColor: AppTheme.borderColor(isDark, cs),
  selectedBorderColor: cs.primary.withValues(alpha: 0.55),
  selectedColor: cs.primary,
  fillColor: cs.primary.withValues(alpha: isDark ? 0.15 : 0.10),
  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
  children: const [
    Text('Mon'), Text('Tue'), Text('Wed'),
    Text('Thu'), Text('Fri'), Text('Sat'), Text('Sun'),
  ],
)
```

The same `_toggleDay` logic as before applies (cannot deselect the last day).
Delete the old `_DayChip` class — it is fully replaced.

The `_SectionLabel('School Days')` above the strip is retained.

---

#### 2 — Custom time-picker drum dialog

Replace `showTimePicker(context: context, initialTime: _dayStart)` with a call
to a new `showDrumTimePicker` function that presents a compact dialog with two
`ListWheelScrollView` drums (hour and minute) and an AM/PM toggle.

**Entry function:**

```dart
Future<TimeOfDay?> showDrumTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(8),        // reduced from 12
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _DrumTimePicker(initialTime: initialTime),
          ),
        ),
      ),
    ),
  );
}
```

**`_DrumTimePicker` widget (StatefulWidget):**

State fields:
```dart
late int _hour;    // 1–12
late int _minute;  // 0–59
late bool _isPm;
late FixedExtentScrollController _hourCtrl;
late FixedExtentScrollController _minuteCtrl;
```

`initState`: convert `initialTime` (24h) to 12h:
```dart
final h24 = initialTime.hour;
_isPm = h24 >= 12;
_hour = h24 % 12 == 0 ? 12 : h24 % 12;
_minute = initialTime.minute;
_hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
_minuteCtrl = FixedExtentScrollController(initialItem: _minute);
```

`_toTimeOfDay()`:
```dart
TimeOfDay _toTimeOfDay() {
  int h = _hour % 12 + (_isPm ? 12 : 0);
  return TimeOfDay(hour: h, minute: _minute);
}
```

Layout (Column, mainAxisSize: min):

```
Header row: "Start Time" (14pt w500) + close icon
Divider (0.5px)
Padding(vertical: 16, horizontal: 20)
  Row(mainAxisAlignment: center)
  ├── SizedBox(width: 72): hour drum
  ├── Text(":", 28pt w300, muted)
  ├── SizedBox(width: 72): minute drum
  ├── SizedBox(width: 12)
  └── Column: AM chip / PM chip
Divider (0.5px)
Footer: Cancel + Confirm
```

**Hour drum** (`ListWheelScrollView.useDelegate`):
- `controller: _hourCtrl`
- `itemExtent: 40`, `diameterRatio: 1.5`, `perspective: 0.003`
- `physics: FixedExtentScrollPhysics()`
- `onSelectedItemChanged: (i) => setState(() => _hour = i + 1)`
- `childDelegate: ListWheelChildLoopingListDelegate` of 12 items (1–12)
- Each item: `Center(child: Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: selected ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4))))`
- Selected item highlighted with a subtle horizontal `Container` behind the center item (use `Stack` with `Positioned`): `height: 40, color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)`

**Minute drum**: same as hour drum but 60 items (0–59), formatted as `'${m.toString().padLeft(2, '0')}'`

**AM/PM toggle** (Column of two compact chips):
```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    _AmPmChip(label: 'AM', selected: !_isPm, onTap: () => setState(() => _isPm = false), cs: cs, isDark: isDark),
    const SizedBox(height: 4),
    _AmPmChip(label: 'PM', selected: _isPm, onTap: () => setState(() => _isPm = true), cs: cs, isDark: isDark),
  ],
)
```

`_AmPmChip` — 32×28 compact chip, `AnimatedContainer(140ms)`:
- Selected: `cs.primary.withValues(alpha: 0.15)` bg, `cs.primary` border @ 1px, `cs.primary` text 11pt w500
- Unselected: `AppTheme.nestedBg` bg, `AppTheme.borderColor` border @ 0.5px, muted text
- `borderRadius: BorderRadius.circular(6)`

**Footer** (Padding fromLTRB 16, 10, 16, 14):
- Cancel: `_WizardTextButton`
- Confirm: `_WizardFilledButton('Confirm')` → `Navigator.of(ctx).pop(_toTimeOfDay())`

---

#### 3 — Remove default slots

In `timetable_rules.dart`, change `_defaultSlots()` to return `const []` and
update `TimetableRules.defaults()` to use `slots: []`. Also remove or mark the
old `_defaultSlots()` helper — it should no longer return any pre-filled slots.

```dart
TimetableRules.defaults() => TimetableRules(
  dayStartTime: const TimeOfDay(hour: 8, minute: 0),
  slots: [],                         // ← was: _defaultSlots()
  activeDays: const [1, 2, 3, 4, 5],
  // all other fields keep their defaults
);
```

---

#### 4 — Slot row redesign

Replace `_SlotRowTile` with a more alive, defined row that uses the same hover/press
pattern as `_FlatRow` in `members_page.dart`.

`_SlotRowTile` redesign (StatefulWidget with `SingleTickerProviderStateMixin`):

State: `bool _isHovered`, `bool _isPressed`, `AnimationController _pressCtrl`,
`Animation<double> _scaleAnim` (1.0 → 0.97, 100ms / 150ms reverse).
`MouseRegion` + `GestureDetector` as in `_FlatRow`.

Visual:
```
ScaleTransition
  AnimatedContainer(150ms)
    decoration: BoxDecoration(
      color: idle(nestedBg) / hover(primary@0.08) / press(primary@0.13),
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      border: Border.all(
        color: hover/press ? cs.primary.withValues(alpha: 0.3)
                           : AppTheme.borderColor(isDark, cs),
        width: 0.5,
      ),
    )
    child: IntrinsicHeight → Row(crossAxisAlignment: stretch)
      ├── Accent bar (3px, rounded left corners)
      │     color = isBreak ? amber@0.7 : brandGreen@0.7
      │     width = hover/press ? 4 : 3
      └── Expanded → Padding(fromLTRB: 12, 10, 12, 10)
            Row
            ├── Number badge (20×20, kChipRadius, surfaceContainerHighest bg)
            │     Text: "${index+1}", 10pt w500
            ├── SizedBox(width: 10)
            ├── Type chip (kChipRadius, 10pt w500)
            │     Lesson: brandGreen@0.12 bg, brandGreen text
            │     Break:  amber@0.12 bg, amber text  (Color(0xFFFFA726))
            ├── SizedBox(width: 10)
            ├── Expanded: Text(timeRange, 12.5pt w400, cs.onSurface)
            ├── Text("${duration} min", 11pt w400, muted @ 0.55)
            ├── SizedBox(width: 8)
            └── GestureDetector → Icon(Icons.close_rounded, 16px, muted@0.4)
                  (32×32 tap area via SizedBox + Center)
```

`onDelete` on the close icon calls the same `_removeSlot` from the parent state
via the `onDelete` callback parameter.

The slot list uses `ListView.separated` with `AppTheme.tableRowDivider` (0.5px)
between rows inside a `Container` with `borderRadius: kCardRadius`, `border: all
borderColor`, `color: modalBg` — a card-like container wrapping the list.

**Empty state** (shown when `_slots.isEmpty`):
```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
  decoration: BoxDecoration(
    color: AppTheme.nestedBg(isDark, cs),
    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
    border: Border.all(
      color: AppTheme.borderColor(isDark, cs),
      style: BorderStyle.solid,
    ),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.view_timeline_outlined, size: 28,
           color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
      const SizedBox(height: 10),
      Text('No slots yet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
           color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
      const SizedBox(height: 4),
      Text('Add lesson and break slots below.',
           style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400,
           color: cs.onSurfaceVariant.withValues(alpha: 0.35))),
    ],
  ),
)
```

---

**Update after completion:**
- [x] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Update `eduxal/lib/models/CONTEXT.md` (default slots change)
- [x] Mark `TW-05` as `[x]` in `eduxal/TASKS.md`
- [x] Run diagnostics — zero errors before committing
- [x] Commit: `ui: timetable wizard — day selector group, drum time picker, slot row redesign`

---

### Task TW-06: Stages 1+2 — Members-Style Search Bar and Entity Rows

**Files to modify:**
- `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`

**Context files to read:**
- `eduxal/AGENT.md`
- `eduxal/BUG.md`
- `eduxal/lib/ui/screens/school_dashboard/members/members_page.dart` — read the
  `_FlatMemberList`, `_FlatRow`/`_FlatRowState`, and `_DepartmentsTabState.build`
  sections to understand the exact search bar and row patterns to replicate.

**Depends on:** TW-05

---

#### 1 — Search bar: replace `_SearchField` with Members-page pattern

Delete `_SearchField`. In both `_Stage1TeacherConstraintsState.build()` and
`_Stage2SubjectConstraintsState.build()`, replace it with the identical `TextField`
pattern used in `_FlatMemberList` / `_DepartmentsTabState`.

The search bar is a **direct `TextField`** inside a `SizedBox(height: 38)` wrapped
in `Padding(fromLTRB: 0, 0, 0, 4)` (no extra custom `Container` around it):

```dart
SizedBox(
  height: 38,
  child: ValueListenableBuilder<TextEditingValue>(
    valueListenable: _searchCtrl,
    builder: (context, value, _) {
      return TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v.trim()),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Search teachers…',   // or 'Search subjects…'
          hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Icon(Icons.search_rounded, size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          suffixIcon: value.text.isNotEmpty
              ? GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.close_rounded, size: 16,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 38),
          filled: true,
          fillColor: isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            borderSide: BorderSide(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5), width: 1.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          isDense: true,
        ),
      );
    },
  ),
)
```

Make sure `_searchCtrl` is a `TextEditingController` field on the state, initialized
in `initState` and disposed in `dispose`.

---

#### 2 — Entity rows: replace `_ConstraintEntityRow` with `_FlatRow`-style rows

Delete `_ConstraintEntityRow`. Implement a new `_WizardEntityRow` StatefulWidget
that replicates `_FlatRow` / `_DepartmentRow` from `members_page.dart` exactly,
adapted for the timetable wizard context.

`_WizardEntityRow` parameters:
```dart
class _WizardEntityRow extends StatefulWidget {
  const _WizardEntityRow({
    required this.name,
    required this.subtitle,        // e.g. "2 constraints" or "No constraints"
    required this.isExpanded,
    required this.cs,
    required this.isDark,
    required this.onTap,           // toggles expanded state
    required this.expandedContent, // Widget shown below when expanded
  });
  final String name;
  final String subtitle;
  final bool isExpanded;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;
  final Widget expandedContent;
}
```

State: `bool _isHovered`, `bool _isPressed`, `AnimationController _pressCtrl`,
`Animation<double> _scaleAnim` (1.0 → 0.98, 100ms / 150ms).

Build method:
```
ScaleTransition
  Column
  ├── MouseRegion + GestureDetector
  │   AnimatedContainer(150ms, kCardRadius)
  │     idle:  cs.primary@0.04 (light) / cs.primary@0.06 (dark)
  │     hover: cs.primary@0.08 / cs.primary@0.12
  │     press: cs.primary@0.13 / cs.primary@0.18
  │   border: 0.5px, idle cs.outline@0.08, hover/press cs.primary@0.25
  │   ClipRRect(kCardRadius)
  │   IntrinsicHeight → Row(stretch)
  │   ├── Accent bar (3→4px, rounded left corners, cs.primary @0.7→1.0)
  │   └── Expanded → Padding(fromLTRB: 12, 10, 12, 10)
  │         Row
  │         ├── Leading icon container (28×28, kChipRadius)
  │         │     bg: hover? cs.primary@0.12 : surfaceContainerHighest
  │         │     Icon(person_outline_rounded OR book_outlined, 14px)
  │         │     color: hover? cs.primary : muted@0.55
  │         ├── SizedBox(10)
  │         ├── Expanded → Column(start, min)
  │         │     Text(name, 13pt w500, cs.onSurface)
  │         │     Text(subtitle, 11.5pt w400, muted@0.55)
  │         ├── Spacer
  │         └── AnimatedRotation(turns: expanded?0.25:0, 180ms)
  │               Icon(chevron_right_rounded, 18px, muted@0.5)
  └── AnimatedCrossFade(180ms, firstChild: SizedBox.shrink, secondChild: expandedContent)
        crossFadeState: isExpanded ? showSecond : showFirst
        sizeCurve: Curves.easeInOut
```

The expanded content (`expandedContent` widget) is a `Container` with:
- `color: AppTheme.nestedBg(isDark, cs)`
- `margin: EdgeInsets.only(left: 3)` — aligns with the accent bar offset
- `border: Border(left: BorderSide(color: cs.primary.withValues(alpha: 0.2), width: 3))` — continues the accent bar visually

Inside the expanded content, per-constraint rows (`_ConstraintChipRow`) are listed
with `AppTheme.tableRowDivider` between them, followed by the "Add Constraint" row.

Update `_Stage1TeacherConstraintsState.build()` and
`_Stage2SubjectConstraintsState.build()` to use `_WizardEntityRow`. Pass
`isExpanded: _expandedId == entity.id`, `onTap: () => setState(() => _expandedId = _expandedId == entity.id ? null : entity.id)`.

---

#### 3 — Add Constraint button

Replace the current plain "Add constraint" `InkWell` text row at the bottom of
the expanded section with a proper compact button:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
  child: OutlinedButton.icon(
    onPressed: () => _showConstraintEntry(entityId, entityName),
    icon: const Icon(Icons.add_rounded, size: 14),
    label: const Text('Add Constraint'),
    style: OutlinedButton.styleFrom(
      foregroundColor: cs.primary,
      side: BorderSide(color: cs.primary.withValues(alpha: 0.4), width: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ),
)
```

---

**Update after completion:**
- [x] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark `TW-06` as `[x]` in `eduxal/TASKS.md`
- [x] Run diagnostics — zero errors
- [x] Commit: `ui: timetable wizard — members-style search and entity rows`

---

### [x] Task TW-07: Constraint Entry Dialog and Constraint Display Redesign

**Files to modify:**
- `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`

**Context files to read:**
- `eduxal/AGENT.md`
- `eduxal/BUG.md`

**Depends on:** TW-06

---

#### 1 — Constraint entry dialog: Block/Require as tabs

Inside `_ConstraintEntryForm`, replace the two `Expanded AnimatedContainer` chips
for Block/Require with an `EduTabBar`-style tab selector (or a custom two-tab strip
matching the `EduTabBar` aesthetic from `edu_tab_bar.dart`).

Use a self-contained `_TypeTabStrip` widget:

```dart
class _TypeTabStrip extends StatelessWidget {
  const _TypeTabStrip({required this.isBlock, required this.onChanged,
                        required this.cs, required this.isDark});
  final bool isBlock;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      child: Row(
        children: [
          _TypeTab(
            label: 'Block',
            selected: isBlock,
            selectedColor: cs.error,
            cs: cs, isDark: isDark,
            onTap: () => onChanged(true),
          ),
          _TypeTab(
            label: 'Require',
            selected: !isBlock,
            selectedColor: cs.primary,
            cs: cs, isDark: isDark,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({required this.label, required this.selected,
                   required this.selectedColor, required this.cs,
                   required this.isDark, required this.onTap});
  final String label;
  final bool selected;
  final Color selectedColor;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
                    blurRadius: 5, offset: const Offset(0, 1.5))]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? selectedColor
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

#### 2 — Constraint entry dialog: day selector uses same ToggleButtons group

In `_ConstraintEntryForm`, replace the day chips `Wrap` with the same
`ToggleButtons` group introduced in TW-05 — exact same style, except only the
days present in `rules.activeDays` are shown (skip days not selected for the
school week).

```dart
// Only show active days
final activeDayLabels = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
final daysToShow = rules.activeDays.toList()..sort();

ToggleButtons(
  isSelected: daysToShow.map((d) => _selectedDays.contains(d)).toList(),
  onPressed: (i) {
    final d = daysToShow[i];
    setState(() {
      if (_selectedDays.contains(d)) { _selectedDays.remove(d); }
      else { _selectedDays.add(d); }
    });
  },
  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
  borderColor: AppTheme.borderColor(isDark, cs),
  selectedBorderColor: cs.primary.withValues(alpha: 0.55),
  selectedColor: cs.primary,
  fillColor: cs.primary.withValues(alpha: isDark ? 0.15 : 0.10),
  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
  children: daysToShow.map((d) => Text(activeDayLabels[d]!)).toList(),
)
```

---

#### 3 — Constraint entry dialog: slots as connected time strip

Replace the slot chip `Wrap` with a compact connected group showing only
start–end times (no "Slot N" label). Use the same `ToggleButtons` approach:

```dart
final lessonSlots = rules.buildLessonSlots();
// lessonSlots: List<({int index, int start, int end})>

ToggleButtons(
  isSelected: lessonSlots.map((s) => _selectedSlots.contains(s.index)).toList(),
  onPressed: (i) {
    final idx = lessonSlots[i].index;
    setState(() {
      if (_selectedSlots.contains(idx)) { _selectedSlots.remove(idx); }
      else { _selectedSlots.add(idx); }
    });
  },
  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
  borderColor: AppTheme.borderColor(isDark, cs),
  selectedBorderColor: cs.primary.withValues(alpha: 0.55),
  selectedColor: cs.primary,
  fillColor: cs.primary.withValues(alpha: isDark ? 0.15 : 0.10),
  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
  constraints: const BoxConstraints(minHeight: 36),
  children: lessonSlots.map((s) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('${_fmtTime(s.start)}–${_fmtTime(s.end)}'),
    )
  ).toList(),
)
```

If the slot list is long (> 6 lesson slots), wrap the `ToggleButtons` in a
`SingleChildScrollView(scrollDirection: Axis.horizontal)` so it doesn't overflow.

---

#### 4 — Collapsed constraint summary: git-style badges

When `_ConstraintEntityRow` is collapsed (not expanded), the subtitle currently
shows "N constraints". Replace this with a git-inspired diff summary:

```dart
String _collapsedSubtitle(List<TeacherConstraintEntry> constraints) {
  final blocks = constraints.where((c) => c.isBlock).length;
  final requires = constraints.where((c) => !c.isBlock).length;
  if (blocks == 0 && requires == 0) return 'No constraints';
  final parts = <String>[];
  if (blocks > 0) parts.add('+$blocks block${blocks == 1 ? '' : 's'}');
  if (requires > 0) parts.add('+$requires require${requires == 1 ? '' : 's'}');
  return parts.join('  ');
}
```

But instead of plain text, render this as two compact inline badges on a `Row`
inside a `Wrap`:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (blocks > 0) _DiffBadge(label: '+$blocks', color: cs.error),
    if (blocks > 0 && requires > 0) const SizedBox(width: 4),
    if (requires > 0) _DiffBadge(label: '+$requires', color: AppTheme.brandGreen),
  ],
)

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
```

Pass these badges as the `subtitle` trailing area of `_WizardEntityRow` — update
`_WizardEntityRow` to accept an optional `Widget? subtitleTrailing` that is shown
to the right of the subtitle text.

---

#### 5 — Expanded constraint rows: more alive `_ConstraintChipRow`

Redesign `_ConstraintChipRow` to feel more defined and less badge-like.
Each constraint row becomes a compact card (56px) inside the expanded section:

```
Container(
  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: isBlock
        ? cs.error.withValues(alpha: isDark ? 0.07 : 0.04)
        : cs.primary.withValues(alpha: isDark ? 0.07 : 0.04),
    borderRadius: BorderRadius.circular(6),
    border: Border(
      left: BorderSide(
        color: isBlock ? cs.error : cs.primary,
        width: 3,
      ),
    ),
  ),
  child: Row(
    children: [
      // Type label
      Text(
        isBlock ? 'Block' : 'Require',
        style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: isBlock ? cs.error : cs.primary,
        ),
      ),
      const SizedBox(width: 10),
      // Day chips inline
      Expanded(
        child: Wrap(spacing: 4, runSpacing: 4,
          children: [
            ...days.map((d) => _MiniChip(label: _dayShort(d), cs: cs)),
            const _MiniSep(),   // a subtle "·" separator
            ...slotLabels.map((l) => _MiniChip(label: l, cs: cs)),
          ],
        ),
      ),
      // Delete
      GestureDetector(
        onTap: onDelete,
        child: SizedBox(
          width: 32, height: 32,
          child: Center(
            child: Icon(Icons.close_rounded, size: 15,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          ),
        ),
      ),
    ],
  ),
)
```

`_MiniChip` — 20px-tall inline chip:
- `Container` with `kChipRadius` (4), `cs.surfaceContainerHighest` bg, `AppTheme.borderColor@0.4` border
- Text: 10.5pt w400, `cs.onSurface`
- Padding: `horizontal: 5, vertical: 2`

For slot labels: use `_fmtTime(start)–_fmtTime(end)` (no "Slot N").
`_dayShort`: use the 3-letter abbreviation (Mon, Tue, etc.).

---

#### 6 — Reduce dialog border radius

All `showDialog` calls in `timetable_screen.dart` that use
`AppTheme.kModalRadius` (12) should use **8** instead for a crisper, less
rounded feel:

- `showTimetableWizardDialog` outer container: `BorderRadius.circular(8)`
- `_showConstraintEntry` dialog container: `BorderRadius.circular(8)`
- `_DurationPickerDialog` (from TW-05): already set to 8
- `showDrumTimePicker` (from TW-05): already set to 8

Update the `ClipRRect` `borderRadius` to match wherever changed.

---

**Update after completion:**
- [x] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark `TW-07` as `[x]` in `eduxal/TASKS.md`
- [x] Run diagnostics — zero errors
- [x] Commit: `ui: timetable wizard — constraint dialog tabs, day groups, slot times, diff badges`

---

### [x] Task TW-08: New Remainder Slots Stage (Grade → Stream → Subject Priority)

**Files to modify:**
- `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
- `eduxal/lib/models/timetable_rules.dart`
- `eduxal/lib/services/timetable_generator.dart`

**Context files to read:**
- `eduxal/AGENT.md`
- `eduxal/BUG.md`
- `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- `eduxal/lib/models/CONTEXT.md`

**Depends on:** TW-07

---

#### Background

When a grade has S subjects and the school has L lesson slots per day over D
active days, the total weekly lessons = L × D. Dividing evenly:

```
base     = (L × D) ÷ S   (integer division)
remainder = (L × D) mod S
```

Each subject gets `base` lessons per week. The `remainder` subjects that get
one extra lesson are determined by the user's chosen priority order.
If the user has not chosen an order for a grade/stream, the generator falls back
to the subjects' natural catalog order (by subject ID ascending).

This eliminates the old `defaultLessonsPerWeek` / `lessonsPerWeekBySubject`
concept — weekly lessons are now fully derived from the slot sequence.

---

#### 1 — Model changes (`timetable_rules.dart`)

Add one new field to `TimetableRules`:

```dart
/// Per-stream remainder subject priority.
///
/// Key format: "{grade}_{stream}" (e.g. "44_1") or "{grade}_null" for
/// grades with a single un-streamed class.
///
/// Value: ordered list of subject IDs. The first `remainder` subjects in
/// this list receive one extra lesson per week beyond the base allocation.
/// If a key is absent, the generator uses ascending subject-ID order.
final Map<String, List<int>> remainderPriority;
```

Update `TimetableRules`:
- Add `this.remainderPriority = const {}` to the constructor (default: empty map).
- Add to `copyWith`: `remainderPriority: remainderPriority ?? this.remainderPriority`
- Add to `toJson`: `'remainder_priority': remainderPriority.map((k, v) => MapEntry(k, v))`
- Add to `fromJson` (v2 path):
  ```dart
  remainderPriority: () {
    final raw = json['remainder_priority'] as Map<String, dynamic>?;
    if (raw == null) return <String, List<int>>{};
    return raw.map((k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()));
  }(),
  ```
- Remove `defaultLessonsPerWeek` and `lessonsPerWeekBySubject` from the model,
  constructor, `copyWith`, `toJson`, `fromJson`, and `lessonsPerWeekForSubject()`.
  These are no longer needed — lesson counts are computed by the generator.

---

#### 2 — Generator changes (`timetable_generator.dart`)

The generator currently calls `rules.lessonsPerWeekForSubject(subjectId)` to
determine how many times per week each subject is scheduled.

Replace this with a computed value:

```dart
/// Compute lessons-per-week for every (grade, stream, subjectId) triple.
///
/// 1. Count lesson slots per day from rules.slots.
/// 2. Multiply by active-day count.
/// 3. For each (grade, stream) group of assignments, divide total weekly
///    lessons by subject count (base), compute remainder, and apply the
///    priority order from rules.remainderPriority.
Map<(int grade, int? stream, int subjectId), int> _computeLessonsPerWeek(
  List<SolverAssignment> assignments,
  TimetableRules rules,
) {
  final lessonSlotsPerDay =
      rules.slots.where((s) => s.type == SlotType.lesson).length;
  final totalPerWeek = lessonSlotsPerDay * rules.activeDays.length;

  // Group assignments by (grade, stream).
  final groups = <(int, int?), List<SolverAssignment>>{};
  for (final a in assignments) {
    final key = (a.grade, a.stream);
    groups.putIfAbsent(key, () => []).add(a);
  }

  final result = <(int, int?, int), int>{};
  for (final entry in groups.entries) {
    final (grade, stream) = entry.key;
    final subjects = entry.value.map((a) => a.subjectId).toSet().toList();
    if (subjects.isEmpty) continue;

    final base = totalPerWeek ~/ subjects.length;
    final remainder = totalPerWeek % subjects.length;

    // Determine priority order.
    final priorityKey = '${grade}_${stream ?? 'null'}';
    final priorityOrder = rules.remainderPriority[priorityKey] ??
        (List<int>.from(subjects)..sort());

    // Assign base + 1 to first `remainder` subjects in priority order,
    // base to the rest.
    int extraGiven = 0;
    for (final sid in subjects) {
      int lessons = base;
      if (extraGiven < remainder && priorityOrder.contains(sid)) {
        final priorityIdx = priorityOrder.indexOf(sid);
        // Give extra to the `remainder` lowest-index subjects in priority order.
        final priorityRank = priorityOrder
            .where((id) => subjects.contains(id))
            .toList()
            .indexOf(sid);
        if (priorityRank < remainder) {
          lessons = base + 1;
          extraGiven++;
        }
      }
      result[(grade, stream, sid)] = lessons.clamp(1, lessonSlotsPerDay * rules.activeDays.length);
    }
  }
  return result;
}
```

Call `_computeLessonsPerWeek` once in `generate()` before building variables,
and use `lessonsMap[(v.grade, v.stream, v.subjectId)] ?? 1` instead of
`rules.lessonsPerWeekForSubject(...)` when expanding assignments into variables.

Also remove `_isSlotAllowedForTeacher` / `_isSlotAllowedForSubject` references
to `rules.maxLessonsPerDayTeacher` and `rules.maxLessonsPerDayClass` if those
fields no longer exist on the model. If these hard caps are still needed for
solver correctness, derive them from the slot count:
```dart
final maxPerDayTeacher = rules.slots.where((s) => s.type == SlotType.lesson).length;
final maxPerDayClass   = rules.slots.where((s) => s.type == SlotType.lesson).length;
```

Remove `_softScore`'s reference to the old `lessonDurationMinutes` /
`breakDurationMinutes` fields if they were removed from the model in TW-03.

---

#### 3 — New stage in `timetable_screen.dart`

Insert a new **Stage 3 — Remainder Slots** between Subject Constraints (was
Stage 2) and Review & Generate (was Stage 3, now becomes Stage 4).

Update stage numbering throughout `_TimetableWizardState`:
- `_stage` range: 0–4 (was 0–3)
- `_buildStage` switch: add `case 3` for `_Stage3RemainderSlots`; rename old
  `case 3 => _Stage3Generate` to `case 4 => _Stage4Generate`
- `_goNext`: `_computeConflicts()` trigger moves to `_stage == 3` (before stage 4)
- Step dots: `totalSteps: 5`
- Stage labels: add `'Remainder Slots'` as label for stage 3
- `isLastStage` check: `_stage == 4`

---

**`_Stage3RemainderSlots` widget:**

```dart
class _Stage3RemainderSlots extends StatefulWidget {
  const _Stage3RemainderSlots({
    required this.rules,
    required this.assignments,   // List<SolverAssignment> loaded in _TimetableWizardState
    required this.config,        // SchoolConfig — for grade/stream labels
    required this.subjects,      // List<_WizardSubject>
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });
  // ...
}
```

State: `Map<String, bool> _expandedGrades`, `Map<String, bool> _expandedStreams`

(Keys are grade IDs as strings; stream keys are "${grade}_${stream ?? 'null'}".)

---

**Layout** (`SingleChildScrollView` → `Column(padding: 20)`):

```
_SectionLabel('Remainder Slots')
SizedBox(8)
Text(
  'Subjects with remainder lessons appear first. Drag to reprioritise.',
  style: 12pt w400 muted,
)
SizedBox(16)
[List of _RemainderGradeSection per grade that has assignments]
```

---

**`_RemainderGradeSection`** — collapsible grade row:

Header row (same `_WizardEntityRow` pattern — accent bar, animated bg, chevron):
- Name: grade label (e.g. "Form 4")
- Subtitle: "${stream count} streams" or "1 stream"
- Expanded content: list of `_RemainderStreamSection`

---

**`_RemainderStreamSection`** — collapsible stream row (nested inside grade):

Header row:
- Name: stream name (e.g. "Blue") or "All" if stream is null
- Subtitle: computed remainder info, e.g. "8 × 5 = 40 lessons · 12 subjects · 3 base + 4 extra"
- Expanded content: reorderable subject list

---

**Reorderable subject list** inside a stream:

Show all subjects assigned to this (grade, stream) in their current priority
order. Each item shows the subject name and a drag handle. The first
`remainder` items are visually tagged with a small "+1" green badge to indicate
they receive the extra lesson.

Use Flutter's `ReorderableListView.builder`:

```dart
ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  onReorder: (oldIndex, newIndex) {
    // update remainderPriority[streamKey] and call onChanged
  },
  itemCount: priorityOrder.length,
  itemBuilder: (ctx, i) {
    final sid = priorityOrder[i];
    final name = _subjectName(sid);
    final isExtra = i < remainder;
    return _RemainderSubjectTile(
      key: ValueKey(sid),
      name: name,
      isExtra: isExtra,
      cs: cs,
      isDark: isDark,
    );
  },
)
```

`_RemainderSubjectTile` — 48px row:
```
Row
├── Icon(drag_handle_rounded, 18px, muted@0.35)
├── SizedBox(10)
├── Expanded: Text(name, 13pt w400)
└── if isExtra: _DiffBadge(label: '+1', color: AppTheme.brandGreen)
```

The drag handle uses `ReorderableDragStartListener` wrapping the icon so only
the handle initiates the drag.

Container for the stream's subject list:
```dart
Container(
  margin: const EdgeInsets.only(left: 3),
  decoration: BoxDecoration(
    color: AppTheme.nestedBg(isDark, cs),
    border: Border(
      left: BorderSide(color: cs.primary.withValues(alpha: 0.2), width: 3),
    ),
  ),
  child: ReorderableListView.builder(...),
)
```

---

**Priority persistence:**

When the user reorders subjects, update `_rules.remainderPriority`:
```dart
void _onReorder(String streamKey, List<int> newOrder) {
  final updated = Map<String, List<int>>.from(_rules.remainderPriority);
  updated[streamKey] = newOrder;
  widget.onChanged(widget.rules.copyWith(remainderPriority: updated));
}
```

The stream key format: `"${grade}_${stream ?? 'null'}"` — must match exactly
what the generator uses in `_computeLessonsPerWeek`.

---

**Remainder math helper** (file-level function):

```dart
({int base, int remainder, int totalPerWeek}) _computeRemainder({
  required TimetableRules rules,
  required int subjectCount,
}) {
  final slotsPerDay = rules.slots.where((s) => s.type == SlotType.lesson).length;
  final total = slotsPerDay * rules.activeDays.length;
  if (subjectCount == 0) return (base: 0, remainder: 0, totalPerWeek: total);
  return (
    base: total ~/ subjectCount,
    remainder: total % subjectCount,
    totalPerWeek: total,
  );
}
```

---

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — add Stage 3 Remainder Slots description, update stage count to 5
- [ ] Update `eduxal/lib/models/CONTEXT.md` — document `remainderPriority`, removal of `defaultLessonsPerWeek`/`lessonsPerWeekBySubject`
- [ ] Mark `TW-08` as `[x]` in `eduxal/TASKS.md`
- [ ] Run diagnostics — zero errors
- [ ] Commit: `feat: timetable wizard — remainder slots stage and per-stream subject priority`

---

### [x] Task TW-09: General Polish — Border Radius, Responsiveness, Final Checks

**Files to modify:**
- `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`

**Context files to read:**
- `eduxal/AGENT.md` (§21)
- `eduxal/BUG.md`

**Depends on:** TW-08

---

#### 1 — Border radius audit

Scan the entire wizard section of `timetable_screen.dart` for any remaining
`BorderRadius.circular(12)` or `AppTheme.kModalRadius` usages. Replace with
`BorderRadius.circular(8)` for ALL dialog containers, constraint entry dialogs,
duration picker dialogs, and drum time picker dialog. The only places that may
retain radius 12 are the mobile bottom sheet (top corners only) and any
`showEduSheet` calls outside the wizard.

`kModalRadius` (12) is intentional for the main timetable wizard dialog wrapper
on mobile (the bottom sheet top corners). On desktop the Dialog container
should be 8. Adjust `showTimetableWizardDialog` if not already correct:

```dart
// desktop: radius 8
borderRadius: BorderRadius.circular(8),
// mobile top corners: radius 12 (standard sheet radius)
borderRadius: const BorderRadius.only(
  topLeft: Radius.circular(AppTheme.kModalRadius),
  topRight: Radius.circular(AppTheme.kModalRadius),
),
```

---

#### 2 — Responsive layout checks

**Dialog height on mobile:** The wizard dialog on mobile uses
`maxHeight: MediaQuery.sizeOf(ctx).height * 0.88`. Verify each stage's content
fits and scrolls correctly within this constraint. If any stage's `Column` inside
`SingleChildScrollView` has a non-scrollable inner `ListView` (shrinkWrap: false),
ensure it is `shrinkWrap: true, physics: NeverScrollableScrollPhysics()`.

**Stage 3 Remainder Slots on mobile:** The `ReorderableListView` inside a
`SingleChildScrollView` is tricky. Ensure the outer scroll is the primary
scroll and the `ReorderableListView` is `shrinkWrap: true`. Test that drag
handles work — on mobile, `ReorderableDragStartListener` must wrap the drag
handle icon for drag-only-from-handle behavior.

**ToggleButtons overflow:** Wherever `ToggleButtons` is used (day selectors in
Stage 0 and constraint entry, slot time strips in constraint entry), wrap in
`SingleChildScrollView(scrollDirection: Axis.horizontal)` if the number of
children could overflow a narrow screen (< 360px). Specifically:
- 7-day strip: likely overflows on very small phones → wrap in horizontal scroll
- Slot time strip: variable length → always wrap in horizontal scroll

**Desktop dialog:** Verify that on screens ≥ 600px the dialog renders at
`maxWidth: 520` and does not stretch full-screen. The `Flexible` body section
should scroll internally rather than expanding the dialog height beyond
`MediaQuery.sizeOf(context).height - 80px`.

Add a `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - 80))` around the wizard's `Column` content to cap its height on desktop.

---

#### 3 — Final integration checklist

Before committing, the executor must verify every item:

| Item | Expected |
|---|---|
| Stage 0: `ToggleButtons` day selector renders and toggles correctly | ✅ |
| Stage 0: `showDrumTimePicker` opens and returns a `TimeOfDay` | ✅ |
| Stage 0: Empty slot state shows when `_slots.isEmpty` | ✅ |
| Stage 0: No default slots on first open | ✅ |
| Stages 1+2: Search bar matches Members page style (no nested container) | ✅ |
| Stages 1+2: Entity rows have accent bar, animated bg, scale on press | ✅ |
| Stages 1+2: `_DiffBadge` shows red blocks / green requires when collapsed | ✅ |
| Stages 1+2: Expanded constraint rows use left-border card style | ✅ |
| Constraint entry: Block/Require type uses tab strip | ✅ |
| Constraint entry: Days use `ToggleButtons` group | ✅ |
| Constraint entry: Slots show HH:MM–HH:MM only | ✅ |
| Stage 3: Grades collapse/expand correctly | ✅ |
| Stage 3: Streams collapse/expand correctly | ✅ |
| Stage 3: Subject drag-reorder updates `remainderPriority` | ✅ |
| Stage 3: "+1" badge shows on first `remainder` subjects | ✅ |
| Stage 4 Generate: still computes conflicts before showing | ✅ |
| Generator: uses `_computeLessonsPerWeek` instead of `defaultLessonsPerWeek` | ✅ |
| `TimetableRules.defaults()` has `slots: []` | ✅ |
| Dialog border radius: 8 on desktop, 12 top-corners on mobile sheet | ✅ |
| All stages scroll within dialog height on mobile | ✅ |
| `ToggleButtons` strips wrapped in horizontal scroll where needed | ✅ |
| `flutter analyze` → zero errors, zero warnings | ✅ |

---

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — final state of wizard
- [ ] Mark `TW-09` as `[x]` in `eduxal/TASKS.md`
- [ ] Commit: `ui: timetable wizard — border radius, responsive fixes, final polish`
