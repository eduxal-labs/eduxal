# EduXal — Task Board (School Dashboard Architecture & Implementation)

> **Important Directive for the AI Agent:**
> We are trusting these tasks to you because we assume that you are an Engineer and Architect with more than four decades of experience. We expect nothing short of amazing. You must care deeply about the result of the written code, its architectural elegance, its functionality, and its usability—not just code completion and compilation without errors. 
> 
> **Read the full `AGENT.md` context before starting.** Ensure absolute alignment with the local-first, offline-ready architecture, reactive Drift streams, and the `logs` table mutation queue.

## UI/UX Design Mandate
- **Aesthetic:** Rigid, elevated, and popping UI. Elements should feel slim and dense, not "spongy", doughy, or bloated with air. No flat UI.
- **Typography:** Thin/light font weights (w300/w400 for body, w500 max for headings). 
- **Shapes & Elevation:** Absolutely NO borders. Use subtle elevation (shadows) and slight color shifts/tints to separate layers and make elements pop.
- **Border Radius:** "In-between" corners—neither perfectly sharp nor pill-shaped (e.g., `BorderRadius.circular(8)` to `12`). Absolutely no pill shapes.
- **Layout:** Generous whitespace. The UI must feel solid, precise, and architectural.

---

## [x] Task 1: The Responsive School Dashboard Shell & Role Switcher

**Objective:** Create the foundational responsive layout for the School Dashboard, accommodating five different distinct roles (Owner, Teacher, Staff, Student, Guardian) seamlessly.

**UI Hierarchy & Feel:**
*   **Desktop Layout:** A fixed Left Navigation Sidebar with a primary content area. The aesthetic must rely on clean elevations and distinct background color shifts to establish hierarchy. Cards and panels should pop cleanly off the canvas without using any outline borders.
*   **Mobile Layout:** Use scrollable tabs at the top for primary section navigation to save vertical space, avoiding a heavy hamburger menu or bottom nav for internal school routing.
*   **Top App Bar:** Must contain the **Role Switcher**. 

**Functionality:**
*   **Role Switcher:** Reads `SchoolContext.membership.entries`. A user can hold multiple roles in one school. Tapping the switcher updates `SchoolContext.currentEntry` via a `ValueNotifier`. The entire dashboard layout, available tabs, and actionable items must rebuild instantly and locally based on the selected role, without page reloads.

**Agent Trust Directive:** We are trusting this task to you. As a senior engineer, ensure the responsive breakpoints (`LayoutBuilder`) are clean, avoiding duplicated logic between mobile and desktop where possible, and that the UI context switching feels completely instantaneous.

---

## [x] Task 2: Academic Year & Term Context Management

**Objective:** Implement the temporal hierarchy (Year -> Term) which dictates what data is shown across the dashboard. Everything revolves around the Term.

**UI Hierarchy & Feel:**
*   **Term Selector UI:** Add an Academic Year and Term selector adjacent to the Role Switcher in the top AppBar. It should be a compact, unobtrusive dropdown/picker.
*   **Blank State (Crucial):** If the database has no terms for this school, the dashboard must blank out all academic features. Present a beautifully styled, prominent "Create First Term" call-to-action centered on the screen for the Owner.

**Functionality:**
*   **Data Scoping:** Create an `ActiveTermContext` provider/stream. Changing the term instantly updates all dependent queries (subjects, classes, exams, attendance) to query *only* for that term.
*   **Default State:** On entering the dashboard, default to the current active term.

**Agent Trust Directive:** We are trusting this task to you. As an experienced architect, ensure that the `ActiveTermContext` acts as a robust filter for all reactive Drift streams. Do not fetch data outside the active term unless explicitly requested.

---

## [x] Task 3: Universal Member Creation Flow (Phone-First)

**Objective:** Build the unified onboarding logic for adding Teachers, Staff, Students, and Guardians.

**UI Hierarchy & Feel:**
*   **Creation Forms:** Slide-over panels (desktop) or full-screen dialogs (mobile) with segmented, logical steps. 
*   **Guardian Flow:** Guardians are not created in isolation; their creation UI is nested *within* the Student profile view to establish the ward relationship implicitly.

**Functionality:**
*   **Phone-First Lookup:** The primary key for human identity in EduXal is the phone number. When an Owner/Admin adds a Teacher, Staff, or Guardian, the first input is the phone number.
*   **Resolution Logic:** Query `users` by phone. If found, link the existing user to the new role instantly. If not found, expand the form to request `Name`, create a new `users` row with status = `invite`, then link the role.
*   **Profile Images:** Implement local file saving to predictable paths (`{appDir}/users/{userId}/profile`). Crucially, write a row to the `logs` table marking a file mutation for the future sync engine.

**Agent Trust Directive:** We are trusting this task to you. With over a decade of experience, you know that identity resolution is tricky. Handle the offline-first creation robustly. Ensure the form is fluid, shows loading states properly, and doesn't block the UI while writing to SQLite.

---

## [x] Task 4: Academic & Administrative Setup (Departments, Subjects, Roles)

**Objective:** Build the interfaces for Owners/Admins to configure academic structures, create departments, and assign staff.

**UI Hierarchy & Feel:**
*   **Settings-Driven Labels:** Use inline elevated chips and tactile data rows to display assignments.
*   **Stream Display:** *Crucial Constraint:* The DB stores streams as integers. You must read `SchoolConfig` to resolve these into human-readable strings (e.g., "Stream A", "North"). The raw integer must never be visible in the UI.

**Functionality:**
*   **Departments:** Allow Owners to create departments and assign Staff/Teachers to them.
*   **Subject/Teacher Linking:** UI to map Teachers to specific Subjects for the Active Term, linking them as Class Teachers.
*   **Student Stream Assignment:** UI to assign students (`enrollments`) to specific grades and streams based on the school's configured curriculum.
*   **Roles/Scopes:** Interface for assigning custom roles and permission scopes to Staff members.

**Agent Trust Directive:** We are trusting this task to you. As a veteran developer, you understand the importance of separating database representation (integers) from presentation (Strings). Your stream-name lookup must be efficient, reactive, and seamlessly integrated into the UI.

---

## [x] Task 5: Staff Operations (Exams, Papers, Grades, Mastery)

**Objective:** Implement the deeply nested hierarchical UI for Staff and Teachers to manage academic performance.

**UI Hierarchy & Feel:**
*   **Hierarchy Enforcement:** The UI navigation must strictly enforce the path: `Term -> Exam -> Paper -> Grade/Mastery`.
*   **Data Entry Views:** Data-dense, spreadsheet-like tables for desktop bulk grading. Highly optimized, easily tappable list views for mobile grading to prevent fat-fingering. Use `AnimatedSaveButton` for row-level or form-level saves.
*   **Analytics Header:** At the top of Exam/Paper views, integrate Shadcn-style visual metrics (Donut charts for class averages, thin bar charts for grade distributions).

**Functionality:**
*   **Teacher Filtering:** When viewing as `TeacherEntry`, the streams and subjects must be strictly filtered to only show classes assigned to that specific teacher in the active term.
*   **Offline-Ready:** Grade entries must write to local Drift tables rapidly, logging the mutations silently in the background.

**Agent Trust Directive:** We are trusting this task to you. Show us your expertise by making data entry for grades incredibly fast. Ensure keyboard navigation works well on desktop tables, and that local Drift streams update the charts instantly as grades are entered.

---

## [x] Task 6: Dashboard Navigation Restructure & Consistent Tab Styling

**Objective:** Restructure the Owner's dashboard navigation to replace the separate "Staff" and "Students" items with a unified "Members" item, replace the "Settings" item with a "Roles" item, and establish a consistent, deliberate tab styling system used across **all** inner-page tabs throughout the entire school dashboard — not just the top-level mobile tabs.

### 6a. Consistent Tab Component

**Problem:** The top-level mobile navigation uses the custom `_PillTabStrip` (icon-only, elevated, with shadow indicator), but inner pages (Academics, Roles) fall back to a raw Material `TabBar` with a plain underline indicator. This creates a jarring visual mismatch. The inner tabs feel generic and flat compared to the deliberate mobile nav.

**Solution:** Extract a reusable `EduTab` / `EduTabBar` component into `lib/ui/widgets/edu_tab_bar.dart` that inner pages use for **all** their tab rows. This component must:
*   Use the same elevated, shadow-based indicator approach (not a thin underline) as the mobile pill strip — adapted for labelled text tabs.
*   Use a slightly tinted/shifted background container with subtle elevation to distinguish the tab row from its surroundings.
*   Match the design mandate: no borders on the indicator, subtle shadow, `BorderRadius.circular(8)` or `10`, slim text (w400 unselected / w500 selected).
*   Accept both icon-only and text-label modes so it can serve all contexts.
*   Be the **single source of truth** for tab aesthetics. No page should build its own raw `TabBar` anymore.

**Agent Trust Directive:** This component is the foundation of visual consistency. Every tabbed surface in the app will use it. Take extreme care with the look and feel — it must be polished, dense, and feel tactile without looking like generic Material.

### 6b. Owner Navigation Items Update

**Current Owner items:**
```
Overview | Academics | Staff | Students | Finance | Timetable | Settings
```

**New Owner items:**
```
Overview | Academics | Members | Finance | Timetable | Roles
```

Changes:
*   **Remove** `Staff` and `Students` as separate nav items.
*   **Add** `Members` (icon: `Icons.people_alt_outlined`) — a unified page for all school member types.
*   **Remove** `Settings`.
*   **Add** `Roles` (icon: `Icons.admin_panel_settings_outlined`) — directly replacing Settings. The old Settings nav item was already just rendering `SchoolRolesScreen`; this makes it explicit.

Update `_itemsForRole(MembershipRole.owner)` in `school_dashboard_screen.dart` and update the `_buildContentPanel` routing accordingly.

**Non-owner roles** are unaffected by this change — their nav items remain the same.

---

## [x] Task 7: Academics Page — Hierarchical Grade/Stream Architecture

**Objective:** Completely replace the current tabbed Academics page (Departments / Subjects / Classes / Exams & Grades) with a hierarchical, data-driven view rooted in the school's `SchoolConfig` grade and stream structure. The academic data is inherently nested — grades contain streams, streams contain enrollments, subjects, class teachers — so the UI must reflect this nesting visually and navigationally, not flatten it into peer tabs.

### 7a. Academics Landing — Grade/Stream Tree

**Current state:** `AcademicsScreen` is a `TabController(length: 4)` rendering four flat tabs: `DepartmentsTab`, `SubjectsTab`, `ClassesTab`, `ExamsGradesScreen`.

**New state:** The Academics landing page is a **scrollable list of grade cards**, one per `GradeConfig` in the school's `SchoolConfig`. No tabs.

**Data source:** Read the school's settings row from the `settings` table for the current `schoolId`. Parse `settings.data` JSON → `SchoolConfig`. For each `CurriculumConfig` → iterate over `GradeConfig` entries.

If the school supports **both** curricula (CBC and 8-4-4), display them as collapsible curriculum sections — each headed by a curriculum label chip, with grade cards nested under it.

If only **one** curriculum is enabled (the common case), show grade cards directly with no curriculum header.

**Grade Card Design:**
*   Each card is an elevated container with the grade's human-readable label from `kCbcGradeLabels` / `kEightFourFourGradeLabels` (e.g., "Grade 4", "Form 2").
*   Below the label, display the stream names as compact elevated chips (e.g., `Green`, `Blue`, `North`). If no streams are defined, show a muted "No streams" label.
*   **Action buttons on each grade card (icon row, right-aligned or trailing):**
    *   `+` icon button — add a new stream to this grade. Opens a mini dialog/sheet for stream name + auto-assigned code.
    *   Edit icon — edit the grade's stream names (batch rename).
    *   Delete icon — remove the grade from the config (with confirmation).
*   **Tappable:** Tapping the body of the grade card navigates to the **Grade Detail Page** (Task 7b).

**Floating Action Button:**
*   A `+` FAB at the bottom-right to **add a new grade** to the school's config.
*   Opens a sheet/dialog to pick a grade number from the available grades in the active curriculum that are not yet enabled.
*   On confirm, appends a new `GradeConfig(grade: selectedGrade, streams: [])` to the config, calls `SettingsDao.updateSchoolConfig()`, and the reactive `watchSettings()` stream triggers a UI rebuild.

**Blank State:** If `SchoolConfig.isEmpty` (no curricula / no grades configured), show an inviting empty state with a "Configure your school's grade structure" message and a CTA button leading to the same add-grade flow.

**What happens to the old tabs:**
*   `DepartmentsTab` — Departments are not grade-scoped. They move to a dedicated "Departments" section accessible from the Grade Detail page or a top-level action in the Academics header. **For now**, add a small "Departments" action/link in the Academics page header bar (an icon button or text link) that opens the existing `DepartmentsTab` in a full-screen overlay/push route.
*   `SubjectsTab` and `ClassesTab` — These are inherently grade+stream scoped. Their content will be absorbed into the Grade Detail Page (Task 7b) where the user has already selected a grade and stream filter.
*   `ExamsGradesScreen` — Remains reachable. For teachers via their own "Exams & Grades" nav item. For owners, it becomes accessible within the Grade Detail Page scoped to a specific grade/stream, or via a top-level "Exams" action in the Academics header.

### 7b. Grade Detail Page (Stub)

**Objective:** When a grade card is tapped, navigate to a new `GradeDetailPage` that shows all data scoped to that specific grade.

**Stream Filter:** At the top, a horizontal row of stream filter chips: `All` (default, selected), then one chip per `GradeStream` in the grade's config. Tapping a chip filters the content below.

**Content:** For now, this page is a **stub**. Display the grade label as a header, the stream filter chips, and a centered "Grade detail — coming soon" placeholder below. The page structure and filter state must be wired up correctly so that when content is added later, it simply plugs in beneath the filter.

**Navigation:** Standard push route with a back button. Not an inline tab — this is a full page.

**Agent Trust Directive:** The Academics page is the centerpiece of the school dashboard. The grade cards must look dense, tactile, and information-rich. The stream chips on each card must feel like solid embedded elements, not floaty badges. The FAB and per-grade action icons must be discoverable but not overwhelming. Think of this as the "project list" view of an IDE — compact, scannable, every element earns its place.

---

## [x] Task 8: Unified Members Page

**Objective:** Replace the separate "Staff" and "Students" nav items with a single "Members" page containing five tabs — one for each membership role at the school: Owners, Teachers, Staff, Students, Guardians. Each tab lists the relevant members and supports creation via a shared FAB.

### 8a. Members Page Shell

**Structure:**
*   Five tabs using the `EduTabBar` component from Task 6a: **Owners** | **Teachers** | **Staff** | **Students** | **Guardians**.
*   A single `+` FAB that is **context-aware** — its action adapts based on the currently active tab:
    *   Owners tab → "Add Owner" (phone-first flow using existing `PhoneFirstPanel`).
    *   Teachers tab → "Add Teacher" (phone-first, reuse existing `AddTeacherPanel`).
    *   Staff tab → "Add Staff" (phone-first, reuse existing `AddStaffPanel`).
    *   Students tab → "Add Student" (name-first, reuse existing `AddStudentPanel`).
    *   Guardians tab → "Add Guardian" (phone-first, reuse existing `AddGuardianPanel`). Note: guardians are contextually linked to a student, so this FAB should either prompt for the ward first or link from the student detail.

### 8b. Tab Content — Member Lists

Each tab renders a reactive list from the corresponding Drift table filtered by `schoolId`:

| Tab | Query source | Display fields |
|---|---|---|
| **Owners** | `owners` table joined with `users` | Name, phone, status badge |
| **Teachers** | `teachers` table joined with `users` | Name, phone, department, subject count badge (current term) |
| **Staff** | `staff` table joined with `users` | Name, phone, department, status badge |
| **Students** | `students` table (school-scoped) | Name, admission number, grade/stream (from current term enrollment), status badge |
| **Guardians** | `guardians` table joined with `users` and `students` (ward) | Name, phone, ward name(s), status badge |

**Member Row Design:**
*   Elevated row with generous padding. User avatar on the left (from cached file at predictable path or initials fallback). Name + secondary info. Status chip on trailing edge.
*   On tap → navigate to member detail (stub placeholder for now — display name, phone, role-specific info, and a back button).
*   On long-press (or context menu on desktop) → quick actions: remove from school, change status.

### 8c. Owner Creation Flow

The "Add Owner" flow is the **only new creation flow** — teachers, staff, students, and guardians already have creation panels (`AddTeacherPanel`, `AddStaffPanel`, `AddStudentPanel`, `AddGuardianPanel`) and the `MemberCreationService`.

**Owner creation** follows the same phone-first pattern:
1. Enter phone number.
2. Query `users` table by phone.
3. If found → link to `owners` table for this school.
4. If not found → expand form for name, create invited user, then link to `owners`.
5. Write both the `users` row (if new) and the `owners` row inside a single transaction, plus the corresponding `logs` entries.

**DAO additions:** Add `ownerExists(schoolId, userId)` and `insertOwner(...)` methods to `MembersDao`. Add `watchOwners(schoolId)` stream.

**Service additions:** Add `createOwner(...)` method to `MemberCreationService` following the exact same pattern as `createTeacher`/`createStaff`.

**Agent Trust Directive:** The Members page is where administrators spend significant time. Every tab must load instantly from local Drift streams. The FAB must feel responsive and the creation panels must flow naturally. Pay attention to the guardian tab — it needs to show which ward(s) each guardian is linked to, potentially multiple rows if a guardian has multiple wards at the same school.

---

## [x] Task 9: Roles Page (Replacing Settings)

**Objective:** The "Settings" nav item is removed and replaced by "Roles". The Roles page manages the school's custom roles and their permission definitions. Role **assignments** (which users hold which roles) are NOT shown on this page's list — they are visible only when navigating into a specific role's detail page.

### 9a. Roles Page Shell

**Structure:**
*   The page is a **single list of role cards** — no tabs on the landing page itself.
*   Each role card shows: role name, description snippet, permission count badge.
*   Tapping a role card navigates to the **Role Detail Page** (Task 9b).
*   A `+` FAB to create a new role. Opens the existing `_RoleFormSheet` (from `school_roles_screen.dart`) or a similar creation form.

**Data Source:** Query `roles` table filtered by `school = schoolId` via `SchoolScopesDao`. Reactive stream via `watchSchoolRoles(schoolId)`.

**Key Change from Current Implementation:** The current `SchoolRolesScreen` has 2 tabs: "Roles" and "Assignments". The "Assignments" tab (which shows all users and their assigned roles across the school) is **removed from the landing page**. Assignment management now lives exclusively inside each role's detail page (Task 9b), making it contextual — you see who has *this specific role*, not a flat dump of all assignments.

### 9b. Role Detail Page

**Structure:** A full push-route page (like the system dashboard's `RoleDetailScreen`) with:
*   **Header:** Role name, description, metadata (created date, etc.).
*   **Two tabs** (using `EduTabBar` from Task 6a): **Permissions** | **Assigned Users**.
*   **Permissions tab:** The existing permission editor UI — grouped by resource, with toggle chips for each action. Uses the same `_buildResourceGroups` pattern from `role_detail_screen.dart` (system dashboard), adapted for school-scoped resources.
*   **Assigned Users tab:** Lists all users who hold this specific role at this school (via `scopes` table query: `school = schoolId, role = roleId`). Includes:
    *   A `+` button/FAB to assign a new user to this role. Opens a school member picker → confirms assignment by inserting a `scopes` row.
    *   Each assigned user row has a "remove" action to unassign (delete the `scopes` row).

**Key Architectural Note:** This mirrors the system dashboard's `RoleDetailScreen` which already has Permissions and Assigned tabs with the full assign/unassign flow. The school-level version should follow the same patterns but query school-scoped data (`SchoolScopesDao`) instead of system-scoped data.

**Agent Trust Directive:** Roles and permissions are a power-user feature. The UI must feel authoritative and precise. Permission toggles must be instantly responsive (local Drift writes). The role detail page should feel like a focused management console — dense but not cluttered. Follow the visual and architectural patterns already established in `role_detail_screen.dart`.

---

## [x] Task 10: Attendance Tracking

**Objective:** Provide a frictionless interface for marking daily or lesson-level attendance.

**UI Hierarchy & Feel:**
*   **Marking UI:** A list of students for a specific Date, Class, and Stream. Segmented controls or elegant toggle buttons for state (Present, Absent, Late) that look and feel like solid tactile switches.
*   **Color Coding:** Subtle color hints (e.g., gently elevated tiles with extremely muted green for present, muted red for absent) conforming to the brand guidelines. No outlines.

**Functionality:**
*   **Quick Actions:** "Mark All Present" button.
*   **Guardian Visibility:** Guardians must have a clean, calendar-based or list-based view of their ward's historical attendance records.

**Agent Trust Directive:** We are trusting this task to you. Teachers do this every day; it must require absolute minimum taps and zero loading spinners, writing instantly to the local database.

---

## [x] Task 11: Financial Management (Fees, Invoices, Payments, & Discounts)

**Objective:** Robust financial tracking for the school Owner/Staff and billing visibility for Guardians.

**UI Hierarchy & Feel:**
*   **Dashboard:** Distinct financial overview cards utilizing elevation and layer separation. Use tabular layouts with exact, right-aligned currency formatting.
*   **Typography:** Status badges must be crisp, solid, and elevated (e.g., a green "Paid" chip, a red "Overdue" chip).

**Functionality:**
*   **Invoicing & Discounts:** Owner/Staff UI to define fee structures by Grade/Stream, apply valid discounts, and generate invoices.
*   **Payments:** Form to record received payments, which automatically calculates and updates the outstanding balance locally.
*   **Guardian View:** A read-only, perfectly clear view of invoices, payments made, and outstanding balances per ward.

**Agent Trust Directive:** We are trusting this task to you. Financial data requires absolute clarity and zero ambiguity. The local database logic must flawlessly handle balance calculations based on the relational invoice, discount, and payment data.

---

## [x] Task 12: Announcements & School-Wide Communications

**Objective:** Implement a broadcast system for school communications.

**UI Hierarchy & Feel:**
*   **Feed:** A chronological, cleanly separated feed of messages. Use crisp elevation and subtle background color tinting for message cards to make them pop. Absolutely no borders.

**Functionality:**
*   **Creation & Targeting:** Owners/Staff can author announcements. They must be able to target specific roles (e.g., "Guardians Only", "Teachers Only") or specific classes.
*   **Contextual Filtering:** The feed must read the `SchoolContext.currentEntry` and only display announcements relevant to that role. 

**Agent Trust Directive:** We are trusting this task to you. This feature should feel like a modern, lightweight social feed. It must respect the user's active context strictly so they aren't spammed with irrelevant notices.

---

## [x] Task 13: Timetable Rules Setup & Generation (Pre-Sync)

**Objective:** Build the UI for defining timetable constraints and viewing the generated timetable, acting as the final dashboard module before introducing the Sync Engine.

**UI Hierarchy & Feel:**
*   **Rules Configuration:** A dense, elevated form where Owners/Admins define constraints (e.g., maximum lessons per day for a teacher, preferred double-lessons). These configurations must feel like high-end toggles and solid sliders.
*   **Desktop Grid:** A classic, spacious weekly grid view to display the resulting schedule, utilizing subtle drop shadows on the schedule blocks to make them stand out.
*   **Mobile View:** A vertical timeline or day-by-day horizontal pager. It must not feel cramped.

**Functionality:**
*   **Rules UI:** Allow creating and saving the rules required for a Genetic Algorithm to run. Store these configurations locally.
*   **Generation Stub:** Include a prominent "Generate Timetable" CTA. *When clicked, do not attempt to implement the Genetic Algorithm.* Simply display an elegant Snackbar/Toast stating: "Timetable generation algorithm pending implementation." 
*   **Viewing Mode:** Provide the necessary Drift queries and UI to render `lessons` and `timetable` records for Owners, Teachers, and Guardians, assuming the data exists in the database.

**Agent Trust Directive:** We are trusting this task to you. Timetables are notoriously complex to display responsively. Your solution must look exceptionally clean on both wide desktop monitors and narrow mobile screens without compromising usability. Ensure the generation logic is perfectly stubbed out so the project owner can inject the Genetic Algorithm later seamlessly.

---

## Execution Rules
1. Work on **exactly one task** per session, in the order they appear above.
2. Read all relevant schemas and files before writing code. Do not guess DB columns.
3. Verify mobile/desktop responsiveness and the "tactile/elevated" design system at every step.
4. Mark the task as `[x]` upon completion.
5. Do not proceed to the next task until the current one is robust, styled correctly, and respects the offline-first/Drift-stream architecture.
6. Tasks 6–9 form a **cohesive restructure group**. They must be executed in order because 6a (tab component) is a dependency for 7, 8, and 9, and 6b (nav restructure) provides the routing for 8 (Members) and 9 (Roles).