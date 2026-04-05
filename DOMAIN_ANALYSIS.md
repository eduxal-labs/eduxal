# EduXal — Comprehensive Domain Analysis

> **Purpose:** This document provides an exhaustive, role-by-role domain analysis of how a school management application is used in a Kenyan/East African school context. It covers CBC (Competency-Based Curriculum) and 8-4-4 curriculum systems, M-Pesa payment workflows, term-based academic calendars, and the realities of schools that frequently operate in low-connectivity environments.
>
> **Audience:** Product owner, AI agents (Examiner/Orchestrator/Executor), and any contributor who needs to understand *why* a feature exists and *how* it fits into daily school life.
>
> **Grounded in:** The actual EduXal schema (33 synced tables + 2 client-only), the existing RBAC model (19 Resources × 9 Actions), the 5 membership roles (`owners`, `teachers`, `staff`, `students`, `guardians`), and the UI already built.

---

## Table of Contents

1. [Role 1: School Owner/Director](#role-1-school-ownerdirector)
2. [Role 2: Teacher](#role-2-teacher)
3. [Role 3: Staff (Admin/Secretary/Accountant)](#role-3-staff-adminsecretaryaccountant)
4. [Role 4: Guardian/Parent](#role-4-guardianparent)
5. [Role 5: Student](#role-5-student)
6. [Cross-Cutting Concerns](#cross-cutting-concerns)
7. [Kenyan/East African Context Notes](#kenyaneast-african-context-notes)

---

## Role 1: School Owner/Director

### Who They Are

In Kenya, a school director/owner is often the person who founded the school (especially private/academy schools), or is the appointed head for a public school board. They may run one school or multiple schools (a chain). They care deeply about **enrollment numbers** (revenue is directly tied to student count), **exam performance** (reputation drives enrollment), **fee collection rates** (cash flow), and **regulatory compliance**. Many school directors are not highly technical — the app must be effortlessly usable, not intimidating.

In EduXal, this is the `owners` table: `(school, user)` — a user can own multiple schools, and a school can have multiple owners.

---

### 1. Core Daily Needs (Must-Have Features)

#### 1a. Dashboard Overview — "How is my school doing right now?"

This is the first screen an owner sees every single morning. It must answer five questions in under 10 seconds:

| Question | Data Source | Current Implementation |
|---|---|---|
| How many students do I have? | `students` WHERE `status = Active` | `MembersDao.watchStudents` → `_StatCard` in `_OwnerOverview` |
| How much money came in this term? | `payments` joined with `invoices` for current term | `FinanceDao.watchTermFinanceSummary` → collection rate % |
| Are my teachers showing up? | `lessons` for today (proxy for teacher presence) | Teacher count via `MembersDao.watchTeachers` (lesson-based presence not yet surfaced) |
| What term are we in and how many days left? | `terms` WHERE current date falls within `start..end` | `_TermInfoCard` — year/term, date range, days remaining badge |
| Any urgent announcements or issues? | `announcements` + `logs` (failed syncs) | Recent 3 announcements + notification badge count |

**What's missing and needed:**

- **Revenue dashboard card**: Total invoiced vs. total collected vs. outstanding balance for the current term. The schema supports this via `fees → invoices → payments` chain. This needs a prominent position — not buried in the Finance tab.
- **Teacher attendance/lesson delivery rate**: The `lessons` table tracks which teachers actually delivered lessons on which days. A daily stat like "14/18 teachers taught today" is extremely valuable. Currently only lesson count is shown — no teacher presence rate.
- **Student attendance summary for today**: "412/450 students present today" — derived from `attendance` table for today's date. Currently only shown per-student for student/guardian roles, not aggregated for the owner dashboard.
- **Enrollment trend mini-chart**: Current term enrollment vs. previous term. Owners obsess over whether enrollment is growing or shrinking. Data exists in `enrollments` across terms.

#### 1b. Financial Oversight — "Is the school solvent?"

This is the owner's #1 operational concern. A Kenyan school director checks fee collection status multiple times per day, especially:
- At the start of term (are parents paying?)
- Mid-term (who hasn't paid? Do we need to send reminders?)
- End of term (can we afford to pay teachers and suppliers?)

**Must-have financial views:**

- **Fee collection rate by grade**: Which grades have the worst payment rates? This directly maps to the existing `fees` (per grade) → `invoices` (per student) → `payments` chain.
- **Outstanding balances list**: Sorted by amount descending — the "biggest debtors" list. Every school director has this on paper. We replace the paper.
- **Daily/weekly collection totals**: "We collected KES 245,000 this week." Derived from `payments.created` timestamps.
- **Payment method breakdown**: Cash vs. M-Pesa vs. Bank vs. Cheque. Critical because M-Pesa has instant confirmation (via `mpesa` table Daraja integration), while cash/cheque needs manual verification.
- **Overdue invoices**: `invoices` WHERE `status = Overdue` — needs a count and total amount.

#### 1c. Academic Oversight — "How are results looking?"

Exam performance IS the school's reputation. In Kenya, schools are literally ranked in newspapers by KCSE/KCPE results. An owner doesn't grade papers — they look at:

- **Term exam averages by grade**: "Grade 8 averaged 62%, Grade 7 averaged 58%". Derived from `grades` aggregated by the grade's enrollment context.
- **Subject-level performance**: "Mathematics is our weakest subject at 48% average." Helps with resource allocation (hire better math teacher? Buy more textbooks?).
- **Stream comparison**: If a school has parallel streams (East, West, North), which stream is performing best? The `ComparisonsTab` already does this beautifully.
- **Teacher effectiveness proxy**: Which teacher's classes perform best in exams? Sensitive but critical data.
- **Year-over-year trends**: Are we improving? This is the long game.

#### 1d. Quick Actions — What Owners Do (Not Just View)

- **Post announcements** to the whole school (all audiences) — existing in `announcements` with audience bitmask
- **Approve payments** — especially cash payments recorded by staff that need owner sign-off (maps to `approvePayment` sync action)
- **Create/edit terms** — defining the academic calendar (`terms` table with overlap triggers)
- **Manage grades and streams** — school structure setup via academics screen + `streams` table
- **Invite/remove staff and teachers** — member management via invitation flow

---

### 2. Weekly/Monthly Needs

| Need | Frequency | Schema Basis |
|---|---|---|
| Review exam results after marking is complete | Per exam (2-4 times/term) | `exams` → `papers` → `grades` |
| Check fee collection progress and send reminders | Weekly | `invoices` WHERE `status IN (Pending, Overdue)` |
| Review teacher lesson delivery rates | Weekly | `lessons` grouped by teacher |
| Create/update fee structures for next term | Once per term | `fees` table (per grade, per term) |
| Generate invoices for all students | Start of term (bulk) | `invoices` — one per student per fee |
| Review and approve roles/permissions | Monthly or as needed | `roles` + `scopes` tables |
| Plan next term (dates, fees, subjects) | End of current term | `terms`, `fees`, `subject_teachers` |
| Department performance review | Monthly | `departments` → `teachers` → `lessons` + `grades` |
| Subscription/plan management | Termly | `plans` → `subscriptions` → `discounts` |
| M-Pesa configuration and reconciliation | Setup once, reconcile monthly | `mpesa` table (Daraja credentials) |

---

### 3. Nice-to-Have / Delight Features

- **Comparative analytics across terms**: "Our Grade 10 average went from 54% in Term 1 to 61% in Term 2." This builds a narrative of improvement that owners use with parents and regulators.
- **Revenue forecasting**: Based on current enrollment × fee structure, projected total revenue for the term. Simple multiplication but saves mental math.
- **Parent engagement metrics**: How many parents have logged in? How many have viewed their child's grades? (Not in current schema — would need analytics tracking.)
- **Certificate/report card generation**: PDF export of student reports at end of term. Teachers enter grades, owners approve, system generates.
- **Competitor benchmarking** (future): Compare your school's performance against county/national averages. This is how schools market themselves.
- **Board meeting data export**: Summary reports (enrollment, finances, academics) exportable for board presentations.
- **Multi-school dashboard**: For owners with school chains — a meta-dashboard showing all schools side by side. The schema supports this (a user can be owner of multiple schools).

---

### 4. Pain Points in Traditional School Management

| Pain Point | How Technology Solves It |
|---|---|
| **Manual fee tracking in exercise books** — loses records, parents dispute balances | Digital ledger with timestamped payments and M-Pesa auto-confirmation |
| **No real-time enrollment numbers** — counted manually at start of term | Live count from `students` WHERE `status = Active` + `enrollments` for current term |
| **Exam results on paper** — takes weeks to compile, analyze, and distribute | Digital grade entry → instant analytics → parent access |
| **Cash handling fraud** — staff collects fees but doesn't record them | All payments logged with `recorder` field (accountability), M-Pesa bypasses cash entirely |
| **Teacher absenteeism invisible** — owners discover it weeks later | `lessons` table creates a daily log; absence = no lesson logged for scheduled slots |
| **Communication via paper notices** — parents lose them, messages don't reach home | Digital `announcements` with audience targeting (parents, students, teachers, staff) |
| **Term planning is chaotic** — dates overlap, fee structures inconsistent | `terms` table with overlap-prevention triggers, structured fee definitions per grade |
| **Can't manage school remotely** — owner must be physically present | Mobile-first app with full offline capability — manage from anywhere |
| **No data for decision-making** — gut feeling instead of analytics | Every data point captured digitally; aggregations and trends computed automatically |

---

### 5. Optimistic UI Patterns

The owner's experience must feel **instant**. Here's what that means concretely:

- **Creating an announcement**: The announcement appears in the feed immediately (written to local SQLite). The sync engine pushes it to the server in the background. If it fails, it appears in the notifications page as a failed sync entry — but the owner never waited for the network.
- **Approving a payment**: The payment status changes to "Approved" instantly in the UI. The `approvePayment` log entry queues for sync. The financial summaries (collection rate, outstanding balance) update immediately because they read from local Drift tables.
- **Editing a fee structure**: Local DB write is instant. All invoices linked to that fee are visible immediately. The sync logs the `updateFee` action.
- **Adding a student**: Student appears in the enrollment list immediately. The `createStudent` + `enrollStudent` log entries queue. If the student's phone conflicts with an existing user on the server, the reconciliation happens silently via delta writer.
- **Term creation**: The term appears in the term selector immediately. The `createTerm` action syncs. If the date range overlaps (detected by trigger), the local insert succeeds but the server will reject — the error appears in notifications.

**Key principle**: The owner never sees a loading spinner for a write operation. Reads may show brief loading states when the stream hasn't emitted yet, but writes are always instant.

---

### 6. Key Metrics/Dashboards

**Owner Dashboard — Dream Layout:**

```
┌──────────────────────────────────────────────┐
│  [School Name]       Term 2, 2025  [avatar]  │
├──────────┬──────────┬──────────┬─────────────┤
│ Students │ Teachers │ Collect. │ Avg Score   │
│   450    │   18     │  78%     │   64.2%     │
├──────────┴──────────┴──────────┴─────────────┤
│ Today's Attendance: 412/450 (91.6%)          │
│ ████████████████████░░░░                     │
├──────────────────────────────────────────────┤
│ Fee Collection This Term                     │
│ Invoiced: KES 4,500,000                      │
│ Collected: KES 3,510,000 (78%)               │
│ Outstanding: KES 990,000                     │
│ ████████████████████░░░░░░                   │
├──────────────────────────────────────────────┤
│ Recent Exam Performance (Mid-Term 2)         │
│ Grade 10: 64%  Grade 9: 58%  Grade 8: 71%   │
├──────────────────────────────────────────────┤
│ Recent Announcements (3)                     │
│ • Sports Day postponed to Friday             │
│ • Term 2 fees deadline extended              │
│ • New math teacher joining next week         │
└──────────────────────────────────────────────┘
```

---

### 7. Notification Needs

| Event | Priority | Mechanism |
|---|---|---|
| Payment received (especially M-Pesa) | High | Real-time — delta from `watchChanges` stream creates local `payments` row → reactive UI |
| Sync failure (action rejected by server) | High | `logs` WHERE `status = Failed` — shown in notification page with error details |
| Term is about to end (7 days, 3 days, 1 day) | Medium | Client-side computation from `terms.end` — can be a local notification |
| Exam marking completed (all papers → status: Marked) | Medium | Reactive — `papers` stream where all papers for an exam have `status = Marked` |
| New student enrolled | Low | Delta from sync — new `students` + `enrollments` row |
| Teacher hasn't logged a lesson in 3+ days | Medium | Client-side computation from `lessons` table — no lesson rows for teacher in recent days |
| Fee payment overdue for 30+ days | High | Client-side computation from `invoices.due` + current date |
| Low collection rate alert (<50% at mid-term) | High | Client-side computation from finance aggregation |

---

### 8. Offline Requirements

**Everything an owner does must work offline.** This is non-negotiable for Kenyan schools where internet may go out for hours or days.

| Operation | Offline? | Notes |
|---|---|---|
| View dashboard metrics | ✅ Yes | All from local Drift DB |
| View financial summaries | ✅ Yes | All computed from local `fees`, `invoices`, `payments` |
| View exam results | ✅ Yes | All from local `grades` + `papers` |
| Post announcements | ✅ Yes | Written to local DB + queued in `logs` |
| Approve payments | ✅ Yes | Local status change + queued in `logs` |
| Create terms | ✅ Yes | Local insert + queued in `logs` |
| Add students/teachers/staff | ✅ Yes | Local insert + queued in `logs` |
| Record cash payments | ✅ Yes | Local insert + queued in `logs` |
| M-Pesa payment confirmation | ❌ No | Requires server callback from Daraja API |
| AI paper generation | ❌ No | Requires server-side AI service |
| PDF report generation | ⚠️ Partial | Can generate locally if template is cached; server-side for complex reports |
| Profile image upload | ⚠️ Partial | Saved locally immediately, S3 upload queues when online |

---

## Role 2: Teacher

### Who They Are

In Kenya, teachers are the backbone of the school but are often overworked and underpaid. A typical secondary school teacher handles 3-5 subjects across multiple grades and streams, with classes of 40-60 students each. They mark hundreds of exam papers per term, often by hand. They track attendance in paper registers. They write schemes of work and lesson plans in physical notebooks that inspectors check.

Technology adoption varies: younger teachers (under 35) are generally smartphone-savvy. Older teachers may need a simpler experience. The app must make their core tasks (attendance, grading, timetable) so fast and easy that it's clearly better than paper.

In EduXal, a teacher is in the `teachers` table: `(school, user)` with optional `department`, `role`, `hired` date, and `status`.

---

### 1. Core Daily Needs

#### 2a. "What am I teaching today?" — Timetable at a Glance

This is literally the first thing a teacher checks every morning. Before anything else: **what classes do I have today?**

- **Today's schedule**: Filtered from `timetable` WHERE `day = today` AND `teacher = me`, ordered by `start` time. Shows: time slot, subject, grade + stream, room (if available).
- **Current implementation**: `_TeacherTodaySchedule` in `_TeacherOverview` does exactly this — filters `TimetableDao.watchTeacherTimetable` to current day of week.
- **What teachers actually want**: A countdown to the next class. "Mathematics, Grade 9 East, starts in 23 minutes." This creates urgency without being stressful.

#### 2b. Attendance Marking — "Who's here?"

This happens at the start of every class or once at morning assembly. It must be **faster than the paper register** or teachers won't use it.

- **Schema**: `attendance` table — `(school, year, term, grade, stream, student, date, status)` where status is Present/Absent/Leave.
- **Current implementation**: `AttendanceTab` has instant-save pattern with "Mark All Present" bulk action. Toggle buttons P/A/L per student. This is excellent — it's faster than paper.
- **Critical detail**: In Kenyan schools, attendance is typically taken by the **class teacher** (assigned via `class_teachers` table) once in the morning, not per-lesson. Subject teachers may take their own attendance for individual classes, but the "official" register is the class teacher's morning roll call.
- **Permission model**: `AttendanceTab` correctly resolves `_canMark` based on whether the teacher is the class teacher for that stream (via `class_teachers` table) OR has `Resource.attendance, Action.mark` permission. BUG-017 expanded this so teachers with the permission can mark for non-assigned classes too.

#### 2c. Grade Entry — "Marking exams"

This is the most labor-intensive task a teacher does. During exam season, a teacher may need to enter scores for 200+ students across multiple papers. It must be:

- **Fast**: Keyboard-driven on desktop (tab between fields), touch-optimized on mobile. No unnecessary taps.
- **Error-proof**: Score cannot exceed total. Visual feedback for out-of-range values.
- **Resumable**: If a teacher marks 50 papers, puts the phone down, and comes back later, the 50 should be saved. The current instant-save pattern handles this.
- **Current implementation**: `_GradeSpreadsheet` (desktop) and `_GradeList` (mobile) in `paper_detail_page.dart`. Grades are saved via `ExamsGradesDao.upsertGrade` immediately. This is solid.

#### 2d. Lesson Logging — "I taught this today"

Kenya's education system requires teachers to maintain a "lesson record" (or "records of work") showing what was taught, when, and to which class. Inspectors from the Ministry of Education check these. Traditionally this is a physical notebook.

- **Schema**: `lessons` table — `(school, year, term, grade, stream, date, subject, teacher)`. Simple existence = "this lesson happened."
- **Current implementation**: The "Generate Lessons" feature (`_GenerateLessonsFab` in `timetable_screen.dart`) auto-generates lesson entries from timetable data for today or this week. Teachers can also edit/substitute.
- **What teachers want**: Automatic logging. "If I showed up and the timetable says I had a class, log it." The generate feature is exactly right.

---

### 2. Weekly/Monthly Needs

| Need | Frequency | Schema Basis |
|---|---|---|
| Review class performance after marking | Per exam (2-4 times/term) | `grades` aggregated by class |
| Update mastery scores for students | After assessments | `mastery` table — per student, per subject, per topic |
| Plan lessons for the week (schemes of work) | Weekly | Not yet in schema — currently `scheme_pages` table exists for file-based schemes |
| Check own timetable for next week | Weekly | `timetable` filtered by teacher |
| Review subject-wise performance across classes | Monthly | `grades` grouped by subject across all classes taught |
| Department meetings (view department members) | Monthly | `teachers` + `staff` WHERE `department = X` |
| Report card preparation | End of term | `grades` + `mastery` aggregated per student |
| Submit continuous assessment marks | Per topic/unit | `grades` WHERE exam type = `Assessment` |

---

### 3. Nice-to-Have / Delight Features

- **Smart timetable conflicts detection**: "You have overlapping classes on Tuesday at 10:00" — the `uq_timetable_teacher_slot` unique index catches this at the DB level, but a friendly UI warning is better.
- **Teaching load visualization**: "You teach 28 lessons/week (school average is 24)." Helps with workload conversations.
- **Student performance alerts**: "John's grades have dropped 15% over the last 3 exams." Derived from `grades` trend analysis.
- **Quick parent messaging**: For a specific student — "Your child missed class today" or "Great improvement in Mathematics!" Currently not in schema (would need a messaging table or integration).
- **Topic coverage tracker**: Which topics have I taught vs. which remain? Maps to `topics` table (global catalog) + `lessons` (what was actually taught). Currently `topics` exist but aren't linked to lessons.
- **AI-assisted grading**: Already partially implemented via `_runAiMarking()` in paper detail page. This is a genuine delight feature — marking 200 papers by hand takes days; AI assistance could cut it to hours.
- **Collaborative exam setting**: Multiple teachers contribute questions to a shared exam bank. The `paper_generation_page.dart` with topic allocation is a start.
- **Personalized recommendations**: "Based on mastery data, 12 students in Grade 9 East need extra help with Quadratic Equations." Maps to `mastery` + `topics`.

---

### 4. Pain Points in Traditional School Management

| Pain Point | Impact | How EduXal Solves It |
|---|---|---|
| **Marking 300 exam papers by hand** — takes 2-3 weeks, delays results | Students and parents wait anxiously; teacher is exhausted | Digital grade entry (instant save, tab-through on desktop), AI-assisted marking for objective questions |
| **Paper attendance registers** — lost, damaged, hard to aggregate | No accurate attendance data for the term; parents uninformed | Digital attendance with "Mark All Present" + per-student toggle; instant sync to guardians |
| **No visibility into student progress trends** — only know grades at exam time | Intervention comes too late | Continuous assessment + mastery tracking + trajectory indicators (improving/declining/stable) |
| **Timetable changes communicated verbally** — causes confusion | Teachers show up to wrong classes | Digital timetable synced to all devices; changes propagate via delta sync |
| **Manual report card writing** — one per student, by hand, end of term | Teachers spend entire last week writing reports instead of teaching | Digital grades auto-populate report templates |
| **Carrying multiple books** — attendance register, record of work, markbook, timetable | Physical burden; easy to lose | Single device replaces all paper records |
| **Subject allocation arguments** — "I was supposed to teach Grade 10!" | Creates staff friction | Digital `subject_teachers` assignments visible to all, set by admin |
| **No departmental collaboration** — each teacher works in isolation | Best practices not shared; weak teachers struggle alone | Department views, shared exam banks, comparative analytics |

---

### 5. Optimistic UI Patterns

- **Marking attendance**: Each P/A/L toggle takes effect immediately (local DB write). No "Save" button. The teacher taps through the class in 30 seconds. If they mark a student absent then change to present, it just overwrites locally. The `markAttendance` log entry captures the final state.
- **Entering grades**: Each score is saved on field blur / enter key. No need to hit "Submit" for the whole class. If network is down, all grades are local. When connectivity returns, each `markGrades` action syncs one at a time.
- **Creating a lesson record**: Tap "Generate for Today" → lessons appear immediately in the log. The bulk insert writes locally, logs sync in background.
- **Viewing timetable**: Always instant — it's a local query. Even if the timetable was just changed by the owner, the delta comes through the watch stream and the UI updates reactively.

---

### 6. Key Metrics/Dashboards

**Teacher Dashboard — Dream Layout:**

```
┌──────────────────────────────────────────────┐
│  Good morning, Mr. Odhiambo       [avatar]   │
│  Teacher · Mwangaza Academy                   │
├──────────────────────────────────────────────┤
│  TODAY'S SCHEDULE (Tuesday)                   │
│  ┌─ 08:00–09:00  Mathematics · Gr 9 East     │
│  ├─ 09:00–10:00  Mathematics · Gr 10 West    │
│  ├─ 10:30–11:30  Physics · Gr 10 East        │
│  └─ 14:00–15:00  Mathematics · Gr 8 North    │
│           Next class in 23 min ▶              │
├──────────┬──────────┬────────────────────────┤
│ My Subj. │ My Exams │ Lessons This Week      │
│    5     │    3     │   12 / 16 (75%)        │
├──────────┴──────────┴────────────────────────┤
│  RECENT GRADES                                │
│  Mid-Term 2 · Grade 9 East · Maths: Avg 58%  │
│  Mid-Term 2 · Grade 10 West · Maths: Avg 64% │
├──────────────────────────────────────────────┤
│  ATTENDANCE TODAY                             │
│  Gr 9 East: 38/42 (marked ✓)                 │
│  Gr 10 West: Not yet marked ⚠                │
├──────────────────────────────────────────────┤
│  Announcements (2 new)                        │
│  • Staff meeting Thursday 4pm                 │
│  • Sports Day schedule attached               │
└──────────────────────────────────────────────┘
```

---

### 7. Notification Needs

| Event | Priority | Mechanism |
|---|---|---|
| Timetable change affecting my classes | High | Delta sync on `timetable` table → reactive stream |
| New exam created that includes my subjects | High | Delta sync on `exams` + `papers` → match against `subject_teachers` |
| Student enrolled/unenrolled in my class | Medium | Delta sync on `enrollments` → reactive stream |
| Exam marking deadline approaching | Medium | Client-side: `exams.end` minus today; surface when papers are still `Pending`/`Progress` |
| Announcement targeting teachers | Medium | Delta sync on `announcements` WHERE audience includes teacher bit (4) |
| My role/permissions changed | Medium | Delta sync on `scopes` table |
| AI marking completed for my paper | High | Local event from `questionBankService` response |
| Parent sent a message about a student (future) | Medium | Not yet in schema |
| New subject/class assigned to me | High | Delta sync on `subject_teachers` WHERE `teacher = me` |

---

### 8. Offline Requirements

| Operation | Offline? | Notes |
|---|---|---|
| View my timetable | ✅ Yes | Local `timetable` query |
| Mark attendance | ✅ Yes | Local write + log queue |
| Enter grades | ✅ Yes | Local write + log queue |
| Generate lessons | ✅ Yes | Local computation from timetable data |
| View student list for my classes | ✅ Yes | Local `enrollments` + `students` query |
| View exam results and analytics | ✅ Yes | Local `grades` aggregation |
| Create an exam | ✅ Yes | Local write + log queue |
| Add papers to an exam | ✅ Yes | Local write + log queue |
| AI paper generation | ❌ No | Requires server-side AI |
| AI grading assistance | ❌ No | Requires server-side AI |
| View/edit schemes of work (if file-based) | ⚠️ Partial | File must be cached locally |
| Upload answer sheets | ⚠️ Partial | File saved locally, S3 upload queues |
| Post announcement | ✅ Yes | Local write + log queue |

---

## Role 3: Staff (Admin/Secretary/Accountant)

### Who They Are

In a Kenyan school, "staff" covers several critical roles:

- **Secretary/Receptionist**: Handles student registration, maintains records, manages communication between parents and teachers, handles visitor reception.
- **Accountant/Bursar**: Manages fee collection, issues receipts, tracks outstanding balances, handles M-Pesa reconciliation, manages school expenses, prepares financial reports for the board.
- **Office Administrator**: General school operations — supplies, maintenance coordination, government correspondence.
- **ICT Staff** (larger schools): Maintains computer labs, sometimes manages the school management system.

These people are the operational backbone. They handle the most tedious, repetitive, error-prone tasks. Technology should eliminate their pain.

In EduXal, staff is in the `staff` table: `(school, user)` with optional `idnumber`, `role`, `department`, `status`.

---

### 1. Core Daily Needs

#### 3a. Fee Collection and Receipting

This is the single most time-consuming task for school administrative staff. In a school of 500 students:

- **Morning rush**: 20-30 parents come to pay fees before going to work (7:00-8:30 AM). Each needs a receipt.
- **M-Pesa payments**: Throughout the day, M-Pesa messages come in. Each must be reconciled against the correct student and invoice.
- **Cash handling**: Cash payments must be recorded with the staff member's name for accountability.

**Schema flow:**
1. `fees` defines what's owed per grade per term (created by owner)
2. `invoices` are generated per student per fee (can be bulk-generated)
3. `payments` record each payment against an invoice (or directly against a school+student)
4. `payments.method` tracks Cash/Cheque/Mpesa/Bank
5. `payments.recorder` tracks who recorded the payment (accountability)

**What staff needs:**
- **Quick payment recording**: Select student (by name or admission number) → see their outstanding balance → record payment amount + method → done. Must be under 30 seconds per transaction.
- **Receipt generation**: After recording, generate a receipt (printable or shareable via WhatsApp).
- **M-Pesa auto-matching**: When an M-Pesa payment comes in via Daraja API, auto-match to the correct student by phone number or reference code. This is the dream feature that saves hours of manual reconciliation.
- **Bulk invoice generation**: "Generate invoices for all Grade 7 students for Term 2 Transport Fee." One action creates 60 invoices.
- **Balance inquiry**: Parent calls and asks "how much do I owe?" Staff should find the answer in 3 seconds by searching student name or ADM number.

#### 3b. Student Registration and Enrollment

Start of term is chaos. 50-100 new students may enroll. Returning students need their enrollment renewed.

**Schema flow:**
1. `students` table — create the student record (ADM number, name, DOB, gender, etc.)
2. `enrollments` table — assign the student to a grade + stream for the current term
3. `guardians` table — link parent/guardian to the student
4. `invoices` — generate fee invoices for the newly enrolled student

**What staff needs:**
- **Quick registration form**: Name, admission number, date of birth, gender, guardian phone → creates student + enrollment + guardian + invoices in one flow. The `MemberCreationService` and phone-first panels handle the user/member creation, but the full enrollment + invoicing flow should be streamlined.
- **Returning student re-enrollment**: "Roll over all Grade 7 East students to Grade 8 East for next term." Bulk operation.
- **Transfer handling**: Student transfers from another school — create student, mark as transferred-in, generate invoices from the transfer date.
- **Search and find**: By name, admission number, or parent phone number. Must be fast — parents are waiting at the desk.

#### 3c. Record Management and Daily Operations

- **Student record queries**: "Give me all students in Grade 10 who haven't paid transport fees." Complex but common query.
- **Report generation**: End-of-term reports, government-mandated enrollment returns, fee collection summaries.
- **Communication relay**: Teachers send notes to parents via staff; parents leave messages for teachers at the office.
- **Document management**: Keeping copies of birth certificates, transfer letters, etc. The `students.documents` field (text/JSON) could store references.

---

### 2. Weekly/Monthly Needs

| Need | Frequency | Schema Basis |
|---|---|---|
| Fee collection reconciliation (cash + M-Pesa + bank) | Weekly | `payments` grouped by method and date |
| Outstanding balance reports for the director | Weekly | `invoices` WHERE `status != Paid` aggregated |
| New student registration (ongoing enrollment) | As needed | `students` + `enrollments` + `guardians` |
| Government enrollment data submission (NEMIS) | Termly | `students` + `enrollments` aggregated by gender, age, grade |
| Generate end-of-term fee statements for parents | End of term | `invoices` + `payments` per student |
| Bulk invoice generation for next term | Start of term | `fees` → `invoices` bulk creation |
| Print/share receipts for the week | Weekly | `payments` with receipt formatting |
| Update student records (address, guardian changes) | As needed | `students`, `guardians` updates |
| Staff attendance tracking | Daily summary | Not yet in schema (staff don't have attendance table) |
| Prepare documents for school inspection | Annually | Aggregated data exports |

---

### 3. Nice-to-Have / Delight Features

- **Auto-complete student search**: Start typing "Wan" → shows "Wanjiku, Grace (ADM 2345, Grade 8 East)" instantly. Powered by local SQLite FTS or LIKE queries.
- **Payment receipt via WhatsApp**: After recording a payment, share a formatted receipt image to the parent's WhatsApp. Very common workflow in Kenya.
- **M-Pesa STK Push**: Instead of waiting for the parent to initiate payment, the staff triggers an STK push to the parent's phone ("Pay KES 15,000 for school fees?"). The `mpesa` table has the Daraja credentials.
- **Defaulter SMS alerts**: Auto-send fee reminders to parents with outstanding balances. Would need SMS integration.
- **Inventory tracking** (future): Track school supplies — books distributed, lab equipment, etc. Not in current schema.
- **Visitor management** (future): Log visitors entering the school. Not in current schema.
- **Daily cash summary**: "Today: 12 cash payments = KES 84,000. 8 M-Pesa payments = KES 126,000. Total: KES 210,000."
- **Duplicate detection**: When registering a new student, flag if a student with the same name and DOB already exists. Prevent ghost students.
- **Fee balance SMS**: Parent sends their child's ADM number to a shortcode and gets back their balance. Would integrate with M-Pesa Daraja.

---

### 4. Pain Points in Traditional School Management

| Pain Point | Impact | How EduXal Solves It |
|---|---|---|
| **Manual receipt books** — carbon copies that fade, numbers that skip | No audit trail; disputes are unresolvable | Digital payment records with `payments.recorder` for accountability |
| **M-Pesa reconciliation nightmare** — matching 50+ daily M-Pesa messages to students | 2-3 hours daily wasted; errors cause parent complaints | Daraja integration auto-matches by phone/reference; manual matching as fallback |
| **Paper student files** — one manila folder per student, filed in a cabinet | Files get lost; information retrieval takes 10+ minutes | Digital student records searchable in seconds |
| **Handwritten fee ledgers** — one per class, maintained by class teacher or secretary | Arithmetic errors; balance disputes; no real-time totals | Automatic balance computation from `invoices - payments` |
| **NEMIS (government system) data entry** — re-typing student data into a government portal | Duplication of effort; data entry errors | Export student data in NEMIS-compatible format (future) |
| **No audit trail for cash** — "I paid KES 5,000 but it's not recorded!" | Trust erosion between parents and school | Every payment timestamped with recorder; M-Pesa has automatic proof |
| **Bulk operations done one-by-one** — generating 300 invoices manually | Takes all day; error-prone | Bulk invoice generation: select fee + grade → done in seconds |
| **Physical queues for fee payment** — parents wait 30-60 minutes | Parent frustration; they avoid paying on time | M-Pesa payment from anywhere; balance check via app |

---

### 5. Optimistic UI Patterns

- **Recording a payment**: Staff enters amount, selects method → payment appears in the student's history instantly. Balance recalculates immediately. Receipt is ready. The `createPayment` log entry queues for sync.
- **Registering a student**: Fill form → student appears in the members list and enrollment list immediately. Guardian receives an invitation (their phone gets a user entry with `status = Invited`). All happens locally.
- **Generating bulk invoices**: Tap "Generate for Grade 7, Term 2 Tuition" → 45 invoices appear in the list within seconds (local batch insert). The `createInvoice` log entries queue one per invoice.
- **Searching for a student**: Results appear as the staff types — no need to press Enter. Powered by Drift's reactive queries with debounced search.

---

### 6. Key Metrics/Dashboards

**Staff Dashboard — Dream Layout:**

```
┌──────────────────────────────────────────────┐
│  Welcome, Susan          Bursar  [avatar]     │
│  Mwangaza Academy · Term 2, 2025              │
├──────────────────────────────────────────────┤
│  TODAY'S COLLECTIONS                          │
│  Cash: KES 84,000 (12 payments)              │
│  M-Pesa: KES 126,000 (8 payments)            │
│  Total: KES 210,000                           │
├──────────┬──────────┬────────────────────────┤
│ Students │ Invoices │ Pending Payments        │
│   450    │  1,350   │    KES 990,000         │
├──────────┴──────────┴────────────────────────┤
│  QUICK ACTIONS                                │
│  [Record Payment] [Search Student] [New Reg]  │
├──────────────────────────────────────────────┤
│  RECENT PAYMENTS                              │
│  09:15  Wanjiku Grace (2345) KES 15,000 Cash  │
│  09:08  Omondi James (1234) KES 8,500 M-Pesa  │
│  08:55  Akinyi Sarah (3456) KES 12,000 Cash   │
├──────────────────────────────────────────────┤
│  OVERDUE INVOICES (top 5)                     │
│  1. Kibet Brian (5678) — KES 45,000 (62 days) │
│  2. Mutua Dennis (4567) — KES 38,000 (45 days)│
│  3. Njeri Winnie (6789) — KES 32,000 (30 days)│
└──────────────────────────────────────────────┘
```

---

### 7. Notification Needs

| Event | Priority | Mechanism |
|---|---|---|
| M-Pesa payment received (Daraja callback) | High | Server pushes delta → new `payments` row with `method = Mpesa` |
| Invoice overdue (past due date) | Medium | Client-side check: `invoices.due < today` AND `status = Pending` |
| Sync failure for recorded payment | High | `logs` WHERE `status = Failed` AND `action = createPayment` |
| New student registered by another staff member | Low | Delta sync on `students` table |
| Announcement from owner | Medium | Delta sync on `announcements` WHERE audience includes staff bit (8) |
| End-of-day collection summary (local) | Medium | Client-side: aggregate today's `payments.created` |
| Bulk invoice generation completed | Medium | Local — after batch insert completes |
| Payment approved by owner | Medium | Delta sync on `payments` where `approvePayment` was processed |

---

### 8. Offline Requirements

| Operation | Offline? | Notes |
|---|---|---|
| Record cash/cheque payments | ✅ Yes | Local write + log queue |
| Search students by name/ADM | ✅ Yes | Local SQLite query |
| View student fee balance | ✅ Yes | Local computation from `invoices` - `payments` |
| Register new students | ✅ Yes | Local write + log queue |
| Generate bulk invoices | ✅ Yes | Local batch write + log queue |
| View payment history | ✅ Yes | Local `payments` query |
| Print/export receipts | ⚠️ Partial | Can generate locally if printer is on local network |
| M-Pesa payment processing | ❌ No | Requires Daraja API (server-side) |
| M-Pesa STK Push | ❌ No | Requires Daraja API (server-side) |
| Sync payment data with other devices | ❌ No | Requires connectivity to push/pull |
| Government (NEMIS) data export | ✅ Yes | Generated from local data |

---

## Role 4: Guardian/Parent

### Who They Are

Kenyan parents are intensely invested in their children's education — it's seen as the primary path to upward mobility. A typical parent interacts with the school in these ways:

- **Daily**: Worries about whether their child went to school and is safe
- **Weekly**: Wonders how their child is performing
- **Monthly**: Checks fee balance, makes payments
- **Termly**: Collects report card, meets teachers during academic days

Many parents are NOT tech-savvy. They use basic smartphones with limited data plans. The app must be extremely simple — fewer screens, larger text, clear labels in plain language (not educational jargon).

In Kenya, it's common for:
- One parent to have children in **multiple schools** (e.g., one in primary, one in secondary)
- Extended family (uncle, grandmother) to be the "guardian" paying fees
- Both parents to monitor the same child independently

In EduXal, guardians are in the `guardians` table: `(school, user, student)` with `relationship` (Father/Mother/Brother/Sister/Guardian) and `role` (Primary/Secondary/Sponsor). The `role = Primary` has a unique index per student — only one primary guardian allowed.

---

### 1. Core Daily Needs

#### 4a. "Is my child in school?" — Attendance Tracking

This is the #1 parental anxiety. For boarding school parents, it's less acute (the child is always at school). For day school parents, especially in urban areas with security concerns, knowing their child arrived safely is critical.

- **Schema**: `attendance` WHERE `student = my_child_adm` AND `date = today`
- **Current implementation**: `_StudentAttendanceSummary` on the guardian overview shows aggregate attendance (present/absent/leave percentages). But parents want **today's** status prominently.
- **What parents actually want**: A single, prominent indicator at the top of the screen:
  - ✅ "Grace was marked PRESENT today at 8:15 AM" (with green checkmark)
  - ❌ "Grace was marked ABSENT today" (with red warning)
  - ⏳ "Attendance not yet taken for today" (grey, neutral)
  
  This single element provides more peace of mind than any other feature.

#### 4b. "How is my child doing?" — Academic Performance

Parents check grades obsessively after exams. In traditional schools, they must physically go to school and queue to see the class teacher. Digital access is transformative.

- **Schema**: `grades` WHERE `student = my_child_adm`, joined with `exams` for context
- **Current implementation**: `_StudentRecentGrades` on guardian overview shows last 3 exams with percentages. The `Progress` screen (from `progress_screen.dart`) has deeper analytics.
- **What parents want to see at a glance**:
  - Latest exam: subject scores + total + percentage + class rank
  - Trend: "Improving" / "Declining" / "Stable" (already implemented as trajectory indicator)
  - Comparison: How does my child compare to the class average? Stream average? Grade average?
  - Subject strengths/weaknesses: "Strong in English (78%), needs help in Mathematics (42%)"

#### 4c. "How much do I owe?" — Fee Balance

Fee transparency is a major trust issue between parents and schools. Parents often claim they've paid more than records show. Digital records solve disputes.

- **Schema**: `invoices` + `payments` WHERE `student = my_child_adm`
- **Current implementation**: `_GuardianFinanceSummary` shows total invoiced / paid / balance with color-coded amounts.
- **What parents want**:
  - Clear total outstanding balance (the one number that matters)
  - Breakdown by fee type (tuition: KES 25,000, transport: KES 8,000, lunch: KES 5,000)
  - Payment history with dates and methods
  - **A "Pay Now" button** that triggers M-Pesa STK Push or shows the school's paybill number

---

### 2. Weekly/Monthly Needs

| Need | Frequency | Schema Basis |
|---|---|---|
| Check attendance for the past week | Weekly | `attendance` for recent dates |
| Review exam results when released | Per exam | `grades` + `exams` |
| Make fee payment | Monthly (or when reminded) | `payments` creation → M-Pesa or cash |
| Read school announcements | As posted | `announcements` WHERE audience includes parents bit (2) |
| Check next term dates/fees | End of term | `terms` + `fees` for next term |
| View report card | End of term | `grades` + `mastery` aggregated |
| Check child's timetable | As needed | `timetable` filtered by grade+stream |
| Contact class teacher (future) | As needed | Not yet in schema |
| View ward's subscription/plan status | Termly | `subscriptions` for the student |

---

### 3. Nice-to-Have / Delight Features

- **Push notifications for attendance**: "Grace was marked present at 8:12 AM" — sent within minutes of the teacher marking attendance. This is the killer feature for day schools.
- **Exam result alerts**: "Grade 9 Mid-Term results are now available. Tap to view Grace's scores." Triggered when all papers for an exam are marked.
- **Fee reminder with payment link**: "Your balance is KES 15,000. Due date: March 15. Pay now via M-Pesa?" One-tap payment.
- **Parent-teacher chat** (future): Direct messaging with the class teacher about the child's progress. Would need a messaging table.
- **Homework tracking** (future): "Grace has a Mathematics assignment due Friday." Not in current schema.
- **Sibling view**: If a parent has 3 children at the same school, show all three on one screen with comparative data. The current `GuardianEntry` expands per ward, which is correct.
- **Multi-school view**: Children at different schools shown on the home screen as separate school cards. Already supported by the membership model.
- **Achievement badges**: "Grace scored highest in English this term! 🏆" Gamification element.
- **Calendar view**: School events, exam dates, fee due dates, holidays — all in one calendar. Data exists across `terms`, `exams`, `fees`.
- **Historical grade graphs**: Line chart showing grade trajectory over terms. "Grace went from 52% to 67% over the year."

---

### 4. Pain Points in Traditional School Management

| Pain Point | Impact | How EduXal Solves It |
|---|---|---|
| **No way to know if child is in school** — until they come home (or don't) | Parental anxiety; safety concern | Real-time attendance status on app dashboard |
| **Queueing at school for results** — takes a half-day off work | Lost productivity; parents skip checking | Digital grade access the moment results are entered |
| **Fee disputes** — "I paid but the school says I didn't!" | Broken trust; confrontations | Timestamped payment records with method and recorder |
| **Lost paper report cards** — child loses them or they get damaged | No record for future reference (e.g., university applications) | Digital report cards always accessible |
| **Communication black hole** — notes sent via child never arrive; can't reach teacher | Missed events; child falls behind without parent knowing | Digital announcements + targeted messaging |
| **No visibility into daily school life** — parent only knows what child tells them | Misses problems (bullying, academic struggle) early | Attendance, grades, and mastery data paint a complete picture |
| **Multiple children, multiple schools** — keeping track is impossible | Important dates missed; fee payments confused | Single app showing all children across all schools |
| **Fee payment inconvenience** — must go to school or bank in person | Late payments; defaulter lists | M-Pesa payment from anywhere, anytime |

---

### 5. Optimistic UI Patterns

- **Viewing attendance**: The moment the teacher marks attendance, the delta syncs to the server, and the server pushes it to the parent's device via `watchChanges`. The parent sees "Present today ✅" without refreshing.
- **Viewing grades**: When the teacher saves a grade, it's in the local DB (teacher's device), gets synced to server, and delta-pushed to the parent's device. The parent sees the new score within seconds (if both are online).
- **Making a payment**: If the parent records a cash payment (at the school), the staff creates the payment and it appears on the parent's device via sync. M-Pesa payments are confirmed by the server's Daraja callback.
- **Reading announcements**: Announcements posted by the owner appear on the parent's device via delta sync. No pull-to-refresh needed — the watch stream pushes it.

**Special consideration for parents**: The app should feel like a read-only window into the school. Parents don't create data (except payments) — they consume it. The UI should be minimal: big numbers, clear labels, obvious status indicators.

---

### 6. Key Metrics/Dashboards

**Guardian Dashboard — Dream Layout:**

```
┌──────────────────────────────────────────────┐
│  Hello, Mrs. Wanjiku             [avatar]     │
│  Guardian · Mwangaza Academy                  │
├──────────────────────────────────────────────┤
│                    Grace Wanjiku               │
│  ┌────────────────────────────────────────┐   │
│  │  ✅ PRESENT TODAY  (marked at 8:12 AM) │   │
│  └────────────────────────────────────────┘   │
│                                               │
│  ADM: 2345  ·  Grade 9 East  ·  Improving ↗  │
├──────────────────────────────────────────────┤
│  LATEST EXAM: Mid-Term 2                      │
│  English: 72%  Maths: 58%  Science: 65%       │
│  Kiswahili: 68%  Social St.: 61%              │
│  Total: 324/500 (64.8%)  ·  Rank: 12th/42    │
├──────────────────────────────────────────────┤
│  ATTENDANCE THIS TERM                         │
│  ██████████████████░░  91% Present            │
│  Present: 62  ·  Absent: 4  ·  Leave: 2      │
├──────────────────────────────────────────────┤
│  FEE BALANCE                                  │
│  Outstanding: KES 15,000                      │
│  Last payment: KES 10,000 (M-Pesa, 12 Mar)   │
│               [Pay Now via M-Pesa]            │
├──────────────────────────────────────────────┤
│  ANNOUNCEMENTS                                │
│  📢 Sports Day this Friday at 8 AM            │
│  📢 End of Term: April 5, 2025                │
└──────────────────────────────────────────────┘
```

---

### 7. Notification Needs

| Event | Priority | Mechanism |
|---|---|---|
| Child marked present/absent today | High | Delta sync on `attendance` WHERE `student = ward.adm` AND `date = today` |
| New exam results available | High | Delta sync on `grades` WHERE `student = ward.adm` |
| Fee payment confirmed | High | Delta sync on `payments` WHERE `student = ward.adm` |
| Fee overdue reminder | Medium | Client-side: `invoices.due < today` AND `status = Pending` |
| School announcement posted | Medium | Delta sync on `announcements` WHERE audience includes parents (bit 1) |
| Child's attendance dropped below 80% | Medium | Client-side computation from attendance aggregation |
| Child's grades declining (3+ exams trend) | Medium | Client-side trajectory computation from `grades` |
| Term is about to end | Low | Client-side from `terms.end` |
| New fee structure published | Medium | Delta sync on `fees` for the ward's grade |
| Report card available | High | Triggered when all exam grades for the term are marked |

---

### 8. Offline Requirements

| Operation | Offline? | Notes |
|---|---|---|
| View child's attendance | ✅ Yes | Local `attendance` query |
| View child's grades | ✅ Yes | Local `grades` query |
| View fee balance | ✅ Yes | Local `invoices` + `payments` computation |
| View payment history | ✅ Yes | Local `payments` query |
| Read announcements | ✅ Yes | Local `announcements` query |
| View timetable | ✅ Yes | Local `timetable` query |
| View report card | ✅ Yes | Local data — all grades/mastery available |
| Make M-Pesa payment | ❌ No | Requires Daraja API |
| Receive attendance notifications | ❌ No | Requires sync connection to receive deltas |
| Contact teacher | ❌ No | Would require messaging infrastructure |

---

## Role 5: Student

### Who They Are

In Kenya, students who would use a school management app are typically **secondary school** students (ages 14-18, Forms 1-4 / Grades 10-12 CBC). Primary school students are generally too young for app-based interaction. Secondary students have varying levels of smartphone access:

- **Day schools**: Many have phones or can access a parent's phone
- **Boarding schools**: Phones are typically confiscated during term; access only during visiting days or holidays
- **Urban schools**: Higher smartphone penetration
- **Rural schools**: May only have access to feature phones

The student's perspective is unique: they are the **subject** of most data in the system (attendance, grades, enrollment), but their **active interaction** with the app is limited. They are primarily consumers of information about themselves.

In EduXal, a student is in the `students` table: `(school, adm)` with optional `user` link (some students — especially younger ones — may not have a phone and thus no user account). The `enrollments` table assigns them to a specific `(year, term, grade, stream)`.

---

### 1. Core Daily Needs

#### 5a. "What class do I have next?" — Timetable

This is the student's most-used feature. The timetable is their roadmap for the day.

- **Schema**: `timetable` filtered by the student's enrolled `(grade, stream)` and `day = today`
- **Current implementation**: `_StudentTodaySchedule` on the student overview shows today's classes with subject, teacher name, and time.
- **What students want**: 
  - "Next class: Physics with Mr. Odhiambo in 12 minutes"
  - A week view to see what's coming
  - Break times explicitly shown (not just "gaps between classes")

#### 5b. "How did I do?" — Grade Viewing

After every exam, students are anxious about their results. In Kenyan schools, results are often announced publicly (teacher reads out scores in class, or results are pinned to a noticeboard). Digital access gives students a private, dignified way to check.

- **Schema**: `grades` WHERE `student = my_adm`, joined with `exams` and `papers`
- **Current implementation**: `_StudentRecentGrades` on overview shows last 3 exams. The `Grades` nav item (student role) goes to the Progress screen with deeper analytics.
- **What students want**:
  - My score vs. class average (to know where they stand without public ranking shame)
  - Subject-by-subject breakdown
  - "What do I need to score in the final exam to get 60% overall?" — grade calculator
  - Historical trend — am I improving?

#### 5c. "Was I in school?" — Attendance Record

Students may want to verify their attendance record, especially if:
- They dispute an "absent" mark (they were in school but arrived late)
- They need to justify an absence (medical leave)
- They want to track their own consistency

- **Schema**: `attendance` WHERE `student = my_adm`
- **Current implementation**: `_StudentAttendanceSummary` shows aggregate + `StudentAttendanceTab` shows detailed calendar heatmap and record list.

---

### 2. Weekly/Monthly Needs

| Need | Frequency | Schema Basis |
|---|---|---|
| View full week timetable | Weekly (Sunday night) | `timetable` for their grade+stream |
| Check exam results when released | Per exam | `grades` filtered by student |
| Review mastery scores per topic | After assessments | `mastery` WHERE `student = adm` |
| Read school announcements | As posted | `announcements` WHERE audience includes students (bit 0) |
| View fee balance (if paying own fees) | Monthly | `invoices` + `payments` |
| Check upcoming exam schedule | Before exams | `exams` + `papers` for their grade |
| View term report card | End of term | Aggregated `grades` + `mastery` |
| Check AI study token usage | When studying | `aiusage` WHERE `student = adm` |

---

### 3. Nice-to-Have / Delight Features

- **AI study assistant**: Given the `aiusage` table that tracks allocated vs. used tokens per student per term, there's a built-in AI study feature concept. Students could ask the AI to explain topics they scored poorly on, generate practice questions, or summarize notes.
- **Grade calculator**: "If I score 80% on the final exam, my term average will be 65%." Simple weighted calculation from existing grades.
- **Study planner** (future): Based on timetable + exam schedule + mastery data, suggest a study plan. "Focus on Trigonometry — your mastery is only 35%."
- **Peer comparison** (anonymized): "You're in the top 25% of your stream in Mathematics." No names, just position.
- **Achievement tracker**: "You've been present for 20 consecutive school days! 🎯" Gamification of good behavior.
- **Assignment/homework tracker** (future): Not in current schema. Would need a dedicated table linking teachers, subjects, due dates, and completion status.
- **Digital library** (future): Access to past exam papers, study notes, textbook chapters.
- **Motivational content**: After a low score: "Don't give up! Students who improved most in your school went from 45% to 68% in one term." Based on anonymized historical data.

---

### 4. Pain Points in Traditional School Management

| Pain Point | Impact | How EduXal Solves It |
|---|---|---|
| **Public grade announcement in class** — humiliating for low performers | Shame discourages struggling students; some avoid school | Private digital access to own grades only |
| **Lost timetable copies** — student loses the paper and misses classes | Missed classes, detention for "absenteeism" | Permanent digital timetable on phone |
| **Can't track own progress** — no view of historical grades | Students don't know if they're improving or declining | Trajectory indicators + historical grade view |
| **Exam schedule confusion** — word of mouth, sometimes wrong | Students show up unprepared or to the wrong exam | Digital exam schedule linked to `exams` + `papers` |
| **No way to check own attendance** — accused of absence wrongly | Unfair punishment | Digital attendance record with dates and status |
| **Can't prepare for exams strategically** — don't know weak areas | Studying everything equally instead of focusing on weak spots | Mastery data highlights weak topics; AI can generate targeted practice |
| **No connection to school from home** — boarding school students during holidays | Feel disconnected; don't know exam dates, school events | App provides all school information offline |
| **Fee payment stress** — called out in assembly for unpaid fees | Shame; students avoid school | Private fee balance view; no public shaming |

---

### 5. Optimistic UI Patterns

Students are primarily consumers, so optimistic UI is less about writes and more about **perceived speed**:

- **Timetable**: Always instant — local data. Should feel like opening a physical timetable pinned to the wall.
- **Grades**: When the teacher finishes marking and syncs, the student's device receives the delta and the grades appear. No manual refresh. "Your Mid-Term results are in!" toast notification when new grades arrive.
- **Attendance**: Today's attendance appears the moment the teacher marks it. If the student checks at 8:30 AM and attendance was marked at 8:15, it's already there.
- **Announcements**: Appear in real-time via the watch stream. A badge count indicates new unread announcements.

**Special consideration**: Students may access the app on low-end devices. The UI must be lightweight — no heavy animations, minimal images, fast list rendering. The data-table style (thin dividers, no cards per row) is actually perfect for this: it renders faster and uses less memory than card-based layouts.

---

### 6. Key Metrics/Dashboards

**Student Dashboard — Dream Layout:**

```
┌──────────────────────────────────────────────┐
│  Hi, Grace 👋              Grade 9 East       │
│  ADM: 2345 · Mwangaza Academy                │
├──────────────────────────────────────────────┤
│  TODAY'S CLASSES (Tuesday)                    │
│  ✅ 08:00  Mathematics — Mr. Odhiambo (done) │
│  ✅ 09:00  English — Mrs. Kamau (done)        │
│  ➡️ 10:30  Physics — Mr. Wekesa (in 15 min)  │
│     14:00  Kiswahili — Mrs. Atieno            │
├──────────────────────────────────────────────┤
│  MY PERFORMANCE                               │
│  Last Exam: Mid-Term 2                        │
│  Total: 324/500 (64.8%)  📈 Improving         │
│  Strongest: English (72%)                     │
│  Needs work: Mathematics (52%)                │
├──────────────────────────────────────────────┤
│  ATTENDANCE THIS TERM                         │
│  ██████████████████░░  91% (62/68 days)       │
├──────────────────────────────────────────────┤
│  ANNOUNCEMENTS                                │
│  📢 Sports Day Friday at 8 AM                 │
│  📢 Science fair submissions due March 20     │
├──────────────────────────────────────────────┤
│  AI STUDY TOKENS                              │
│  ████████░░░  Used: 45/100 this term          │
│          [Study with AI →]                    │
└──────────────────────────────────────────────┘
```

---

### 7. Notification Needs

| Event | Priority | Mechanism |
|---|---|---|
| New exam results available | High | Delta sync on `grades` WHERE `student = adm` |
| Marked absent (possibly wrongly) | High | Delta sync on `attendance` WHERE `status = Absent` for today |
| Upcoming exam tomorrow | High | Client-side: `exams.start = tomorrow` for their grade |
| New announcement for students | Medium | Delta sync on `announcements` WHERE audience bit 0 |
| AI token allocation changed | Low | Delta sync on `aiusage` |
| Timetable changed | High | Delta sync on `timetable` for their grade+stream |
| Attendance streak milestone (10, 20, 50 days) | Low | Client-side gamification |
| Grade improvement notification | Medium | Client-side: compare latest exam average to previous |
| New fee invoice generated | Low | Delta sync on `invoices` WHERE `student = adm` |

---

### 8. Offline Requirements

| Operation | Offline? | Notes |
|---|---|---|
| View timetable | ✅ Yes | Local query |
| View my grades | ✅ Yes | Local query |
| View my attendance | ✅ Yes | Local query |
| Read announcements | ✅ Yes | Local query |
| View fee balance | ✅ Yes | Local computation |
| View mastery scores | ✅ Yes | Local query |
| Use AI study assistant | ❌ No | Requires server-side AI |
| Receive grade notifications | ❌ No | Requires sync connection |
| View timetable for next term | ✅ Yes | Local query (if term data synced) |
| View exam schedule | ✅ Yes | Local `exams` + `papers` query |

---

## Cross-Cutting Concerns

### A. Multi-Role Users

A single user can hold **multiple roles** at the same school:

- A teacher who is also a parent (guardian) of a student at the same school
- A school owner who is also a teacher (very common in small private schools)
- A staff member who is also a parent
- A teacher who is the school owner AND a parent of a student there

EduXal handles this via the `SchoolMembership` model: one card on the home screen per school, with role badges showing all roles. The `SchoolContext` allows role switching within a session. Permissions are **unioned** across all roles — so a teacher who is also an owner gets both sets of permissions.

**UX implication**: The role switcher in the dashboard AppBar is critical. A teacher-parent needs to quickly flip between "My teaching view" and "My child's grades." This must be one tap, not a full navigation change.

### B. Multi-School Users

A user can be a member of multiple schools:

- Parent with children in different schools
- Teacher employed at two schools (part-time)
- System admin overseeing multiple schools

The home screen shows one card per school. Each school session is independent (`SchoolContext` is created per school entry).

### C. Data Freshness and Sync Timing

Different roles have different expectations for data freshness:

| Role | Expectation | Technical Reality |
|---|---|---|
| Owner | "I want to see today's fee collections in real-time" | Near real-time if online; based on sync stream interval |
| Teacher | "I want the student list to be current when I mark attendance" | Enrollment changes via delta sync; very fresh if connected |
| Staff | "I need payment data to be accurate RIGHT NOW" | Local writes are instant; M-Pesa depends on server callback |
| Guardian | "I want to see today's attendance as soon as it's marked" | Depends on teacher's device syncing → server → parent's device |
| Student | "I want exam results immediately when they're released" | Depends on grade entry sync propagation |

**End-to-end latency for a grade entry** (teacher marks → student sees):
1. Teacher enters grade → instant local write
2. Teacher's device syncs → `markGrades` action sent via `pushActions` stream (0-30 seconds if online)
3. Server processes and broadcasts → `watchChanges` delta to student's device (sub-second server-side)
4. Student's device receives delta → `DeltaWriter` applies to local DB → Drift stream emits → UI updates (sub-second)

**Best case**: ~1-2 seconds. **Typical case**: ~5-30 seconds. **Worst case** (one side offline): until both come online.

### D. CBC vs. 8-4-4 Curriculum Differences

The app must support both curriculum systems as Kenya transitions from 8-4-4 to CBC:

| Aspect | 8-4-4 | CBC |
|---|---|---|
| Grade structure | Std 1-8, Form 1-4 | PP1-PP2, Grade 1-6 (Primary), Grade 7-9 (Junior Secondary), Grade 10-12 (Senior Secondary) |
| Assessment style | Heavy on final exams | Continuous assessment + competency evaluation |
| Subject names | Traditional (e.g., "Mathematics") | May include new names (e.g., "Creative Arts and Sports") |
| Reporting | Score-based (marks out of total) | Competency levels + mastery tracking |
| Grade labels | `kEightFourFourGradeLabels` | `kCbcGradeLabels` |

**Schema impact**: The `curriculum_subjects` table has a `curriculum` column (0=CBC, 1=EightFourFour). The `subjects` global catalog links subjects to curricula. The `topics` table provides CBC-style sub-divisions per grade for mastery tracking.

**UI impact**: The app resolves grade labels and subject names via `gradeLabelsFor(curriculumType)` and `subjectLabel(curriculumType, subjectId)` from `curriculum_levels.dart`. The same screens serve both curricula — the labels change, the data model doesn't.

### E. Term-Based Academic Calendar

Kenya operates on a **3-term year**:
- **Term 1**: January – April
- **Term 2**: May – August  
- **Term 3**: September – December

Some schools also define a "Term 0" for holiday programs. Each term has:
- A start and end date (`terms` table with overlap triggers)
- Associated fee structures (`fees` per term per grade)
- Enrollment snapshots (`enrollments` per term)
- Exam periods within the term
- Subject-teacher assignments per term (`subject_teachers`)

**Everything in EduXal is term-scoped.** The `ActiveTermContext` (selected via the term selector chip in the dashboard) filters all data: attendance, grades, lessons, fees, invoices, payments, timetable — all keyed by `(school, year, term)`.

### F. Financial Reality — M-Pesa

M-Pesa is not an optional add-on — it's the primary payment method for most Kenyan parents. ~95% of Kenyan adults have M-Pesa. The school's Paybill number and till number are as important as the school name.

**M-Pesa integration flow (via Daraja API):**
1. School configures M-Pesa credentials in `mpesa` table (consumer key, consumer secret, passkey, shortcode, environment)
2. Parent sends money to the school's Paybill number with the student's admission number as reference
3. Safaricom hits the school's Daraja callback URL (server-side)
4. Server creates a `payments` row with `method = Mpesa`, `reference = M-Pesa transaction code`
5. Server pushes delta to all connected clients
6. Staff sees the payment appear; parent sees their balance decrease

**Alternative**: Staff initiates an STK Push — sends a payment request to the parent's phone. Parent enters M-Pesa PIN to confirm. Same callback flow.

This is a **server-side** operation. The client's role is:
- Displaying M-Pesa payment history
- Showing the paybill/till number for manual payment
- Triggering STK Push requests (future feature)
- Reconciling unmatched M-Pesa payments

---

## Kenyan/East African Context Notes

### Infrastructure Realities

| Factor | Implication for EduXal |
|---|---|
| **Intermittent internet** — especially rural schools | Offline-first architecture is not a luxury, it's a requirement. All CRUD must work offline. |
| **Power outages** — scheduled and unscheduled | App must save state frequently (Drift auto-commits help). No "submit" buttons where losing connection = losing work. |
| **Low-end smartphones** — Samsung A-series, Tecno, Infinix | Lightweight UI, minimal animations on low-end devices, efficient SQLite queries. |
| **Expensive data** — parents won't waste MB on a bloated app | Efficient sync (delta-based, not full-table), minimal image downloads, text-first UI. |
| **Shared devices** — multiple family members share one phone | Account switching feature is essential. Data isolation between accounts. |

### Cultural Context

| Factor | Design Implication |
|---|---|
| **Exam ranking is everything** — schools compete publicly on KCSE results | Ranking features (class rank, stream comparison, subject comparison) are core, not nice-to-have |
| **Fee collection is adversarial** — parents delay, schools chase | Fee balance must be crystal clear and undisputable. M-Pesa auto-matching eliminates "I paid!" disputes. |
| **Teacher respect is high** — but so is accountability pressure | The app should empower teachers (faster grading, less paperwork) not surveil them (no "who's late" dashboards visible to parents) |
| **Ministry of Education reporting** — schools must submit data to government systems (NEMIS, KNEC) | Data export capabilities are important. The schema captures all data MoE needs. |
| **Boarding vs. day schools** — very different attendance patterns | Attendance features should be configurable. Boarding schools don't need daily attendance alerts. |
| **Gender sensitivity** — some schools are single-gender, some mixed | `students.gender` (Male/Female) exists. Reports should support gender-disaggregated data for government reporting. |
| **Disability/special needs** — legally mandated inclusion | Not yet in schema. Future: `students` may need a special needs/disability field for government reporting. |
| **Multi-language** (future) — English is official, Kiswahili is widely spoken | App currently in English. Future localization to Kiswahili would significantly increase adoption. |

### Regulatory Requirements

- **NEMIS** (National Education Management Information System): Schools must register students in the government database. EduXal should be able to export data in NEMIS-compatible format.
- **KNEC** (Kenya National Examinations Council): National exam registration data must match school records. Student names, admission numbers, and grades must be accurate and exportable.
- **TSC** (Teachers Service Commission): For public schools, teacher data (employment status, qualifications, teaching load) must be reportable.
- **Data protection**: Kenya's Data Protection Act (2019) requires consent for personal data processing. Student data (especially minors) has additional protections.

### Competitive Landscape Context

EduXal competes in a market where:
- **Zeraki** — established school management platform in Kenya, web-first
- **Classlist** — newer entrant, mobile-focused
- **Paper + WhatsApp** — the actual competitor for most schools (free, familiar)

EduXal's differentiators:
1. **Offline-first** — most competitors require constant internet
2. **Local-first** — data lives on the device, not just in the cloud
3. **Mobile + Desktop** — Flutter enables both, unlike web-only competitors
4. **M-Pesa native** — not an afterthought but a core payment channel
5. **AI features** — paper generation, AI grading assistance, study assistant

---

## Summary: Feature Priority Matrix

### P0 — Must Work Perfectly (Core Loop)

These features must be rock-solid because they're used daily by the majority of users:

| Feature | Primary Users | Schema Tables |
|---|---|---|
| Attendance marking + viewing | Teachers (mark), Guardians (view), Students (view) | `attendance` |
| Grade entry + viewing | Teachers (entry), Guardians (view), Students (view), Owners (analytics) | `grades`, `mastery` |
| Timetable viewing | All 5 roles | `timetable` |
| Fee balance + payment recording | Staff (entry), Guardians (view), Owners (oversight) | `fees`, `invoices`, `payments` |
| Student enrollment | Staff (entry), Owners (count) | `students`, `enrollments` |
| Dashboard overview per role | All 5 roles | Multiple aggregations |
| Announcements | Owners (post), All others (read) | `announcements` |
| Offline operation | All roles | `logs` (sync queue) |

### P1 — Must Work Well (Weekly/Monthly)

| Feature | Primary Users | Schema Tables |
|---|---|---|
| Exam creation + management | Teachers, Owners | `exams`, `papers` |
| Term management | Owners | `terms` |
| Stream/grade configuration | Owners | `streams`, `enrollments` |
| Role and permission management | Owners | `roles`, `scopes` |
| Member management (invite/edit/remove) | Owners, Staff | `teachers`, `staff`, `owners`, `guardians` |
| Financial reporting | Owners, Staff | Aggregated from `invoices`, `payments` |
| Subject-teacher assignments | Owners, Teachers | `subject_teachers` |
| Department management | Owners | `departments`, `teachers`, `staff` |

### P2 — Important for Engagement (Delight)

| Feature | Primary Users | Schema Tables |
|---|---|---|
| AI paper generation | Teachers | `topics`, external AI service |
| AI grading assistance | Teachers | `grades`, external AI service |
| AI study assistant | Students | `aiusage`, external AI service |
| M-Pesa STK Push | Staff, Guardians | `mpesa`, `payments` |
| Performance analytics + trends | Owners, Teachers | `grades`, `mastery` aggregated |
| Mastery tracking per topic | Teachers, Students | `mastery`, `topics` |
| Notification alerts (real-time) | Guardians, Students | Delta sync events |
| Timetable generation wizard | Owners | `timetable`, local algorithm |

### P3 — Future / Nice-to-Have

| Feature | Notes |
|---|---|
| Parent-teacher messaging | Needs new schema table |
| Homework/assignment tracking | Needs new schema table |
| Visitor management | Needs new schema table |
| Inventory/supplies tracking | Needs new schema table |
| SMS integration for non-smartphone parents | External SMS gateway |
| NEMIS data export | Data transformation layer |
| Multi-language (Kiswahili) | Localization framework |
| Receipt generation + WhatsApp sharing | PDF generation + share API |
| Board meeting report generation | PDF/Excel export |
| Student grade calculator | Client-side computation |

---

*This document should be updated as new domain insights emerge from user testing, school visits, or feedback from the Kenyan education community. Each insight should be traced back to a specific role and a specific schema entity.*