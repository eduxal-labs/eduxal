# Progress Screen — CONTEXT.md

## Overview

This directory contains the **Progress Screen** — a four-tab academic progress viewer used by both **students** (viewing their own progress) and **guardians** (viewing their ward's progress).

## Files

| File | Status | Description |
|---|---|---|
| `progress_screen.dart` | ✅ Active | Main progress screen with 4 tabs: Overview, Exams, Mastery, Attendance |

## Key Classes

### Public

| Class | Description |
|---|---|
| `ProgressScreen` | `StatefulWidget` — entry point. Accepts `SchoolContext`, reads `currentEntry` to determine student scoping. |

### Internal Widgets

| Class | Description |
|---|---|
| `_ProgressTabBar` | Elevated tab bar with 4 tabs (Overview, Exams, Mastery, Attendance) |
| `_OverviewTab` | Identity header + 2×2 stats grid + recent exam results |
| `_StudentIdentityHeader` | Avatar + name + ADM + enrollment grade chip |
| `_StatsGrid` | 2×2 grid: attendance rate, latest exam avg, subjects count, class rank |
| `_AttendanceStat` | Single stat card for attendance percentage |
| `_LatestExamAvgStat` | Single stat card for latest exam average |
| `_SubjectsCountStat` | Single stat card for number of graded subjects |
| `_ClassRankStat` | Single stat card showing class rank |
| `_RecentExamResults` | List of recent exam result rows |
| `_ExamsTab` | Exam list grouped by exam with per-paper scores |
| `_ExamCard` | Individual exam card showing papers and scores |
| `_MasteryTab` | Subject-by-subject mastery progress with topic breakdown |
| `_MasterySubjectCard` | Single subject mastery card with topic rows |
| `_MasteryTopicRow` | Individual topic mastery progress bar |
| `_AttendanceTab` | Monthly calendar with attendance summary bar |
| `_AttendanceSummaryBar` | Present/absent/leave counts with attendance rate circle |
| `_AttendanceCalendar` | Month grid with day cells colored by attendance status |
| `_CalendarDayCell` | Single day cell in the attendance calendar |
| `_CalendarLegend` | Legend for attendance status colors |
| `_StatCard` | Reusable stat card with icon, label, value, tint |
| `_PercentBadge` | Small percentage badge used in exam cards |
| `_SectionTitle` | Section heading label |
| `_LoadingShimmer` | Loading placeholder (currently unused) |

## Entry Type Handling

The screen supports two `MembershipEntry` types:

- **`GuardianEntry`** → scopes all queries by `entry.ward.adm`
- **`StudentEntry`** → scopes all queries by `entry.student.adm`

Both resolve to a `StudentsData` object passed as `student` to all child widgets. Any other entry type shows a fallback message.

## Dependencies

- `AttendanceDao` — attendance records and summary stats
- `CatalogDao` — subject names
- `EnrollmentsDao` — student enrollment (grade chip display)
- `ExamsGradesDao` — grades, mastery data
- `ActiveTermProvider` — current term context from widget tree
- `SchoolContext` — school + entry + permissions

## History

- **Task B2:** Renamed from `GuardianProgressScreen` → `ProgressScreen`. Added `StudentEntry` support alongside existing `GuardianEntry`. Renamed internal `ward` parameters to `student` for clarity. File renamed from `guardian_progress_screen.dart` → `progress_screen.dart`.

## Last Updated

Task B2