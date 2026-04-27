# EduXal Flutter — Question Schema & Exam Redesign Tasks

## Track A — Foundation Widgets (sequential — all later tracks depend on A1)

---

### Task A1: TiptapRenderer widget + flutter_math_fork
**Files to create/modify:** `lib/ui/widgets/tiptap_renderer.dart`, `pubspec.yaml`
**Depends on:** nothing
**Parallel group:** A-sequential

**Specification:**

Add to `pubspec.yaml` under `dependencies`:
```
flutter_math_fork: ^0.7.4
flutter_svg: ^2.0.10+1
```

Create `lib/ui/widgets/tiptap_renderer.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Convenience helper. If bodyFormat == 'tiptap', parses JSON and returns
/// a TiptapRenderer. Otherwise returns a plain Text widget.
Widget renderBody(String body, String bodyFormat, {TextStyle? style}) {
  if (bodyFormat == 'tiptap') {
    final doc = jsonDecode(body) as Map<String, dynamic>;
    return TiptapRenderer(document: doc, baseStyle: style);
  }
  return Text(body, style: style);
}

/// Read-only renderer for TipTap/ProseMirror JSON documents.
class TiptapRenderer extends StatelessWidget {
  const TiptapRenderer({super.key, required this.document, this.baseStyle});

  final Map<String, dynamic> document;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) => _renderNode(context, document);

  Widget _renderNode(BuildContext context, Map<String, dynamic> node) {
    final type = node['type'] as String? ?? '';
    final content =
        (node['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    switch (type) {
      case 'doc':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.map((n) => _renderNode(context, n)).toList(),
        );

      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              style: baseStyle ?? DefaultTextStyle.of(context).style,
              children:
                  content.map((n) => _renderInline(context, n)).toList(),
            ),
          ),
        );

      case 'orderedList':
        int idx = 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.map((item) {
            idx++;
            return _renderListItem(context, item, prefix: '$idx. ');
          }).toList(),
        );

      case 'bulletList':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content
              .map((item) => _renderListItem(context, item, prefix: '• '))
              .toList(),
        );

      case 'mathBlock':
        final latex =
            ((node['attrs'] as Map?)?['latex'] as String?) ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Math.tex(
              latex,
              mathStyle: MathStyle.display,
              textStyle: baseStyle ?? const TextStyle(fontSize: 16),
            ),
          ),
        );

      case 'table':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _renderTable(context, content),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  InlineSpan _renderInline(
      BuildContext context, Map<String, dynamic> node) {
    final type = node['type'] as String? ?? '';

    if (type == 'hardBreak') return const TextSpan(text: '\n');

    if (type == 'mathInline') {
      final latex =
          ((node['attrs'] as Map?)?['latex'] as String?) ?? '';
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          latex,
          textStyle: baseStyle ?? const TextStyle(fontSize: 14),
        ),
      );
    }

    if (type == 'text') {
      final text = node['text'] as String? ?? '';
      final marks =
          (node['marks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      var style = baseStyle ?? const TextStyle();
      for (final mark in marks) {
        switch (mark['type'] as String? ?? '') {
          case 'bold':
            style = style.copyWith(fontWeight: FontWeight.bold);
          case 'italic':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'code':
            style = style.copyWith(fontFamily: 'monospace',
                backgroundColor: Colors.grey.shade100);
        }
      }
      return TextSpan(text: text, style: style);
    }

    // Container inline nodes — recurse into content
    final content =
        (node['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return TextSpan(
      children: content.map((n) => _renderInline(context, n)).toList(),
    );
  }

  Widget _renderListItem(BuildContext ctx, Map<String, dynamic> item,
      {required String prefix}) {
    final content =
        (item['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prefix, style: baseStyle),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  content.map((n) => _renderNode(ctx, n)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderTable(
      BuildContext ctx, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      defaultColumnWidth: const FlexColumnWidth(),
      children: rows.map((row) {
        final cells =
            (row['content'] as List?)?.cast<Map<String, dynamic>>() ??
                [];
        final isHeader = row['type'] == 'tableHeader';
        return TableRow(
          decoration: isHeader
              ? BoxDecoration(color: Colors.grey.shade100)
              : null,
          children: cells.map((cell) {
            final cellContent =
                (cell['content'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cellContent
                    .map((n) => _renderNode(ctx, n))
                    .toList(),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
```

**Update after completion:**
- [x] Update `lib/ui/CONTEXT.md` — add TiptapRenderer and renderBody entries
- [x] Mark this task `[x]`
- [x] git commit: `feat: add TiptapRenderer widget and flutter_math_fork`

---

### Task A2: StimulusBlock widget
**Files to create/modify:** `lib/ui/widgets/stimulus_block.dart`
**Depends on:** Task A1
**Parallel group:** A-sequential

**Specification:**

Create `lib/ui/widgets/stimulus_block.dart`:

```dart
import 'package:flutter/material.dart';
import 'tiptap_renderer.dart';

/// Renders a question stimulus (passage, table, graph, diagram) in a
/// visually distinct container that separates it from the question body.
///
/// Stimulus map shape:
///   { 'type': 'passage'|'table'|'graph'|'diagram',
///     'body': String, 'body_format': 'plain'|'tiptap',
///     'caption': String? }
class StimulusBlock extends StatelessWidget {
  const StimulusBlock({super.key, required this.stimulus});

  final Map<String, dynamic> stimulus;

  @override
  Widget build(BuildContext context) {
    final type = stimulus['type'] as String? ?? 'passage';
    final body = stimulus['body'] as String? ?? '';
    final bodyFormat = stimulus['body_format'] as String? ?? 'plain';
    final caption = stimulus['caption'] as String?;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (type) {
        'passage' => _PassageBlock(
            body: body,
            bodyFormat: bodyFormat,
            caption: caption,
            theme: theme,
          ),
        'table' => _TableBlock(
            body: body,
            bodyFormat: bodyFormat,
            caption: caption,
            theme: theme,
          ),
        _ => _ImageBlock(stimulus: stimulus, caption: caption, theme: theme),
      },
    );
  }
}

class _PassageBlock extends StatelessWidget {
  const _PassageBlock(
      {required this.body,
      required this.bodyFormat,
      required this.caption,
      required this.theme});
  final String body;
  final String bodyFormat;
  final String? caption;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        border: Border(
          left: BorderSide(
              color: theme.colorScheme.primary, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) ...[
            Text(
              caption!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
          renderBody(body, bodyFormat,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock(
      {required this.body,
      required this.bodyFormat,
      required this.caption,
      required this.theme});
  final String body;
  final String bodyFormat;
  final String? caption;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        renderBody(body, bodyFormat),
      ],
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock(
      {required this.stimulus,
      required this.caption,
      required this.theme});
  final Map<String, dynamic> stimulus;
  final String? caption;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Graph/diagram — body is descriptive text if no image is present.
    final body = stimulus['body'] as String? ?? '';
    final bodyFormat = stimulus['body_format'] as String? ?? 'plain';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        renderBody(body, bodyFormat),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
```

**Update after completion:**
- [x] Update `lib/ui/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] git commit: `feat: add StimulusBlock widget`

---

### Task A3: AnswerSpaceWidget
**Files to create/modify:** `lib/ui/widgets/answer_space.dart`
**Depends on:** Task A2
**Parallel group:** A-sequential

**Specification:**

Create `lib/ui/widgets/answer_space.dart`:

```dart
import 'package:flutter/material.dart';

/// Renders the blank answer space for one question or part on a paper preview.
/// Used ONLY in read-only paper previews — not in live exam taking.
class AnswerSpaceWidget extends StatelessWidget {
  const AnswerSpaceWidget({
    super.key,
    required this.answerSpaceType,
    this.answerLines = 4,
    this.answerBoxHeightMm = 80,
  });

  /// 'lines' | 'plain_box' | 'diagram_box' | 'construction_box' | 'grid_box'
  final String answerSpaceType;
  final int answerLines;

  /// Height in mm — converted to logical pixels at 3.78 px/mm.
  final int answerBoxHeightMm;

  static const double _mmToPx = 3.78;
  static const double _lineHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: switch (answerSpaceType) {
        'lines' => _buildLines(),
        'plain_box' => _buildBox(context, label: null),
        'diagram_box' => _buildBox(context, label: 'Diagram'),
        'construction_box' =>
          _buildBox(context, label: 'Use ruler and compasses'),
        'grid_box' => _buildGrid(context),
        _ => _buildLines(),
      },
    );
  }

  Widget _buildLines() {
    return Column(
      children: List.generate(
        answerLines,
        (_) => const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Divider(height: 1, thickness: 0.5, color: Color(0xFFBBBBBB)),
        ),
      ),
    );
  }

  Widget _buildBox(BuildContext context, {required String? label}) {
    final height = answerBoxHeightMm * _mmToPx;
    return Stack(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (label != null)
          Positioned(
            right: 6,
            bottom: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final height = answerBoxHeightMm * _mmToPx;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _GridPainter(),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cellSize = 28.0; // ~7mm at 96 dpi
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    for (double x = cellSize; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = cellSize; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
```

**Update after completion:**
- [x] Update `lib/ui/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] git commit: `feat: add AnswerSpaceWidget`

---

## Track B — Paper ID Refactor (no dependencies — start immediately)

---

### Task B1: Replace 6-field composite with paper_id
**Files to create/modify:** All screens in `lib/ui/screens/school_dashboard/academics/` and `lib/ui/screens/school_dashboard/exams/` that use (school + exam + subject + paper + grade + stream) as a composite paper identity. Also service files in `lib/services/`.
**Depends on:** nothing
**Parallel group:** B

**Specification:**

The backend replaces the 6-field composite paper key with a single `paper_id: String` across all RPCs.

Steps:
1. Search the codebase for parameters named `examId`, `subjectId`/`subject`, `paperId`/`paper` (as an int), `grade`, `stream` being passed together as a unit to identify a specific paper.
2. Replace each such grouping with a single `paperId: String` parameter.
3. Update all gRPC request messages to use the `paper_id` field:
   - `GetPaperQuestionsRequest` — replace 6 fields with `paper_id: String`
   - `FinalizePaperRequest` — replace with `paper_id`
   - `GetPaperPdfRequest` — replace with `paper_id`
   - `SetPaperQuestionSectionRequest` — replace with `paper_id`
   - `ClearPaperQuestionsRequest` — replace with `paper_id`
   - `CopyPaperToStreamsRequest` — replace with `paper_id`
   - `GetMarkingStatusRequest` — replace with `paper_id`
   - `GetQuestionGradesRequest` — replace with `paper_id`
   - `RegenerateQuestionRequest` — replace with `paper_id`
4. Update navigation routes and arguments throughout.
5. This is a pure refactor — no behavior or UI changes.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `refactor: replace 6-field paper composite with paper_id`

---

## Track C — Question Display Update (depends A1, A2)

---

### Task C1: Update all question rendering for new schema
**Files to create/modify:** Any widget/screen in `lib/ui/` that currently renders `question['text']` as a plain string. Key files: `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`, `lib/ui/screens/system/settings/questions_list_page.dart`, `lib/ui/screens/system/settings/create_question_sheet.dart`.
**Depends on:** Task A1, Task A2
**Parallel group:** C

**Specification:**

Questions now carry these additional fields (backward compat: `text` still works if `body` absent):
```
body: String            (replaces text — use body ?? text)
body_format: String     (default 'plain')
stimulus: Map?          { type, body, body_format, caption }
parts: List<Map>?       each: { label, body, body_format, marks, answer_space_type, answer_lines, answer_box_height_mm, rubric, example_answer }
type: String            definition | explanation | calculation | structured | experiment | data_response | diagram
difficulty: int         1–5
cognitive_level: String recall | comprehension | application | analysis
example_answer: dynamic String (old) or Map { format, content } (new)
```

Update all question rendering to:
1. Read body as `q['body'] ?? q['text'] ?? ''` and format as `q['body_format'] ?? 'plain'`.
2. Before rendering the question body, if `q['stimulus'] != null` render `StimulusBlock(stimulus: q['stimulus'])`.
3. After the question body, if `q['parts'] != null && (q['parts'] as List).isNotEmpty`, render parts:
   ```dart
   Column(children: parts.map((p) => Padding(
     padding: const EdgeInsets.only(left: 16, top: 6),
     child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('(${p['label']})  ', style: boldStyle),
       Expanded(child: renderBody(p['body'], p['body_format'] ?? 'plain')),
     ]),
   )).toList())
   ```
4. Remove any existing logic that splits `\n(a)` from question text strings.
5. Add a small type badge `Chip` next to the question number showing `q['type']` (e.g. "calculation", "definition"). Use distinct colors per type.
6. For `example_answer` display: check if it is a String (old) or a Map with `format` key. If Map, use `renderBody(ea['content'], ea['format'])`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: update question rendering for new schema`

---

## Track D — Exam Creation Wizard (no dependencies — start immediately)

---

### Task D1: Exam wizard Steps 1 & 2 — event details and paper scheduling
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exam_creation_page.dart`
**Depends on:** nothing
**Parallel group:** D-sequential

**Specification:**

Rewrite `ExamCreationPage` as a 5-step `PageView` wizard.

Scaffold structure:
```dart
Scaffold(
  appBar: AppBar(title: Text('Create Exam — Step $_step of 5')),
  body: Column(children: [
    LinearProgressIndicator(value: _step / 5),
    Expanded(child: PageView(controller: _pageCtrl, physics: NeverScrollableScrollPhysics(), children: [step1, step2, step3, step4, step5])),
  ]),
  bottomNavigationBar: _BottomNavRow(onBack: _back, onNext: _next, nextLabel: _step == 5 ? 'Activate' : 'Next'),
)
```

**Step 1 — Event Details** (`_EventDetailsStep`):
Form fields (use `Form` + `GlobalKey<FormState>`):
- Name: `TextFormField` required
- Type: `DropdownButtonFormField` values: `exam`, `mock`, `holiday_revision` (display: Exam, Mock, Holiday Revision)
- Term: `SegmentedButton<int>` segments: 1, 2, 3
- Year: `TextFormField` with int validator (default current year)
- Start Date: `TextButton` showing selected date, opens `showDatePicker`
- End Date: same, must be >= start date

State stored in `_EventDraft` data class.

**Step 2 — Schedule Papers** (`_SchedulePapersStep`):
State: `List<_PaperScheduleRow>` where:
```dart
class _PaperScheduleRow {
  int? subjectId;
  String? subjectName;
  int? grade;
  int? stream;          // null = all streams
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int? durationMinutes; // auto-computed from start/end
  String? invigilatorId;
  String? invigilatorName;
}
```

UI: `ListView` of `_PaperScheduleCard` widgets. Each card is a `Card` containing a responsive grid of dropdowns/pickers for each field. A trailing `IconButton(Icons.delete_outline)` removes the row.

Floating "Add Paper" button (`TextButton.icon(Icons.add)`) appends a new empty `_PaperScheduleRow`.

Below the list: `_TimetablePreview` widget.
- Collects unique dates (columns) and unique grades (rows) from current rows.
- Renders a `Table` where each cell shows subject abbreviation chips for that grade+date.
- Empty cells have `Colors.grey.shade100` background.

Validation on Next: every row must have subject, grade, date, startTime, endTime set. Show inline error on incomplete rows.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] git commit: `feat: exam wizard steps 1+2`

---

### Task D2: Exam wizard Step 3 — Syllabus coverage
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exam_creation_page.dart` (continued)
**Depends on:** Task D1
**Parallel group:** D-sequential

**Specification:**

**Step 3 — Syllabus Coverage** (`_SyllabusCoverageStep`):

On step entry: for each unique (subjectId, grade) pair in the paper schedule rows, fetch topics via `GetTaughtTopics(school, subject, grade)` RPC. Show loading shimmer while fetching.

Layout: `TabBar` at top with one tab per unique subject. Each tab body:
- `ExpansionTile` per grade (e.g. "Form 2")
- Within each grade: `ListView` of `CheckboxListTile` per topic
  - Title: topic name
  - Subtitle: `taught_date` formatted as "Covered [date]" if status == completed
  - Checkbox pre-checked if `status == completed` in fetched data
- If that grade has stream-specific rows in the schedule: show "Stream overrides" `ExpansionTile` below the grade checkboxes. Inside: `SegmentedButton` to pick a stream, then its own checkbox list.

Top of each tab: `Chip` showing "N / Total topics covered" with green color when N > 0.

State: `Map<String, Map<int, Set<int>>>` keyed as `subjectId -> grade -> Set<topicId>`.

Validation: Next button disabled if any (subject, grade) combination has zero topics checked. Show warning `Card` listing the uncovered combinations.

On Next:
- Call `ConfirmExamCoverage` RPC for each (scheduleId, topicIds) combination.
- Store confirmed coverage locally for Step 4 display.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: exam wizard step 3 — syllabus coverage`

---

### Task D3: Exam wizard Steps 4 & 5 — Review and Confirm
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exam_creation_page.dart` (continued)
**Depends on:** Task D2
**Parallel group:** D-sequential

**Specification:**

**Step 4 — Review** (`_ReviewStep`):

At top: scrollable `_TimetablePreview` (larger version of Step 2 preview).

Below: `ListView` of summary cards, one per scheduled paper:
- Subject + Grade + Stream label
- Date + time range + duration
- Invigilator: name or amber `Row(Icons.warning_amber, Text('No invigilator assigned'))`
- Topics eligible: "N topics confirmed"
- If N < 10: amber warning card "Low question pool — paper generation may fail. Return to step 3 to add more topics."

No interactive elements — read-only review.

**Step 5 — Confirm** (`_ConfirmStep`):

Summary text: "You are about to activate [N] exam papers across [K] subjects and [M] grades. Papers will be automatically generated 1 hour before each scheduled start time. Teachers will be notified 30 minutes before."

`FilledButton('Activate Exam')`. On tap:
1. Show `CircularProgressIndicator` overlay.
2. Call `CreateEvent` RPC → get `eventId`.
3. For each `_PaperScheduleRow`: call `SchedulePaper(eventId, ...)` RPC → get `scheduleId`.
4. For each schedule: call `ConfirmExamCoverage(scheduleId, topicIds)` RPC.
5. On all success: pop wizard, navigate to event detail screen, show SnackBar "Exam activated — papers will be auto-generated".
6. On any error: hide overlay, show error SnackBar, stay on step 5 with retry available.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: exam wizard steps 4+5 — review and confirm`

---

## Track E — Teacher Tools (no dependencies — start immediately)

---

### Task E1: Taught Topics screen
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/taught_topics_page.dart` (new file)
**Depends on:** nothing
**Parallel group:** E

**Specification:**

New `TaughtTopicsPage` widget.

Constructor:
```dart
const TaughtTopicsPage({
  super.key,
  required this.schoolId,
  required this.subjectId,
  required this.subjectName,
  required this.grade,
  this.streams = const [],  // list of stream codes this teacher covers
});
```

If `streams.length > 1`: show `SegmentedButton<int?>` at top with "All" (null) + each stream code. Selected stream determines which stream's data is shown and saved.

Body: `ListView.builder` of topic tiles fetched from `GetTaughtTopics(school, subject, grade, stream)` RPC.

Each tile — `ListTile`:
- `title`: topic name
- `trailing`: `_StatusChip(status)` — tap cycles through not_started → in_progress → completed
  - not_started: grey chip, label "Not started"
  - in_progress: amber chip, label "In progress"
  - completed: green chip, label "Completed ✓"
- `subtitle`: if completed and `taught_date != null`: `Text('Covered ${formatDate(taught_date)}')`

On status tap: optimistic UI update + call `SetTaughtTopics` RPC. On error: revert and show SnackBar.

Entry point: add "Topics Coverage" `ListTile` (with `Icons.checklist` icon) in the teacher's subject section of the school academics screen.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: taught topics page for teachers`

---

### Task E2: Assessment creation page
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/create_assessment_page.dart` (new file)
**Depends on:** nothing
**Parallel group:** E

**Specification:**

New `CreateAssessmentPage` widget.

Constructor:
```dart
const CreateAssessmentPage({
  super.key,
  required this.schoolId,
  required this.subjectId,
  required this.subjectName,
  required this.grade,
  this.stream,
});
```

Single-page form (not a wizard) with `Form` + validation:
- `name`: `TextFormField` — e.g. "Form 2A Chemistry CAT 1"
- `topic`: single-select. `DropdownButtonFormField` populated by fetching topics for this subject/grade.
- `grade` + `stream`: pre-filled from constructor, editable `DropdownButtonFormField`
- `total_marks`: `TextFormField` with int validator
- `date`: date picker `TextButton`

`FilledButton('Generate Papers')`:
1. Validate form.
2. Call `GenerateAssessment` RPC: `(school, subject, grade, stream, topic_id, total_marks, date)`.
3. Show `CircularProgressIndicator` during call.
4. On success: `Navigator.push(StudentPapersListPage(paperId: response.paperId))`.
5. On error: show SnackBar.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: assessment creation page`

---

### Task E3: Assignment creation page
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/create_assignment_page.dart` (new file)
**Depends on:** nothing
**Parallel group:** E

**Specification:**

New `CreateAssignmentPage` widget. Similar to E2 but multi-topic.

Constructor same as E2.

Form differences from E2:
- `topics` — multi-select chip panel. Fetch all topics for subject+grade. Show as `Wrap` of `FilterChip`. Selected topics appear in an "added topics" section.
- For each selected topic: a `Row` with topic name + `Slider(min: 0.5, max: 3.0, divisions: 5)` for weight. Label: "Weight: 1.5×". Default weight 1.0.
- `due_date`: date picker (not a fixed time — assignment is due by this date)
- `total_marks`: same as E2

Button: `FilledButton('Generate Assignments')`:
1. Call `GenerateAssignment` RPC: `(school, subject, grade, stream, topic_allocations: [{topic_id, weight}], total_marks, due_date)`.
2. Same success/error flow as E2 → navigate to `StudentPapersListPage`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: assignment creation page`

---

## Track F — Paper Management (depends A1, A2, A3)

---

### Task F1: Per-student papers list
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/student_papers_list_page.dart` (new file)
**Depends on:** Task A3
**Parallel group:** F

**Specification:**

New `StudentPapersListPage` widget.

Constructor:
```dart
const StudentPapersListPage({
  super.key,
  required this.paperId,
  required this.paperName,
});
```

On `initState`: start polling `GetStudentPapersStatus(paper_id)` every 3 seconds until `phase == complete` or `phase == failed`.

While generating: show `LinearProgressIndicator` + `Text('Generating papers… ${marked}/${total}')` at top of body. List below shows students with `CircularProgressIndicator` on their rows.

Once complete: stop polling. `ListView.builder` of student rows.

Each `_StudentPaperRow` (`StatefulWidget`):
- Leading: `CircleAvatar` with student initials
- Title: student name
- Subtitle: admission number
- Trailing: `Row` of:
  - Status badge: `Chip` green "Ready" or red "Failed"
  - `IconButton(Icons.visibility_outlined)` → push `PaperPreviewPage(paperId, studentId)`
  - If failed: `IconButton(Icons.refresh)` → retry single-student generation

`AppBar` actions:
- Default: `TextButton.icon(Icons.print, 'Print All')` → calls `_printAll()`
- Long-press any row → enter multi-select mode (change to `TextButton.icon(Icons.print, 'Print Selected')`)

`_printAll()`: iterate all ready students, open each `pdf_url` via `url_launcher` `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: per-student papers list with print-all`

---

### Task F2: Paper preview screen
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_preview_page.dart` (new file)
**Depends on:** Task A1, Task A2, Task A3
**Parallel group:** F (parallel with F1)

**Specification:**

New `PaperPreviewPage` widget.

Constructor:
```dart
const PaperPreviewPage({
  super.key,
  required this.paperId,
  this.studentId,
});
```

State: `bool _showMarkingScheme = false`.

`AppBar` action: `IconButton` that toggles `_showMarkingScheme`. Icon: `Icons.fact_check_outlined` (scheme) or `Icons.article_outlined` (paper).

On init: fetch `GetPaperQuestions(paper_id)`. If `studentId != null`, fetch `GetStudentPaperPdf(paper_id, student_id)` to get the PDF URL and student details.

Body: `SingleChildScrollView` → `Padding(16)` → `Column`:

**1. Header box** (`Container` with `Border.all`, `borderRadius: 8`, `padding: 16`):
- School name: bold, 16px, centered
- Exam name: 13px, centered
- Subject + Grade/Stream: 13px, centered
- `Divider`
- Row: `[Date]  [Duration: N min]  [Total: N marks]`
- If studentId: `Divider` + Row with `[Name: ___]  [Adm: ___]` (pre-filled from fetched student data)
- `Divider`
- `Text('ANSWER ALL QUESTIONS IN THE SPACES PROVIDED', style: labelSmall, textAlign: center)`

**2. Questions** — numbered `Column`:
For each `PaperQuestion` at `position` index:

```
Row:  [  Q{position}.  ]  [question body ... (expanded)]  [ {marks} marks ]
```

If `question.stimulus != null`: render `StimulusBlock` above the question body.

Question body: `renderBody(q.body, q.bodyFormat)`.

If `q.parts.isNotEmpty`: render parts below body, each indented 16px with `(label)` prefix.

If `_showMarkingScheme == false`:
- Show `AnswerSpaceWidget` after each question/part body.

If `_showMarkingScheme == true`:
- Show rubric criteria as bulleted list: `• criterion text [N mark(s)]`
- Show example answer:
  - format=='plain' or 'tiptap': `renderBody(content, format)` in a tinted Container
  - format=='svg': render inline SVG via `SvgPicture.string(content)` from `flutter_svg`
  - format=='image': show cached image widget

Between questions: `Divider(height: 24)`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: paper preview screen with marking scheme toggle`

---

## Track G — Bulk Upload Update (depends A1, A2)

---

### Task G1: Update BulkImportSheet for new question schema
**Files to create/modify:** `lib/ui/screens/system/settings/bulk_import_sheet.dart`
**Depends on:** Task A1, Task A2
**Parallel group:** G

**Specification:**

The existing `BulkImportSheet` parses pasted JSON and submits via `BulkImportQuestions` RPC.

**Parser changes** (in `_validate()` and the question validation loop):

Accept both old and new formats:
```dart
// body backward compat
final body = q['body'] as String? ?? q['text'] as String? ?? '';
final bodyFormat = q['body_format'] as String? ?? 'plain';

// example_answer backward compat
final rawEa = q['example_answer'];
final exampleAnswerContent = rawEa is String
    ? rawEa
    : (rawEa as Map?)?['content'] as String? ?? '';

// New fields (optional — do not reject if absent)
final parts = (q['parts'] as List?)?.cast<Map<String, dynamic>>();
final stimulus = q['stimulus'] as Map<String, dynamic>?;
final qType = q['type'] as String? ?? 'definition';
final difficulty = q['difficulty'] as int? ?? 3;
```

Additional validation:
- If `parts != null`: verify `parts.map((p) => p['marks']).sum == q['marks']`. If not, add error.
- If `max_marks` present: verify `max_marks <= marks`.
- Do NOT reject questions missing new fields — they default gracefully.

**Preview changes** (replace the plain-text question preview with rich preview):

After successful validation, show a preview list. Each preview item renders:
- Type badge `Chip`: `qType` with color coding (definition=blue, calculation=orange, structured=purple, experiment=green, diagram=teal, explanation=grey)
- Difficulty indicator: `Text('★' * difficulty)` in amber
- `StimulusBlock(stimulus)` if stimulus present
- `renderBody(body, bodyFormat)` for question body
- If parts: indented Column of `(label) renderBody(part.body, part.bodyFormat)` per part
- Marks badge

Keep the existing image upload workflow (absolute path → R2 upload → update URL) completely unchanged.

**Update after completion:**
- [x] Update `lib/ui/screens/system/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] git commit: `feat: update bulk import for new question schema`

---

## Dependency & Execution Summary

```
A1 → A2 → A3
A1, A2      → C1, G1
A1, A2, A3  → F1, F2
D1 → D2 → D3
(B1, E1, E2, E3, D1 start immediately — no dependencies)
```

| Wave | Tasks | Start condition |
|------|-------|-----------------|
| 1 | B1, D1, E1, E2, E3 | Immediately |
| 2 | A1 | Immediately (parallel with wave 1) |
| 3 | A2 | After A1 |
| 4 | A3, C1, G1 | After A2 |
| 5 | F1, F2 | After A3 |
| 6 | D2 | After D1 |
| 7 | D3 | After D2 |


---

## Track M — Model, Service & Proto Foundations (prerequisites for D/E/F)

> These tasks must complete before Tasks D2, D3, E1, E2, E3, F1, F2 can be executed.
> M0, M1, M3 have no dependencies and start immediately (parallel with Wave 1).

---

### Task M0: Regenerate proto stubs after server adds paper.proto
**Files to create/modify:** `lib/proto/services/paper.pb.dart` (generated), `lib/proto/services/paper.pbgrpc.dart` (generated), `lib/proto/services/paper.pbenum.dart` (generated), `lib/proto/services/paper.pbjson.dart` (generated), `lib/proto/services/question_bank.pb.dart` (regenerated with new Question fields)
**Context files to read (if needed):** `lib/proto/CONTEXT.md`
**Depends on:** Server agent must have added `paper.proto` to `ledger/protos/services/` and updated `question_bank.proto` with new Question fields (body, body_format, parts, stimulus, type, difficulty, cognitive_level, max_marks, answer_space_type, answer_lines, answer_box_height_mm) before this task runs.
**Parallel group:** M-immediate

**Specification:**

This task has one step: run `generate.sh` from the eduxal project root.

```sh
cd /home/abdihakim/Documents/GITHUB/eduxal-labs/eduxal
chmod +x generate.sh
./generate.sh
```

After running, verify the following files now exist:
- `lib/proto/services/paper.pb.dart`
- `lib/proto/services/paper.pbgrpc.dart`

Also verify `lib/proto/services/question_bank.pb.dart` contains references to `body`, `bodyFormat`, `parts`, `stimulus` fields on the `Question` message class.

**Expected new proto message classes** (from `paper.pb.dart`):
- `CreateEventRequest`, `CreateEventResponse`
- `SchedulePaperRequest`, `SchedulePaperResponse`
- `ConfirmExamCoverageRequest`, `ConfirmExamCoverageResponse`
- `GetTaughtTopicsRequest`, `TaughtTopic`, `GetTaughtTopicsResponse`
- `SetTaughtTopicRequest`, `SetTaughtTopicResponse`
- `GenerateAssessmentRequest`, `GenerateAssessmentResponse`
- `GenerateAssignmentRequest`, `TopicWeight`, `GenerateAssignmentResponse`
- `GetStudentPapersStatusRequest`, `StudentEntry`, `GetStudentPapersStatusResponse`
- `GetStudentPaperPdfRequest`, `GetStudentPaperPdfResponse`

**Expected new proto service** (from `paper.pbgrpc.dart`):
- `PaperClient` with methods: `createEvent`, `schedulePaper`, `confirmExamCoverage`, `getTaughtTopics`, `setTaughtTopic`, `generateAssessment`, `generateAssignment`, `getStudentPapersStatus`, `getStudentPaperPdf`

If the generated files are missing or incomplete, stop and notify: the server agent has not yet committed the proto changes.

**Update after completion:**
- [x] Update `lib/proto/CONTEXT.md` — add `paper.pb.dart`, `paper.pbgrpc.dart` entries; note `question_bank.pb.dart` was regenerated with new Question fields
- [x] Mark this task `[x]`
- [x] git commit: `chore: regenerate proto stubs — add paper service, new Question fields`

---

### Task M1: Add url_launcher to pubspec.yaml
**Files to create/modify:** `pubspec.yaml`
**Depends on:** nothing
**Parallel group:** M-immediate

**Specification:**

Add `url_launcher: ^6.3.0` to `pubspec.yaml` under the `dependencies:` section, alongside the other existing dependencies (e.g. after `file_picker`):

```yaml
  url_launcher: ^6.3.0
```

Then run `flutter pub get` to resolve it.

`url_launcher` is required by `StudentPapersListPage` (Task F1) which calls:
```dart
import 'package:url_launcher/url_launcher.dart';
// ...
await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
```

Do NOT add it to dev_dependencies. It is a runtime dependency.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] git commit: `chore: add url_launcher dependency for PDF print-all`

---

### Task M2: Update Question model + add QuestionPart class
**Files to create/modify:** `lib/models/question.dart`, `lib/models/paper_generation.dart`
**Context files to read (if needed):** `lib/models/CONTEXT.md`
**Depends on:** Task M0 (needs regenerated `question_bank.pb.dart` with new Question fields)
**Parallel group:** M-after-M0

**Specification:**

The `Question` and `PaperQuestion` domain models need new fields to match the updated proto schema. All changes are **backward-compatible**: existing code using `question.text` continues to work; new code uses `question.body` / `question.bodyFormat`.

---

**Step 1 — Add `RubricCriterion.fromMap` factory** to `lib/models/question.dart` (the class already has `fromProto`; add alongside it):

```dart
factory RubricCriterion.fromMap(Map<String, dynamic> m) => RubricCriterion(
  criterion: m['criterion'] as String? ?? '',
  marks: m['marks'] as int? ?? 0,
);
```

---

**Step 2 — Add `QuestionPart` class** to `lib/models/question.dart`, inserted before the `Question` class:

```dart
/// A labelled sub-question (part) within a structured question.
class QuestionPart {
  final String label;           // e.g. 'a', 'b', 'i', 'ii'
  final String body;            // part question text
  final String bodyFormat;      // 'plain' | 'tiptap'
  final int marks;
  final String answerSpaceType; // 'lines' | 'plain_box' | 'diagram_box' | 'construction_box' | 'grid_box'
  final int answerLines;        // lines count when answerSpaceType == 'lines'
  final int answerBoxHeightMm;  // box height in mm for box types
  final List<RubricCriterion> rubric;
  final dynamic exampleAnswer;  // String (old) or Map<String, dynamic>{format, content} (new)

  const QuestionPart({
    required this.label,
    required this.body,
    this.bodyFormat = 'plain',
    required this.marks,
    this.answerSpaceType = 'lines',
    this.answerLines = 4,
    this.answerBoxHeightMm = 80,
    this.rubric = const [],
    this.exampleAnswer,
  });

  factory QuestionPart.fromMap(Map<String, dynamic> m) => QuestionPart(
    label: m['label'] as String? ?? '',
    body: m['body'] as String? ?? '',
    bodyFormat: m['body_format'] as String? ?? 'plain',
    marks: m['marks'] as int? ?? 0,
    answerSpaceType: m['answer_space_type'] as String? ?? 'lines',
    answerLines: m['answer_lines'] as int? ?? 4,
    answerBoxHeightMm: m['answer_box_height_mm'] as int? ?? 80,
    rubric: (m['rubric'] as List<dynamic>?)
            ?.map((e) => RubricCriterion.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    exampleAnswer: m['example_answer'],
  );
}
```

---

**Step 3 — Update `Question` class** in `lib/models/question.dart`. Replace the existing `Question` class definition with the following (keeping the `fromProto` import at top of file):

New fields to add:
```dart
final String body;            // replaces text; == text if body not provided by server
final String bodyFormat;      // 'plain' | 'tiptap'; default 'plain'
final List<QuestionPart> parts;
final Map<String, dynamic>? stimulus; // {type, body, body_format, caption?}
final String type;            // 'definition'|'explanation'|'calculation'|'structured'|'experiment'|'data_response'|'diagram'
final int difficulty;         // 1–5
final String cognitiveLevel;  // 'recall'|'comprehension'|'application'|'analysis'
final int maxMarks;           // <= marks; for partial-credit questions
final String answerSpaceType; // 'lines'|'plain_box'|'diagram_box'|'construction_box'|'grid_box'
final int answerLines;        // line count when answerSpaceType == 'lines'
```

Updated constructor — use initializer to derive `body` and `maxMarks` from legacy fields when not provided:
```dart
const Question({
  required this.id,
  required this.topicId,
  required this.text,
  String? body,
  this.bodyFormat = 'plain',
  this.parts = const [],
  this.stimulus,
  this.type = 'definition',
  this.difficulty = 3,
  this.cognitiveLevel = 'recall',
  required this.marks,
  int? maxMarks,
  this.answerSpaceType = 'lines',
  this.answerLines = 4,
  required this.rubric,
  this.exampleAnswer,
  required this.images,
  required this.created,
  required this.updated,
}) : body = body ?? text,
     maxMarks = maxMarks ?? marks;
```

Updated `Question.fromProto` factory — handle new optional fields gracefully. Note: proto field named `type` generates as `type_2` in Dart to avoid keyword conflict; verify with actual generated code and adjust if different:
```dart
factory Question.fromProto(pb.Question proto) {
  List<QuestionPart> parts = [];
  try {
    parts = proto.parts
        .map((p) => QuestionPart.fromMap({
              'label': p.label,
              'body': p.body,
              'body_format': p.bodyFormat,
              'marks': p.marks,
              'answer_space_type': p.answerSpaceType,
              'answer_lines': p.answerLines,
              'answer_box_height_mm': p.answerBoxHeightMm,
              'rubric': p.rubric
                  .map((r) => {'criterion': r.criterion, 'marks': r.marks})
                  .toList(),
              'example_answer': p.hasExampleAnswer() ? p.exampleAnswer : null,
            }))
        .toList();
  } catch (_) {
    // proto.parts not present in older server versions — ignore
  }

  Map<String, dynamic>? stimulus;
  try {
    if (proto.hasStimulus()) {
      stimulus = {
        'type': proto.stimulus.type,
        'body': proto.stimulus.body,
        'body_format': proto.stimulus.bodyFormat,
        if (proto.stimulus.hasCaption()) 'caption': proto.stimulus.caption,
      };
    }
  } catch (_) {}

  return Question(
    id: proto.id,
    topicId: proto.topicId,
    text: proto.text,
    body: proto.hasBody() ? proto.body : proto.text,
    bodyFormat: proto.hasBodyFormat() ? proto.bodyFormat : 'plain',
    parts: parts,
    stimulus: stimulus,
    // proto field 'type' becomes 'type_2' in Dart due to keyword collision.
    // If the generated name differs, check question_bank.pb.dart and adjust.
    type: proto.hasType2() ? proto.type2 : 'definition',
    difficulty: proto.hasDifficulty() ? proto.difficulty : 3,
    cognitiveLevel:
        proto.hasCognitiveLevel() ? proto.cognitiveLevel : 'recall',
    marks: proto.marks,
    maxMarks: proto.hasMaxMarks() ? proto.maxMarks : proto.marks,
    answerSpaceType:
        proto.hasAnswerSpaceType() ? proto.answerSpaceType : 'lines',
    answerLines: proto.hasAnswerLines() ? proto.answerLines : 4,
    rubric: proto.rubric.map(RubricCriterion.fromProto).toList(),
    exampleAnswer: proto.hasExampleAnswer() ? proto.exampleAnswer : null,
    images: proto.images.map(QuestionImage.fromProto).toList(),
    created:
        DateTime.fromMillisecondsSinceEpoch(proto.created.toInt() * 1000),
    updated:
        DateTime.fromMillisecondsSinceEpoch(proto.updated.toInt() * 1000),
  );
}
```

---

**Step 4 — Update `PaperQuestion` class** in `lib/models/paper_generation.dart`. Add new fields mirroring `Question`:

```dart
final String body;
final String bodyFormat;
final List<QuestionPart> parts;
final Map<String, dynamic>? stimulus;
final String type;
final int difficulty;
final String answerSpaceType;
final int answerLines;
```

Update the constructor to include them (with defaults), and update `PaperQuestion.fromProto` to read them from `proto.question` (the nested `Question` proto message). Use the same `hasBody()` / `hasBodyFormat()` / `hasType2()` guards as in `Question.fromProto` above.

Add `import 'question.dart' show QuestionPart;` at the top of `paper_generation.dart` if not already imported (it already imports `question.dart` via the `RubricCriterion` + `QuestionImage` usage, so `QuestionPart` will be available).

**Update after completion:**
- [x] Update `lib/models/CONTEXT.md` — update `question.dart` entry to mention QuestionPart and new Question fields; update `paper_generation.dart` entry to mention PaperQuestion new fields
- [x] Mark this task `[x]`
- [x] git commit: `feat: add QuestionPart model and new Question/PaperQuestion fields`

---

### Task M3: Event and Paper domain model classes
**Files to create/modify:** `lib/models/event.dart` (new), `lib/models/paper.dart` (new)
**Context files to read (if needed):** `lib/models/CONTEXT.md`
**Depends on:** nothing
**Parallel group:** M-immediate

**Specification:**

Create two new model files for the exam lifecycle domain. These are pure Dart — no Drift or proto imports.

---

**`lib/models/event.dart`:**

```dart
/// Generation phases for a scheduled paper.
enum PaperGenerationPhase {
  pending,     // not yet started — exam is in the future
  generating,  // server is generating student papers
  complete,    // all student papers are ready
  failed,      // generation failed
}

/// An exam event created by a school admin.
class ExamEvent {
  final String id;
  final String schoolId;
  final String name;
  final String type;       // 'exam' | 'mock' | 'holiday_revision'
  final int term;          // 1 | 2 | 3
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final List<ScheduledPaper> papers;

  const ExamEvent({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.type,
    required this.term,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.papers = const [],
  });
}

/// A paper (one subject × one grade × one stream) scheduled within an event.
class ScheduledPaper {
  final String scheduleId;
  final String eventId;
  final int subjectId;
  final String subjectName;
  final int grade;
  final int? stream;             // null = all streams
  final DateTime date;
  final int startMinutes;        // minutes since midnight
  final int endMinutes;          // minutes since midnight
  final String? invigilatorId;
  final String? invigilatorName;
  final PaperGenerationPhase phase;
  final int totalStudents;
  final int generatedCount;

  const ScheduledPaper({
    required this.scheduleId,
    required this.eventId,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    this.stream,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    this.invigilatorId,
    this.invigilatorName,
    this.phase = PaperGenerationPhase.pending,
    this.totalStudents = 0,
    this.generatedCount = 0,
  });

  int get durationMinutes => endMinutes - startMinutes;

  /// Human-readable time range, e.g. "08:00 – 10:00".
  String get timeRange {
    String fmt(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '${fmt(startMinutes)} – ${fmt(endMinutes)}';
  }

  /// Exact DateTime when the exam starts (combines date + startMinutes).
  DateTime get startDateTime =>
      DateTime(date.year, date.month, date.day)
          .add(Duration(minutes: startMinutes));
}
```

---

**`lib/models/paper.dart`:**

```dart
import 'event.dart' show PaperGenerationPhase;

/// A per-student generated paper entry, from GetStudentPapersStatus RPC.
class StudentPaperEntry {
  final String studentId;
  final String studentName;
  final String admNo;
  final bool isReady;
  final bool isFailed;
  final String? pdfUrl;      // null until generation completes
  final DateTime? pdfExpiry; // null until generation completes

  const StudentPaperEntry({
    required this.studentId,
    required this.studentName,
    required this.admNo,
    required this.isReady,
    required this.isFailed,
    this.pdfUrl,
    this.pdfExpiry,
  });
}

/// Aggregated generation status for all students on a paper.
/// Returned by [PaperService.getStudentPapersStatus].
class StudentPapersStatus {
  final PaperGenerationPhase phase;
  final int total;
  final int generated;
  final List<StudentPaperEntry> students;

  const StudentPapersStatus({
    required this.phase,
    required this.total,
    required this.generated,
    required this.students,
  });
}

/// A single student's paper PDF metadata.
/// Returned by [PaperService.getStudentPaperPdf].
class StudentPaperPdf {
  final String pdfUrl;
  final DateTime expiry;
  final String studentName;
  final String admNo;

  const StudentPaperPdf({
    required this.pdfUrl,
    required this.expiry,
    required this.studentName,
    required this.admNo,
  });
}
```

**Update after completion:**
- [x] Update `lib/models/CONTEXT.md` — add `event.dart` (ExamEvent, ScheduledPaper, PaperGenerationPhase) and `paper.dart` (StudentPaperEntry, StudentPapersStatus, StudentPaperPdf) entries
- [x] Mark this task `[x]`
- [x] git commit: `feat: add ExamEvent, ScheduledPaper, and StudentPaper domain models`

---

### Task M4: PaperService — new gRPC service wrapper
**Files to create/modify:** `lib/services/paper_service.dart` (new)
**Context files to read (if needed):** `lib/services/CONTEXT.md`, `lib/models/CONTEXT.md`
**Depends on:** Task M0 (needs `paper.pbgrpc.dart`), Task M3 (for model types)
**Parallel group:** M-after-M0

**Specification:**

Create `lib/services/paper_service.dart`. This service wraps the `Paper` gRPC service and is the central dependency for Tasks D2, D3, E1, E2, E3, F1, F2.

```dart
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:grpc/grpc.dart';

import '../models/event.dart';
import '../models/paper.dart';
import '../models/result.dart';
import '../proto/services/paper.pb.dart' as pb;
import '../proto/services/paper.pbgrpc.dart' as pbgrpc;

/// A topic with its current taught status.
/// Returned by [PaperService.getTaughtTopics].
class TaughtTopic {
  final int topicId;
  final String topicName;
  /// 0 = not_started, 1 = in_progress, 2 = completed
  final int status;
  final DateTime? taughtDate; // non-null when status == 2

  const TaughtTopic({
    required this.topicId,
    required this.topicName,
    required this.status,
    this.taughtDate,
  });
}

/// Service wrapping the Paper gRPC service.
///
/// Handles the exam lifecycle: event creation, paper scheduling, syllabus
/// coverage confirmation, assessment/assignment generation, and per-student
/// paper status polling and PDF retrieval.
class PaperService {
  PaperService({required ClientChannel channel}) : _channel = channel;

  final ClientChannel _channel;

  pbgrpc.PaperClient get _client => pbgrpc.PaperClient(_channel);

  CallOptions _opts(String token) => CallOptions(
        metadata: {'authorization': 'Bearer $token'},
        timeout: const Duration(seconds: 30),
      );

  // ---------------------------------------------------------------------------
  // Exam lifecycle
  // ---------------------------------------------------------------------------

  /// Create an exam event. Returns the new event ID on success.
  Future<Result<String, GrpcError>> createEvent({
    required String school,
    required String name,
    required String type,
    required int term,
    required int year,
    required DateTime startDate,
    required DateTime endDate,
    required String accessToken,
  }) async {
    try {
      final req = pb.CreateEventRequest()
        ..school = school
        ..name = name
        ..type = type
        ..term = term
        ..year = year
        ..startDate = Int64(startDate.millisecondsSinceEpoch ~/ 1000)
        ..endDate = Int64(endDate.millisecondsSinceEpoch ~/ 1000);
      final resp =
          await _client.createEvent(req, options: _opts(accessToken));
      return Ok(resp.eventId);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('createEvent failed: $e'));
    }
  }

  /// Schedule a paper within an existing event. Returns the new schedule ID.
  ///
  /// [stream] = 0 means "all streams for this grade".
  /// [startMinutes] and [endMinutes] are minutes since midnight.
  Future<Result<String, GrpcError>> schedulePaper({
    required String eventId,
    required int subjectId,
    required int grade,
    int stream = 0,
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
    String? invigilatorId,
    required String accessToken,
  }) async {
    try {
      final req = pb.SchedulePaperRequest()
        ..eventId = eventId
        ..subjectId = subjectId
        ..grade = grade
        ..stream = stream
        ..date = Int64(date.millisecondsSinceEpoch ~/ 1000)
        ..startMinutes = startMinutes
        ..endMinutes = endMinutes;
      if (invigilatorId != null) req.invigilatorId = invigilatorId;
      final resp =
          await _client.schedulePaper(req, options: _opts(accessToken));
      return Ok(resp.scheduleId);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('schedulePaper failed: $e'));
    }
  }

  /// Confirm the syllabus topic coverage for a scheduled paper.
  Future<Result<void, GrpcError>> confirmExamCoverage({
    required String scheduleId,
    required List<int> topicIds,
    required String accessToken,
  }) async {
    try {
      final req = pb.ConfirmExamCoverageRequest()
        ..scheduleId = scheduleId
        ..topicIds.addAll(topicIds);
      await _client.confirmExamCoverage(req, options: _opts(accessToken));
      return Ok(null);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('confirmExamCoverage failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Topic coverage
  // ---------------------------------------------------------------------------

  /// Fetch the taught-topics status for a subject+grade (optionally per-stream).
  ///
  /// [stream] = 0 returns aggregate status across all streams.
  Future<Result<List<TaughtTopic>, GrpcError>> getTaughtTopics({
    required String school,
    required int subjectId,
    required int grade,
    int stream = 0,
    required String accessToken,
  }) async {
    try {
      final req = pb.GetTaughtTopicsRequest()
        ..school = school
        ..subjectId = subjectId
        ..grade = grade
        ..stream = stream;
      final resp =
          await _client.getTaughtTopics(req, options: _opts(accessToken));
      final topics = resp.topics
          .map((t) => TaughtTopic(
                topicId: t.topicId,
                topicName: t.topicName,
                status: t.status,
                taughtDate: t.hasTaughtDate() && t.taughtDate != Int64.ZERO
                    ? DateTime.fromMillisecondsSinceEpoch(
                        t.taughtDate.toInt() * 1000)
                    : null,
              ))
          .toList();
      return Ok(topics);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('getTaughtTopics failed: $e'));
    }
  }

  /// Update the taught status for a single topic.
  ///
  /// [status]: 0 = not_started, 1 = in_progress, 2 = completed.
  /// [stream] = 0 sets the status for all streams.
  Future<Result<void, GrpcError>> setTaughtTopic({
    required String school,
    required int subjectId,
    required int grade,
    required int stream,
    required int topicId,
    required int status,
    required String accessToken,
  }) async {
    try {
      final req = pb.SetTaughtTopicRequest()
        ..school = school
        ..subjectId = subjectId
        ..grade = grade
        ..stream = stream
        ..topicId = topicId
        ..status = status;
      await _client.setTaughtTopic(req, options: _opts(accessToken));
      return Ok(null);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('setTaughtTopic failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Generation
  // ---------------------------------------------------------------------------

  /// Generate a single-topic class assessment. Returns the paper ID.
  Future<Result<String, GrpcError>> generateAssessment({
    required String school,
    required int subjectId,
    required int grade,
    int stream = 0,
    required int topicId,
    required int totalMarks,
    required DateTime date,
    required String accessToken,
  }) async {
    try {
      final req = pb.GenerateAssessmentRequest()
        ..school = school
        ..subjectId = subjectId
        ..grade = grade
        ..stream = stream
        ..topicId = topicId
        ..totalMarks = totalMarks
        ..date = Int64(date.millisecondsSinceEpoch ~/ 1000);
      final resp =
          await _client.generateAssessment(req, options: _opts(accessToken));
      return Ok(resp.paperId);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('generateAssessment failed: $e'));
    }
  }

  /// Generate a multi-topic assignment. Returns the paper ID.
  ///
  /// [topicAllocations] is a list of records with topicId + weight (e.g. 1.5x).
  Future<Result<String, GrpcError>> generateAssignment({
    required String school,
    required int subjectId,
    required int grade,
    int stream = 0,
    required List<({int topicId, double weight})> topicAllocations,
    required int totalMarks,
    required DateTime dueDate,
    required String accessToken,
  }) async {
    try {
      final req = pb.GenerateAssignmentRequest()
        ..school = school
        ..subjectId = subjectId
        ..grade = grade
        ..stream = stream
        ..totalMarks = totalMarks
        ..dueDate = Int64(dueDate.millisecondsSinceEpoch ~/ 1000);
      for (final a in topicAllocations) {
        req.topicAllocations.add(
          pb.TopicWeight()
            ..topicId = a.topicId
            ..weight = a.weight,
        );
      }
      final resp =
          await _client.generateAssignment(req, options: _opts(accessToken));
      return Ok(resp.paperId);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('generateAssignment failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Per-student paper status & retrieval
  // ---------------------------------------------------------------------------

  /// Poll generation progress for all students on a paper.
  Future<Result<StudentPapersStatus, GrpcError>> getStudentPapersStatus({
    required String paperId,
    required String accessToken,
  }) async {
    try {
      final req = pb.GetStudentPapersStatusRequest()..paperId = paperId;
      final resp = await _client.getStudentPapersStatus(
          req, options: _opts(accessToken));
      final phase =
          PaperGenerationPhase.values[resp.phase.clamp(0, 3)];
      final students = resp.students
          .map((s) => StudentPaperEntry(
                studentId: s.studentId,
                studentName: s.name,
                admNo: s.admNo,
                isReady: s.ready,
                isFailed: s.failed,
                pdfUrl: s.pdfUrl.isEmpty ? null : s.pdfUrl,
                pdfExpiry: s.pdfExpiry == Int64.ZERO
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        s.pdfExpiry.toInt() * 1000),
              ))
          .toList();
      return Ok(StudentPapersStatus(
        phase: phase,
        total: resp.total,
        generated: resp.generated,
        students: students,
      ));
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('getStudentPapersStatus failed: $e'));
    }
  }

  /// Get the presigned PDF URL for a specific student's generated paper.
  Future<Result<StudentPaperPdf, GrpcError>> getStudentPaperPdf({
    required String paperId,
    required String studentId,
    required String accessToken,
  }) async {
    try {
      final req = pb.GetStudentPaperPdfRequest()
        ..paperId = paperId
        ..studentId = studentId;
      final resp =
          await _client.getStudentPaperPdf(req, options: _opts(accessToken));
      return Ok(StudentPaperPdf(
        pdfUrl: resp.pdfUrl,
        expiry:
            DateTime.fromMillisecondsSinceEpoch(resp.expiry.toInt() * 1000),
        studentName: resp.studentName,
        admNo: resp.admNo,
      ));
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('getStudentPaperPdf failed: $e'));
    }
  }
}
```

**Constructor wiring:** `PaperService` must be instantiated in `lib/client.dart` alongside the existing `QuestionBankService`. Add a `PaperService get paperService` getter. Export a global `late PaperService paperService;` in `client.dart` for use by UI screens (following the same pattern as the existing `QuestionBankService` instance).

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md` — add `paper_service.dart` entry with all methods and TaughtTopic type
- [x] Update `lib/models/CONTEXT.md` — note TaughtTopic is defined in `services/paper_service.dart`
- [x] Mark this task `[x]`
- [x] git commit: `feat: add PaperService with exam lifecycle, coverage, and generation methods`

---

### Task M5: Event detail screen
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/event_detail_screen.dart` (new)
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** Task M3, Task M4
**Parallel group:** M-ui

**Specification:**

New `EventDetailScreen` widget. The admin lands here after completing the exam wizard (Task D3 navigates here on success) or by tapping an existing event from the events list.

**Constructor:**
```dart
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.schoolId,
    this.papers = const [],
    this.eventType = 'exam',
    this.term = 1,
    this.year,
  });

  final String eventId;
  final String eventName;
  final String schoolId;
  final List<ScheduledPaper> papers; // pre-loaded from wizard or empty
  final String eventType;            // 'exam' | 'mock' | 'holiday_revision'
  final int term;
  final int? year;
}
```

**Layout:**

```
AppBar
  title: Text(eventName)
  subtitle: Text('${eventType.toUpperCase()} · Term $term ${year ?? ''}')
  actions: [IconButton(Icons.refresh, tooltip: 'Refresh status', onTap: _refresh)]

Body: ListView
  if papers.isEmpty:
    Center(Column[Icon(Icons.event_available, size: 64), Text('No papers scheduled')])
  else:
    for each ScheduledPaper: _ScheduledPaperCard
```

**`_ScheduledPaperCard`** — `StatefulWidget` that polls its own paper phase:

```dart
class _ScheduledPaperCard extends StatefulWidget {
  const _ScheduledPaperCard({required this.paper, required this.schoolId});
  final ScheduledPaper paper;
  final String schoolId;
}
```

Polling: in `initState`, if `paper.phase == generating`, start a `Timer.periodic(Duration(seconds: 5), _pollStatus)`. In `_pollStatus`, call `paperService.getStudentPapersStatus(paperId: paper.scheduleId, accessToken: accessToken)`. On `Ok`, update local `_phase`, `_total`, `_generated`. Cancel timer when phase == complete or failed. Cancel in `dispose`.

Card layout:
```
Card(
  child: ListTile(
    title: Text('${paper.subjectName} — Grade ${gradeLabel(paper.grade)}'
                 '${paper.stream != null ? ' (Stream ${paper.stream})' : ''}'),
    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${formatDate(paper.date)}  ·  ${paper.timeRange}  ·  ${paper.durationMinutes} min'),
      if (paper.invigilatorName != null)
        Text('Invigilator: ${paper.invigilatorName}')
      else
        Row(children: [Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                        Text(' No invigilator assigned',
                             style: TextStyle(color: Colors.orange, fontSize: 12))]),
      SizedBox(height: 4),
      _PhaseChip(phase: _phase, generated: _generated, total: _total),
    ]),
    trailing: _phase == PaperGenerationPhase.complete
        ? IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Preview paper',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaperPreviewPage(paperId: paper.scheduleId),
              ),
            ),
          )
        : null,
  ),
)
```

**`_PhaseChip`** widget (private, stateless):

| Phase | Color | Label |
|---|---|---|
| pending | grey | "Scheduled" |
| generating | amber | Row[SizedBox(14,14,CircularProgressIndicator(strokeWidth:2)), " Generating $generated/$total"] |
| complete | green | "Ready" |
| failed | red | "Failed" |

Use `Chip(backgroundColor: color, label: ...)` with white label text.

Imports needed: `event.dart`, `paper_service.dart` (via global `paperService`), `paper_preview_page.dart` (Task F2), `client.dart` (for `accessToken`), `models/school_config.dart` (for `gradeLabel`).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — add `event_detail_screen.dart` entry
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: event detail screen with per-paper phase polling`

---

### Task M6: Teacher paper reveal screen (time-gated read-only view)
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/paper_reveal_page.dart` (new)
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md` (for TiptapRenderer, StimulusBlock, AnswerSpaceWidget)
**Depends on:** Task A1, Task A2, Task A3, Task M4
**Parallel group:** M-ui

**Specification:**

New `PaperRevealPage` widget. This is the teacher-facing read-only paper view, available starting 30 minutes before the exam. It always shows the marking scheme (teachers need it to supervise and correct papers). It is structurally similar to `PaperPreviewPage` (Task F2) but with key differences:

1. Time-gated: locked until 30 min before exam start.
2. Marking scheme always visible (no toggle).
3. Shows "CONFIDENTIAL — TEACHER COPY" banner.
4. No student name/adm fields in header.

**Constructor:**
```dart
class PaperRevealPage extends StatefulWidget {
  const PaperRevealPage({
    super.key,
    required this.paperId,
    required this.examStartTime, // exact DateTime when exam begins
    required this.examName,
    required this.subjectName,
  });

  final String paperId;
  final DateTime examStartTime;
  final String examName;
  final String subjectName;
}
```

**State:**
```dart
class _PaperRevealPageState extends State<PaperRevealPage> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  List<PaperQuestion> _questions = [];
  bool _isLoading = false;
  String? _error;

  DateTime get _revealTime =>
      widget.examStartTime.subtract(const Duration(minutes: 30));

  bool get _isRevealed => DateTime.now().isAfter(_revealTime);
```

**`initState`:**
- Compute `_remaining = _revealTime.difference(DateTime.now())`.
- If `!_isRevealed`: start `Timer.periodic(Duration(seconds: 1), _tick)`.
- If `_isRevealed`: call `_loadQuestions()`.

**`_tick(Timer t)`:**
```dart
void _tick(Timer t) {
  final remaining = _revealTime.difference(DateTime.now());
  if (remaining.isNegative || remaining == Duration.zero) {
    t.cancel();
    _loadQuestions();
  }
  if (mounted) setState(() => _remaining = remaining);
}
```

**`_loadQuestions()`:** Call `QuestionBankService.getPaperQuestions(paperId: widget.paperId, accessToken: accessToken)`. On `Ok`, `setState(() { _questions = resp; _isLoading = false; })`. On `Err`, `setState(() { _error = e.message; _isLoading = false; })`.

**`dispose`:** cancel `_countdownTimer`.

**Build — locked state** (when `!_isRevealed`):
```
AppBar(title: Text(widget.subjectName), subtitle: Text(widget.examName))
Body: Center(Column(mainAxisSize: MainAxisSize.min, children: [
  Icon(Icons.lock_clock_outlined, size: 72, color: Colors.grey.shade400),
  SizedBox(height: 16),
  Text('Paper available at ${_formatTime(_revealTime)}',
       style: textTheme.titleMedium),
  SizedBox(height: 8),
  Text('Available in ${_remaining.inMinutes}m ${_remaining.inSeconds % 60}s',
       style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary,
                                            fontWeight: FontWeight.bold)),
  SizedBox(height: 4),
  Text('This paper is confidential until 30 minutes before the exam.',
       style: textTheme.bodySmall?.copyWith(color: Colors.grey),
       textAlign: TextAlign.center),
]))
```

**Build — revealed state** (`_isRevealed == true`):

If `_isLoading`: `Center(CircularProgressIndicator())`.
If `_error != null`: `Center(Text('Failed to load: $_error'))` with retry button.

Otherwise `SingleChildScrollView` → `Padding(EdgeInsets.all(16))` → `Column`:

**Header box** (`Container` with `Border.all(color: Colors.grey.shade300)`, `borderRadius: 8`, `padding: EdgeInsets.all(14)`):
- School name: bold, 16px, centered (load from `SchoolContext` or pass as constructor param — use `widget.schoolName` if added, else omit)
- `Text(widget.examName, textAlign: center)`
- `Text(widget.subjectName, textAlign: center)`
- `Divider`
- `Text('CONFIDENTIAL — TEACHER COPY', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11), textAlign: center)`
- `Divider`
- `Text('ANSWER ALL QUESTIONS IN THE SPACES PROVIDED', style: labelSmall, textAlign: center)`

**Questions** — same rendering pattern as `PaperPreviewPage` (Task F2):
For each `PaperQuestion` at index `i`:
- Question number + body row + marks badge
- `StimulusBlock` if `question.stimulus != null`
- `renderBody(question.body, question.bodyFormat)`
- Parts column if `question.parts.isNotEmpty`
- Marking scheme (always shown):
  - Rubric: bulleted list `• ${criterion.criterion} [${criterion.marks} mark(s)]`
  - Example answer: `renderBody(content, format)` or `SvgPicture.string(content)` for svg format, in a tinted `Container(color: colorScheme.surfaceVariant.withOpacity(0.4))`
- `Divider(height: 24)` between questions

**Entry point:** Add a "View Paper" `ListTile` or `IconButton` in the teacher's exam schedule screen once `paper.phase == PaperGenerationPhase.complete`. Navigation example:
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => PaperRevealPage(
    paperId: paper.scheduleId,
    examStartTime: paper.startDateTime,
    examName: eventName,
    subjectName: paper.subjectName,
  ),
));
```

Imports: `dart:async`, `package:flutter_svg/flutter_svg.dart`, `tiptap_renderer.dart` (for renderBody), `stimulus_block.dart`, `answer_space.dart`, `models/paper_generation.dart` (for `PaperQuestion`), `services/question_bank.dart` (for `getPaperQuestions`), `client.dart` (for `accessToken`).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — add `paper_reveal_page.dart` entry
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: teacher paper reveal screen with 30-min time gate`



---

## Updated Dependency & Execution Summary (revised — includes Track M)

```
A1 → A2 → A3
A1, A2            → C1, G1
A1, A2, A3        → F2, M6
A1, A2, A3, M4    → F1
M0                → M2, M4
M3                → M4
M4                → D2, D3, E1, E2, E3, F1, F2
M3, M4            → M5
D1 → D2 → D3
(B1, D1, M0, M1, M3 start immediately — no dependencies)
```

| Wave | Tasks | Start condition |
|------|-------|-----------------|
| 1 | B1, D1, M0, M1, M3 | Immediately |
| 2 | A1 | Immediately (parallel with wave 1) |
| 3 | A2, M2 | A2 after A1 · M2 after M0 |
| 4 | A3, C1, G1, M4 | A3/C1/G1 after A2 · M4 after M0 + M3 |
| 5 | D2, E1, E2, E3 | After M4 · D2 also after D1 |
| 6 | F1, F2, M5, M6 | F1/F2 after A3 + M4 · M5 after M4 · M6 after A3 + M4 |
| 7 | D3 | After D2 |

**Dependency corrections for existing tasks:**
- Task D2 now also depends on Task M4 (calls `PaperService.getTaughtTopics`)
- Task D3 now also depends on Task M4 (calls `PaperService.createEvent`, `schedulePaper`, `confirmExamCoverage`)
- Task E1 now also depends on Task M4 (calls `PaperService.getTaughtTopics`, `setTaughtTopic`)
- Task E2 now also depends on Task M4 (calls `PaperService.generateAssessment`)
- Task E3 now also depends on Task M4 (calls `PaperService.generateAssignment`)
- Task F1 now also depends on Task M4 (calls `PaperService.getStudentPapersStatus`) and Task M1 (url_launcher)
- Task F2 now also depends on Task M4 (calls `PaperService.getStudentPaperPdf`) and Task M2 (PaperQuestion new fields)
- Task C1 now also depends on Task M2 (reads `question.body`, `question.bodyFormat`, `question.parts`, `question.stimulus`)
- Task G1 now also depends on Task M2 (backward-compat preview uses new Question fields)
