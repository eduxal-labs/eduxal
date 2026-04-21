# TASKS.md

### Task 01: Wire the "Generate Paper" button to PaperGenerationPage ✅ DONE
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** N/A — all context is inlined below
**Depends on:** none
**Parallel group:** P1

**Specification:**

In `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`:

1. Add this import near the other local screen imports (around line 34, after `paper_pdf_viewer.dart`):
   ```
   import 'paper_generation_page.dart';
   ```

2. Find the "Generate Paper" `InkWell.onTap` callback inside `_PaperHeaderState.build()` (around line 1200). It currently shows a "Paper generation coming soon" SnackBar:
   ```dart
   onTap: () {
     // TODO: Task 12 — navigate to PaperGenerationPage
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Paper generation coming soon'),
       ),
     );
   },
   ```

   Replace it with a `Navigator.push` to `PaperGenerationPage`:
   ```dart
   onTap: () {
     Navigator.of(context).push(
       MaterialPageRoute(
         builder: (context) => PaperGenerationPage(
           schoolId: widget.schoolId,
           examId: widget.exam.exam.id,
           subjectId: widget.paper.subject,
           paperId: widget.paper.paper,
           grade: widget.paper.grade,
           stream: widget.paper.stream,
           subjectName: widget.subjectNames[widget.paper.subject] ??
               'Subject ${widget.paper.subject}',
           examName: widget.exam.exam.name,
         ),
       ),
     );
   },
   ```

**Parameter mapping (all from `_PaperHeader` widget fields):**
- `schoolId` ← `widget.schoolId` (`String`)
- `examId` ← `widget.exam.exam.id` (`String`)
- `subjectId` ← `widget.paper.subject` (`int`)
- `paperId` ← `widget.paper.paper` (`int?` — nullable, matches constructor)
- `grade` ← `widget.paper.grade` (`int`)
- `stream` ← `widget.paper.stream` (`int?` — nullable, matches constructor)
- `subjectName` ← `widget.subjectNames[widget.paper.subject] ?? 'Subject ${widget.paper.subject}'`
- `examName` ← `widget.exam.exam.name` (`String`)

**`PaperGenerationPage` constructor signature (for reference):**
```dart
const PaperGenerationPage({
  super.key,
  required this.schoolId,       // String
  required this.examId,         // String
  required this.subjectId,      // int
  this.paperId,                 // int?
  required this.grade,          // int
  this.stream,                  // int?
  required this.subjectName,    // String
  required this.examName,       // String
});
```

**`ExamWithPapers` typedef (for reference):**
```dart
typedef ExamWithPapers = ({Exam exam, List<Paper> papers, UsersData teacher});
```
Access the exam id and name via `widget.exam.exam.id` and `widget.exam.exam.name`.

**No other files need to change.** The `PaperGenerationPage` itself, all 3 wizard steps, the `QuestionBankService`, all models (`PaperQuestion`, `TopicAllocation`, `PaperPdf`), and the `paper_pdf_viewer.dart` download helper are all fully implemented.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note that the Generate Paper button is now wired up; paper generation feature is complete
- [x] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — same note
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task — `feat: wire Generate Paper button to PaperGenerationPage`
