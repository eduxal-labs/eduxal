# ui/ — UI Layer Context

> Flutter UI layer. No business logic permitted here — only stream/future consumption and presentation.
> Screens bind to `Stream<T>` and `Future<Result<T, E>>` from the services layer and DAOs.

## Overview

The UI layer contains **3 subdirectories** (screens, widgets, theme) and consumes reactive Drift streams + service results for all data display. State management is done via Drift reactive streams exposed as `Stream<T>`, `ValueNotifier<T>`, and `ChangeNotifier` — no external state management package.

## Directory Structure

```
ui/
├── CONTEXT.md              # This file
├── screens/
│   ├── CONTEXT.md          # Screen inventory with routes and dependencies
│   ├── account/            # User account/profile management
│   ├── auth/               # Login, OTP verification, setup
│   ├── home/               # Home screen — membership picker
│   ├── school_dashboard/   # School-scoped dashboard (the main app surface)
│   ├── splash/             # Splash/loading screen
│   └── system/             # System admin dashboard (super_/system users)
├── widgets/
│   ├── CONTEXT.md          # Shared widget inventory
│   ├── member_creation/    # Phone-first member creation panels
│   └── (shared widgets)    # Reusable components used across screens
└── theme/
    └── app_theme.dart      # Light/dark theme definitions
```

## Theme — `theme/app_theme.dart`

- **Status:** ✅ Complete
- **Exports:** `AppTheme` class with static methods:
  - `AppTheme.light()` → `ThemeData` — light theme.
  - `AppTheme.dark()` → `ThemeData` — dark theme.
  - `AppTheme.resolveThemeMode(AppThemeMode mode)` → `ThemeMode` — maps `AppThemeMode` enum to Flutter's `ThemeMode`.
- **Used by:** `main.dart` in the `MaterialApp` widget.
- **Dark theme surface staircase constants:**
  - `_slateBg` (`#0A0E13`) — scaffoldBg / surfaceContainerLowest
  - `_slateContainerLow` (`#10161F`) — surfaceContainerLow (added in Task A1)
  - `_slateSurface` (`#121A24`) — surface
  - `_slateContainer` (`#1A2435`) — surfaceContainer
  - `_slateContainerHigh` (`#1F2A3C`) — surfaceContainerHigh (added in Task A1)
  - `_slateItem` (`#243042`) — surfaceContainerHighest

## Key UI Patterns

### Data Binding
- Screens use `StreamBuilder<T>` to bind to DAO watch methods (e.g. `watchMemberships(userId)`).
- Fallible operations use `Future<Result<T, E>>` → consumed via `switch` on `Ok`/`Err`.
- Entry-sensitive data uses `ValueListenableBuilder<MembershipEntry>` on `SchoolContext.currentEntry`.
- Term-sensitive data uses `ValueListenableBuilder<Term?>` on `ActiveTermContext.termNotifier`.

### Navigation
- `SplashScreen` → checks `client.active()` → routes to `HomeScreen` or `LoginScreen`.
- `HomeScreen` → displays `SchoolMembership` cards → tapping enters `SchoolDashboardScreen`.
- `SchoolDashboardScreen` → responsive layout (sidebar on desktop, top tabs on mobile) → hosts all school-scoped pages.
- System dashboard is a separate route for `UserLevel.system` / `UserLevel.super_` users.

### Responsive Layout
- `LayoutBuilder` is used for responsive breakpoints in `SchoolDashboardScreen`:
  - **Desktop:** Fixed left navigation sidebar + content area.
  - **Mobile:** Scrollable top tabs for section navigation.
- Breakpoint logic avoids duplication between mobile/desktop where possible.

### School Dashboard Structure
The school dashboard uses `SchoolContext` (provided via `InheritedWidget` or similar) to scope all data:
- `SchoolContext.membership` — all entries for this school.
- `SchoolContext.permissions` — aggregated `SchoolPermissions` (constant for session).
- `SchoolContext.currentEntry` — `ValueNotifier<MembershipEntry>` for the active role.

Navigation items vary by role (determined by `currentEntry.role`):
- **Owner:** Overview | Academics | Members | Finance | Timetable | Roles
- **Teacher:** Core 4 always visible: Overview | Academics | Exams | Timetable. Permission-gated extras: Attendance | Members | Finance | Announcements | Roles
- **Staff:** Overview | Members | Finance | Attendance | Announcements
- **Student:** Overview | Timetable | Grades | Attendance
- **Guardian:** Overview | Attendance | Grades | Finance (read-only)

#### Mobile Tab Navigation
- **Teacher role:** Uses `_SimpleTabBar` — a scrollable, text-only `TabBar` with pill-style selected indicator (`cs.primary` bg, white text). No icons. Height 40px, font 12.5/w400, border radius `kChipRadius` (4.0). Uses `isScrollable: true` with `TabAlignment.start`.
- **All other roles:** Use `LoopingTabStrip` — the existing infinite-scrolling icon+label tab strip.

`ActiveTermContext` scopes all academic data to the selected year/term.

## Dependencies

- **Depends on:** `models/` (domain models, `SchoolContext`, `ActiveTermContext`, `Result`, `MembershipEntry`, etc.), `services/` (`Authentication`, `MemberCreationService`, `MemberManagementService`), `database/daos/` (global DAO singletons from `client.dart` for reactive streams), `core/` (constants, `grpc_errors.dart` for `toFriendlyMessage()`), `cache/file_cache.dart` (serving cached images), `client.dart` (global `client`, `cache`, DAO singletons).
- **Depended on by:** `main.dart` (imports `SplashScreen`, `AppTheme`).

## UI Design Guidelines

All design tokens are codified in `AppTheme` (`lib/ui/theme/app_theme.dart`) and documented in AGENT.md §21. Use the constants directly — do not hardcode values.

### Key Tokens

| Token / Helper | Value | Use |
|---|---|---|
| `AppTheme.kModalRadius` | `12.0` | Modal/dialog containers, bottom sheets |
| `AppTheme.kCardRadius` | `8.0` | Cards, inputs, buttons |
| `AppTheme.kChipRadius` | `4.0` | Chips, badges, small tags |
| `AppTheme.modalShadow(isDark)` | dual box-shadow | All dialogs and sheets |
| `AppTheme.tableRowDivider(isDark, cs)` | `0.5 px` divider | Between rows in data-table lists |
| `AppTheme.modalBg(isDark, cs)` | `#18222E` / `cs.surface` | Modal container background |
| `AppTheme.nestedBg(isDark, cs)` | `#1A2536` / `cs.surfaceContainerHighest` | Nested sections inside modals |
| `AppTheme.overlayBg(isDark, cs)` | `#1E2A3A` / `cs.surface` | Dropdown/popover background |
| `AppTheme.borderColor(isDark, cs)` | `#2A3848` / `cs.outlineVariant@0.6` | Container/card borders |

### Summary Rules
- Typography: `w300`/`w400` body, `w500` max headings. Never `w600`/`bold`.
- Radii: `kModalRadius(12)` for dialogs, `kCardRadius(8)` for cards/inputs, `kChipRadius(4)` for tags. Never `0` or `≥ 20`.
- Spacing: `12–16 px` internal padding, `6–8 px` between items. Never `20–32 px`.
- Back button: always `Icons.chevron_left_rounded` (size 22–24). Never `Icons.arrow_back`.
- Action buttons: always animated (`AnimatedSaveButton` pattern — scale, check flash, loading spinner).
- Lists: data-table style (rows + thin dividers), not card-based. Reference: `_GradeSpreadsheet` in `paper_detail_page.dart`.
- Gold-standard reference widget: `lib/ui/widgets/create_term_modal.dart` (`_CreateTermDialog`).

## Conventions

- No business logic in UI files — all logic goes through services/DAOs.
- No direct DB or gRPC imports in screen/widget files.
- Screens are stateful when they manage subscriptions, animation controllers, or form state.
- Shared widgets go in `widgets/`. Screen-specific widgets stay in their screen directory.
- `EduTabBar` (in `widgets/edu_tab_bar.dart`) is the **single source of truth** for all tab aesthetics — no raw `TabBar` in any screen.
- All tab surfaces in the app use `EduTabBar`, whether icon-only or text-label mode.

## Last Updated
Task A1: Added `TiptapRenderer` widget and `renderBody` helper to `lib/ui/widgets/tiptap_renderer.dart`. Added `flutter_math_fork: ^0.7.4` and `flutter_svg: ^2.0.10+1` to `pubspec.yaml`.

- `tiptap_renderer.dart` — new shared widget. `TiptapRenderer` is a read-only, stateless renderer for TipTap/ProseMirror JSON documents. Handles node types: `doc`, `paragraph`, `orderedList`, `bulletList`, `mathBlock`, `table`. Handles inline types: `text` (with bold/italic/code marks), `hardBreak`, `mathInline`. Math nodes rendered via `flutter_math_fork` (`Math.tex`). `renderBody(body, bodyFormat, {style})` is a convenience top-level helper: if `bodyFormat == 'tiptap'` returns a `TiptapRenderer`; otherwise returns a plain `Text` widget.

Previous:
AUTH-C05: `MemberActionError` converted to sealed class — UI switch expressions updated.

- `teachers_tab.dart` — 3 switch expressions updated: `case Err(error: MemberActionError.permissionDenied): showPermissionDenied(context, 'hardcoded')` replaced with `case Err(error: PermissionDenied(:final reason)): showPermissionDenied(context, reason)`. Affected handlers: `_TeachersTabState` Dismissible `confirmDismiss`, `_TeacherRow._confirmRemove()`, `_TeacherInfoSheetState._confirmRemove()`.
- `staff_tab.dart` — 2 switch expressions updated. Affected handlers: `_StaffTabState` Dismissible `confirmDismiss`, `_StaffInfoSheet._confirmRemove()`.
- `students_tab.dart` — 2 switch expressions updated. Affected handlers: `_StudentsTabState` Dismissible `confirmDismiss`, `_StudentRow._confirmDelete()`.
- `guardians_tab.dart` — 1 switch expression updated. Affected handler: `_WardItem._unlinkGuardian()`.
- `owners_tab.dart` — 3 switch expressions updated. Affected handlers: `_OwnersTabState` Dismissible `confirmDismiss`, `_OwnerRow._confirmRemoveOwner()`, `_OwnerInfoSheet._confirmRemoveOwner()`.
- `departments_tab.dart` — no changes needed (does not use `MemberActionError`).

All permission-denied UI messages now display the exact denial reason string from `AuthorizationService` rather than a hardcoded fallback.

Previous:
AUTH-C04: permission gating added to announcements, timetable, attendance, and members screens.

- `announcements_screen.dart` — **No visibility changes needed.** FAB (`canCreate`), edit/delete row actions (`canEdit`/`canDelete`) were already correctly gated. **Updated:** Added `permission_denied_handler.dart` import. Wrapped `_AnnouncementRowState._confirmDelete()` DAO call with `guardedAction()`. Added `context.mounted` guard before the call.

- `timetable_screen.dart` — **No visibility changes needed.** FABs (`canGenerate`, `canDelete`, `canGenerateLessons`, `canManage`) were already correctly gated. **Updated:** Added `permission_denied_handler.dart` and `authorization_service.dart` imports. Added `on PermissionException catch (e)` block in `_deleteTimetable()` (before `finally`) and in `_runGeneration()` (before the generic `catch (e)`) — both call `showPermissionDenied(context, e.reason)`.

- `attendance_tab.dart` — **No visibility changes needed.** `_canMark` resolution and `canMark` prop-gating of `_ActionBar` and `_StatusToggleGroup` were already in place. **Updated:** Added `permission_denied_handler.dart` import. Wrapped `_AttendanceMarkingBodyState._markAllPresent()` inner DAO call with `guardedAction()`. Wrapped `_AttendanceMarkingBodyState._markSingle()` DAO call with `guardedAction()`.

- `teachers_tab.dart` — **No visibility changes needed.** `_canDelete`/`_canEdit` getters already in place. **Updated:** Added `permission_denied_handler.dart` import. Added specific `case Err(error: MemberActionError.permissionDenied)` with `showPermissionDenied()` in three handlers: `_TeachersTabState` Dismissible `confirmDismiss`, `_TeacherRow._confirmRemove()`, and `_TeacherInfoSheetState._confirmRemove()`.

- `staff_tab.dart` — **No visibility changes needed.** `_canDelete`/`_canEdit` getters already in place. **Updated:** Added `permission_denied_handler.dart` import. Added `case Err(error: MemberActionError.permissionDenied)` handling in `_StaffTabState` Dismissible `confirmDismiss` and `_StaffInfoSheet._confirmRemove()`.

- `students_tab.dart` — **No visibility changes needed.** `_canDelete` getter already in place. **Updated:** Added `permission_denied_handler.dart` import. Added `case Err(error: MemberActionError.permissionDenied)` handling in `_StudentsTabState` Dismissible `confirmDismiss` and `_StudentRow._confirmDelete()`.

- `guardians_tab.dart` — **No visibility changes needed.** `_canEditGuardian`/`_canUnlinkGuardian` getters already in place. **Updated:** Added `permission_denied_handler.dart` import. `_WardItem._unlinkGuardian()` previously ignored the return value of `service.removeGuardian()` — now captures result and handles `MemberActionError.permissionDenied` with `showPermissionDenied()`.

- `owners_tab.dart` — **No visibility changes needed.** `_canDelete` getter already in place. **Updated:** Added `permission_denied_handler.dart` import. Added `case Err(error: MemberActionError.permissionDenied)` handling in `_OwnersTabState` Dismissible `confirmDismiss`, `_OwnerRow._confirmRemoveOwner()`, and `_OwnerInfoSheet._confirmRemoveOwner()`.

- `departments_tab.dart` — **No visibility changes needed.** `_canDelete` and `_canDeleteDept`/`_canUpdateDept` getters already in place. **Updated:** Added `permission_denied_handler.dart` import. Wrapped `_DepartmentsTabState._confirmDeleteDepartment()` DAO call with `guardedAction()`. In `_DepartmentDetailScreenState`: wrapped `_confirmDelete()` DAO call with `guardedAction()` + `deleted` flag to guard nav pop, and wrapped `_removeTeacher()`/`_removeStaff()` DAO calls with `guardedAction()`.

- `members_page.dart` — **No changes needed.** FAB visibility already gated by `_canCreateForCurrentTab()` which checks the relevant `Resource`/`Action.create` per tab.

Previous:
AUTH-C06: permission gating added to system dashboard.

- `screens/system/plans/plans_section.dart` — **Updated.** Added `if (permissions.can(Resource.plans, Action.update))` guard to the Edit row-action button in `_PlansSectionState.build()`. Previously the Edit `EduDataTableAction` was always shown regardless of permissions. All other system dashboard screens were already fully permission-gated (no changes required).

Previous:
AUTH-C02: permission gating added to exams and grades screens.

- `exam_creation_page.dart` — **Updated.** Added imports for `authorization_service.dart` and `permission_denied_handler.dart`. Added `on PermissionException catch (e)` block before the generic `catch (e, stack)` in `_save()` — shows permission-denied snackbar and resets `_saving = false`.
- `create_paper_sheet.dart` — **Updated.** Added imports for `authorization_service.dart` and `permission_denied_handler.dart`. Added `on PermissionException catch (e)` block before `finally` in `_save()`.
- `paper_detail_page.dart` — **Updated.** Added imports for `authorization_service.dart` and `permission_denied_handler.dart`. Added `on PermissionException catch (e)` blocks to: `_PaperHeaderState._advance()`, `_PaperHeaderState._deletePaper()`, `_GradeSpreadsheetState._saveRow()`, `_GradeSpreadsheetState._quickGrade()`, `_GradeListState._quickGrade()`, and `_MobileGradeEntrySheetState._save()`. All visibility gates (`canManage`, `canGrade`, `canEdit`) were already correctly in place.
- `grade_detail_page.dart` — **Updated.** Added imports for `authorization_service.dart` and `permission_denied_handler.dart`. Added `on PermissionException catch (e)` block before the generic `catch (e, stack)` in `_CreateExamFromGradeSheetState._save()`.
- `exam_list_view.dart` — **No changes needed.** Create-exam FAB already gated by `_canCreateExam` (checks `Resource.exams / Action.create`). No delete-row button exists on exam list rows.
- `exam_detail_page.dart` — **No changes needed.** Read-only page (Papers/Grades/Performance tabs). No mutation buttons. `schoolContext` already properly threaded to `_PapersTab` → `PaperDetailPage`. The add-paper/edit/delete-exam functionality lives in `exam_group_detail_view.dart` (which already has `_canCreateExam`, `_canEditExam`, `_canDeleteExam` gates).

Previous: AUTH-C03: permission gating added to finance screens.

- `finance_screen.dart` — **Updated.** Added imports for `authorization_service.dart` and `permission_denied_handler.dart`. Wrapped `_CreateFeeSheetState._save()` and `_RecordPaymentSheetState._save()` mutation paths with `on PermissionException catch (e)` blocks (before the generic `catch (e)`) that call `showPermissionDenied(context, e.reason)` and reset `_saving = false`. All visibility-level permission gates were already in place: `_FeesTab` FAB gated by `canCreateFee`, `_InvoiceListView` row actions gated by `canRecord`/`canEditInvoice`/`canDeleteInvoice`, and `_PaymentsTab` row actions gated by `canApprove`/`canEdit`/`canDelete`.
- `fee_detail_page.dart` — **Updated.** Added imports for `authorization_service.dart` and `permission_denied_handler.dart`. Wrapped `_FeeDetailPageState._generateInvoices()` and `_FeeDetailPageState._deleteFee()` with `on PermissionException catch (e)` blocks (before the generic `catch (e)`) that call `showPermissionDenied(context, e.reason)`. Visibility gates (`_canCreateFee` → `canGenerateInvoices`, `_canDeleteFee` → `canDelete`) were already correctly wired to `_GradeFeePage`.

Previous: Task G2-A — Fixed `_ClassRankStat` tie handling and scoped ranking to student's grade.

- `progress_screen.dart` (`_ClassRankStat`) — **Fixed.** Two bugs resolved:
  1. **Tie handling:** Replaced simple iteration-based ranking with competition ranking (RANK() style). Uses `studentTotals.values.where((s) => s > targetScore).length + 1` — students with identical scores share the same rank.
  2. **Grade scoping:** Previously used `watchClassGrades(schoolId, examId)` which returned grades across ALL grades/streams. Now looks up the student's enrollment via `EnrollmentsDao.watchStudentEnrollment()` to determine their grade level, then fetches enrolled students for that grade via `ExamsGradesDao.getEnrolledStudents()` (no stream filter — all streams in the grade). Grades are filtered to only include enrolled students in the same grade before computing rank.
  - `_StatsGrid` now passes `year` and `term` to `_ClassRankStat`.
  - `_ClassRankStat` constructor accepts `year` and `term` (both `int`).
  - Nesting pattern: `StreamBuilder<Enrollment?>` → `StreamBuilder<List<Grade>>` → `FutureBuilder<List<StudentsData>>`.
  - Label renamed from `'Class Rank'` to `'Grade Rank'`.

Previous: Task G2-C — Fixed tie-aware stream ranking in comparisons tab.

- `comparisons_tab.dart` (`_RankingTableState`) — **Fixed.** Stream rankings now use competition ranking (RANK() style) instead of simple index-based numbering. If two streams share the same `averageScore`, they receive the same rank. Tie-aware `ranks` list is computed after sorting and passed to both `_RankingRow` (replaces `i + 1`) and `_PodiumSection` (new `ranks` parameter replaces hardcoded 1, 2, 3). Podium medal colors and heights are now derived from the actual rank value, so tied streams get matching medals.

Previous: Task C4 — Fixed "My Subjects" and "My Exams" quick stats showing 0 in teacher overview.

- `overview_screen.dart` (`_TeacherQuickStats`) — **Fixed.** "My Subjects" now uses a reactive `StreamBuilder<List<SubjectTeacher>>` via `MembersDao.watchTeacherSubjectsForTerm(schoolId, userId, year, term)` instead of the stale `entry.subjectCount` pre-computed once at home-screen load. Distinct subject IDs are counted client-side. "My Exams" filter expanded: in addition to matching exams where the teacher is the creator or an invigilator, it now also matches exams containing papers whose subject is in the teacher's assigned subject set (`teacherSubjectIds.contains(p.subject)`). Both stats update live when the underlying tables change.
- `members_dao.dart` — **Added two methods:** `watchTeacherSubjectsForTerm(schoolId, teacherUserId, {year, term})` returns `Stream<List<SubjectTeacher>>` filtered to a specific year/term. `watchTeacherSubjectCount(schoolId, teacherUserId, {year, term})` returns `Stream<int>` with a reactive `COUNT(DISTINCT subject)` query.
- `academics_screen.dart` — **Already fully gated.** Grade/stream tree mutations (add grade, add/edit streams, delete grade) are gated behind `Resource.classes` with `Action.create/update/delete`. FAB and empty-state CTA respect `canCreate`. `OwnerEntry` bypass is correct.
- `grade_detail_page.dart` — **Fixed.** The contextual FAB in `_actionsForContentTab` previously returned all mutation actions unconditionally. Added per-tab RBAC gates:
  - Students FAB → `Resource.students, Action.assign`
  - Exams FAB → `Resource.exams, Action.create`
  - Subjects FAB → `Resource.classes, Action.assign`
  - Timetable FAB → `Resource.classes, Action.create`
  - Lessons FAB → `Resource.lessons, Action.create`
  - Teachers FAB → `Resource.classes, Action.assign` (both class-teacher and subject-teacher)
  - Attendance — no FAB (inline marking, gated separately by Task D2)
- Added `_can(Resource, Action)` helper with `OwnerEntry` bypass, `_hasFabForContentTab` now delegates to `_actionsForContentTab(...).isNotEmpty`, and `initState` FAB scale accounts for permissions.
- New imports in `grade_detail_page.dart`: `permissions.dart`, `material.dart` now hides `Action`.
