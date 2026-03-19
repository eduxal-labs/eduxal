# TASKS.md

> Timetable wizard overhaul — convert full-page wizard to a compact dialog,
> merge day-selection into stage 0, remove load-constraints, fix Save, and
> polish every stage to match the create_term_modal aesthetic.
>
> All tasks follow §0d self-sufficient format. Executors MUST read AGENT.md
> and BUG.md in full before starting any task.

---

## Execution Plan

```
Round 1 (sequential): TW-01 → TW-02 → TW-03 → TW-04
```

All four tasks modify only `timetable_screen.dart`. They are strictly
sequential — each depends on the previous.

---

### Task TW-01: ✅ Architecture — Dialog Entry Point, Stage Reduction, Save Fix

**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** none (first task)
**Parallel group:** Sequential

---

#### Reference design (inline — executor must NOT read create_term_modal.dart)

The create_term_modal pattern the wizard must match:

```dart
// Desktop entry point
showDialog<T>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.35),
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kModalRadius), // 12
          border: Border.all(color: AppTheme.borderColor(isDark, cs)),
          boxShadow: AppTheme.modalShadow(isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
          child: <wizard widget here>,
        ),
      ),
    ),
  ),
);

// Mobile entry point
showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.kModalRadius),
          topRight: Radius.circular(AppTheme.kModalRadius),
        ),
        border: Border(top: BorderSide(color: AppTheme.borderColor(isDark, cs))),
      ),
      // constrain height on mobile so it doesn't go full-screen
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: <wizard widget here>,
    ),
  ),
);
```

The dialog wizard widget itself is a plain `StatefulWidget` — NO Scaffold, NO AppBar.
Its layout is a `Column` with:
1. **Dialog header** — handle (mobile only) + title row + step dots + thin divider
2. **Expanded body** — `PageView` (non-scrollable, driven by stage index)
3. **Dialog footer** — thin divider + Back/Next/Save navigation row

---

#### Specification

**1. Create `showTimetableWizardDialog` function** (replaces `Navigator.push` in `_openRulesSheet`):

```dart
Future<_RulesSheetResult?> showTimetableWizardDialog({
  required BuildContext context,
  required TimetableRules initialRules,
  required SchoolContext schoolContext,
  required ActiveTermContext termContext,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<_RulesSheetResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
              child: _TimetableWizard(
                initialRules: initialRules,
                schoolContext: schoolContext,
                termContext: termContext,
              ),
            ),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<_RulesSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.kModalRadius),
              topRight: Radius.circular(AppTheme.kModalRadius),
            ),
            border: Border(
              top: BorderSide(color: AppTheme.borderColor(isDark, cs)),
            ),
          ),
          child: _TimetableWizard(
            initialRules: initialRules,
            schoolContext: schoolContext,
            termContext: termContext,
          ),
        ),
      );
    },
  );
}
```

**2. Rename `_TimetableWizardPage` → `_TimetableWizard`** and remove the Scaffold entirely.

The `_TimetableWizard` widget is a plain Column — no Scaffold, no AppBar:

```dart
class _TimetableWizard extends StatefulWidget {
  const _TimetableWizard({
    required this.initialRules,
    required this.schoolContext,
    required this.termContext,
  });
  final TimetableRules initialRules;
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_TimetableWizard> createState() => _TimetableWizardState();
}
```

The `build` method returns a `Column` (not a Scaffold):

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  final isMobile = MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildHeader(cs, isDark, isMobile),
      Divider(height: 1, thickness: 0.5, color: AppTheme.borderColor(isDark, cs)),
      Flexible(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(key: ValueKey(_stage), child: _buildStage(cs, isDark)),
        ),
      ),
      Divider(height: 1, thickness: 0.5, color: AppTheme.borderColor(isDark, cs)),
      _buildFooter(cs, isDark),
    ],
  );
}
```

**`_buildHeader`** returns a Padding widget with:
- Handle bar (mobile only): centered `Container(width: 36, height: 3, margin: EdgeInsets.only(top: 10, bottom: 4), decoration: BoxDecoration(color: cs.outlineVariant.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(2)))`
- Row: Expanded Column (stage title 14pt w500 + subtitle "Step N of 4" 11pt w400 muted) + `_WizardStepDots(currentStep: _stage, totalSteps: 4, cs: cs)` + close IconButton (`Icons.close`, size 17, muted)
- Padding: `EdgeInsets.fromLTRB(20, isMobile ? 4 : 16, 12, 12)`
- Close button calls `Navigator.of(context).pop()` (no result = user dismissed)

**3. Reduce stages from 5 to 4.**

Stage mapping (OLD → NEW):
- OLD Stage 0 (Slot Sequence) + OLD Stage 1 (Active Days) → **NEW Stage 0** ("Day & Slot Setup")
- OLD Stage 2 (Teacher Constraints) → **NEW Stage 1** ("Teacher Constraints")
- OLD Stage 3 (Subject Constraints) → **NEW Stage 2** ("Subject Constraints")
- OLD Stage 4 (Review & Generate) → **NEW Stage 3** ("Review & Generate")

Update `_stage` field: `int _stage = 0; // 0=Days+Slots, 1=Teachers, 2=Subjects, 3=Generate`

Update `_buildStage` switch:
```dart
Widget _buildStage(ColorScheme cs, bool isDark) => switch (_stage) {
  0 => _Stage0DaysSlots(rules: _rules, cs: cs, isDark: isDark, onChanged: (r) => setState(() => _rules = r)),
  1 => _Stage1TeacherConstraints(rules: _rules, teachers: _teachers, cs: cs, isDark: isDark, onChanged: (r) => setState(() => _rules = r)),
  2 => _Stage2SubjectConstraints(rules: _rules, subjects: _subjects, cs: cs, isDark: isDark, onChanged: (r) => setState(() => _rules = r)),
  3 => _Stage3Generate(...),
  _ => const SizedBox.shrink(),
};
```

Update `_goNext`: when `_stage == 2`, call `_computeConflicts()` before advancing.
Update step dot count: `_WizardStepDots(totalSteps: 4)`.

**4. Fix `_save()`** — must actually persist to disk with loading state:

Add `bool _saving = false;` to `_TimetableWizardState`.

```dart
Future<void> _save() async {
  final term = widget.termContext.currentTerm;
  if (term == null || _saving) return;
  setState(() => _saving = true);
  try {
    await FileCache.saveTimetableRules(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      rules: _rules,
    );
    if (mounted) Navigator.of(context).pop(_RulesSheetResult(rules: _rules, shouldGenerate: false));
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}
```

**5. Update `_openRulesSheet`** to use the new function:

```dart
Future<void> _openRulesSheet() async {
  final term = widget.termContext.currentTerm;
  if (term == null || _rules == null) return;

  final result = await showTimetableWizardDialog(
    context: context,
    initialRules: _rules!,
    schoolContext: widget.schoolContext,
    termContext: widget.termContext,
  );

  if (result == null || !mounted) return;

  // Rules were already saved to disk inside the dialog (_save).
  // Only reload the in-memory copy and optionally re-run generation.
  if (mounted) setState(() => _rules = result.rules);

  if (result.shouldGenerate) {
    await _runGeneration(result.rules);
  }
}
```

Note: when `shouldGenerate: false` (user clicked Save), FileCache was already called
inside the dialog. The caller only needs to update its `_rules` reference and skip
the generation call. No need to call `FileCache.saveTimetableRules` again in the caller.

When `shouldGenerate: true` (user clicked Apply Timetable after generation preview),
the caller's `_runGeneration` writes the timetable entries to the DB.

**6. `_buildFooter`** — replaces `_buildNavBar`:

```dart
Widget _buildFooter(ColorScheme cs, bool isDark) {
  final isLastStage = _stage == 3;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Row(
      children: [
        if (_stage > 0)
          _WizardTextButton(label: 'Back', onTap: _goBack, cs: cs),
        const Spacer(),
        if (!isLastStage) ...[
          _WizardTextButton(
            label: 'Save',
            onTap: _saving ? null : _save,
            loading: _saving,
            cs: cs,
          ),
          const SizedBox(width: 8),
          _WizardFilledButton(
            label: _stage == 2 ? 'Review' : 'Next',
            onTap: _goNext,
            cs: cs,
          ),
        ],
      ],
    ),
  );
}
```

`_WizardTextButton` — a compact text button with optional loading spinner:
- 13pt w400, `cs.onSurfaceVariant.withValues(alpha: 0.7)` color when enabled
- When `loading: true`, show a 14×14 `CircularProgressIndicator(strokeWidth: 1.5)` next to the text
- `GestureDetector` with `HitTestBehavior.opaque`, padding `symmetric(horizontal: 12, vertical: 8)`

`_WizardFilledButton` — a compact filled button:
- `FilledButton` with `backgroundColor: AppTheme.brandGreen`, `foregroundColor: Colors.white`
- `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.kCardRadius))`
- 13pt w500

**7. `_WizardStepDots`** — update `totalSteps` default and rendering to 4 dots.

The existing `_WizardStepDots` widget at the bottom of the file uses animated pill indicators. Keep it but make sure it works for 4 steps. No change needed to the widget itself — just pass `totalSteps: 4` at call sites.

---

**Update after completion:**
- [x] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note the wizard is now a dialog and stages reduced to 4
- [x] Mark `TW-01` as `[x]` in `eduxal/TASKS.md`
- [x] Commit: `refactor: timetable wizard — dialog entry point and 4-stage structure`

---

### Task TW-02: ✅ Stage 0 — Compact Day + Slot Setup (Redesign)

**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** TW-01
**Parallel group:** Sequential

---

#### Specification

Replace the current `_Stage0SlotBuilder` / `_Stage0SlotBuilderState` and the now-removed
`_Stage1ActiveDays` with a single new `_Stage0DaysSlots` / `_Stage0DaysSlotsState` widget.

Also DELETE these now-dead classes (they only served the old Active Days stage and its
load-constraints section):
- `_Stage1ActiveDays`, `_WizardDayChip`, `_WizardSection`, `_WizardRuleRow`,
  `_WizardStepper`, `_WizardStepBtn`, `_ExpandableFab`, `_MiniActionFab`

Also REMOVE the `_ExpandableFab` / `_MiniActionFab` usage — slot-add is now two
inline tappable rows in the scrollable content (no floating FAB inside a dialog).

---

**`_Stage0DaysSlots` widget signature:**

```dart
class _Stage0DaysSlots extends StatefulWidget {
  const _Stage0DaysSlots({
    required this.rules,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });
  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;
  @override
  State<_Stage0DaysSlots> createState() => _Stage0DaysSlotsState();
}
```

---

**State fields:**
```dart
late List<int> _activeDays;     // weekday indices 1=Mon…7=Sun
late List<TimetableSlot> _slots;
late TimeOfDay _dayStart;
```
Initialise from `widget.rules` in `initState`.

---

**Layout — `SingleChildScrollView` wrapping a `Column`:**

```
Padding(all: 20)
  Column(crossAxisAlignment: stretch, spacing: 16)
  ├── [Section A] Day selector
  ├── [Section B] Day-start time row
  ├── [Divider 0.5px]
  ├── [Section C] Slot list
  └── [Section D] Add-slot actions
```

---

**Section A — Day Selector:**

Label: `_SectionLabel('School Days')` (see label style below).

Below the label, a `Wrap(spacing: 6, runSpacing: 6)` of 7 compact day chips for
Mon–Sun (indices 1–7). Each chip:

```dart
_DayChip(
  label: 'Mon', // short label
  selected: _activeDays.contains(1),
  cs: cs,
  isDark: isDark,
  onTap: () => _toggleDay(1),
)
```

`_DayChip` widget — compact 34-36px tall selectable chip:
- Container with `borderRadius: BorderRadius.circular(AppTheme.kCardRadius)` (8)
- Unselected: `border: Border.all(color: AppTheme.borderColor(isDark, cs))`, `color: AppTheme.nestedBg(isDark, cs)`
- Selected: `border: Border.all(color: cs.primary.withValues(alpha: 0.55))`, `color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08)`
- Text: 12.5pt w500, `cs.onSurface` selected, `cs.onSurfaceVariant.withValues(alpha: 0.7)` unselected
- Padding: `EdgeInsets.symmetric(horizontal: 12, vertical: 8)`
- Wrap in `AnimatedContainer` (duration: 140ms) for smooth color transition
- `InkWell` with `borderRadius` same as container, `splashFactory: NoSplash.splashFactory`

`_toggleDay(int weekdayIndex)`:
```dart
void _toggleDay(int d) {
  setState(() {
    if (_activeDays.contains(d)) {
      if (_activeDays.length > 1) _activeDays = List.from(_activeDays)..remove(d);
    } else {
      _activeDays = List.from(_activeDays)..add(d)..sort();
    }
  });
  _notify();
}
```

---

**Section B — Day-start time row:**

A single compact tappable row (48px, `AppTheme.nestedBg` fill, `AppTheme.kCardRadius` border radius,
`border: Border.all(AppTheme.borderColor)`) that opens `showTimePicker` on tap:

```
[Icon: wb_sunny_outlined, 14px, muted]  "Starts at"  [Spacer]  [Chip: "8:00 AM"]
```

The time chip on the right: `cs.primary.withValues(alpha: 0.10)` background,
`cs.primary` text, 12pt w500, `BorderRadius.circular(AppTheme.kChipRadius)` (4),
padding `horizontal: 10, vertical: 5`.

---

**Section C — Slot list:**

Label row: `_SectionLabel('Slot Sequence')` + a small badge showing
`"N lessons"` (count of `SlotType.lesson` slots) — `cs.primary.withValues(alpha: 0.1)`
bg, `cs.primary` text, 10pt w500, `kChipRadius` border radius.

If empty: centered muted text "No slots yet — add lesson and break slots below." (13pt w400, `cs.onSurfaceVariant.withValues(alpha: 0.5)`).

Slot list items: `_SlotRowTile` (see redesign below), separated by
`Divider(height: 1, thickness: 0.5, indent: 0, endIndent: 0, color: AppTheme.borderColor(isDark, cs).withValues(alpha: 0.35))`.

**`_SlotRowTile` redesign** — compact 48px row:
```
[Number badge]  [Type chip]  [Time range]  [Spacer]  [Duration label]  [Delete icon]
```
- Number badge: 20×20 rounded container (`kChipRadius`), `cs.surfaceContainerHighest` bg, index+1 in 10pt w500
- Type chip: "Lesson" (green tint) or "Break" (muted amber tint), 10pt w500, `kChipRadius`, padding `horizontal: 6, vertical: 2`
  - Lesson: `AppTheme.brandGreen.withValues(alpha: 0.12)` bg, `AppTheme.brandGreen` text
  - Break: `const Color(0xFFFFA726).withValues(alpha: 0.12)` bg, `const Color(0xFFFFA726)` text
- Time range: 12pt w400 `cs.onSurface`, e.g. "8:00 – 8:40"
- Duration: 11pt w400 `cs.onSurfaceVariant.withValues(alpha: 0.6)`, e.g. "40 min"
- Delete: `Icons.close_rounded` size 16, `cs.onSurfaceVariant.withValues(alpha: 0.4)`, 32×32 tap area

Row padding: `EdgeInsets.symmetric(horizontal: 14, vertical: 0)`, row height via `SizedBox(height: 48)`.

---

**Section D — Add-slot actions:**

Two compact inline action rows at the bottom of the scroll content (below the slot list),
styled as tappable `Container` rows with a border — NO floating FAB inside the dialog.

```dart
Row(
  children: [
    Expanded(child: _AddSlotButton(label: '+ Add Lesson', color: AppTheme.brandGreen, onTap: () => _promptAdd(SlotType.lesson, context))),
    const SizedBox(width: 8),
    Expanded(child: _AddSlotButton(label: '+ Add Break', color: const Color(0xFFFFA726), onTap: () => _promptAdd(SlotType.breakSlot, context))),
  ],
)
```

`_AddSlotButton` — compact outlined button:
- `Container` with `height: 38`, `borderRadius: kCardRadius`, `border: Border.all(color: color.withValues(alpha: 0.35))`
- `color.withValues(alpha: 0.06)` background
- Text: `color` at 12.5pt w500, centered

---

**`_promptAdd` — duration input dialog** (replaces the old large dialog):

```dart
Future<void> _promptAdd(SlotType type, BuildContext context) async {
  final label = type == SlotType.lesson ? 'Lesson' : 'Break';
  final defaultMins = type == SlotType.lesson ? 40 : 10;
  int? selected = defaultMins;
  // show a compact inline dialog
  final result = await showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _DurationPickerDialog(
      slotLabel: label,
      initialMinutes: defaultMins,
    ),
  );
  if (result == null || result < 5 || result > 240) return;
  setState(() => _slots = [..._slots, TimetableSlot(type: type, durationMinutes: result)]);
  _notify();
}
```

**`_DurationPickerDialog`** — compact dialog matching create_term_modal style:
- `Dialog(backgroundColor: transparent, elevation: 0)` → `ConstrainedBox(maxWidth: 300)` → styled Container (same decoration: `modalBg`, `kModalRadius` border radius, `borderColor` border, `modalShadow`)
- Content: header row ("Add Lesson Slot" / "Add Break Slot", 14pt w500 + close icon) + thin divider
- Body: a row of duration presets (compact chips: 30, 40, 45, 60 min for lesson; 5, 10, 15, 20 min for break) + a small number `TextField` for custom entry
  - Duration preset chips: same `_DayChip` style but showing "40 min", pre-selected chip highlights in `cs.primary` tint
  - TextField: compact, keyboardType number, `isDense: true`, prefilled with selected value
- Footer: divider + "Cancel" text + "Add" FilledButton (brandGreen)
- State tracks `_minutes` int

---

**`_SectionLabel` helper widget:**

```dart
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
```

---

**Break-slot display note (important):** Break slots in `_slots` are ONLY used to
compute lesson-slot start/end times (they advance the time cursor). They are NEVER
written to the timetable table in the database — only `GeneratedSlot` entries from
`TimetableGenerator` (which only schedules lesson slots) are written to the DB.
The timetable display infers breaks from time gaps between consecutive lesson slots.
Do NOT add any DB-write logic for break slots.

---

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — update Stage 0 description
- [ ] Mark `TW-02` as `[x]` in `eduxal/TASKS.md`
- [ ] Commit: `ui: timetable wizard — compact day+slot stage redesign`

---

### Task TW-03: ✅ Stages 1+2 — Teacher and Subject Constraint UI Polish

**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** TW-02
**Parallel group:** Sequential

---

#### Specification

Rename and redesign the teacher and subject constraint stages. The goal is a compact,
polished look consistent with the rest of the dialog and the create_term_modal aesthetic.

**Rename:**
- `_Stage2TeacherConstraints` / `_Stage2TeacherConstraintsState` → `_Stage1TeacherConstraints` / `_Stage1TeacherConstraintsState`
- `_Stage3SubjectConstraints` / `_Stage3SubjectConstraintsState` → `_Stage2SubjectConstraints` / `_Stage2SubjectConstraintsState`

These are already correct in the `_buildStage` switch after TW-01, just update
the class names to match.

---

**Overall layout for both constraint stages:**

```
SingleChildScrollView
  Column(padding: 20, spacing: 0)
  ├── _SearchField (compact inline search)
  ├── SizedBox(height: 12)
  └── ListView of _ConstraintEntityRow items (non-scrolling, shrinkWrap: true)
       Each row expands inline when tapped (AnimatedCrossFade)
```

---

**`_SearchField` — compact inline search bar:**

```dart
Container(
  height: 38,
  decoration: BoxDecoration(
    color: AppTheme.nestedBg(isDark, cs),
    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
    border: Border.all(color: AppTheme.borderColor(isDark, cs)),
  ),
  child: Row(
    children: [
      const SizedBox(width: 10),
      Icon(Icons.search_rounded, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Search teachers…', // or 'Search subjects…'
            hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      if (_search.isNotEmpty)
        GestureDetector(
          onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.close_rounded, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ),
    ],
  ),
)
```

---

**`_ConstraintEntityRow` — replaces `_EntityConstraintCard`:**

A compact row that expands inline. Height when collapsed: 44px. When expanded: reveals
the constraint list and an "Add Constraint" button via `AnimatedCrossFade`.

Collapsed row:
```
[Name 13pt w400]  [Spacer]  [Count badge if > 0]  [Chevron rotates 90° when expanded]
```
- Count badge: `cs.primary.withValues(alpha: 0.1)` bg, `cs.primary` text, 10pt w500, `kChipRadius`
- Chevron: `Icons.chevron_right_rounded`, 18px, `cs.onSurfaceVariant.withValues(alpha: 0.5)`, `AnimatedRotation` (0° collapsed, 90° expanded, 180ms)
- Row background: transparent; `InkWell` with `cs.primary.withValues(alpha: 0.04)` hover
- Separated from next row by `Divider(height: 1, thickness: 0.5, color: AppTheme.borderColor(isDark, cs).withValues(alpha: 0.35))`

Expanded section (shown below the row via `AnimatedCrossFade`):
```
Container(
  color: AppTheme.nestedBg(isDark, cs),
  child: Column(
    ├── per-constraint: _ConstraintChipRow
    ├── Divider (0.5px)
    └── "Add Constraint" row (tappable, opens _ConstraintEntryDialog)
  )
)
```

---

**`_ConstraintChipRow` — replaces `_ConstraintTile`:**

A compact row (40px) showing the constraint data as chips:
```
[Block/Require chip]  [Day chips...]  [Slot chips...]  [Spacer]  [Delete icon]
```

- Block chip: `cs.error.withValues(alpha: 0.10)` bg, `cs.error` text, "Block" 10pt w500
- Require chip: `cs.primary.withValues(alpha: 0.10)` bg, `cs.primary` text, "Require" 10pt w500
- Day chips: short day label (Mon/Tue/…), `cs.onSurfaceVariant.withValues(alpha: 0.08)` bg, 10pt w400, `kChipRadius`, compact
- Slot chips: "Slot N", same style as day chips
- Delete: `Icons.close_rounded` 14px, 32×32 tap area, `cs.onSurfaceVariant.withValues(alpha: 0.35)` color
- Padding: `EdgeInsets.symmetric(horizontal: 14, vertical: 0)`

---

**"Add Constraint" row at bottom of expanded section:**

A 40px tappable row:
```
[Icon: add_rounded, 14px, cs.primary @ 0.7]  ["Add constraint" 12.5pt w400 cs.primary @ 0.8]
```
`InkWell` with `cs.primary.withValues(alpha: 0.04)` hover, calls `_showConstraintEntry(entityId, entityName)`.

---

**`_showConstraintEntry` — replaces `_showConstraintSheet` and `_ConstraintSheet`:**

Convert from `showModalBottomSheet` to `showDialog`. Use the same dialog container
pattern as TW-01 (maxWidth 400px, `modalBg`, `kModalRadius`, `borderColor`, `modalShadow`).

```dart
Future<void> _showConstraintEntry(String entityId, String entityName) async {
  final result = await showDialog<({List<int> days, List<int> slotIndices, bool isBlock})>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
            child: _ConstraintEntryForm(
              entityName: entityName,
              rules: widget.rules,
              cs: cs,
              isDark: isDark,
            ),
          ),
        ),
      ),
    ),
  );
  if (result == null) return;
  // append to constraints list via onChanged callback
  _add(entityId, result.days, result.slotIndices, result.isBlock);
}
```

**`_ConstraintEntryForm`** — replaces `_ConstraintSheet` / `_ConstraintSheetState`:

Layout (same pattern as create_term_modal form):
```
SingleChildScrollView
  Column(mainAxisSize: min, crossAxisAlignment: stretch)
  ├── Header: "Add Constraint" (14pt w500) + entity name subtitle (12pt w400 muted) + close button
  ├── Divider (0.5px)
  ├── Padding(20)
  │   ├── _SectionLabel('Type')
  │   ├── SizedBox(8)
  │   ├── Row: [Block chip]  [Require chip]   ← same _DayChip style, full width split
  │   ├── SizedBox(14)
  │   ├── _SectionLabel('Days')
  │   ├── SizedBox(8)
  │   ├── Wrap(spacing:6, runSpacing:6): day chips from rules.activeDays (using _DayChip)
  │   ├── SizedBox(14)
  │   ├── _SectionLabel('Slots')  ← lesson slots only (from rules.buildLessonSlots())
  │   ├── SizedBox(8)
  │   └── Wrap(spacing:6, runSpacing:6): slot chips — "Slot N  HH:MM–HH:MM" (using _DayChip style)
  ├── Divider (0.5px)
  └── Padding(fromLTRB: 20, 10, 20, 14)
       Row: Cancel (text) + "Add" FilledButton (brandGreen, disabled if nothing selected)
```

**Type selector chips:** Two chips side-by-side in a Row, each `Expanded`:
- "Block" — when selected: `cs.error.withValues(alpha: 0.12)` bg, `cs.error` border, `cs.error` text
- "Require" — when selected: `cs.primary.withValues(alpha: 0.12)` bg, `cs.primary` border, `cs.primary` text
- Unselected: `AppTheme.nestedBg` bg, `AppTheme.borderColor` border, muted text
- Height 38px, `kCardRadius` border radius, text 12.5pt w500, `AnimatedContainer` 140ms

**Slot chips:** Each shows "Slot N" label (e.g. "Slot 3") and the computed time range
"HH:MM–HH:MM" on a second line (10pt w400 muted) — or stacked in a compact two-line chip.
Use `rules.buildLessonSlots()` to get `List<({int index, int start, int end})>`.
Slot chips use the same `_DayChip` selection style.

**Validation before "Add":** At least one day, at least one slot, and type must be selected.
The "Add" button is disabled (alpha: 0.35, no onTap) when validation fails.

Delete the old `_ConstraintSheet`, `_ConstraintSheetState`, `_ConstraintTypeChip`,
and `_showConstraintSheet` — they are fully replaced.

---

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — update constraint stage descriptions
- [ ] Mark `TW-03` as `[x]` in `eduxal/TASKS.md`
- [ ] Commit: `ui: timetable wizard — compact constraint stages redesign`

---

### Task TW-04: Stage 3 — Review & Generate UI Polish + Full Integration Check

**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** TW-03
**Parallel group:** Sequential

---

#### Specification

Rename `_Stage4Generate` / `_Stage4GenerateState` → `_Stage3Generate` / `_Stage3GenerateState`.
Rename `_ConflictCard` if needed. Update the `_buildStage` switch in `_TimetableWizardState`
so `case 3:` uses `_Stage3Generate(...)`.

The stage lives inside the dialog — it does NOT push a new route and does NOT use Scaffold.
Its content is a `SingleChildScrollView` with a `Column`. The dialog footer from TW-01
shows NO Back/Next buttons when `_stage == 3` (since the generate stage has its own actions),
but DOES show a "Back" text button and a "Save & Close" action.

Actually: for Stage 3 the footer from TW-01 already hides Next when `isLastStage`. Add
a "Back" button on the left and "Save" on the right (same as other stages, using the
`_save()` method from TW-01). The Generate button lives INSIDE the stage body, not in the footer.

---

**Stage 3 layout (`SingleChildScrollView` → `Column`, padding: 20):**

```
Column(spacing: 16)
├── [If conflicts] _ConflictSection
├── [If no conflicts] _SummarySection
└── _GenerateSection
```

---

**`_SummarySection` — shown when `conflicts.isEmpty`:**

A compact stats grid showing the configured rules:

```dart
Wrap(
  spacing: 8, runSpacing: 8,
  children: [
    _StatChip(label: 'Days', value: '${rules.activeDays.length}'),
    _StatChip(label: 'Slots/Day', value: '${lessonSlotCount}'),
    _StatChip(label: 'Teacher rules', value: '${rules.teacherConstraints.length}'),
    _StatChip(label: 'Subject rules', value: '${rules.subjectConstraints.length}'),
  ],
)
```

`_StatChip` — compact info chip:
- Container: `AppTheme.nestedBg` bg, `AppTheme.borderColor` border, `kCardRadius` radius
- Two texts in a Row: value (16pt w500 `cs.onSurface`) + "  " + label (11pt w400 `cs.onSurfaceVariant.withValues(alpha: 0.6)`)
- Padding: `horizontal: 12, vertical: 8`

---

**`_ConflictSection` — shown when `conflicts.isNotEmpty`:**

```
_SectionLabel('Conflicts Detected', trailing: red count badge)
SizedBox(8)
ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics)
  ↳ _ConflictCard per conflict
```

**`_ConflictCard` redesign** — compact card (no heavy elevation):

```
Container(
  decoration: BoxDecoration(
    color: AppTheme.nestedBg(isDark, cs),
    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
    border: Border.all(color: cs.error.withValues(alpha: 0.3)),
  ),
  padding: EdgeInsets.all(12),
  child: Column(
    crossAxisAlignment: start,
    children: [
      // Teacher row
      Row: [Icon(person_outline_rounded, 14px, muted)  "Teacher: {teacherName}" 12.5pt w400  "Block/Require" badge]
      SizedBox(4)
      // Subject row
      Row: [Icon(book_outlined, 14px, muted)  "Subject: {subjectName}" 12.5pt w400  "Block/Require" badge]
      SizedBox(10)
      // Priority picker
      _SectionLabel('Which takes priority?')
      SizedBox(6)
      Row(
        children: [
          Expanded(_PriorityChip(label: teacherName, selected: conflict.teacherWins, onTap: () => onChanged(conflict, true))),
          SizedBox(width: 8),
          Expanded(_PriorityChip(label: subjectName, selected: !conflict.teacherWins, onTap: () => onChanged(conflict, false))),
        ],
      ),
    ],
  ),
)
```

`_PriorityChip` — 36px tall selectable chip using the same selected/unselected style as
`_DayChip` from TW-02, but with `cs.primary` (not `brandGreen`) as the active color.
Text: 12pt w500. `AnimatedContainer` 140ms transition.

---

**`_GenerateSection` — the generate button and result display:**

```
Column(crossAxisAlignment: stretch, spacing: 12)
├── [If _generationResult == null && !_generating] _GenerateButton
├── [If _generating] _GeneratingIndicator
├── [If GeneratorSuccess] _SuccessPanel
└── [If GeneratorFailure] _FailurePanel
```

**`_GenerateButton`:**
A full-width `FilledButton` styled with `AppTheme.brandGreen`:
```dart
FilledButton.icon(
  onPressed: onGenerate,
  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
  label: const Text('Generate Timetable'),
  style: FilledButton.styleFrom(
    backgroundColor: AppTheme.brandGreen,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 44),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
    ),
    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
  ),
)
```

**`_GeneratingIndicator`:**
A centered Column:
```
CircularProgressIndicator(strokeWidth: 2, color: cs.primary)
SizedBox(12)
Text("Generating…" 13pt w400 muted, animated status messages cycling every 1.5s)
```
Use a `Timer.periodic` in `_Stage3GenerateState.initState` to cycle through
messages like: "Analysing subjects…", "Building slot matrix…", "Resolving constraints…",
"Optimising schedule…" — replacing the old `_statusMessages` / `_pulseCtrl` animation
with a simpler text-swap animation using `AnimatedSwitcher` + `FadeTransition`.

**`_SuccessPanel`:**
```
Container(
  decoration: BoxDecoration(
    color: AppTheme.brandGreen.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
    border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.3)),
  ),
  padding: EdgeInsets.all(14),
  child: Column(
    ├── Row: [Icon check_circle_outline_rounded green 18px]  "Timetable ready!" 13.5pt w500
    ├── SizedBox(4)
    ├── Text: "{N} slots across {D} days  ·  {ms}ms" 12pt w400 muted
    ├── SizedBox(12)
    └── Row(mainAxisAlignment: end):
         TextButton("Regenerate", onTap: onGenerate, style muted)
         SizedBox(8)
         FilledButton("Apply Timetable →", onTap: onComplete, brandGreen style)
  ),
)
```

**`_FailurePanel`:**
```
Container(
  decoration: BoxDecoration(
    color: cs.error.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
    border: Border.all(color: cs.error.withValues(alpha: 0.3)),
  ),
  padding: EdgeInsets.all(14),
  child: Column(
    ├── Row: [Icon error_outline_rounded error 18px]  "Could not generate" 13.5pt w500 cs.error
    ├── SizedBox(6)
    ├── Text(result.reason, 12pt w400, cs.onSurfaceVariant, maxLines: 4, overflow: ellipsis)
    ├── SizedBox(12)
    └── Align(right): OutlinedButton("Try Again", onTap: onGenerate)
  ),
)
```

---

**Integration checklist — executor must verify:**

1. `showTimetableWizardDialog` is called from `_openRulesSheet` (TW-01).
2. `_buildStage` switch covers cases 0–3 with the correct widget names from TW-02/03/04.
3. `_computeConflicts` is called in `_goNext` when `_stage == 2` (before advancing to 3).
4. `_save()` correctly calls `FileCache.saveTimetableRules` and pops with `shouldGenerate: false`.
5. `_completeWithGeneration()` pops with `shouldGenerate: true` (called by "Apply Timetable" in `_SuccessPanel`).
6. `_WizardStepDots` is passed `totalSteps: 4` and `currentStep: _stage`.
7. Run `flutter analyze` (or use the diagnostics tool) — zero errors before committing.
8. `_Stage1ActiveDays`, `_WizardSection`, `_WizardRuleRow`, `_WizardStepper`, `_WizardStepBtn`,
   `_ExpandableFab`, `_MiniActionFab`, `_ConstraintSheet`, `_ConstraintSheetState`,
   `_ConstraintTypeChip`, `_showConstraintSheet` are all deleted (not referenced anywhere).

---

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — rewrite the full timetable wizard section to reflect the new 4-stage dialog design
- [ ] Mark `TW-04` as `[x]` in `eduxal/TASKS.md`
- [ ] Commit: `ui: timetable wizard — generate stage polish and full dialog integration`
