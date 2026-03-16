# EduXal — Task Board

> **Workflow:** Examiner writes tasks → Orchestrator dispatches → Executor implements.
> Each task is self-sufficient. The executor should not need to explore the codebase.

---

## Track A: Window Resize Navigation Loss (Critical — Must Be First)

### Task A1: Prevent ExamsGradesScreen rebuild on window resize (navigation state loss)

**Files to modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Problem:** The `ExamsGradesScreen` is a `StatelessWidget` that creates a new `_ExamsShell` on every build. When the parent `_DashboardShellState` rebuilds due to a layout mode change (window resize), it calls `_buildContentPanel` which returns a **new** `ExamsGradesScreen(...)` widget. Since `ExamsGradesScreen` is a `StatelessWidget`, it immediately calls `build()` and creates a **new** `_ExamsShell`. Flutter sees a new `_ExamsShell` widget instance and tears down the old `_ExamsShellState` — which holds `_view`, `_selectedGroup`, `_selectedPaper`, etc. This resets navigation to `_ExamsView.list`.

Additionally, `_ExamsShellState._loadConfig()` and `_loadSubjectNames()` use `.listen()` on streams without storing the subscription — so they leak subscriptions and trigger `setState` on every stream event, causing unnecessary rebuilds.

**Specification:**

1. In `_ExamsShellState`, store the stream subscriptions from `_loadConfig()` and `_loadSubjectNames()` and cancel them in `dispose()`:

```dart
import 'dart:async';

// Add fields:
StreamSubscription? _configSub;
StreamSubscription? _subjectNamesSub;

// In _loadSubjectNames():
Future<void> _loadSubjectNames() async {
  _subjectNamesSub = _catalogDao.watchSubjects().listen((subjects) {
    if (!mounted) return;
    setState(() {
      _subjectNames = {for (final s in subjects) s.id: s.name};
    });
  });
}

// In _loadConfig():
Future<void> _loadConfig() async {
  final schoolId = widget.schoolContext.membership.school.id;
  _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((allStreams) {
    if (!mounted) return;
    setState(() {
      _config = _buildConfigFromStreams(allStreams);
    });
  });
}

// In dispose():
@override
void dispose() {
  _configSub?.cancel();
  _subjectNamesSub?.cancel();
  super.dispose();
}
```

2. The root cause of navigation loss is that `_DashboardShellState.build` is wrapped in a `ValueListenableBuilder` → `LayoutBuilder` chain. When the layout mode changes, `setState` is called via `addPostFrameCallback`, which triggers a full rebuild of the content area. The `_buildContentPanel` method returns `ExamsGradesScreen(schoolContext: widget.schoolContext)` — since `ExamsGradesScreen` is a `StatelessWidget`, it always returns a new `_ExamsShell` widget, causing the state to be discarded.

   **Fix in `school_dashboard_screen.dart` (lines ~312–338):** The `LayoutBuilder` currently schedules a `setState` when `_layoutMode` changes. This causes the entire content area to rebuild, creating new widget instances. Instead, use the `newMode` value directly in the `_buildLayout` call without storing it in state:

   In `_DashboardShellState`, change the `build` method:

```dart
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<MembershipEntry>(
    valueListenable: widget.schoolContext.currentEntry,
    builder: (context, currentEntry, _) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final newMode = w >= AppTheme.kDesktopBreakpoint
              ? _LayoutMode.full
              : w >= AppTheme.kMobileBreakpoint
              ? _LayoutMode.rail
              : _LayoutMode.mobile;
          // Use newMode directly — do NOT call setState.
          // The LayoutBuilder already rebuilds on constraint changes,
          // so storing _layoutMode in state is redundant and causes
          // content area teardown.
          return _buildLayout(context, currentEntry, newMode);
        },
      );
    },
  );
}
```

   Remove the `_layoutMode` field entirely (it's no longer needed since `newMode` is computed inline). Remove the `addPostFrameCallback` + `setState` block.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note resize fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `fix: prevent navigation state loss on window resize in exams screen`

---

## Track B: Paper Detail Page — Student Filtering (Bug #2)

### Task B1: Pass paper's stream to getEnrolledStudents so only grade/stream students are listed

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/database/daos/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Problem:** Both `_PaperDetailPageState._loadStudents()` (paper_detail_page.dart L188–199) and `_PaperDetailViewState._loadStudents()` (exams_grades_screen.dart L6625–6637) call `_dao.getEnrolledStudents(...)` without passing the `stream` parameter. The DAO method signature already supports `int? stream` but it's not being passed. This causes ALL students in the grade to be shown, regardless of which stream the paper targets.

The `Paper` object has a `stream` field (nullable int) that corresponds to the stream code. When `paper.stream` is non-null, only students enrolled in that specific stream should be shown.

**Specification:**

1. **In `paper_detail_page.dart` (around line 188–199),** modify `_loadStudents()`:

```dart
Future<void> _loadStudents() async {
  final list = await _dao.getEnrolledStudents(
    schoolId: widget.schoolId,
    year: widget.year,
    term: widget.term,
    grade: widget.grade,
    stream: _paper.stream,  // ADD THIS — filters by paper's stream
  );
  if (!mounted) return;
  setState(() {
    _students = list;
    _loadingStudents = false;
  });
}
```

2. **In `exams_grades_screen.dart` (`_PaperDetailViewState._loadStudents`, around line 6625–6637),** modify similarly:

```dart
Future<void> _loadStudents() async {
  final list = await _dao.getEnrolledStudents(
    schoolId: widget.schoolId,
    year: widget.year,
    term: widget.term,
    grade: widget.grade,
    stream: widget.paper.stream,  // ADD THIS
  );
  if (!mounted) return;
  setState(() {
    _students = list;
    _loadingStudents = false;
  });
}
```

The DAO method `getEnrolledStudents` already has the `stream` parameter with a `null` default (meaning "all streams"). No DAO changes needed.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note student filtering fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `fix: filter students by paper's grade/stream in paper detail pages`

---

## Track C: Paper Status Button — Visual & Behavioral Fixes (Bugs #3, #4, #5, #6)

These tasks fix the status advance button in both `paper_detail_page.dart` and `exams_grades_screen.dart`. They must be sequential since they modify the same widget.

### Task C1: Fix status advance button in paper_detail_page.dart — semantic colors, arc progress, animation, and immediate UI update

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Problem (Bug #3):** The status advance button in `_PaperActionBarState` (paper_detail_page.dart L696–899) already has correct per-status colors in `_buttonConfig()` (blue for Start, orange for Done, green for Grade). But the user reports "always the same reddish/pinkish color" — this suggests the `_PaperStatusChip` widget (L3538–3573) or the button itself uses a single color. Looking at the code, `_buttonConfig` returns correct colors per status, so the issue may be that the widget doesn't rebuild after status change (Bug #6).

**Problem (Bug #4):** There is no circular arc indicator on the status button. The user wants a circular progress arc that fills proportionally: Pending=0%, Progress=33%, Done=66%, Marked=100% (filled green circle with white check).

**Problem (Bug #5):** When clicked, the button only shows a brief checkmark flash for the "Start→Progress" transition (and nothing for other transitions). The user wants meaningful animation for every transition.

**Problem (Bug #6):** After `_advance()` updates the paper status in the DB, the `_PaperActionBar` widget does NOT react because it receives `widget.paper` as a snapshot — it's not watching the stream. The parent `_PaperDetailPageState` does have a `_paperStream` but the `_PaperActionBar` receives `currentPaper` from the `StreamBuilder<Paper?>`. However, looking at the build method (L230–235), the `_PaperActionBar` receives `currentPaper` from the outer `StreamBuilder<Paper?>` — so this SHOULD work. The real issue is that `_PaperActionBarState._buttonConfig` reads `widget.paper.status`, and the widget IS getting the new paper from the stream. Let me re-examine...

Actually, the `_advance()` method calls `widget.dao.updatePaper(...)` which updates the DB. The `_paperStream` in the parent watches the paper. When the DB updates, `_paperStream` emits a new `Paper` with the updated status, which causes the `StreamBuilder<Paper?>` to rebuild with `currentPaper` having the new status. The `_PaperActionBar` receives this new `currentPaper`. Since `_PaperActionBar` is a `StatefulWidget`, `didUpdateWidget` would be called — but there's no `didUpdateWidget` override, and the `build` method reads `widget.paper.status` which should be the new value.

So the likely cause is: the animation/busy state prevents the visual update. In `_advance()`, `setState(() => _busy = true)` is set, then after the DB update, the `_showCheck` logic runs for 600ms and only then sets `_busy = false`. During this time, the button shows a checkmark or spinner, and the STATUS description/chip beside it doesn't update because `_busy` blocks the re-render of the config. But actually `_buttonConfig` reads `widget.paper.status` which is the NEW status from the parent stream... Let me check again.

Wait — the issue is that `_advance()` only shows the checkmark for `PaperStatus.pending → progress`, and for other transitions it just sets `_busy = false` immediately. The button DOES update but there's no animation feedback for the other transitions. And the `_PaperStatusChip` beside it DOES read `widget.paper.status` which should update. So Bug #6 might be specific to the `exams_grades_screen.dart` version (`_StatusAdvanceButton`) which is a different widget.

Let me check `_StatusAdvanceButton` in exams_grades_screen.dart (L7197–7253): it uses `AnimatedSaveButton` and receives `widget.paper.status` — but the parent `_PaperStatusRow` receives the `paper` prop from the outer `_PaperDetailView`, which gets `widget.paper` — a static prop, NOT from a stream. The `_PaperDetailView` in exams_grades_screen.dart does NOT have a `StreamBuilder` for the paper itself — it only has one for grades. So when the status is updated in DB, the parent `_ExamsShellState` still holds the OLD `_selectedPaper` object. **This is the root cause of Bug #6 in exams_grades_screen.dart.**

**Specification:**

Replace the `_PaperActionBar` and `_PaperActionBarState` classes (L673–899 of paper_detail_page.dart) with a new implementation that:

1. **Uses semantic colors with circular arc progress indicator:**
   - Replace the rectangular button with a circular icon button that has a colored arc around it
   - Arc coverage: Pending = 25% (blue), Progress = 50% (orange), Done = 75% (green), Marked = 100% (green, filled, white check)
   - The arc color should be the color of the NEXT status (what clicking will transition TO)
   - When Marked (final state), show a fully filled green circle with a white check icon

2. **Meaningful transition animation:**
   - On click: the arc should animate from current coverage to next coverage over 400ms with `Curves.easeInOut`
   - The icon should cross-fade from current icon to next icon
   - A brief scale pulse (0.9 → 1.0, 200ms elastic) on the button itself
   - After the DB update completes and status changes, the button should show a brief green flash (200ms)

3. **Immediate UI reflection (already works in this file via StreamBuilder):**
   - The parent `_PaperDetailPageState.build()` already wraps `_PaperActionBar` in `StreamBuilder<Paper?>` which provides `currentPaper`. So status updates are reflected immediately. No changes needed for this in paper_detail_page.dart.

Here is the replacement implementation for `_PaperActionBar` and `_PaperActionBarState`:

```dart
class _PaperActionBar extends StatefulWidget {
  const _PaperActionBar({
    required this.paper,
    required this.schoolId,
    required this.exam,
    required this.dao,
    required this.canManage,
    required this.cs,
    this.onDeleted,
  });

  final Paper paper;
  final String schoolId;
  final Exam exam;
  final ExamsGradesDao dao;
  final bool canManage;
  final ColorScheme cs;
  final VoidCallback? onDeleted;

  @override
  State<_PaperActionBar> createState() => _PaperActionBarState();
}

class _PaperActionBarState extends State<_PaperActionBar>
    with TickerProviderStateMixin {
  bool _busy = false;
  late AnimationController _arcCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _flashCtrl;
  late Animation<double> _arcAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arcAnimation = Tween<double>(
      begin: _arcFraction(widget.paper.status),
      end: _arcFraction(widget.paper.status),
    ).animate(CurvedAnimation(parent: _arcCtrl, curve: Curves.easeInOut));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_scaleCtrl);
  }

  @override
  void didUpdateWidget(_PaperActionBar old) {
    super.didUpdateWidget(old);
    if (old.paper.status != widget.paper.status) {
      // Animate arc from old fraction to new fraction
      _arcAnimation = Tween<double>(
        begin: _arcFraction(old.paper.status),
        end: _arcFraction(widget.paper.status),
      ).animate(CurvedAnimation(parent: _arcCtrl, curve: Curves.easeInOut));
      _arcCtrl.forward(from: 0);
      // Flash green briefly
      _flashCtrl.forward(from: 0).then((_) {
        if (mounted) _flashCtrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _arcCtrl.dispose();
    _scaleCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  double _arcFraction(PaperStatus s) => switch (s) {
    PaperStatus.pending => 0.0,
    PaperStatus.progress => 0.33,
    PaperStatus.done => 0.66,
    PaperStatus.marked => 1.0,
  };

  Color _statusColor(PaperStatus s) => switch (s) {
    PaperStatus.pending => const Color(0xFF42A5F5),   // blue
    PaperStatus.progress => const Color(0xFFFFA726),   // orange
    PaperStatus.done => const Color(0xFF66BB6A),       // green
    PaperStatus.marked => const Color(0xFF43A047),     // dark green
  };

  IconData _statusIcon(PaperStatus s) => switch (s) {
    PaperStatus.pending => Icons.play_arrow_rounded,
    PaperStatus.progress => Icons.check_circle_outline_rounded,
    PaperStatus.done => Icons.grading_rounded,
    PaperStatus.marked => Icons.check_rounded,
  };

  String _statusLabel(PaperStatus s) => switch (s) {
    PaperStatus.pending => 'Start',
    PaperStatus.progress => 'Done',
    PaperStatus.done => 'Grade',
    PaperStatus.marked => 'Marked',
  };

  PaperStatus? _nextStatus(PaperStatus s) => switch (s) {
    PaperStatus.pending => PaperStatus.progress,
    PaperStatus.progress => PaperStatus.done,
    PaperStatus.done => PaperStatus.marked,
    PaperStatus.marked => null,
  };

  Future<void> _deletePaper(BuildContext context) async {
    final subjLabel =
        widget.paper.paper != null ? 'Paper ${widget.paper.paper}' : 'Paper';
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Paper?',
      message: 'This will permanently remove $subjLabel.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    try {
      await widget.dao.deletePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        accountId: accountId,
      );
      widget.onDeleted?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance() async {
    final next = _nextStatus(widget.paper.status);
    if (next == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    // Scale pulse
    _scaleCtrl.forward(from: 0);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.updatePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        changes: PapersCompanion(status: Value(next), updated: Value(now)),
        accountId: accountId,
      );
      // Arc animation + flash handled in didUpdateWidget when stream delivers new status
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusDescription(PaperStatus s) => switch (s) {
    PaperStatus.pending => 'Not yet started',
    PaperStatus.progress => 'Exam in progress',
    PaperStatus.done => 'Exam completed, awaiting grading',
    PaperStatus.marked => 'Fully graded',
  };

  @override
  Widget build(BuildContext context) {
    final status = widget.paper.status;
    final next = _nextStatus(status);
    final isPending = status == PaperStatus.pending;
    final isMarked = status == PaperStatus.marked;
    final color = _statusColor(status);
    final nextColor = next != null ? _statusColor(next) : color;

    return Row(
      children: [
        // Delete button — only in pending state
        if (widget.canManage && isPending) ...[
          Tooltip(
            message: 'Delete paper',
            child: InkWell(
              onTap: _busy ? null : () => _deletePaper(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: widget.cs.error.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        _PaperStatusChip(status: status, cs: widget.cs),
        const SizedBox(width: 8),
        Text(
          _statusDescription(status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: widget.cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        if (widget.canManage)
          AnimatedBuilder(
            animation: Listenable.merge([_arcAnimation, _scaleAnimation, _flashCtrl]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleCtrl.isAnimating ? _scaleAnimation.value : 1.0,
                child: _buildCircularButton(status, isMarked, color, nextColor),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCircularButton(
    PaperStatus status,
    bool isMarked,
    Color color,
    Color nextColor,
  ) {
    final arcValue = _arcCtrl.isAnimating
        ? _arcAnimation.value
        : _arcFraction(status);
    final flashValue = _flashCtrl.value;
    final size = 40.0;

    if (isMarked) {
      // Fully filled green circle with white check
      return Tooltip(
        message: 'Fully graded',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(const Color(0xFF43A047), const Color(0xFF66BB6A), flashValue),
          ),
          child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
        ),
      );
    }

    final next = _nextStatus(status);
    if (next == null) return const SizedBox.shrink();

    return Tooltip(
      message: _statusLabel(status),
      child: GestureDetector(
        onTap: _busy ? null : _advance,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ArcProgressPainter(
              progress: arcValue,
              arcColor: nextColor,
              trackColor: widget.cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 3.0,
              flashColor: flashValue > 0
                  ? const Color(0xFF66BB6A).withValues(alpha: flashValue * 0.5)
                  : null,
            ),
            child: Center(
              child: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: nextColor,
                      ),
                    )
                  : Icon(_statusIcon(status), size: 18, color: nextColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for a circular arc progress indicator with track.
class _ArcProgressPainter extends CustomPainter {
  _ArcProgressPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
    this.flashColor,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;
  final Color? flashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle, light)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Flash fill
    if (flashColor != null) {
      final flashPaint = Paint()
        ..color = flashColor!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - strokeWidth / 2, flashPaint);
    }

    // Arc (partial circle)
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      const startAngle = -math.pi / 2; // 12 o'clock
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.flashColor != flashColor;
}
```

Make sure to add `import 'dart:math' as math;` at the top if not already present (it already is at line 2).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note status button redesign
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `ui: redesign paper status button with semantic colors, arc progress, and animations`

---

### Task C2: Fix status advance button in exams_grades_screen.dart — same visual fixes + reactive status update

**Files to modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** None
**Depends on:** Task C1 (uses same pattern)
**Parallel group:** P3

**Problem:** The `_StatusAdvanceButton` in exams_grades_screen.dart (L7197–7253) uses a plain `AnimatedSaveButton` with no color/arc semantics. It also does not reactively reflect the status change because the `_PaperDetailView` receives `widget.paper` as a static prop from `_ExamsShellState._selectedPaper` — which is never updated after the DB write. The `_PaperDetailView` does NOT have a `StreamBuilder` for the paper itself.

**Specification:**

1. **Add a paper stream to `_PaperDetailView`:** Wrap the content in a `StreamBuilder<Paper?>` that watches the paper, so status changes are reflected immediately.

2. **Replace `_PaperStatusRow` and `_StatusAdvanceButton`** with a new `_StatusAdvanceCircle` widget that matches the design from Task C1 (circular arc progress button with semantic colors, animation).

**Detailed changes:**

**Step 1:** In `_PaperDetailViewState` (line ~6613), add a paper stream and wrap the build content in it:

```dart
class _PaperDetailViewState extends State<_PaperDetailView> {
  late final ExamsGradesDao _dao;
  List<StudentsData> _students = [];
  bool _loadingStudents = true;
  late Stream<Paper?> _paperStream;

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _paperStream = _dao.watchPaper(
      schoolId: widget.schoolId,
      examId: widget.exam.exam.id,
      subject: widget.paper.subject,
      paperNum: widget.paper.paper,
    );
    _loadStudents();
  }
```

Then in the `build` method, wrap the existing content with `StreamBuilder<Paper?>`:

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  return StreamBuilder<Paper?>(
    stream: _paperStream,
    builder: (context, paperSnap) {
      final paper = paperSnap.data ?? widget.paper;
      final exam = widget.exam.exam;
      final subjectLabel =
          widget.subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
      final paperLabel = paper.paper != null ? ' Paper ${paper.paper}' : '';
      final gradeLabel = '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: '$subjectLabel$paperLabel',
            subtitle: '$gradeLabel · ${widget.year} T${widget.term}',
            leadingAction: _HeaderAction(
              icon: Icons.chevron_left,
              label: 'Back',
              onTap: widget.onBack,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<GradeRow>>(
              stream: _dao.watchGradesForPaper(
                schoolId: widget.schoolId,
                examId: exam.id,
                subject: paper.subject,
                paper: paper.paper,
              ),
              builder: (context, snap) {
                // ... same as before but using `paper` variable instead of `widget.paper`
                // Pass `paper` to _PaperStatusRow and _GradeSpreadsheet/_GradeList
              },
            ),
          ),
        ],
      );
    },
  );
}
```

**Step 2:** Replace `_PaperStatusRow` (L7162–7195) and `_StatusAdvanceButton` (L7197–7253) with a new implementation matching the circular arc design from C1:

```dart
class _PaperStatusRow extends StatelessWidget {
  const _PaperStatusRow({
    required this.paper,
    required this.schoolId,
    required this.exam,
    required this.dao,
    required this.canManage,
    required this.cs,
  });
  final Paper paper;
  final String schoolId;
  final Exam exam;
  final ExamsGradesDao dao;
  final bool canManage;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusChip(status: paper.status, cs: cs),
        const Spacer(),
        if (canManage)
          _StatusAdvanceCircle(
            paper: paper,
            schoolId: schoolId,
            exam: exam,
            dao: dao,
            cs: cs,
          ),
      ],
    );
  }
}
```

The `_StatusAdvanceCircle` widget should follow the exact same pattern as the `_PaperActionBar`'s circular button from C1:
- Circular button with arc progress painter
- Arc fractions: pending=0.0, progress=0.33, done=0.66, marked=1.0
- Colors: pending→blue, progress→orange, done→green, marked→dark green (filled)
- Icon per status: play, check_circle_outline, grading, check
- Scale pulse + arc animation on click
- Flash animation via didUpdateWidget when paper.status changes
- Fully filled green circle with white check at marked state

Copy the `_ArcProgressPainter` class from C1 into this file as well (or if it's large, define it identically — these are private classes in separate files so no conflict).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note exams_grades_screen status button fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `ui: fix status button + reactive status in exams_grades_screen paper detail view`

---

## Track D: Grade Entry Visibility (Bug #7)

### Task D1: Show grade input at all paper statuses instead of hiding it during Pending/InProgress

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** None
**Depends on:** Task C1 (paper_detail_page status button must be updated first, so canGrade logic is clear)
**Parallel group:** P4

**Problem:** In `paper_detail_page.dart`, the `_SpreadsheetRow` widget (L1931–2184) only shows the grade edit button (`showGradeButton`) and submission controls (`showSubmit`) when `paperStatus == PaperStatus.done || paperStatus == PaperStatus.marked`. The grade input TextFormField IS always shown (it's gated only by `widget.canGrade`, not by status), but the edit icon, submission button, and quick-grade AI button are hidden during Pending and InProgress.

The user wants grade entry to be visible at ALL statuses — the grade box should always be interactable, not hidden. The submission/AI features can still be gated behind Done/Marked, but the basic grade input should be available.

Similarly in `exams_grades_screen.dart`, the `_GradeSpreadsheet` and `_SpreadsheetRow` (L7530+) use the same pattern — they don't pass `paperStatus` or `submissionCount` at all (they're the simpler version without AI features), so the grade input IS always shown there. But the grade edit button is also missing.

**Specification:**

1. **In `paper_detail_page.dart` `_SpreadsheetRowState.build()` (around L1933–2184):**

   Change `showGradeButton` to always be true when `canGrade` is true (remove the status check):

   ```dart
   final showGradeButton = widget.canGrade;
   ```

   Keep `showSubmit` gated to Done/Marked as before — submission features make sense only after exam is done:
   ```dart
   final showSubmit =
       widget.paperStatus == PaperStatus.done ||
       widget.paperStatus == PaperStatus.marked;
   ```

2. **In `paper_detail_page.dart` `_GradeListState` (mobile version, around L2215–2744):**

   Apply the same change — ensure grade entry is always available regardless of paper status. The mobile `_openGradeEntry` and `_openStudentActionSheet` methods should work at any status.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `ui: allow grade entry at all paper statuses`

---

## Track E: Answer Sheet Submission + AI Marking on Per-Student Button (Bug #8)

### Task E1: Ensure per-student submission/mark buttons work correctly with proper state and coloring

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** Tasks C1, D1
**Parallel group:** P5

**Problem:** The per-student quick-grade AI button in `_SpreadsheetRow` has the same static color (always indigo `#6366F1`). The user wants this button to also use the circular arc + semantic color pattern matching the overall status advance button. Specifically:

1. The per-student mark icon button should visually indicate state:
   - No submissions: grey upload icon
   - Has submissions but not graded: indigo pulsing dot or icon
   - Graded: green check

2. When a student's papers are provided or changed, the overall AI "Mark with AI" button should reflect that there are pending changes (new/changed submissions that haven't been AI-marked yet).

3. The per-student quick-grade button (`Icons.auto_fix_high`) currently always uses the same indigo color. It should use a small circular arc indicator similar to the status button — but simpler:
   - No submission: hidden/disabled
   - Has submission, not graded: show with indigo arc at 50%
   - Has submission, graded: show with green filled circle + check

**Specification:**

1. **In `_SpreadsheetRowState.build()` (paper_detail_page.dart around L1933):**

   Update the quick-grade AI button (the `Icons.auto_fix_high` button) to use a small `_MiniArcIndicator` widget:

   ```dart
   // Replace the existing quick-grade button block:
   if (showSubmit && widget.submissionCount > 0) ...[
     GestureDetector(
       onTap: (widget.isQuickGrading || !widget.canGrade)
           ? null
           : widget.onQuickGradeTap,
       child: Tooltip(
         message: 'Quick-grade with AI',
         child: _MiniArcIndicator(
           hasGrade: widget.existingGrade != null,
           isProcessing: widget.isQuickGrading,
         ),
       ),
     ),
     const SizedBox(width: 4),
   ],
   ```

2. **Add `_MiniArcIndicator` widget** (new, add near the bottom of the file):

   ```dart
   class _MiniArcIndicator extends StatelessWidget {
     const _MiniArcIndicator({
       required this.hasGrade,
       required this.isProcessing,
     });

     final bool hasGrade;
     final bool isProcessing;

     @override
     Widget build(BuildContext context) {
       if (isProcessing) {
         return SizedBox(
           width: 28,
           height: 28,
           child: Padding(
             padding: const EdgeInsets.all(7),
             child: CircularProgressIndicator(
               strokeWidth: 1.5,
               color: const Color(0xFF6366F1),
             ),
           ),
         );
       }
       if (hasGrade) {
         return Container(
           width: 28,
           height: 28,
           decoration: BoxDecoration(
             color: const Color(0xFF66BB6A).withValues(alpha: 0.15),
             borderRadius: BorderRadius.circular(14),
           ),
           child: const Icon(Icons.check_rounded, size: 15, color: Color(0xFF66BB6A)),
         );
       }
       return SizedBox(
         width: 28,
         height: 28,
         child: CustomPaint(
           painter: _ArcProgressPainter(
             progress: 0.5,
             arcColor: const Color(0xFF6366F1),
             trackColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
             strokeWidth: 2.0,
           ),
           child: const Center(
             child: Icon(Icons.auto_fix_high, size: 13, color: Color(0xFF6366F1)),
           ),
         ),
       );
     }
   }
   ```

3. **Track "dirty" submissions** — when submissions are added/changed, mark which students have new submissions that haven't been AI-graded yet. Add a `Set<int> _dirtySubmissions` field to `_GradeSpreadsheetState`:

   ```dart
   final Set<int> _dirtySubmissions = {};
   ```

   In `_openSubmissionSheet`, update the `onUpdated` callback to add the student to `_dirtySubmissions`:

   ```dart
   onUpdated: (paths) {
     if (mounted) {
       setState(() {
         _submissions[adm] = paths;
         if (paths.isNotEmpty) _dirtySubmissions.add(adm);
       });
     }
   },
   ```

   After AI marking completes (in `_runAiMarking`), clear the dirty set:
   ```dart
   setState(() {
     _dirtySubmissions.clear();
     // ... existing reset code
   });
   ```

   Pass `_dirtySubmissions.isNotEmpty` to the `_AiMarkButton` to show a visual indicator of pending changes (e.g., a small orange dot on the button or change the label to "Mark with AI (N new)").

4. **Update `_AiMarkButton`** to accept and display a `hasPendingChanges` parameter:
   - Add `final bool hasPendingChanges;` and `final int pendingCount;`
   - When `hasPendingChanges` is true and phase is idle, show modified label: `'Mark N new with AI'`
   - Add a small pulsing orange dot on the button when there are pending changes

5. **Apply same changes to `_GradeListState`** (mobile version, L2215–2744) — it has its own `_submissions`, `_quickGrading` maps. Apply the same `_dirtySubmissions` tracking and `_MiniArcIndicator` usage.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `ui: improve per-student AI mark buttons with arc indicators and dirty tracking`

---

## Track F: Paper Detail Page Reload on Resize (Bug #1)

### Task F1: Prevent paper_detail_page.dart from reloading data on window resize

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** Task A1 (the main resize fix must land first)
**Parallel group:** P4

**Problem:** `PaperDetailPage` is a separate `Scaffold` pushed via `Navigator.push`. When the window resizes, the parent `_DashboardShellState` rebuilds but `PaperDetailPage` is on the Navigator stack — it should NOT be torn down. However, the page's `build()` method contains a `LayoutBuilder` (L254) inside the `StreamBuilder` chain, which recalculates `isDesktop` on every constraint change. This causes the list content to switch between `_GradeSpreadsheet` and `_GradeList`, which tears down the active widget (losing draft state, focus, etc.).

**Specification:**

1. **Move the `isDesktop` computation to state** instead of recomputing it on every build inside LayoutBuilder. Use `MediaQuery.sizeOf(context).width` in the build method (which doesn't cause child teardown like LayoutBuilder does), and only switch layout modes when the threshold is actually crossed:

   In `_PaperDetailPageState`, add a field:
   ```dart
   bool _isDesktop = true; // default, set in initState or first build
   ```

   In `build()`, replace the inner `LayoutBuilder` with a width check that doesn't recreate child widgets unnecessarily:

   ```dart
   // Replace:
   //   return LayoutBuilder(
   //     builder: (context, constraints) {
   //       final isDesktop = constraints.maxWidth >= AppTheme.kMobileBreakpoint;
   //       ...
   //
   // With:
   final screenWidth = MediaQuery.sizeOf(context).width;
   final isDesktop = screenWidth >= AppTheme.kMobileBreakpoint;
   ```

   This still rebuilds on resize, but since the `_GradeSpreadsheet` and `_GradeList` are `StatefulWidget`s, they preserve state as long as they aren't swapped out. The key issue was `LayoutBuilder` triggering constant rebuilds — `MediaQuery.sizeOf` only triggers rebuild when the actual size changes, which is less frequent.

2. **Prevent unnecessary stream re-subscription:** The streams (`_gradesStream`, `_paperStream`) are created once in `initState` and never recreated — this is correct and should NOT be changed.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task with message `fix: prevent paper detail page data reload on window resize`

---

## Execution Order Summary

| Phase | Tasks | Parallel? | Notes |
|-------|-------|-----------|-------|
| 1 | A1, B1 | Yes (P1) — different files, no overlap | Critical resize fix + student filter |
| 2 | C1 | Sequential | Paper detail page status button redesign |
| 3 | C2 | Sequential (depends on C1 pattern) | Exams grades screen status button + reactive update |
| 4 | D1, F1 | Yes (P4) — D1 touches SpreadsheetRow visibility, F1 touches LayoutBuilder in parent | Grade visibility + resize reload fix |
| 5 | E1 | Sequential (depends on C1, D1) | Per-student AI button improvements |

**Total: 7 tasks across 5 phases.**

Each phase should be followed by a git commit as specified in each task.