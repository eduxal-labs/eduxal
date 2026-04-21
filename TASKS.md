# TASKS.md

## Bug Fixes — Marking Status Indicator + Notification Error

---

### [x] Task C01: Fix MarkingStatusIndicator shown for wrong paper status

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None — full spec below
**Depends on:** None
**Parallel group:** P1 (client)

**Root cause:** In `_PaperDetailPageState.build`, the `MarkingStatusIndicator` is rendered
when:
```dart
if (_aiPhase != _AiPhase.idle ||
    currentPaper.status == PaperStatus.progress)
```
`PaperStatus.progress` (index 1) means the exam is currently being written by students.
This is wrong — the indicator should only appear after the exam is finished and marking
has been triggered. Showing it during `progress` causes the indicator to poll the server
immediately, which returns `QUEUED` (server default when no job exists), then eventually
a 502 error as the poll stream runs indefinitely.

**Fix:** Change `PaperStatus.progress` → `PaperStatus.done` in the condition:

```dart
if (_aiPhase != _AiPhase.idle ||
    currentPaper.status == PaperStatus.done)
```

`PaperStatus.done` (index 2) means the exam is finished and AI marking may be active.
This is the correct trigger point — the indicator should show when the paper has been
marked as done and the AI marking job may be running or queued on the server.

The change is a single token replacement on the condition line. No other logic changes
are needed.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: show MarkingStatusIndicator only when paper status is done, not progress"`
