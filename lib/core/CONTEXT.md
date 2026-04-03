# core/ — Shared Utilities Context

> Shared utilities with no domain knowledge. Safe to use in services, DAOs, models, and tests without Flutter bindings (except `app_cache.dart` which imports a model). Also contains the source branding asset (`assets/icon.png`) used by `flutter_launcher_icons`.

## Overview

This directory contains **7 files** providing app-wide constants, extension methods, error mapping, an in-memory cache, academic formatting utilities, a demo data seeder, and permission parsing/serialisation utilities. Nothing here has domain-specific business logic — these are pure utilities.

## Files

| File | Key Exports | Status |
|---|---|---|
| `academic_utils.dart` | `percentageColor`, `masteryColor`, `formatPercent`, `formatScore`, `formatDateFromDays`, `formatDateFromSeconds`, `formatTimeOfDay` | ✅ Complete |
| `app_cache.dart` | `AppCache` | ✅ Complete |
| `constants.dart` | `kDomain`, `kPort`, `kVerificationExpiry`, `kResendCooldown`, `kAccessTokenDuration`, `kRefreshTokenDuration` | ✅ Complete |
| `extensions.dart` | `PhoneNormalisation` extension on `String`, `gradeLabel()`, `gradeStreamLabel()` | ✅ Complete |
| `grpc_errors.dart` | `GrpcErrorMessage` extension on `GrpcError` | ✅ Complete |
| `permission_parser.dart` | `parsePermissions`, `serialisePermissions`, `countPermissions`, `popcount` | ✅ Complete |
| `seeder.dart` | `Seeder` | ✅ Complete |

## Detailed Exports

### Academic Utilities — `academic_utils.dart`

Shared color-coding, formatting, and date conversion functions used across the Academics section. Centralises logic that was previously duplicated as private helpers (`_pctColor`, `_fmtDate`, `_fmtScore`, etc.) across many tab and page files.

**Color utilities:**

| Function | Signature | Description |
|---|---|---|
| `percentageColor` | `Color percentageColor(double percent)` | 3-tier color: ≥75% green, ≥50% amber, <50% red |
| `masteryColor` | `Color masteryColor(double percent)` | 4-tier color: ≥80% green, ≥60% amber, ≥40% orange, <40% red |

**Formatting utilities:**

| Function | Signature | Description |
|---|---|---|
| `formatPercent` | `String formatPercent(double? percent)` | "72.4%" or "—" if null |
| `formatScore` | `String formatScore(double? score, int? total)` | "72/100" or "—" if null |
| `formatDateFromDays` | `String formatDateFromDays(int? daysSinceEpoch)` | "12 Mar 2025" from days since epoch |
| `formatDateFromSeconds` | `String formatDateFromSeconds(int? secondsSinceEpoch)` | "12 Mar 2025" from seconds since epoch |
| `formatTimeOfDay` | `String formatTimeOfDay(int secondsSinceMidnight)` | "08:30" from seconds since midnight |

**Dependencies:** `package:flutter/material.dart` (for `Color`).

### `AppCache` — `app_cache.dart`

Lightweight in-memory cache for hot data read frequently during a session. A single global instance is held in `client.dart` as `final cache = AppCache()` and cleared on logout.

- `Authenticated? currentUser` — the active authenticated user. Set after `active()`, `_refresh()`, or `switchAccount()` in `client.dart`. Null after `clear()`.
- `T? get<T>(String key)` — typed retrieval from generic key-value store. Returns null if absent or wrong type.
- `void set<T>(String key, T value)` — stores value under key.
- `void remove(String key)` — removes single entry (does NOT clear `currentUser`).
- `void clear()` — clears everything including `currentUser`. Called on logout.

**Dependencies:** `models/authenticated.dart` (for `Authenticated` type reference).

### Constants — `constants.dart`

| Constant | Type | Value | Usage |
|---|---|---|---|
| `kDomain` | `String` | `'localhost'` | gRPC server domain (placeholder — will be config-driven later) |
| `kPort` | `int` | `50051` | gRPC server port |
| `kVerificationExpiry` | `Duration` | 15 minutes | OTP lifetime — show countdown in UI |
| `kResendCooldown` | `Duration` | 90 seconds | Minimum gap between OTP resend attempts |
| `kAccessTokenDuration` | `Duration` | 3 days | `token_expiry = created_at + kAccessTokenDuration` |
| `kRefreshTokenDuration` | `Duration` | 30 days | `refresh_token_expiry = created_at + kRefreshTokenDuration` |
| `kDemoMode` | `bool` | `true` | When `true`, splash screen auto-seeds demo data on first login if no schools exist locally. Set to `false` before production builds. |

`kFileBasePath` is declared but is an empty string — runtime value resolved via `path_provider`. Do not use directly.

**Dependencies:** None (pure Dart constants).

## Branding & Icon Pipeline

### Source Asset
- `assets/icon.png` — 1024×1024 PNG of the EduXal logo (stylised "E" with a green leaf on a deep indigo/purple background `#2A1B5E`). This is the single source-of-truth image for all launcher icons.

### `flutter_launcher_icons` Configuration (in `pubspec.yaml`)
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
  adaptive_icon_background: "#2A1B5E"
  adaptive_icon_foreground: "assets/icon.png"
  remove_alpha_ios: true
```

Run `dart run flutter_launcher_icons` after changing `assets/icon.png` to regenerate all platform-specific icon sizes.

### What the pipeline generates
| Platform | Artefacts |
|---|---|
| **Android** | `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` (legacy), `drawable-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png` (adaptive foreground), `mipmap-anydpi-v26/ic_launcher.xml` (adaptive manifest), `values/colors.xml` → `ic_launcher_background` colour |
| **iOS** | `Assets.xcassets/AppIcon.appiconset/Icon-App-*` at all required sizes, alpha channel removed |

### Native Splash
- Android `launch_background.xml` (both `drawable/` and `drawable-v21/`) uses `@color/launch_background` → `#3F51B5` (brand indigo from `AppTheme.brandIndigo`).
- Android `LaunchTheme` in both `values/styles.xml` and `values-night/styles.xml` sets `android:statusBarColor` to the same brand indigo.
- The Flutter `SplashScreen` widget takes over immediately with a matching indigo background + animated logo — seamless transition from native splash.

### App Name & Identity
| Platform | Where | Value |
|---|---|---|
| Android | `AndroidManifest.xml` `android:label` | `EduXal` |
| Android | `build.gradle.kts` `applicationId` / `namespace` | `com.eduxal.app` |
| iOS | `Info.plist` `CFBundleDisplayName` | `EduXal` |
| iOS | `Info.plist` `CFBundleName` | `EduXal` |
| pubspec | `description` | `EduXal — School management, simplified.` |

### `PhoneNormalisation`, `gradeLabel`, `gradeStreamLabel` — `extensions.dart`

Extension on `String` providing `String? toKenyanPhone()`.

Normalises Kenyan phone numbers to 10-digit local format (`07xxxxxxxx` or `01xxxxxxxx`).

Accepted input formats:
- `07xxxxxxxx`, `01xxxxxxxx` — already local.
- `+2547xxxxxxxx`, `+2541xxxxxxxx` — international with `+`.
- `2547xxxxxxxx`, `2541xxxxxxxx` — international without `+`.
- `7xxxxxxxx`, `1xxxxxxxx` — 9-digit subscriber number (prepends `0`).

Returns `null` if the input is not a recognisable Kenyan mobile number.

**Dependencies:** None (pure Dart — phone normalisation only).

**Grade label utilities:**

| Function | Signature | Description |
|---|---|---|
| `gradeLabel` | `String gradeLabel(int grade, {SchoolConfig? config})` | Converts a raw grade integer to a human-readable label ("Form 4", "Grade 3", "PP1", etc.). If `config` is provided, constrains lookup to the school's active curricula. Otherwise uses dual-lookup: CBC first, then 8-4-4. Falls back to `'Level $grade'` for unknown values. |
| `gradeStreamLabel` | `String gradeStreamLabel(int grade, {String? streamName, SchoolConfig? config})` | Builds a "Grade · Stream" display string. If `streamName` is null or empty, returns just the grade label. Raw stream IDs never leak to the UI. |

**Dependencies:** `models/school_config.dart` (for `SchoolConfig`, `gradeLabelsFor`, `kCbcGradeLabels`, `kEightFourFourGradeLabels`).

### `GrpcErrorMessage` — `grpc_errors.dart`

Extension on `GrpcError` providing `String toFriendlyMessage()`.

Maps gRPC status codes to user-friendly messages:

| Code | Friendly message |
|---|---|
| `unavailable` (14) | "Could not reach the server..." |
| `deadlineExceeded` (4) | "The request timed out..." |
| `unauthenticated` (16) | "Your session has expired..." |
| `permissionDenied` (7) | "You do not have permission..." |
| `invalidArgument` (3) | Server message or "The information you provided is not valid..." |
| `notFound` (5) | Server message or "The requested resource was not found." |
| `alreadyExists` (6) | Server message or "This resource already exists." |
| `resourceExhausted` (8) | "Too many requests..." |
| `cancelled` (1) | "The request was cancelled..." |
| `internal` (13) | "Something went wrong on our end..." |
| `unimplemented` (12) | "This feature is not available yet." |
| Other | Server message or "Something went wrong..." |

Uses internal `_serverMessageOr(String fallback)` helper — returns server-provided message if non-empty, otherwise the fallback.

**Dependencies:** `package:grpc/grpc.dart`.

### Permission Parser — `permission_parser.dart`

Shared permission parsing and serialisation utilities, extracted from the roles UI layer for reuse across the codebase (dashboard session init, role detail, role creation, etc.).

**Functions:**

| Function | Signature | Description |
|---|---|---|
| `parsePermissions` | `Map<Resource, int> parsePermissions(String? jsonStr)` | Resilient multi-format parser that handles: (1) standard JSON objects via `Permissions.fromJson`, (2) seeder binary-int JSON arrays via `Permissions.fromBlob`, (3) base64-encoded strings via base64 decode → UTF-8 JSON or raw binary blob. Each attempt is logged via `debugPrint`. Falls through gracefully — never throws. Returns empty map for null/empty input. |
| `serialisePermissions` | `@Deprecated` `String serialisePermissions(Map<Resource, int> perms)` | **Deprecated.** Serialises a `Map<Resource, int>` to the canonical JSON list-of-objects format: `[{"resource": "students", "actions": ["read", "update"]}]`. Retained only for writing to the local DB `roles.permissions` text column. For sync payloads, use `Permissions(map).toBlob()` instead. |
| `countPermissions` | `int countPermissions(Map<Resource, int> perms)` | Returns the total number of granted individual permission bits across all resources (Hamming weight sum). |
| `popcount` | `int popcount(int v)` | Hamming weight helper — counts the number of set bits in an integer. |

**Dependencies:** `dart:convert`, `dart:typed_data`, `package:flutter/foundation.dart` (debugPrint), `models/permissions.dart` (Resource, Permissions).

**Depended on by:** `ui/screens/school_dashboard/roles/_role_helpers.dart` (re-export), `ui/screens/school_dashboard/school_dashboard_screen.dart` (session init), `ui/screens/school_dashboard/roles/school_role_detail_screen.dart` (save verification), `database/daos/roles_dao.dart` (`parsePermissions` used to convert JSON text → `Permissions` → binary blob for sync payloads).

### Seeder — `seeder.dart`

Populates the local Drift database with a realistic Kenyan secondary school for demo purposes. Called once on first login when no schools exist locally.

**Public API:**

| Method | Signature | Description |
|---|---|---|
| `Seeder.seed` | `static Future<bool> seed(AppDatabase database, String userId)` | Seeds the database with a full school. Returns `true` if seeding was performed, `false` if data already exists (guard against double-seeding). |

**What gets created:**

| Entity | Count | Notes |
|---|---|---|
| School | 1 | "Mwangaza Academy", Nairobi, active, est. ~2018 |
| Settings | 1 | SchoolConfig with both CBC (all levels except PP1/PP2) and 8-4-4 (Form 3 & Form 4 only — sub-Form-3 removed) |
| Departments | 5 | Science, Mathematics, Languages, Humanities, Technical |
| Teachers | 12 | Realistic Kenyan names, varied departments, some with head-of-dept roles |
| Staff | 5 | Bursar, Secretary, Lab Technician, Librarian, Counselor |
| Owner | 1 | The logged-in user |
| Terms | 3 | Dynamically computed relative to today |
| Students | ~700+ | Distributed across 14 focus grades: Form 3 (~69), Form 4 (~69), CBC Grades 1–3 (~108, 18/stream), Grades 4–6 (~102, 17/stream), Grades 7–9 (~90, 15/stream), Grades 10–12 (~84, 12/stream) |
| Guardians | ~500+ | ~15% share guardians (siblings pattern) |
| Enrollments | ~700+ | All students enrolled for current term |
| Subjects | ~9-11 per class | KCSE subjects for Forms 3/4, CBC Lower Primary (9 subjects), Upper Primary (10), Junior Secondary (11), Senior Secondary STEM/Social Sciences/Arts (9 each) |
| Class Teachers | 1 per stream | Round-robin from teacher pool |
| Timetable | ~40 slots/class | 8 periods/day, Mon-Fri, with collision avoidance |
| Attendance | Up to 20 days | ~90% present, ~7% absent, ~3% leave. Debug log confirms day count. |
| Exams | 2-3 per grade | "Opening Term Exam", "CAT 1", plus "Mock KCSE" for Form 4 |
| Papers | 1 per subject per exam | Single-paper subjects |
| Grades | Bell-curve distribution | 15-98 out of 100, mean ~62, stddev ~15 |
| Fees | 2 per grade | Tuition (KES 15,000) + Activity Fee (KES 2,000) |
| Invoices | 1 per student per fee | Linked to fee records |
| Payments | ~60% of invoices | 50-100% of amount, varied methods (cash/cheque/mpesa/bank) |
| Announcements | 5 | Term opening, exam schedule, sports day, parent meeting, library hours |
| Roles | 1 | "Teacher" role with teaching permissions (attendance, lessons, grades) |
| Scopes | 12 | All teachers assigned the Teacher role |
| Mastery | Form 4 only | 4 subjects × 5 topics per student, scores 30-98% |
| Lessons | ~100 | Spread over up to 25 working days across all focus grades |

**Key implementation details:**

- Uses deterministic `Random(42)` seed for reproducible output.
- Every insert into a synced table also writes a corresponding `logs` entry (`LogOperation.insert`) so the sync engine can push the seed data to the server for other users (teachers, parents, etc.) to see.
- Invoice status updates after payments also produce `LogOperation.update` log entries with the correct column bitmask.
- Entire operation wrapped in a single transaction for atomicity.
- Uses `ObjectId().oid` from `bson` package for text IDs.
- A `_log(LogTable, rowKey)` helper generates log entries with `account = userId`, `op = insert`, `status = pending`, `created = nowMs` (milliseconds since epoch).
- Row keys follow the "|"-delimited PK convention (e.g. `"schoolId|adm"` for students, `"schoolId|year|term|grade|stream|student|date"` for attendance).
- Name generation: 45% male / 55% female, within each gender 60% Islamic / 40% other Kenyan names.
- Grade numbering follows `kCbcGradeLabels` (Grade 1=3, Grade 2=4, …, Grade 12=14) and `kEightFourFourGradeLabels` (Form 3=43, Form 4=44).
- Student DOB ages are now realistic per Kenyan grade level: Grade 1 ≈ 6 yrs through Grade 12 ≈ 18 yrs, Form 3 ≈ 17, Form 4 ≈ 18 (±1 year variation).
- Attendance and lesson seeding clamp dates to `min(today, termEnd)` to avoid edge cases when the term hasn't fully elapsed. A `debugPrint` logs the number of attendance/lesson days seeded for diagnostics.
- `_seedSettings()` now includes all CBC grade configs (Grades 1–12 across all 6 levels) and only Form 3/Form 4 for 8-4-4 (sub-Form-3 8-4-4 levels removed).
- `_focusGrades` expanded from 4 entries to 14: Form 3, Form 4, CBC Grades 1–3 (Lower Primary, 18/stream), Grades 4–6 (Upper Primary, 17/stream), Grades 7–9 (Junior Secondary, 15/stream), Grades 10–12 (Senior Secondary, 12/stream).
- CBC subject sets defined per level: `_cbcLowerPrimarySubjects` (9 subjects), `_cbcUpperPrimarySubjects` (10), `_cbcJuniorSecondarySubjects` (11), `_cbcStemSubjects` (9), `_cbcSocialSubjects` (9), `_cbcArtsSubjects` (9).

**Dependencies:** `dart:convert`, `dart:math`, `package:bson`, `package:drift`, `package:flutter/foundation.dart` (for `debugPrint`), `database/database.dart`, `database/tables/enums.dart`, `database/tables/curriculum_subjects.dart`, `models/school_config.dart`.

## Dependencies

- **Depends on:** `package:grpc` (only `grpc_errors.dart`), `models/authenticated.dart` (only `app_cache.dart`), `package:bson` + `package:drift` + `database/` + `models/school_config.dart` (only `seeder.dart`)
- **Depended on by:** `services/` (constants, extensions, error mapping), `client.dart` (constants, `AppCache`), `ui/` (error display via `toFriendlyMessage()`, seeder trigger)

## Conventions

- All logic here is pure Dart — no Flutter framework imports (except `academic_utils.dart` which imports `Color` from `material.dart`).
- `extensions.dart` is a library file (uses `library;` directive).
- `constants.dart` is a library file (uses `library;` directive).
- Token duration values are the **only** place these durations are defined. If the backend changes them, update only this file.

## Android Release Build Configuration

### Signing
- **Keystore:** `android/app/eduxal-release.jks` (RSA 2048-bit, 10,000-day validity, alias `eduxal`)
- **Key properties:** `android/key.properties` — read by `build.gradle.kts` at build time. Git-ignored.
- **Signing config:** `build.gradle.kts` conditionally creates a `release` signing config if `key.properties` exists; falls back to `debug` signing otherwise (for CI or fresh clones without the keystore).

### R8 / ProGuard
- `isMinifyEnabled = true` and `isShrinkResources = true` enabled for release builds.
- `android/app/proguard-rules.pro` contains keep rules for:
  - Flutter engine classes (`io.flutter.**`)
  - gRPC / OkHttp / Protobuf classes
  - JNI native methods
  - SQLite (drift_flutter / sqlite3_flutter_libs)
  - Google Play Core split-install classes (`-dontwarn` — referenced by Flutter's deferred component support but not used)

### Build Outputs
| Command | Output | Size |
|---|---|---|
| `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` | ~73.8 MB |
| `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` | ~51.9 MB |

### Existing Configuration (unchanged)
- `minSdk = 21` (was already set)
- `INTERNET` and `ACCESS_NETWORK_STATE` permissions in `AndroidManifest.xml` (were already present)
- `applicationId = "com.eduxal.app"`, `android:label = "EduXal"` (set in Task 12)

## Last Updated
Task A3 — Deprecated `serialisePermissions()` (retained for local DB text column compat). Sync payloads now use `parsePermissions()` + `Permissions.toBlob()` via `roles_dao.dart`. All 7 files current.