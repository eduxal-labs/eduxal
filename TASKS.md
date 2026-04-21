# TASKS.md

## Fix: Paper Generation — No Topics Shown for 8-4-4 Subjects

### Background

When a user opens the paper generation page for any subject (e.g. Kiswahili, subject_id=2, grade=44 for Form 4), the topic list is empty and the page shows "No topics found". This is caused by **two server-side bugs** that have been diagnosed and addressed via server tasks in `../ledger/TASKS.md` (Tasks L1 and L2):

**Bug 1 — Grade mismatch:** Server topics were stored with grade `1–4` (relative year) while papers store grade `41–44` (absolute 8-4-4 Form codes). The client query `watchTopicsBySubjectAndGrade(subjectId, grade: 44)` found no rows.

**Bug 2 — Sync gap:** 500+ topics were bulk-inserted directly into the server SQLite DB without going through the gRPC action handler, so they had no changelog entries. The client's `topics` table only had 2 rows (IDs 1–2).

**Status:** The server fixes (grade migration + startup changelog resync) propagate automatically to the client through the existing sync stream. The `_applyTopic` delta writer already handles upserts correctly. **No client code changes are required to fix the core bug.**

The single client task below is a UX improvement: the "No topics found" empty state message currently says "Add topics for this subject and grade to generate a paper", which is misleading when the real cause is a sync delay. The improved message distinguishes between "no topics exist" and "topics may be syncing".

---

### Task C1: Improve empty-topics message in paper generation page

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** None — the method is fully described below
**Depends on:** None (pure UX, independent of server tasks)
**Parallel group:** P1

**Specification:**

In `_PaperGenerationPageState._buildEmptyTopics` (located at line ~654 in `paper_generation_page.dart`), update the descriptive subtitle text from:

```dart
'Add topics for this subject and grade to generate a paper',
```

to:

```dart
'Topics for this subject may still be syncing, or none have been added for this grade yet.',
```

Only change this one string. Do not change any other code, layout, or styling in this method.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/academics/CONTEXT.md` if it exists, otherwise skip
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task with message `ui: clarify empty-topics message in paper generation page`