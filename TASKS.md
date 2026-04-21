# TASKS.md

## Exam Paper PDF — Kenyan Format Improvements

---

### Task 01: PDF renderer — spacing, font sizes, right-aligned marks, answer lines, footer

**Files to create/modify:** `src/pdf.rs`
**Context files to read (if needed):** None — full spec below
**Depends on:** None
**Parallel group:** P1 (server)

**Specification:**

This task addresses the five highest-impact visual deficiencies in the generated exam PDF,
all of which are pure renderer changes — zero schema or proto changes required.

The server PDF renderer is at `src/pdf.rs` and uses the `printpdf` crate.
Read the file in full before editing. All changes are within `generate_paper_pdf`.

---

**Fix 1 — Increase font sizes**

Current values that are too small for a printed exam paper:
- Question text body: currently `Pt(10.0)` → change to `Pt(11.0)`
- Sub-header line (exam | subject | paper | grade): currently `Pt(11.0)` or `Pt(10.0)` → change to `Pt(12.0)`
- Inline marks annotation: currently same as body → keep at `Pt(11.0)`

Do NOT change the school name (16pt) or section headers — those are already correct.

---

**Fix 2 — Question spacing**

Current `paragraph_spacing_mm` (or equivalent gap between questions) is ~3.0mm — far too tight.
Change the vertical gap inserted **between** questions (after all answer lines for one question
and before the bold number of the next) to `12.0` mm.

The gap between the question text and its answer lines (Fix 3) is separate — use `4.0` mm there.

---

**Fix 3 — Answer lines below every question**

After rendering each question's text, draw ruled horizontal lines for the student to write on.
The number of lines is calculated as: `max(3, question_marks * 2)` (minimum 3 lines, 2 per mark).
Each line is:
- A full-width horizontal rule from left margin to right margin
- `0.3` pt stroke width, color `(0.7, 0.7, 0.7)` (light gray)
- Vertical spacing between lines: `7.0` mm

Before drawing each line, check if the remaining vertical space on the page is less than
`7.0` mm — if so, call `flush_page()` to start a new page first.

---

**Fix 4 — Right-aligned marks column**

Currently `"(3 marks)"` is appended inline at the end of the question text.
Change this so the marks string is placed at the **right margin** on the same
baseline as the first line of the question text:
- Calculate `marks_text = format!("({} {})", marks, if marks == 1 { "mark" } else { "marks" })`
- Measure the text width using the same `avg_char_width` heuristic currently used for centering:
  `text_width = marks_text.len() as f64 * font_size_pt * 0.5 * 0.3528`
- Place it at `x = page_width_mm - right_margin_mm - text_width`, same `y` as the question number
- Remove `"(X marks)"` from the inline question text body

---

**Fix 5 — Page footer: page number + "Turn over"**

After every page is finalized (in `flush_page()` or equivalent), render a footer:
- **Page number**: centered at the bottom margin, format `"- {n} -"`, `Pt(9.0)`, regular font
- **"Turn over"**: right-aligned at the bottom margin, `Pt(9.0)`, regular font — render on
  ALL pages **except the last**. Since the last page is not known until all questions are
  processed, track a `Vec` of page layer references. After all questions are done, iterate
  pages and add "Turn over" to all except the final one.

Also add **"— END OF PAPER —"** centered, `Pt(11.0)`, bold, after the last question's
answer lines (and the total marks line), before closing the final page.

---

**Update after completion:**
- [ ] Update any relevant CONTEXT.md in the ledger project
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: answer lines, spacing, font sizes, marks column, page footer in PDF renderer"`

---

### Task 02: PDF renderer — candidate info box + expanded instructions block

**Files to create/modify:** `src/pdf.rs`
**Context files to read (if needed):** None
**Depends on:** Task 01 (read after T01 is merged so y-positions don't conflict)
**Parallel group:** P2 (server)

**Specification:**

Both additions go between the existing horizontal rule (after school name/motto)
and the first question. They require no schema changes — the content is templated.

---

**Addition 1 — Candidate information box**

Immediately after the second horizontal rule, render a bordered rectangle containing
five labeled fill-in lines. The box should:
- Have a `0.5` pt border, color `(0.3, 0.3, 0.3)`
- Internal padding: `4.0` mm on all sides
- Each row: label text at left (`Pt(10.0)`, regular), then a dotted/underscored fill
  line stretching to the right edge of the box interior
- Rows (in order):
  1. `Name:` — line width: full remaining width
  2. `Adm. No.:` — line width: 60mm
  3. `Class / Stream:` — line width: 60mm
  4. `Signature:` — line width: 60mm
  5. `Date:` — line width: 40mm
- Row height: `9.0` mm
- After the box, add `6.0` mm vertical gap before instructions

The fill lines are plain horizontal rules at `y = row_baseline - 1.0 mm`,
`0.4` pt, color `(0.5, 0.5, 0.5)`.

---

**Addition 2 — Expanded instructions block**

Replace the single hardcoded `"Answer ALL questions."` line with a multi-line
italic instructions block. Render each line at `Pt(10.0)`, italic font, left-aligned,
with `4.0` mm between lines.

Default instruction lines (use these verbatim unless an `instructions` parameter is
added in a later task):
1. `"Answer ALL questions in this paper."`
2. `"Show all your working clearly in the spaces provided."`
3. `"All answers must be written in the spaces provided."`
4. `"This paper consists of {N} printed pages."` — where N is the final page count.
   Since page count is not known upfront, render this line as
   `"This paper consists of [N] printed pages."` and do a post-processing string
   replacement after all pages are built, OR simply omit the page count for now and
   render `"Check that all pages are present before starting."`
5. `"Candidates should check the paper for any missing pages."`

After the instructions, add the same second horizontal rule that currently exists
(or keep it in its current position — just ensure it comes after the instructions).

---

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: candidate info box and expanded instructions in PDF header"`

---

### Task 03: Schema + proto — add time_allowed_minutes and instructions to papers table

**Files to create/modify:**
- Migration file (new migration in your migrations directory)
- `src/models/paper.rs` (or equivalent model file)
- `proto/question_bank.proto`
- Regenerate Dart proto files and deliver updated `question_bank.pb.dart` + `question_bank.pbgrpc.dart`

**Context files to read (if needed):** Existing papers table schema, existing proto definitions
**Depends on:** None (can run in parallel with Tasks 01–02)
**Parallel group:** P1 (server)

**Specification:**

Add two optional columns to the `papers` table:

```sql
ALTER TABLE papers ADD COLUMN time_allowed_minutes SMALLINT;
ALTER TABLE papers ADD COLUMN instructions TEXT;
```

`time_allowed_minutes` — e.g. `90` for 1h30m, `150` for 2h30m. NULL means not set.
`instructions` — free-text override for the instructions block. NULL means use defaults.

Update the server paper model to include these two fields (nullable).

Update the proto `CreatePaperPayload`, `UpdatePaperPayload`, and `PaperInsert` messages
to include:
```proto
optional int32 time_allowed_minutes = <next_field_number>;
optional string instructions        = <next_field_number>;
```

Also update `FinalizePaperResponse` (or add a new helper message) so that
`generate_paper_pdf` receives `time_allowed_minutes: Option<i16>` and
`instructions: Option<&str>`. The PDF function should:
- Render `"Time: X hours Y minutes"` in the header sub-block when set
- Use the custom `instructions` string (split on `\n`) instead of the default lines when set

Regenerate Dart proto stubs and deliver updated files to the client team.

---

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add time_allowed_minutes and instructions to papers schema and proto"`

---

### Task 04: PDF renderer — use time_allowed_minutes + instructions in header

**Files to create/modify:** `src/pdf.rs`, `src/services/question_bank.rs` (finalize_paper handler)
**Context files to read (if needed):** Task 03 changes
**Depends on:** Task 03
**Parallel group:** P3 (server)

**Specification:**

Wire the new schema fields into the PDF renderer.

**In `finalize_paper` handler (`src/services/question_bank.rs`):**
- Query the `papers` table to fetch `time_allowed_minutes` and `instructions` for the paper
- Pass them as `Option<i16>` and `Option<String>` to `generate_paper_pdf`

**In `generate_paper_pdf` (`src/pdf.rs`):**

Update the function signature:
```rust
pub fn generate_paper_pdf(
    school_name: &str,
    school_motto: Option<&str>,
    exam_name: &str,
    subject_name: &str,
    paper_num: i32,
    grade: i16,
    time_allowed_minutes: Option<i16>,   // ← new
    instructions: Option<&str>,          // ← new
    questions: &[(String, i16, Vec<(String, i16)>)],
) -> Vec<u8>
```

**Time allowed rendering** — add after the exam/subject/grade sub-header line:
```
"Time: X hours Y minutes"     (if time_allowed_minutes is Some and >= 60)
"Time: X minutes"             (if < 60)
```
Format: `Pt(11.0)`, regular, centered.

Also render total marks in the header:
```
"Total Marks: {sum}"
```
Where `sum = questions.iter().map(|(_, m, _)| *m as i32).sum::<i32>()`.
Render at `Pt(11.0)`, regular, centered, on the same line or the line below time allowed.

**Instructions rendering** — in the instructions block (Task 02):
- If `instructions` is `Some(text)`, split on `"\n"` and render each line instead of defaults
- If `None`, use the default 5-line block from Task 02

---

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: render time allowed, total marks, and custom instructions in PDF header"`

---

### Task 05: Marking scheme PDF — generate separate PDF using existing rubric data

**Files to create/modify:**
- `src/pdf.rs` — add `generate_marking_scheme_pdf` function
- `src/services/question_bank.rs` — call it in `finalize_paper`
- Proto: add `marking_scheme_url` + `marking_scheme_expiry` to `FinalizePaperResponse`

**Context files to read (if needed):** Task 01 changes (for shared helper functions)
**Depends on:** Task 01
**Parallel group:** P2 (server, disjoint files from Task 02)

**Specification:**

The rubric data is already passed into `generate_paper_pdf` as the third tuple element
`Vec<(String, i16)>` (criterion text + marks) but is currently ignored (`_rubric`).
This task generates a separate marking scheme PDF from that data.

**New function `generate_marking_scheme_pdf`:**

Same header as the question paper (school name, exam, subject, grade) but with
`"MARKING SCHEME"` appended to the exam title line, e.g.:
`"END OF TERM 1 EXAMINATIONS — MARKING SCHEME"`

For each question:
- Render the question number bold (`Pt(11.0)`): `"1."`
- Render the question text at `Pt(10.0)` italic (abbreviated if long — first 80 chars + "…")
- For each rubric criterion in `Vec<(String, i16)>`:
  - Render as a bullet: `"  • {criterion_text} .......................... {marks} mark(s)"`
  - `Pt(10.0)`, regular
  - Vertical gap between criteria: `3.0` mm
- After all criteria, render a thin divider line
- Total for question right-aligned: `"[{sum} marks]"`
- Vertical gap between questions: `8.0` mm

Footer on each page: page number centered (same as question paper).
Final line: `"— END OF MARKING SCHEME —"` centered, bold.

**In `finalize_paper` handler:**
- Call `generate_marking_scheme_pdf(...)` after `generate_paper_pdf(...)`
- Upload the marking scheme PDF to S3 (same bucket, key pattern:
  `marking_schemes/{school}/{exam}/{subject}/{paper}/{grade}/{stream}.pdf`)
- Return the S3 presigned GET URL + expiry in `FinalizePaperResponse`:
  ```proto
  string marking_scheme_url    = <next>;
  int64  marking_scheme_expiry = <next>;
  ```

**Update the client-side `PaperPdf` model** (client team task — see Client Task 02) to
store and display the marking scheme URL.

---

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: generate separate marking scheme PDF from rubric data"`

---

### Task 06: Schema + proto — section support on paper_questions

**Files to create/modify:**
- Migration file
- `src/models/paper_question.rs` (or equivalent)
- `proto/question_bank.proto` — update `GeneratePaperResponse`, `PaperQuestion`,
  `GetPaperQuestionsResponse`, `EditPaperQuestionRequest`
- Regenerate and deliver updated Dart proto stubs

**Context files to read (if needed):** None
**Depends on:** None (schema work, parallel with anything)
**Parallel group:** P1 (server, disjoint from Task 03)

**Specification:**

Add a nullable `section` column to `paper_questions`:

```sql
ALTER TABLE paper_questions ADD COLUMN section TEXT;
-- Valid values: 'A', 'B', 'C', 'D', or NULL (means unsectioned)
```

Update `PaperQuestion` proto message to include:
```proto
optional string section = <next_field_number>;
```

The server does NOT auto-assign sections during `generate_paper` — sections start as NULL.
A future client UI (Client Task 03) will let the teacher drag questions into sections.
The `edit_paper_question` (or a new `assign_paper_question_section`) endpoint will write
the section value.

Add a new RPC to assign/clear a section:
```proto
rpc SetPaperQuestionSection (SetPaperQuestionSectionRequest)
    returns (SetPaperQuestionSectionResponse);

message SetPaperQuestionSectionRequest {
  string school  = 1;
  string exam    = 2;
  int32  subject = 3;
  optional int32 paper   = 4;
  int32  grade   = 5;
  optional int32 stream  = 6;
  int32  position        = 7;   // 0-based position of the question
  optional string section = 8;  // NULL clears the section
}

message SetPaperQuestionSectionResponse {}
```

In `get_paper_questions` and `generate_paper` responses, populate `section` from the DB.

In `finalize_paper` + `generate_paper_pdf`: pass section data. The PDF renderer
(updated in Task 07) will use it to insert section headers.

---

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add section column to paper_questions, SetPaperQuestionSection RPC"`

---

### Task 07: PDF renderer — section headers

**Files to create/modify:** `src/pdf.rs`, `src/services/question_bank.rs`
**Context files to read (if needed):** Task 06 changes
**Depends on:** Task 06, Task 01
**Parallel group:** P4 (server)

**Specification:**

Update `generate_paper_pdf` to accept section data alongside each question.

Change the questions parameter from:
```rust
questions: &[(String, i16, Vec<(String, i16)>)]
```
To:
```rust
questions: &[(String, i16, Vec<(String, i16)>, Option<String>)]
//                                               ^^^ section: "A", "B", "C", or None
```

Before rendering each question, check if its section differs from the previous question's
section. If so, insert a section header block:

```
SECTION A (40 marks)
Answer ALL questions in this section.
```

Rendering:
- `"SECTION {letter}"` — `Pt(12.0)`, bold, centered
- Marks total in parentheses: sum the marks of all questions in that section
- Instruction line: `Pt(10.0)`, italic, centered
- A thin full-width horizontal rule below the instruction line
- Vertical gap before first question in section: `8.0` mm
- Vertical gap after section header rule and before question `1`: `6.0` mm

Questions with `section = None` are rendered without any section header (as today).

If ALL questions have `section = None`, behaviour is unchanged from Task 01.

---

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: section headers in PDF renderer"`

---

---
## Client Tasks
---

### Task C01: Fix question numbering display (Q0 → Q1) in paper generation wizard

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1 (client)

**STATUS: ✅ ALREADY DONE** — fixed in the previous session. The three render sites
(lines 912, 1061, 1621) now use `question.order + 1`. The `position: question.order`
passed to the server for `regenerateQuestion` is unchanged (correct 0-based value).

---

### Task C02: ✅ Store and display marking scheme URL after finalization

**Files to create/modify:**
- `lib/models/paper_generation.dart`
- `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
- `lib/ui/screens/school_dashboard/academics/paper_pdf_viewer.dart`
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** Server Task 05 must be complete (delivers `marking_scheme_url` +
`marking_scheme_expiry` in `FinalizePaperResponse` proto)
**Parallel group:** P2 (client, blocked on server T05)

**Specification:**

**Step 1 — Update `PaperPdf` model** in `lib/models/paper_generation.dart`:

```dart
class PaperPdf {
  final String pdfUrl;
  final DateTime pdfExpiry;
  final String? markingSchemeUrl;       // ← new
  final DateTime? markingSchemeExpiry;  // ← new

  const PaperPdf({
    required this.pdfUrl,
    required this.pdfExpiry,
    this.markingSchemeUrl,
    this.markingSchemeExpiry,
  });

  factory PaperPdf.fromProto(pb.FinalizePaperResponse proto) => PaperPdf(
    pdfUrl: proto.pdfUrl,
    pdfExpiry: DateTime.fromMillisecondsSinceEpoch(proto.pdfExpiry.toInt() * 1000),
    markingSchemeUrl: proto.hasMarkingSchemeUrl() ? proto.markingSchemeUrl : null,
    markingSchemeExpiry: proto.hasMarkingSchemeExpiry()
        ? DateTime.fromMillisecondsSinceEpoch(proto.markingSchemeExpiry.toInt() * 1000)
        : null,
  );

  factory PaperPdf.fromGetPdfProto(pb.GetPaperPdfResponse proto) => PaperPdf(
    pdfUrl: proto.pdfUrl,
    pdfExpiry: DateTime.fromMillisecondsSinceEpoch(proto.pdfExpiry.toInt() * 1000),
    // GetPaperPdfResponse does not carry marking scheme URL — stays null
  );
}
```

**Step 2 — Show "View Marking Scheme" button** alongside the existing "View / Print Paper"
button in `_PaperHeaderState` in `paper_detail_page.dart`:

```dart
// After the existing "View / Print Paper" IconButton:
if (paper.markingSchemeUrl != null) ...[
  const SizedBox(width: 4),
  Tooltip(
    message: 'View Marking Scheme',
    child: IconButton(
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
      icon: Icon(Icons.fact_check_outlined, size: 18, color: cs.secondary),
      onPressed: () => _openMarkingScheme(paper.markingSchemeUrl!),
    ),
  ),
],
```

`_openMarkingScheme` opens the `PaperPdfViewer` screen passing the marking scheme URL
instead of the question paper URL. Pass a `title: 'Marking Scheme'` parameter so the
viewer can label it correctly.

**Step 3 — Update `PaperPdfViewer`** to accept an optional `title` parameter:
```dart
final String title; // defaults to 'Exam Paper'
```
Display this in the AppBar title.

Note: the `paper` column in the local Drift `papers` table does NOT store the marking
scheme URL — it is fetched fresh each time from `FinalizePaperResponse` and held
in the `_PaperGenerationPageState._paperPdf` field. If the user navigates away and
comes back, they tap "View / Print Paper" which calls `getPaperPdf` — the marking
scheme URL is not in that response. For now this is acceptable; a future task can
add `marking_scheme_url` to the Drift table.

---

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "feat: display marking scheme PDF link after paper finalization"`

---

### Task C03: Add time_allowed and instructions fields to create/edit paper UI

**Files to create/modify:**
- `lib/ui/screens/school_dashboard/exams/create_paper_sheet.dart`
- `lib/database/tables/papers.dart` (add two nullable columns to `Papers` Drift table)
- `lib/database/daos/exams_grades_dao.dart` (update createPaper / updatePaper)
- `lib/sync/delta_writer.dart` (update `_applyPapers` to handle new columns)

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`,
`lib/database/CONTEXT.md`
**Depends on:** Server Task 03 must be complete (delivers updated proto with new fields)
**Parallel group:** P2 (client, blocked on server T03)

**Specification:**

**Step 1 — Add columns to Drift `Papers` table** in `lib/database/tables/papers.dart`:

```dart
IntColumn get timeAllowedMinutes => integer().nullable()();
TextColumn get customInstructions => text().nullable()();
```

Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate.

**Step 2 — Update `create_paper_sheet.dart`**

Add two optional fields to the create/edit paper form:

**Time Allowed** — a row with a numeric text field:
```
Time allowed (minutes): [____]   (optional — leave blank if not set)
```
Use an `int?` state variable `_timeAllowedMinutes`. Parse on submit.
Below the field, show a computed hint: e.g. `"= 1 hour 30 minutes"` when the value
is 90. Use:
```dart
String _formatMinutes(int m) {
  final h = m ~/ 60;
  final rem = m % 60;
  if (h == 0) return '$rem minutes';
  if (rem == 0) return '$h ${h == 1 ? 'hour' : 'hours'}';
  return '$h ${h == 1 ? 'hour' : 'hours'} $rem minutes';
}
```

**Custom Instructions** — a multiline text field, optional:
```
Instructions (optional):
[                                           ]
[  Leave blank to use default instructions  ]
```
`maxLines: 5`, `minLines: 2`.

Both fields appear after the existing fields (subject, grade, stream, total marks)
and before the save button.

**Step 3 — Pass fields through to DAO and log**

In `ExamsGradesDao.createPaper` and `ExamsGradesDao.updatePaper`, include
`timeAllowedMinutes` and `customInstructions` in the `PapersCompanion`.

In the `CreatePaperPayload` and `UpdatePaperPayload` proto constructors (inside the DAO),
set the new optional fields when present.

**Step 4 — Update `DeltaWriter._applyPapers`**

In the `_applyPapers` upsert SQL (in `lib/sync/delta_writer.dart`), add the two new
columns to the `INSERT` column list and the `ON CONFLICT DO UPDATE SET` clause.
Map from `PaperInsert.timeAllowedMinutes` and `PaperInsert.instructions`.

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md` — note new columns on `Papers` table
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add time_allowed and custom instructions to paper create/edit UI"`

---

### Task C04: ✅ Section assignment UI in paper generation wizard

**Files to create/modify:**
- `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
- `lib/services/question_bank.dart`
- `lib/models/paper_generation.dart`

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** Server Task 06 must be complete (delivers `section` field on `PaperQuestion`
proto and `SetPaperQuestionSection` RPC)
**Parallel group:** P3 (client, blocked on server T06)

**Specification:**

**Step 1 — Update `PaperQuestion` model** in `lib/models/paper_generation.dart`:

```dart
class PaperQuestion {
  // ... existing fields ...
  final String? section;   // ← new: 'A', 'B', 'C', or null

  const PaperQuestion({
    // ... existing ...
    this.section,
  });

  factory PaperQuestion.fromProto(pb.PaperQuestion proto) {
    final q = proto.question;
    return PaperQuestion(
      id: q.id.toString(),
      questionId: q.id,
      text: q.text,
      marks: q.marks,
      rubric: q.rubric.map(RubricCriterion.fromProto).toList(),
      images: q.images.map(QuestionImage.fromProto).toList(),
      order: proto.position,
      section: proto.hasSection() ? proto.section : null,
    );
  }
}
```

**Step 2 — Add `setPaperQuestionSection` to `QuestionBankService`**
in `lib/services/question_bank.dart`:

```dart
Future<Result<void, GrpcError>> setPaperQuestionSection({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? stream,
  required int position,
  String? section,  // null clears the section
  required String accessToken,
}) async {
  try {
    final req = pb.SetPaperQuestionSectionRequest()
      ..school = school
      ..exam = exam
      ..subject = subject
      ..grade = grade
      ..position = position;
    if (paper != null) req.paper = paper;
    if (stream != null) req.stream = stream;
    if (section != null) req.section = section;
    final options = CallOptions(
      metadata: {'authorization': 'Bearer $accessToken'},
      timeout: const Duration(seconds: 15),
    );
    final client = pbgrpc.QuestionBankClient(_mainChannel);
    await client.setPaperQuestionSection(req, options: options);
    return const Ok(null);
  } on GrpcError catch (e) {
    return Err(e);
  } catch (e, st) {
    print('[QB] setPaperQuestionSection ← UNEXPECTED ${e.runtimeType}: $e\n$st');
    return Err(GrpcError.internal('setPaperQuestionSection failed: $e'));
  }
}
```

**Step 3 — Section picker in the question review UI**

In `paper_generation_page.dart`, in the question card (the review step), add a section
badge/chip beside the question number. Tapping it opens a small bottom sheet with
choices: `None`, `Section A`, `Section B`, `Section C`.

The chip displays the current section (or `"No section"` in a muted style if null).
On selection, call `setPaperQuestionSection`, then update local state:
```dart
_generatedQuestions = _generatedQuestions.map((q) {
  if (q.order == question.order) {
    return PaperQuestion(
      id: q.id,
      questionId: q.questionId,
      text: q.text,
      marks: q.marks,
      rubric: q.rubric,
      images: q.images,
      order: q.order,
      section: selectedSection,  // updated
    );
  }
  return q;
}).toList();
setState(() {});
```

Show a brief loading indicator on the chip while the RPC is in flight.
On error, show a SnackBar and revert to the previous section value.

The section picker bottom sheet is a simple `Column` of `ListTile`s:
```
○ No section
● Section A
○ Section B
○ Section C
```
Current selection shown with a filled radio dot.

---

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "feat: section assignment UI in paper generation wizard"`
