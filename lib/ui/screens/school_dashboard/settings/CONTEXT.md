# ui/screens/school_dashboard/settings/ — Settings Context

## Overview

Owner-facing school profile and settings editor. Provides a full-page form for editing school identity, contact details, location, and logo. Also includes navigation links to M-Pesa configuration and a read-only subscription plan display.

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
  - **Post-save refresh (F5 fix):** `_school` is a mutable `SchoolsData` field (not a getter). After successful save, re-reads from `schoolsDao.getSchool()` and updates `_school` via `setState`, preventing stale data if user navigates away and back.
  - Error banner for validation/save failures
  - Responsive: constrained to 560px max-width on desktop, full-width on mobile
  - **Integrations section:** Navigation row linking to `MpesaConfigScreen`
  - **Subscription section:** Read-only display of active plans via `_SubscriptionSection` StreamBuilder on `plansDao.watchAllPlans()`
- **Private widgets:**
  - `_ErrorBanner` — error display container
  - `_SectionHeader` — uppercase section label (matches account screen pattern)
  - `_SectionContainer` — bordered card container for form sections
  - `_FormField` — labeled text field row with hint support
  - `_CountyPickerRow` — tappable row that opens county picker sheet
  - `_LogoSection` — logo preview + pick/clear buttons
  - `_CountyPickerSheet` — searchable county list sheet (47 Kenya counties)
  - `_NavigationRow` — tappable row with icon, label, subtitle, and chevron for sub-screen navigation
  - `_SubscriptionSection` — StreamBuilder widget displaying active plans from `plansDao.watchAllPlans()`
  - `_PlanRow` — individual plan display row showing name, description, amount, features, and "managed by admin" note
- **Dependencies:**
  - `cache/file_cache.dart` — `FileCache.saveBytes`, `FileCache.get`, `FileCache.logoPath`
  - `client.dart` — `cache`, `schoolsDao`, `plansDao` globals
  - `database/database.dart` — `SchoolsData`, `SchoolsCompanion`, `Plan`
  - `database/tables/curriculum_subjects.dart` — `KenyaCounty` enum
  - `database/tables/enums.dart` — `PlanStatus` enum
  - `models/school_context.dart` — `SchoolContext`
  - `ui/theme/app_theme.dart` — design tokens
  - `ui/widgets/animated_save_button.dart` — `AnimatedSaveButton`
  - `ui/widgets/edu_sheet.dart` — `showEduSheet`
  - `mpesa_config_screen.dart` — `MpesaConfigScreen` (navigation target)

### `mpesa_config_screen.dart`
- **Status:** ✅ Complete
- **Exports:** `MpesaConfigScreen` (public `StatefulWidget`)
- **Props:** `SchoolContext schoolContext`
- **Features:**
  - Full Scaffold with AppBar, back button (`Icons.chevron_left_rounded`), delete action, and `AnimatedSaveButton`
  - Environment toggle: sandbox / production (radio-style `_EnvOption` tiles)
  - Business short code field (text, numeric keyboard)
  - API credentials: consumer key, consumer secret, passkey — all with visibility toggle (masked by default)
  - Loads existing config on init via `catalogDao.getMpesa(schoolId)`
  - Save creates/updates via `catalogDao.upsertMpesa()` which auto-selects `SyncAction.createMpesa` or `SyncAction.updateMpesa`
  - Delete via `catalogDao.deleteMpesa()` with confirmation dialog
  - Dirty tracking across all fields with `AnimatedSaveButton`
  - Info note pointing to Safaricom Daraja portal
  - Responsive: constrained to 560px max-width on desktop
- **Private widgets:**
  - `_ErrorBanner` — error display container
  - `_SectionLabel` — uppercase section label
  - `_EnvOption` — selectable environment option tile with icon, label, subtitle
  - `_ConfigField` — labeled text field with optional obscure toggle and visibility button
- **Dependencies:**
  - `client.dart` — `cache`, `catalogDao` globals
  - `database/tables/mpesa.dart` — `MpesaEnv` enum
  - `models/school_context.dart` — `SchoolContext`
  - `ui/theme/app_theme.dart` — design tokens (`kRadius`, `kCardRadius`, `kModalRadius`, `kChipRadius`, `kTabletBreakpoint`)
  - `ui/widgets/animated_save_button.dart` — `AnimatedSaveButton`

## Conventions
- Follows AGENT.md §21: w300/w400 body, w500 headings max, 8px card radius, 12px modal radius
- Section pattern matches `account_screen.dart` (section header + container + dividers)
- No `Navigator.pop()` on save — stays on page, shows SnackBar confirmation
- M-Pesa config is a separate pushed route (`MaterialPageRoute`) from the settings screen
- Subscription section is read-only; plans are managed by system/super users only
- Back button always uses `Icons.chevron_left_rounded` (size 22-24)
- Sensitive fields (consumer key, consumer secret, passkey) are masked by default with visibility toggles

## Last Updated
Task F5 — Fixed stale school data after save: `_school` changed from getter to mutable field, refreshed from DAO after successful save.