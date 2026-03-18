# TASKS.md

---

### [x] Task 3: Remove duplicate create-exam entry points from Exams tab
**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart`
**Context files to read (if needed):** none — file is self-contained
**Depends on:** none
**Parallel group:** P1

**Problem:**
In the Academics > Grade view, the Exams tab currently has two ways to trigger exam creation that appear simultaneously when there are no exams:

1. A `FloatingActionButton.small` rendered via `Scaffold.floatingActionButton` (always visible when the user can manage and config is loaded).
2. An `OutlinedButton.icon` labelled "Create Exam" inside the `_buildEmpty` widget body, which appears centred on screen when the list is globally empty.

The user sees a redundant centered "Create Exam" button AND a floating action button (+) at the same time. The FAB must be removed. The centered empty-state button must also be removed — the empty state should remain (with its icon and text), but without the button. Exam creation should only be triggered from outside this tab (e.g., via navigation-level controls), not from within the tab itself.

Look at the `build` method's `floatingActionButton` parameter and the `_buildEmpty` method's `if (isGloballyEmpty && _canManage && _configLoaded)` branch. Both need to be cleaned up.

The gold-standard for empty states in this project shows an icon + label + sublabel but no action button inside the list area.

---

### [x] Task 4: Fix Create Department modal — double header and unfocusable description field
**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_sheet.dart`, `eduxal/lib/ui/widgets/edu_form_field.dart`
**Depends on:** none
**Parallel group:** P1

**Problem:**
When a user taps the FAB on the Departments tab, `_showCreateDepartment()` calls `showEduSheet(context, builder: ...)` passing a `_CreateDepartmentSheet` widget as the builder result. The `_CreateDepartmentSheet.build` method manually builds its own complete bottom sheet container from scratch — it renders its own drag-handle pill, its own "New Department" title text, and its own padding/column — as if it were a raw `showModalBottomSheet` child.

However, `showEduSheet` on mobile already wraps the builder result inside an `EduSheet`, which renders its own drag-handle and (if a `title` is passed) its own header. In this case no `title` is passed to `showEduSheet`, so only one `EduSheet` header appears — but the `_CreateDepartmentSheet` itself still manually draws its own handle + title, resulting in the handle and title appearing duplicated or at odds with the surrounding `EduSheet` container.

Additionally, the description field (`_descCtrl`) uses `EduFormField` but the field is reportedly not focusable or selectable on mobile. The issue may be related to how the field is wrapped inside `SafeArea` + `Padding(viewInsets)` inside a `Column(mainAxisSize: min)` — the combined layout may be clipping or intercepting taps on the second field.

The fix should make the department creation form consistent with the `EduSheet` design system: let `showEduSheet` own the container, handle, and title; the form body should only contain the fields and the save button. Study `eduxal/lib/ui/widgets/edu_sheet.dart` and `eduxal/lib/ui/widgets/create_term_modal.dart` for reference on how forms are composed inside `showEduSheet`.

Also check the `SafeArea` wrapper and the `viewInsets` padding inside `_CreateDepartmentSheet.build` — these are almost certainly causing layout conflicts with `EduSheet`'s own `viewInsets` handling (double-applying the keyboard inset).

---

### [ ] Task 5: Fix member creation panels — form field styling and keyboard/modal layout issues
**Files to modify:**
- `eduxal/lib/ui/widgets/member_creation/phone_first_panel.dart`
- `eduxal/lib/ui/widgets/member_creation/add_teacher_panel.dart`
- `eduxal/lib/ui/widgets/member_creation/add_staff_panel.dart`
- `eduxal/lib/ui/widgets/member_creation/add_student_panel.dart`
- `eduxal/lib/ui/widgets/member_creation/add_guardian_panel.dart`
- `eduxal/lib/ui/widgets/member_creation/add_owner_panel.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_sheet.dart`, `eduxal/lib/ui/widgets/edu_form_field.dart`, `eduxal/lib/ui/widgets/create_term_modal.dart`
**Depends on:** none
**Parallel group:** P2

**Problem:**
The member creation modals (Owner, Teacher, Staff, Student, Guardian) are launched via `showEduSheet`, which wraps them in an `EduSheet`. However the panels have two style issues:

**Issue A — "Purplish" form field colour:**
The `_StyledInput` widget inside `phone_first_panel.dart` and the extra-fields widgets in the teacher/staff/student/guardian panels use a custom `Container + TextField` pattern with `Color(0xFF1E2A3A)` fill and their own border styling. On light mode this produces a dark blue/purple tint on the input fields that clashes with the rest of the UI. The input fields should use `EduFormField` (from `eduxal/lib/ui/widgets/edu_form_field.dart`) or at minimum adopt the same fill colours: `cs.surfaceContainerLowest` on light and `Color(0xFF1E2A3A)` on dark, with no tint visible in light mode.

**Issue B — Keyboard "shoots the modal up":**
When the keyboard appears, the modal jumps upward and leaves a white gap between the keyboard top and the modal content bottom. This is a classic symptom of `resizeToAvoidBottomInset` being `true` on the route (or the `Scaffold` inside the sheet), combined with the sheet itself also applying `MediaQuery.viewInsets.bottom` padding — causing the keyboard inset to be applied twice. Study how `EduSheet` handles `viewInsets` (it applies `Padding(EdgeInsets.only(bottom: viewInsets.bottom))`) and check whether any inner widget is also listening to `viewInsets` or is inside a `Scaffold` with `resizeToAvoidBottomInset` not explicitly set to `false`.

**Issue C — Large top border radius on mobile sheet:**
The mobile bottom sheet has an overly large top border radius (e.g. `Radius.circular(20)` from `AppTheme._sheetRadius`). Per the design guidelines, modal containers should use `AppTheme.kModalRadius = 12.0` for the top corners. Check the `EduSheet` radius value and whether it matches the design spec.

The gold-standard reference modal is `eduxal/lib/ui/widgets/create_term_modal.dart` — specifically `_CreateTermSheet`. Compare how it composes its container and handles keyboard insets vs. how the member creation panels do it.

---

### [x] Task 6: Fix Announcements compose sheet — double header, white overlay on inputs, keyboard jump
**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_sheet.dart`, `eduxal/lib/ui/widgets/edu_form_field.dart`
**Depends on:** none
**Parallel group:** P1

**Problem:**
The `_showComposeSheet` function calls `showEduSheet(context, builder: ...)` and passes a `_ComposeSheet` widget. On mobile, `showEduSheet` wraps the content in an `EduSheet` which renders its own drag-handle and optional title row. However, `_ComposeSheet.build` manually renders its own complete container from scratch: it applies its own `BoxDecoration` with `color: cs.surface` and `borderRadius: BorderRadius.vertical(top: Radius.circular(14))`, and it also draws its own drag-handle, its own header row with the "New Announcement" / "Edit Announcement" title and a Publish button. 

This creates a double-header situation: `EduSheet` renders a handle + (no title, since none is passed), then `_ComposeSheet` renders its own handle and header on top of the already-themed `EduSheet` container. The `_ComposeSheet.build` returns a `Container` with its own `BoxDecoration` wrapping — this `Container` sits inside `EduSheet`'s own container, causing a white/opaque layer to appear on top of the modal background.

Additionally, `_ComposeSheet` applies `Padding(EdgeInsets.only(bottom: mq.viewInsets.bottom))` at the same level that `EduSheet` also applies keyboard inset padding — causing the double-inset keyboard-jump bug.

The input fields in `_ComposeSheet` use a private `_SheetField` widget that renders with `cs.surfaceContainerHighest` fill — which in some colour scheme configurations can produce a white or light overlay on top of the `EduSheet` background colour, making the fields look hidden or ghosted while still accepting input.

The fix should remove `_ComposeSheet`'s manual container wrapping, delegate the handle/title to `showEduSheet`/`EduSheet`, and let keyboard inset handling happen in exactly one place. The `_SheetField` widget's fill colour should be verified to be legible against `AppTheme.modalBg`.

---

### [x] Task 7: Fix Create Fee Structure modal — container layering (white overlay)
**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_sheet.dart`
**Depends on:** none
**Parallel group:** P1

**Problem:**
The `_showCreateFeeSheet` function calls `showEduSheet(context, builder: ...)`, which wraps the result in an `EduSheet` with its own `AppTheme.modalBg` background, drag-handle, and border. However, `_CreateFeeSheetState.build` returns its own `Padding + Container` that contains a `SingleChildScrollView` — and crucially, the `Container` adds additional padding (`EdgeInsets.fromLTRB(24, 20, 24, 24)`) and draws its own drag-handle pill and "Create Fee Structure" title header.

This means the modal has `EduSheet`'s container as the outer layer, then `_CreateFeeSheetState`'s own `Padding` applying `viewInsets.bottom` as a separate inner layer — double-applying the keyboard inset. Furthermore, any background colour from the inner `Container` (if present) sits on top of `EduSheet`'s `AppTheme.modalBg`, producing a visible layer/overlay on top of the modal.

The field styling also uses a private `_SheetField` and `_fieldDecoration` that apply `AppTheme.kRadius` (12.0) for field border radius — which is correct — but the overall padding and container structure must be restructured to delegate to `showEduSheet`/`EduSheet` properly: remove the manual handle + header from the build method, pass a `title` to `showEduSheet` instead, and let keyboard inset be handled solely by `EduSheet`.

---

### [x] Task 8: Fix mobile grade-entry sheet (paper detail) — modal layout and styling
**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_sheet.dart`
**Depends on:** none
**Parallel group:** P1

**Problem:**
In the Paper Detail page, tapping a student row (on mobile) opens `_MobileGradeEntrySheet` via `showEduSheet`. The `_MobileGradeEntrySheet.build` returns a `Padding(EdgeInsets.only(bottom: viewInsets.bottom)) + Container` structure with its own `BoxDecoration` (colour `cs.surface`, radius `BorderRadius.vertical(top: Radius.circular(12))`), its own drag-handle, and its own student-name header. It then applies `viewInsets.bottom` padding internally.

This reproduces the same double-container + double-keyboard-inset pattern seen in the other sheets: `EduSheet` wraps it in `AppTheme.modalBg` with `viewInsets` padding AND the inner widget adds its own `viewInsets` padding and `cs.surface` colour on top — resulting in a visible white/opaque layer appearing above the keyboard when it opens, and the modal jumping on keyboard appearance.

Additionally, `_MobileGradeEntrySheet` draws its own drag-handle and header, while `showEduSheet` in `_openGradeEntry` does not pass a `title`, so the handle from `EduSheet` and the handle from the inner widget are stacked.

Similarly, `_openStudentActionSheet` in `_GradeListState` calls `showEduSheet` with a `title` but the inner `Column` also starts with padding that may conflict with `EduSheet`'s title row.

The fix should align these sheets with the `EduSheet` design contract: the inner widget should only provide form content (no wrapping container, no handle, no `viewInsets` padding of its own), and `showEduSheet` should handle the outer chrome. Read `eduxal/lib/ui/widgets/edu_sheet.dart` to understand what `EduSheet` already provides before adding anything in the inner widget.

---

### [x] Task 9: Fix Members tab search bar — always-visible, properly sized
**Files to modify:** `eduxal/lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_data_table.dart`
**Depends on:** none
**Parallel group:** P2

**Problem:**
In the Members page, each tab (Owners, Teachers, Staff, Students, Guardians) uses `_FlatMemberList` which renders a search toolbar. In its current state, when `showSearch = false`, the search bar is completely hidden and only a small `32×32` `IconButton` with `Icons.search_rounded` appears, positioned at the far right via `const Spacer()`. The user must tap the icon button to reveal the search field — this is the "hidden behind a search icon" issue.

The Departments tab uses `EduDataTable` which has its own search toolbar (via the `showSearch` / `onToggleSearch` mechanism from `edu_data_table.dart`) — check whether it exhibits the same behaviour.

The expected behaviour is that the search bar should always be visible in the toolbar area without requiring a toggle tap. The search field should be appropriately wide (full-width or near-full-width of the toolbar), use a reasonable height (around 36–40px), and have the standard search icon as a prefix inside the field — not as a separate toggle button.

Study the current `_FlatMemberList.build` method's search toolbar logic (the `if (showSearch)` branch) and the state management in each tab state (e.g. `_OwnersTabState`, `_TeachersTabState`, etc.) to understand how `_showSearch`, `onToggleSearch`, and `onSearchChanged` are wired. The fix should make the field permanently visible: always showing the `TextField` and removing the toggle-to-reveal pattern. The close/clear button can remain when there is active text, but the field itself should not be hidden.

---

### [ ] Task 10: Normalise mobile bottom-sheet top border radius across all modals
**Files to modify:**
- `eduxal/lib/ui/widgets/edu_sheet.dart`
- `eduxal/lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
- `eduxal/lib/ui/screens/school_dashboard/finance/finance_screen.dart`
- `eduxal/lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
- `eduxal/lib/ui/screens/school_dashboard/members/members_page.dart`
- `eduxal/lib/ui/widgets/create_term_modal.dart`
**Context files to read (if needed):** `eduxal/lib/ui/theme/app_theme.dart`
**Depends on:** Task 4, Task 6, Task 7, Task 8 (those tasks may restructure the inner widgets; this task corrects the radius on the outer container)
**Parallel group:** P3

**Problem:**
Mobile bottom sheets currently use an overly large top corner radius. Inspection of the codebase shows:

- `EduSheet` uses `Radius.circular(16)` in its `BorderRadius.only(topLeft, topRight)` decoration.
- `_CreateTermSheet` uses `Radius.circular(16)` for its top corners.
- `_ComposeSheet` (announcements) uses `Radius.circular(14)` in its own container.
- `_CreateFeeSheet` (finance) uses no explicit radius on its inner container (delegates to `EduSheet`).
- `_MobileGradeEntrySheet` uses `Radius.circular(12)` in its own `BoxDecoration`.
- `AppTheme._sheetRadius` defines `Radius.circular(20)` — the largest value, not currently used by `EduSheet` but referenced elsewhere.

The design guideline in `AGENT.md §21` states: modal/dialog containers should use `AppTheme.kModalRadius = 12.0`. This is the single source of truth for modal corner radii. All bottom sheets should use `12.0` for their top corners, not `14`, `16`, or `20`.

The fix should ensure that `EduSheet` uses `AppTheme.kModalRadius` (12.0) for its top corner radii, and that any inner widget that still manually applies its own container radius (after Tasks 4–8 are done) is also corrected. The `_CreateTermSheet` should also be updated to use `AppTheme.kModalRadius` for consistency. Do NOT change dialog corner radii — `AppTheme.kModalRadius` applies to dialogs too and that is correct as-is.

Note: Tasks 4, 6, 7, and 8 may restructure some of the inner containers. This task should be done after those are complete to avoid conflicts, and should sweep all affected files to verify consistency.

---

### [x] Task 1: Implement S3 file upload (push) and download (watch) in the sync engine

**Files to create/modify:**
- `lib/sync/sync_engine.dart` — add `_handleFileUrls()`, call it from `_processActionResponse()` and `_onDelta()`
- `lib/cache/file_cache.dart` — add `upload()` static method for HTTP PUT

**Context files to read (if needed):** none — all necessary code is inlined below

**Depends on:** none
**Parallel group:** P1

---

**Specification:**

#### Background

The proto `FileUrl` message has four fields:
- `path` (String) — relative path matching `FileCache` conventions, e.g. `"users/{id}/profile"`, `"schools/{schoolId}/students/{adm}/image"`, `"schools/{schoolId}/logo"`
- `putUrl` (String) — signed S3 PUT URL, valid ~1 hour, used by the **action originator** to upload the file bytes to S3
- `getUrl` (String) — signed S3 GET URL, valid ~1 month, used by **all other clients** to download the file
- `expiry` (Int64) — ms since epoch when the GET URL expires

`ActionResponse` (field 6) carries `fileUrls` — these arrive on the **device that performed the action** (e.g. the device that called `saveStudentImage`). This device already has the file locally at `FileCache`'s resolved path. It must PUT the local file bytes to `putUrl`.

`SyncDelta` (field 6) also carries `fileUrls` — these arrive on **all other devices** via the watch stream. These devices do NOT have the file locally. They must GET-download from `getUrl` using `FileCache.download()`.

Both the originator device AND other devices may receive `fileUrls` in `SyncDelta` (the server broadcasts to all watchers including the originator). So the download path must be safe to call even when the file already exists — `FileCache.download()` already overwrites, which is fine.

---

#### Step 1 — Add `FileCache.upload()` to `lib/cache/file_cache.dart`

Add this static method to the `FileCache` class, after the existing `download()` method:

```dart
/// Uploads the file at [relativePath] to S3 via HTTP PUT to [putUrl].
///
/// The file must already exist locally (e.g. saved by [saveBytes] or
/// copied from image_picker). Returns `true` on success, `false` on any
/// error (file missing, network error, non-2xx response).
///
/// Content-Type is always `application/octet-stream` — the server accepts
/// any binary content for file fields.
static Future<bool> upload(String putUrl, String relativePath) async {
  try {
    final file = await _resolve(relativePath);
    if (!file.existsSync()) return false;

    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse(putUrl));
      final length = await file.length();
      request.headers.set(HttpHeaders.contentLengthHeader, length.toString());
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/octet-stream',
      );
      await request.addStream(file.openRead());
      final response = await request.close();
      // Drain response body to allow connection reuse.
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } finally {
      client.close(force: false);
    }
  } catch (_) {
    return false;
  }
}
```

The import `dart:io` is already present in `file_cache.dart`.

---

#### Step 2 — Add `_handleFileUrls()` to `lib/sync/sync_engine.dart`

Add this private method to the `SyncEngine` class. Place it just after `_applyActionRow()` (after line 600):

```dart
/// Handles [FileUrl] entries from either an [ActionResponse] or a [SyncDelta].
///
/// - If [isPushOriginator] is `true`: this device performed the action and
///   already has the file locally. For each URL that has a non-empty [putUrl],
///   upload the local file to S3. Skip entries with empty [putUrl].
///
/// - If [isPushOriginator] is `false` (watch stream delta): this device is a
///   watcher. For each URL that has a non-empty [getUrl], download the file
///   from S3 into the local cache. Skip entries with empty [getUrl].
///
/// Errors in individual file operations are logged but do not throw —
/// a failed upload/download should not abort the sync engine.
Future<void> _handleFileUrls(
  List<sync_pb.FileUrl> fileUrls, {
  required bool isPushOriginator,
}) async {
  for (final fileUrl in fileUrls) {
    final path = fileUrl.path;
    if (path.isEmpty) continue;

    if (isPushOriginator) {
      final putUrl = fileUrl.putUrl;
      if (putUrl.isEmpty) continue;
      debugPrint(
        '[SyncEngine] Uploading file: path=$path',
      );
      final ok = await FileCache.upload(putUrl, path);
      if (ok) {
        debugPrint('[SyncEngine] Upload OK: path=$path');
      } else {
        debugPrint('[SyncEngine] Upload FAILED: path=$path');
      }
    } else {
      final getUrl = fileUrl.getUrl;
      if (getUrl.isEmpty) continue;
      debugPrint(
        '[SyncEngine] Downloading file: path=$path',
      );
      final file = await FileCache.download(getUrl, path);
      if (file != null) {
        debugPrint('[SyncEngine] Download OK: path=$path');
      } else {
        debugPrint('[SyncEngine] Download FAILED: path=$path');
      }
    }
  }
}
```

---

#### Step 3 — Call `_handleFileUrls()` from `_processActionResponse()`

In `_processActionResponse()` (lines 500–581), after the `if (response.success)` block deletes the log AND after the `case 2: conflict` block deletes the log, add the file URL handling. The method should call `_handleFileUrls` with `isPushOriginator: true` whenever the response is successful (code 0) or a conflict resolution (code 2) — both cases delete the log and mean the server accepted the data.

The existing method body ends with a comment block and a `catch`. Modify the success branch and case-2 conflict branch as follows:

In the `if (response.success)` branch, after `await _logsDao.deleteLog(logId);`, add:
```dart
// Upload local files to S3 if the server provided PUT URLs.
if (response.fileUrls.isNotEmpty) {
  await _handleFileUrls(response.fileUrls, isPushOriginator: true);
}
```

In `case 2:` (conflict), after `await _logsDao.deleteLog(logId);`, add:
```dart
if (response.fileUrls.isNotEmpty) {
  await _handleFileUrls(response.fileUrls, isPushOriginator: true);
}
```

---

#### Step 4 — Call `_handleFileUrls()` from `_onDelta()`

In `_onDelta()` (lines 674–762), after the sentinel check (`if (delta.table == 0) { ... return; }`) and after `await _deltaWriter.apply(delta);`, add:

```dart
// Download files from S3 if the server provided GET URLs.
if (delta.fileUrls.isNotEmpty) {
  await _handleFileUrls(delta.fileUrls, isPushOriginator: false);
}
```

This must come AFTER `_deltaWriter.apply(delta)` so the row data is written before files are downloaded.

---

#### Step 5 — Add `FileCache` import to `sync_engine.dart`

`sync_engine.dart` does not currently import `file_cache.dart`. Add this import at the top of the file alongside the other local imports:

```dart
import '../cache/file_cache.dart';
```

---

**After completion:**
- [x] Update `lib/sync/CONTEXT.md` if it exists — add note about `_handleFileUrls` in `SyncEngine`
- [x] Update `lib/cache/CONTEXT.md` if it exists — add note about `FileCache.upload()`
- [x] Mark this task `[x]`
- [x] Run `git add -A && git commit -m "feat: implement S3 file upload and download in sync engine (push + watch)"`

---

### [x] Task 2: Add year picker to InlineCalendar and replace all showDatePicker call sites

**Files to create/modify:**
- `lib/ui/widgets/inline_calendar.dart` — add year-picker mode to the existing widget
- `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart` — replace `showDatePicker` (L2960–2968)
- `lib/ui/screens/school_dashboard/academics/tabs/attendance_tab.dart` — replace `showDatePicker` (L187–197)
- `lib/ui/screens/school_dashboard/finance/finance_screen.dart` — replace `showDatePicker` (L2344–2354)
- `lib/ui/screens/school_dashboard/members/members_page.dart` — replace `showDatePicker` (L3560–3570)
- `lib/ui/screens/system/schools/create_school_sheet.dart` — replace `showDatePicker` (L334–344)

**Context files to read (if needed):** none — all necessary code is inlined below

**Depends on:** none
**Parallel group:** P1 (can run in parallel with Task 1 — different files)

---

**Specification:**

#### Part A — Patch `InlineCalendar` with a year-picker mode

The full current file is at `lib/ui/widgets/inline_calendar.dart`. It contains:
- `InlineCalendar` (StatefulWidget + `_InlineCalendarState`) — the collapsible trigger + animated body
- `_CalendarGrid` (StatelessWidget) — renders the month header, day-of-week row, and day cells
- `_DayCell` (StatelessWidget) — individual day cell
- `_NavArrow` (StatelessWidget) — left/right chevron button

**What to add:**

Add a boolean state field `_showYearPicker` to `_InlineCalendarState` (default `false`). When `true`, `_CalendarGrid` renders a scrollable year-grid instead of the day grid. When the user taps a year, `_showYearPicker` becomes `false` and `_viewMonth` snaps to that year (keeping the current month).

**Changes to `_InlineCalendarState`:**

Add field:
```dart
bool _showYearPicker = false;
```

Add method:
```dart
void _toggleYearPicker() {
  setState(() => _showYearPicker = !_showYearPicker);
}

void _selectYear(int year) {
  setState(() {
    _showYearPicker = false;
    // Clamp the month to firstDate/lastDate bounds in the selected year.
    int month = _viewMonth.month;
    if (year == widget.firstDate.year && month < widget.firstDate.month) {
      month = widget.firstDate.month;
    }
    if (year == widget.lastDate.year && month > widget.lastDate.month) {
      month = widget.lastDate.month;
    }
    _viewMonth = DateTime(year, month);
  });
}
```

Pass `_showYearPicker`, `_toggleYearPicker`, and `_selectYear` down to `_CalendarGrid`.

**Changes to `_CalendarGrid`:**

Add required constructor params:
```dart
required this.showYearPicker,
required this.onToggleYearPicker,
required this.onYearSelected,
```

Add fields:
```dart
final bool showYearPicker;
final VoidCallback onToggleYearPicker;
final ValueChanged<int> onYearSelected;
```

In `_CalendarGrid.build()`, make the month/year header label tappable. Replace the existing plain `Text('${_kMonthNames[...]} ${viewMonth.year}', ...)` with:

```dart
GestureDetector(
  onTap: onToggleYearPicker,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        showYearPicker
            ? '${viewMonth.year}'
            : '${_kMonthNames[viewMonth.month - 1]} ${viewMonth.year}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
          letterSpacing: 0.1,
        ),
      ),
      const SizedBox(width: 4),
      AnimatedRotation(
        turns: showYearPicker ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          Icons.keyboard_arrow_down,
          size: 14,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    ],
  ),
),
```

In `_CalendarGrid.build()`, after the header row and before the day-of-week row, use a conditional to switch the body content:

```dart
if (showYearPicker)
  _YearGrid(
    firstYear: firstDate.year,
    lastYear: lastDate.year,
    currentYear: viewMonth.year,
    accent: accent,
    cs: cs,
    isDark: isDark,
    onYearSelected: onYearSelected,
  )
else ...[
  const SizedBox(height: 6),
  // day-of-week header row
  // day grid rows
]
```

The left/right nav arrows should be hidden (or disabled) when `showYearPicker` is true — replace the `_NavArrow` widgets with invisible `SizedBox(width: 32)` placeholders when `showYearPicker` is true.

**New `_YearGrid` widget (add at the bottom of the file):**

```dart
class _YearGrid extends StatefulWidget {
  const _YearGrid({
    required this.firstYear,
    required this.lastYear,
    required this.currentYear,
    required this.accent,
    required this.cs,
    required this.isDark,
    required this.onYearSelected,
  });

  final int firstYear;
  final int lastYear;
  final int currentYear;
  final Color accent;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<int> onYearSelected;

  @override
  State<_YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<_YearGrid> {
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    // Pre-scroll so the current year is roughly centred.
    final totalYears = widget.lastYear - widget.firstYear + 1;
    final currentIndex = widget.currentYear - widget.firstYear;
    // 3 columns, each row ~40px tall.
    final rowIndex = currentIndex ~/ 3;
    final totalRows = (totalYears / 3).ceil();
    // Show ~4 rows (160px). Offset so current row is in the middle.
    const visibleRows = 4.0;
    const rowHeight = 40.0;
    final maxScroll = (totalRows - visibleRows).clamp(0, double.infinity) * rowHeight;
    final targetScroll = ((rowIndex - visibleRows / 2) * rowHeight)
        .clamp(0.0, maxScroll.toDouble());
    _scrollCtrl = ScrollController(initialScrollOffset: targetScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      widget.lastYear - widget.firstYear + 1,
      (i) => widget.firstYear + i,
    );

    // Build rows of 3.
    final rows = <Widget>[];
    for (var i = 0; i < years.length; i += 3) {
      final rowYears = years.skip(i).take(3).toList();
      rows.add(
        Row(
          children: [
            for (final year in rowYears)
              Expanded(
                child: _YearCell(
                  year: year,
                  isSelected: year == widget.currentYear,
                  accent: widget.accent,
                  cs: widget.cs,
                  onTap: () => widget.onYearSelected(year),
                ),
              ),
            // Pad incomplete last row.
            for (var p = rowYears.length; p < 3; p++) const Expanded(child: SizedBox()),
          ],
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: rows,
      ),
    );
  }
}

class _YearCell extends StatelessWidget {
  const _YearCell({
    required this.year,
    required this.isSelected,
    required this.accent,
    required this.cs,
    required this.onTap,
  });

  final int year;
  final bool isSelected;
  final Color accent;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accent : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$year',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? Colors.white : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
```

---

#### Part B — Add a `showInlineDatePicker()` dialog helper

Add a new file `lib/ui/widgets/inline_date_picker_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'inline_calendar.dart';

/// Shows [InlineCalendar] inside a styled modal dialog.
///
/// This is a drop-in replacement for Flutter's [showDatePicker] that uses
/// the custom [InlineCalendar] widget (with year-picker support) instead of
/// the Material date picker dialog.
///
/// Returns the selected [DateTime], or `null` if the user dismissed without
/// selecting.
///
/// ```dart
/// final picked = await showInlineDatePicker(
///   context: context,
///   initialDate: _selectedDate,
///   firstDate: DateTime(1990),
///   lastDate: DateTime.now(),
/// );
/// if (picked != null) setState(() => _selectedDate = picked);
/// ```
Future<DateTime?> showInlineDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Select date',
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) {
      return _InlineDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
      );
    },
  );
}

class _InlineDatePickerDialog extends StatefulWidget {
  const _InlineDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  @override
  State<_InlineDatePickerDialog> createState() =>
      _InlineDatePickerDialogState();
}

class _InlineDatePickerDialogState extends State<_InlineDatePickerDialog> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
          boxShadow: AppTheme.modalShadow(isDark),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),

            // Calendar — starts expanded (no trigger row needed inside dialog)
            _InlineCalendarExpanded(
              value: _selected,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onChanged: (d) {
                setState(() => _selected = d);
                // Auto-close with a short delay so the user sees the selection.
                if (d != null) {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (context.mounted) Navigator.of(context).pop(d);
                  });
                }
              },
            ),

            const SizedBox(height: 8),

            // Cancel button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A version of [InlineCalendar] that renders always-expanded (no trigger row,
/// no collapse animation). Used inside the dialog where the calendar should
/// always be visible.
class _InlineCalendarExpanded extends StatefulWidget {
  const _InlineCalendarExpanded({
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<_InlineCalendarExpanded> createState() =>
      _InlineCalendarExpandedState();
}

class _InlineCalendarExpandedState extends State<_InlineCalendarExpanded> {
  late DateTime _viewMonth;
  bool _showYearPicker = false;

  @override
  void initState() {
    super.initState();
    final base = widget.value ?? DateTime.now();
    // Clamp to valid range.
    final clamped = base.isBefore(widget.firstDate)
        ? widget.firstDate
        : base.isAfter(widget.lastDate)
            ? widget.lastDate
            : base;
    _viewMonth = DateTime(clamped.year, clamped.month);
  }

  void _prevMonth() {
    final prev = DateTime(_viewMonth.year, _viewMonth.month - 1);
    if (!prev.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month))) {
      setState(() => _viewMonth = prev);
    }
  }

  void _nextMonth() {
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    if (!next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month))) {
      setState(() => _viewMonth = next);
    }
  }

  void _toggleYearPicker() {
    setState(() => _showYearPicker = !_showYearPicker);
  }

  void _selectYear(int year) {
    setState(() {
      _showYearPicker = false;
      int month = _viewMonth.month;
      if (year == widget.firstDate.year && month < widget.firstDate.month) {
        month = widget.firstDate.month;
      }
      if (year == widget.lastDate.year && month > widget.lastDate.month) {
        month = widget.lastDate.month;
      }
      _viewMonth = DateTime(year, month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return _CalendarGrid(
      viewMonth: _viewMonth,
      selected: widget.value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      accent: accent,
      cs: cs,
      isDark: isDark,
      showYearPicker: _showYearPicker,
      onPrevMonth: _prevMonth,
      onNextMonth: _nextMonth,
      onDayTap: (d) => widget.onChanged(d),
      onToggleYearPicker: _toggleYearPicker,
      onYearSelected: _selectYear,
    );
  }
}
```

Note: `_CalendarGrid`, `_YearGrid`, `_YearCell` are defined in `inline_calendar.dart`. Since `inline_date_picker_dialog.dart` needs access to `_CalendarGrid` (which starts with `_` making it file-private), there are two options:

**Preferred approach:** Make `_CalendarGrid` package-private by renaming it to `CalendarGrid` (removing the leading underscore) in `inline_calendar.dart`, and have `_InlineCalendarExpanded` use `CalendarGrid` directly. This avoids code duplication.

Alternatively, duplicate the always-expanded implementation inside the dialog file. **Use the rename approach** — it is cleaner.

So in `inline_calendar.dart`, rename `_CalendarGrid` → `CalendarGrid`, `_DayCell` → `DayCell`, `_NavArrow` → `NavArrow`, `_YearGrid` → `YearGrid`, `_YearCell` → `YearCell`. Update all references within the same file. These are all leaf rendering widgets — making them non-private is safe since they have no exported API surface that would invite misuse.

---

#### Part C — Replace all `showDatePicker` call sites

For each call site below, replace the `showDatePicker(...)` call with `showInlineDatePicker(...)`. Add the import `import 'package:eduxal/ui/widgets/inline_date_picker_dialog.dart';` (or the relative equivalent) to each file. Remove any `builder:` parameter that was only used for theme wrapping — `showInlineDatePicker` handles theming internally.

**Site 1 — `grade_detail_page.dart` L2960–2968:**
```dart
// BEFORE:
final picked = await showDatePicker(
  context: context,
  initialDate: date,
  firstDate: DateTime(2020),
  lastDate: DateTime(2050),
);

// AFTER:
final picked = await showInlineDatePicker(
  context: context,
  initialDate: date,
  firstDate: DateTime(2020),
  lastDate: DateTime(2050),
  title: 'Select date',
);
```

**Site 2 — `attendance_tab.dart` L187–199:**
```dart
// BEFORE:
final picked = await showDatePicker(
  context: context,
  initialDate: _selectedDate,
  firstDate: DateTime(2020),
  lastDate: DateTime.now(),
  builder: (context, child) {
    return Theme(data: Theme.of(context).copyWith(colorScheme: cs), child: child!);
  },
);

// AFTER:
final picked = await showInlineDatePicker(
  context: context,
  initialDate: _selectedDate,
  firstDate: DateTime(2020),
  lastDate: DateTime.now(),
  title: 'Select date',
);
// Remove the `cs` variable if it was only used for the builder.
```

**Site 3 — `finance_screen.dart` L2344–2362:**
```dart
// BEFORE:
final picked = await showDatePicker(
  context: context,
  initialDate: _dueDate,
  firstDate: DateTime.now(),
  lastDate: DateTime.now().add(const Duration(days: 365)),
  builder: (context, child) {
    return Theme(data: Theme.of(context).copyWith(colorScheme: cs), child: child!);
  },
);

// AFTER:
final picked = await showInlineDatePicker(
  context: context,
  initialDate: _dueDate,
  firstDate: DateTime.now(),
  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
  title: 'Due date',
);
// Also widen lastDate from 365 days to 365*3 days (3 years) so future
// school years are reachable — the prior 1-year limit was unnecessarily tight.
// Remove the `cs` variable if only used for the builder.
```

**Site 4 — `members_page.dart` L3560–3570:**
```dart
// BEFORE:
final picked = await showDatePicker(
  context: ctx,
  initialDate: hiredDate ?? DateTime.now(),
  firstDate: DateTime(1970),
  lastDate: DateTime.now(),
);

// AFTER:
final picked = await showInlineDatePicker(
  context: ctx,
  initialDate: hiredDate ?? DateTime.now(),
  firstDate: DateTime(1970),
  lastDate: DateTime.now(),
  title: 'Hire date',
);
```

**Site 5 — `create_school_sheet.dart` L334–344:**

Read the full `_pickEstablishedDate` method first (it has a DateTime conversion from days-since-epoch). Replace only the `showDatePicker(...)` call with `showInlineDatePicker(...)`, preserving all surrounding logic:

```dart
// BEFORE:
final picked = await showDatePicker(
  context: context,
  initialDate: _establishedDays != null
      ? DateTime.fromMillisecondsSinceEpoch(_establishedDays! * 86400 * 1000, isUtc: true)
      : now,
  firstDate: DateTime(1800),
  lastDate: now,
);

// AFTER:
final picked = await showInlineDatePicker(
  context: context,
  initialDate: _establishedDays != null
      ? DateTime.fromMillisecondsSinceEpoch(_establishedDays! * 86400 * 1000, isUtc: true)
      : now,
  firstDate: DateTime(1800),
  lastDate: now,
  title: 'Established date',
);
```

---

**After completion:**
- [ ] Ensure there are no remaining `showDatePicker` calls in the codebase (grep to verify)
- [ ] Check for any diagnostic errors
- [ ] Mark this task `[x]`
- [ ] Run `git add -A && git commit -m "feat: InlineCalendar year picker + replace all showDatePicker with custom dialog"`
```

Now let me spawn both executor agents in parallel: