# TASKS.md

---

### Task 01: ~~Unify mobile tab bar across all roles (Teacher dashboard + Owner dashboard)~~ ✅

**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

The user has two related complaints about the mobile tab bar on the school dashboard:

1. **Teacher dashboard tabs look wrong.** On mobile, the teacher role is routed to `_SimpleTabBar` (line ~460: `if (isMobile && currentEntry.role == MembershipRole.teacher)`). This widget uses a solid `cs.primary` fill indicator with `cs.onPrimary` text, `BorderRadius.circular(4)`, and no background container — it looks flat and out of place. The user wants it to look like the **day tabs** on the timetable page (`_MobileDayStrip` in `timetable_screen.dart` lines ~9158–9222), which uses a tinted `surfaceContainerHighest` background strip, `cs.surface` indicator with box shadow, `AnimatedContainer` transitions, and `cs.onSurface`/`cs.onSurfaceVariant` text colors.

2. **Owner dashboard tabs scroll infinitely.** On mobile, all non-teacher roles use `LoopingTabStrip` (line ~462: `else if (isMobile)`), a custom infinite-looping `ListView.builder` with `items.length × 1000` virtual items. The user wants this replaced with a **fixed, non-scrolling tab bar** matching the same day-tab style. The user also wants: **no icons** (currently tabs render icon + label in a Column), and **renamed tabs** — specifically `"Exams & Grades"` → `"Exams"`.

**What to do:**

**A) Create a single unified mobile tab bar widget** (replace both `_SimpleTabBar` and `LoopingTabStrip` usage) modeled on the `_MobileDayStrip` / `EduTabBar` design language:
- Outer container: `height: 44`, `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)`, `padding: EdgeInsets.all(3)`, background `cs.surfaceContainerHighest` with alpha (0.6 dark / 0.45 light), `BorderRadius.circular(10)`, subtle outer box shadow.
- Each tab: `Expanded` child in a `Row`, `GestureDetector` → `AnimatedContainer(duration: 180ms)`, selected: `cs.surface` background + box shadow (`blurRadius: 5, offset: Offset(0, 1.5)`), `BorderRadius.circular(8)`. Unselected: transparent.
- Text-only (no icons): `fontSize: 12.5`, selected `FontWeight.w500` + `cs.onSurface`, unselected `FontWeight.w400` + `cs.onSurfaceVariant.withValues(alpha: 0.7)`.
- The widget must call the existing `_selectIndex(int)` callback on tap and highlight based on `_selectedIndex`.
- Since different roles have different tab counts (teacher: 4, owner: 8, staff: variable), tabs with more than 5 items should use `isScrollable` behavior — a horizontally scrollable `Row` inside a `SingleChildScrollView` with fixed minimum tab widths (e.g. ~80px each) rather than `Expanded`. For ≤5 tabs, use `Expanded` children in a `Row` (non-scrollable, equally distributed).

**B) Remove the teacher-specific branch.** Delete the `if (isMobile && currentEntry.role == MembershipRole.teacher)` → `_SimpleTabBar(...)` block. All mobile roles should go through the new unified widget.

**C) Remove the `LoopingTabStrip` usage.** Replace the `else if (isMobile)` → `LoopingTabStrip(...)` block with the new unified widget.

**D) Rename tabs.** In the `_itemsForRole` method:
- Owner tabs (line ~268–276): rename `'Exams & Grades'` → `'Exams'`
- Staff tabs (line ~330–332, if they have `'Exams & Grades'`): rename similarly
- Any other roles with the same verbose label: rename to be concise

**E) Remove icons from mobile tab labels.** The new widget should only render text. Icons may still be used in the desktop sidebar/rail — only the mobile tab bar is affected.

**F) Handle `TabController` integration.** The current `_SimpleTabBar` uses a `TabController` for `TabBarView` integration. The new widget must either:
- Continue using `TabController` and `TabBar` (but restyle it), OR
- Use a simple index-based approach that calls `_tabController.animateTo(index)` on tap (like `LoopingTabStrip` does via `_selectIndex`), keeping `TabBarView` working.

The `_SimpleTabBar` widget (lines ~1316–1361) can be deleted or repurposed. The `LoopingTabStrip` widget file (`lib/ui/widgets/looping_tab_strip.dart`) can be left in place (it may be used elsewhere) but should no longer be imported by the dashboard screen.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note the new unified mobile tab bar and tab renames
- [x] Mark this task `[x]`

---

### Task 02: Fix pinkish input fields in light theme + add optional ADM field to student creation

**Files to create/modify:** `lib/ui/theme/app_theme.dart`, `lib/ui/widgets/member_creation/add_student_panel.dart`, `lib/services/members.dart`
**Context files to read (if needed):** `lib/ui/widgets/CONTEXT.md`, `lib/services/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Two sub-issues:

**Sub-issue A: Pinkish/lavender color on input fields in light mode**

The root cause is in `lib/ui/theme/app_theme.dart`. In the `light()` method (around line 282–294), the `ColorScheme` is built from `ColorScheme.fromSeed(seedColor: brandIndigo)` and then specific surface colors are overridden. However, `surfaceContainerLow` and `surfaceContainerHigh` are **NOT overridden** in the light theme — they inherit the indigo-tinted values from `fromSeed`, producing a pinkish/lavender hue. The dark theme (around line 323–324) correctly overrides both:

```
surfaceContainerLow: _slateContainerLow,
surfaceContainerHigh: _slateContainerHigh,
```

**Fix:** Add two neutral gray overrides to the `light()` method's `base.copyWith(...)` call. Choose values that slot into the existing light palette staircase:
- `_lightBg` = `0xFFFFFFFF` (white) — `surfaceContainerLowest`
- **New** — `surfaceContainerLow`: approximately `Color(0xFFF5F6F8)`
- `_lightContainer` = `0xFFF1F3F5` — `surfaceContainer`
- **New** — `surfaceContainerHigh`: approximately `Color(0xFFEBEDF0)`
- `_lightItem` = `0xFFE8EBEE` — `surfaceContainerHighest`

This single theme fix eliminates the pinkish color globally — in the student photo picker background, gender chips, guardian search input, calendar widgets, grade picker sheets, and everywhere else `surfaceContainerLow` / `surfaceContainerHigh` is used.

**Sub-issue B: Optional ADM number field on student creation form**

Currently, `add_student_panel.dart` has no ADM input field. The subtitle text at line ~304 says "An admission number will be assigned automatically." The service method `createStudent()` in `lib/services/members.dart` (line ~415) does not accept an `adm` parameter — it always calls `_dao.nextAdmissionNumber(schoolId)`.

**Fix:**

1. **In `lib/services/members.dart`** — add an optional `int? adm` parameter to `createStudent()`. If provided and > 0, use it directly. If null or 0, fall back to the existing `_dao.nextAdmissionNumber(schoolId)` auto-increment. Before using a user-provided ADM, validate that it doesn't already exist at the school by querying the students table (the DAO already has `getStudent(schoolId, adm)` or similar). If it conflicts, return an error result.

2. **In `add_student_panel.dart`** — add an optional `TextFormField` for the ADM number. Place it after the Name field (or after the Photo picker, before Gender). Use:
   - Label: `'Admission number'`
   - Hint: `'Leave blank to auto-assign'`
   - `keyboardType: TextInputType.number`
   - `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`
   - Style it consistently with the other `EduFormField` inputs (NOT with `surfaceContainerLow` — use the standard input decoration from the theme)
   - Pass the parsed `int?` value to the service's `createStudent()` call

3. **Update the subtitle text** to say something like: `'Fill in the student\'s details. You can optionally specify an admission number.'`

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md` — note the ADM field addition to `add_student_panel.dart`
- [ ] Update `lib/services/CONTEXT.md` — note the new `adm` parameter on `createStudent()`
- [ ] Mark this task `[x]`

---

### Task 03: Fix roles permissions persistence — root cause diagnosis and fix ✅ [x]

**Files to create/modify:** `lib/ui/screens/school_dashboard/roles/_role_helpers.dart`, `lib/sync/delta_writer.dart`, `lib/core/seeder.dart`
**Context files to read (if needed):** `lib/models/CONTEXT.md`, `lib/sync/CONTEXT.md`, `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

This is BUG-011 recurring. Previous fix attempts addressed UI state timing (ValueKey, didUpdateWidget) and added logging, but the **actual root cause was never found**. After exhaustive code tracing, the examiner has identified **two distinct root causes** that corrupt the `roles.permissions` column, making `parsePermissions()` return an empty map:

**Root Cause 1: The seeder stores permissions in an unparseable format**

In `lib/core/seeder.dart` (lines ~2193–2213), the seeder builds a binary blob as a `List<int>` (`permBytes = [5, 2, 0, 7, 2, 0, 8, 130, 0, ...]`) representing the `[resource_id, lo_byte, hi_byte]` binary format. It then stores `jsonEncode(permBytes)` in the database — this produces a JSON array of raw integers like `'[5,2,0,7,2,0,8,130,0,9,15,0,11,134,0,14,2,0]'`.

`Permissions.fromJson()` in `lib/models/permissions.dart` handles two shapes:
- Shape 1 (list of objects): `[{"resource": "users", "actions": ["read"]}]` — iterates and checks `entry is Map<String, dynamic>`
- Shape 2 (flat map): `{"users.read": true}`

The seeder's `[5, 2, 0, ...]` format is **neither** shape. When `Permissions.fromJson` iterates the list, each entry is an `int`, not a `Map<String, dynamic>`, so every entry is silently skipped. Result: empty permissions.

**Root Cause 2: The delta writer stores permissions as base64**

In `lib/sync/delta_writer.dart` (line ~1251), `_applyRoles` stores:
```
permissions: Value(base64Encode(row.permissions)),
```

`row.permissions` is a protobuf `bytes` field (`List<int>`). The client originally sent these bytes as `utf8.encode(jsonString)` when creating the log payload. The server stores and returns the same bytes. But the delta writer **base64-encodes** them instead of UTF-8-decoding them back to the original JSON string.

So after a server sync, the permissions column contains something like `'W3sicmVzb3VyY2UiOiJ1c2VycyIsImFjdGlvbnMiOlsicmVhZCJdfV0='` — a base64 string that `jsonDecode()` will throw on, causing `parsePermissions` to return empty.

**The fix has three parts:**

**Part A — Fix `parsePermissions` in `_role_helpers.dart` to handle all formats:**

Make the function resilient to all three storage formats it might encounter:

```
Map<Resource, int> parsePermissions(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]' || jsonStr == '{}') {
    return {};
  }

  // Attempt 1: Standard JSON decode (handles JSON object format)
  try {
    final decoded = jsonDecode(jsonStr);
    final perms = Permissions.fromJson(decoded);
    if (perms.isNotEmpty) return Map<Resource, int>.from(perms.map);

    // If fromJson returned empty but decoded was a non-empty List<int>,
    // it might be the seeder's binary blob format: [resource_id, lo, hi, ...]
    if (decoded is List && decoded.isNotEmpty && decoded.first is int) {
      final bytes = Uint8List.fromList(decoded.cast<int>());
      final blobPerms = Permissions.fromBlob(bytes);
      if (blobPerms.isNotEmpty) return Map<Resource, int>.from(blobPerms.map);
    }

    return {};
  } catch (_) {
    // jsonDecode failed — might be base64
  }

  // Attempt 2: base64 decode → try as UTF-8 JSON string
  try {
    final bytes = base64Decode(jsonStr);
    final jsonFromBytes = utf8.decode(bytes);
    final decoded = jsonDecode(jsonFromBytes);
    final perms = Permissions.fromJson(decoded);
    if (perms.isNotEmpty) return Map<Resource, int>.from(perms.map);
  } catch (_) {}

  // Attempt 3: base64 decode → try as binary blob
  try {
    final bytes = Uint8List.fromList(base64Decode(jsonStr));
    final blobPerms = Permissions.fromBlob(bytes);
    if (blobPerms.isNotEmpty) return Map<Resource, int>.from(blobPerms.map);
  } catch (_) {}

  return {};
}
```

Add necessary imports: `dart:convert` (base64Decode, utf8), `dart:typed_data` (Uint8List).

**Part B — Fix the delta writer in `delta_writer.dart`:**

In `_applyRoles` (line ~1251), change:
```
permissions: Value(base64Encode(row.permissions)),
```
to:
```
permissions: Value(utf8.decode(row.permissions)),
```

The protobuf bytes field contains the UTF-8-encoded JSON string that the client originally sent. Decoding with `utf8.decode` restores the original JSON string, which `parsePermissions` can then parse directly.

However, if the server could also send raw binary blob bytes (not UTF-8 JSON), then a safer approach is:
```
permissions: Value(_decodePermissions(row.permissions)),
```
where `_decodePermissions` tries `utf8.decode` first, falls back to `base64Encode`, so at minimum parsePermissions can handle it:
```
String _decodePermissions(List<int> bytes) {
  try {
    final json = utf8.decode(bytes);
    // Verify it's valid JSON
    jsonDecode(json);
    return json;
  } catch (_) {
    // Fallback: store as base64, parsePermissions knows how to handle it
    return base64Encode(bytes);
  }
}
```

**Part C — Fix the seeder in `seeder.dart`:**

Replace the raw binary blob + `jsonEncode(permBytes)` approach (lines ~2193–2213) with the standard `serialisePermissions` format. Import `_role_helpers.dart`'s `serialisePermissions` (or reimplement inline). Build a `Map<Resource, int>` and serialise it:

```
final permMap = <Resource, int>{
  Resource.students: Action.read.mask,
  Resource.classes: Action.read.mask,
  Resource.attendance: Action.read.mask | Action.mark.mask,
  Resource.lessons: Action.create.mask | Action.read.mask | Action.update.mask | Action.delete.mask,
  Resource.grades: Action.read.mask | Action.update.mask | Action.mark.mask,
  Resource.announcements: Action.read.mask,
};
```

Then use the existing `serialisePermissions(permMap)` to produce the JSON string stored in `permissions`. This ensures the seeded role is in the same format as user-created roles.

Also update the `sync_pb.CreateRolePayload` to use `utf8.encode(serialisePermissions(permMap))` for the `permissions` field, ensuring consistency.

**Part D — Update BUG.md:**

Append BUG-012 entry documenting the true root causes and fixes. Reference BUG-011 and note that the previous fix addressed symptoms (UI state timing) but not the underlying data corruption (seeder format + delta writer encoding).

**Update after completion:**
- [ ] Update `lib/sync/CONTEXT.md` — note the delta writer permissions encoding fix
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note the `parsePermissions` resilience improvement
- [ ] Append BUG-012 to `BUG.md`
- [ ] Mark this task `[x]`

---

### Task 04: Verify and cleanup after all tasks

**Files to create/modify:** Various CONTEXT.md files
**Context files to read (if needed):** All modified files from Tasks 01–03
**Depends on:** Task 01, Task 02, Task 03
**Parallel group:** P2 (sequential — runs after all P1 tasks complete)

**Specification:**

Final verification pass:

1. Run `dart analyze` / `flutter analyze` to check for any compilation errors introduced by the three parallel tasks.
2. Verify no import conflicts (e.g., Task 01 and Task 03 both modify dashboard-related files — ensure no merge conflicts in imports).
3. Verify the `LoopingTabStrip` import is removed from `school_dashboard_screen.dart` if no longer used there.
4. Verify `_SimpleTabBar` widget is either removed or no longer referenced.
5. Check that `_role_helpers.dart` has all necessary imports for the new `parsePermissions` logic (`dart:convert`, `dart:typed_data`).
6. Spot-check that the light theme color staircase in `app_theme.dart` is monotonically ordered (lowest → low → container → high → highest) by inspecting the hex values.

**Update after completion:**
- [ ] Update top-level `lib/CONTEXT.md` if needed
- [ ] Mark this task `[x]`
