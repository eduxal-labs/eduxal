# ui/screens/school_dashboard/settings/ — Settings Context

## Overview

Owner-facing school profile and settings editor. Provides a full-page form for editing school identity, contact details, location, and logo.

## Files

### `school_settings_screen.dart`
- **Status:** ✅ Complete
- **Exports:** `SchoolSettingsScreen` (public `StatefulWidget`)
- **Props:** `SchoolContext schoolContext`
- **Features:**
  - Editable fields: school name (required), motto, phone, email, domain, county (required, picker sheet), established year
  - Logo picker via `ImagePicker` → cached at `{appDir}/schools/{schoolId}/logo` via `FileCache`
  - Dirty tracking across all fields with `AnimatedSaveButton`
  - Save writes via `SchoolsDao.updateSchoolDetails()` which auto-creates `SyncAction.updateSchool` log entry
  - Logo save via `FileCache.saveBytes()` + `SchoolsDao.logLogoChange()`
  - Error banner for validation/save failures
  - Responsive: constrained to 560px max-width on desktop, full-width on mobile
- **Private widgets:**
  - `_ErrorBanner` — error display container
  - `_SectionHeader` — uppercase section label (matches account screen pattern)
  - `_SectionContainer` — bordered card container for form sections
  - `_FormField` — labeled text field row with hint support
  - `_CountyPickerRow` — tappable row that opens county picker sheet
  - `_LogoSection` — logo preview + pick/clear buttons
  - `_CountyPickerSheet` — searchable county list sheet (47 Kenya counties)
- **Dependencies:**
  - `cache/file_cache.dart` — `FileCache.saveBytes`, `FileCache.get`, `FileCache.logoPath`
  - `client.dart` — `cache`, `schoolsDao` globals
  - `database/database.dart` — `SchoolsData`, `SchoolsCompanion`
  - `database/tables/curriculum_subjects.dart` — `KenyaCounty` enum
  - `models/school_context.dart` — `SchoolContext`
  - `ui/theme/app_theme.dart` — design tokens
  - `ui/widgets/animated_save_button.dart` — `AnimatedSaveButton`
  - `ui/widgets/edu_sheet.dart` — `showEduSheet`

## Conventions
- Follows AGENT.md §21: w300/w400 body, w500 headings max, 8px card radius, 12px modal radius
- Section pattern matches `account_screen.dart` (section header + container + dividers)
- No `Navigator.pop()` on save — stays on page, shows SnackBar confirmation

## Last Updated
Task F4 — Created `SchoolSettingsScreen` and wired it into the owner nav in `school_dashboard_screen.dart` as the 'Settings' nav item (`Icons.settings_outlined`).