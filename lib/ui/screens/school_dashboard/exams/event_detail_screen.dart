import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../models/event.dart';
import '../../../../models/result.dart';
// TODO(F2): Uncomment when Task F2 (PaperPreviewPage) is complete.
// import '../academics/paper_preview_page.dart';

// =============================================================================
// EventDetailScreen
// =============================================================================

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
  final List<ScheduledPaper> papers;
  final String eventType;
  final int term;
  final int? year;

  void _refresh(BuildContext context) {
    // Papers are passed in from the parent navigator. Each card polls its own
    // status automatically via a 5-second Timer. A manual refresh tap shows a
    // brief confirmation so the user knows the auto-refresh is active.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cards auto-refresh every 5 s while generating'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(eventName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _refresh(context),
          ),
        ],
      ),
      body: papers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No papers scheduled',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final paper in papers)
                  _ScheduledPaperCard(
                    key: ValueKey(paper.scheduleId),
                    paper: paper,
                    schoolId: schoolId,
                  ),
              ],
            ),
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================

String _formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// =============================================================================
// _ScheduledPaperCard
// =============================================================================

class _ScheduledPaperCard extends StatefulWidget {
  const _ScheduledPaperCard({
    super.key,
    required this.paper,
    required this.schoolId,
  });

  final ScheduledPaper paper;
  final String schoolId;

  @override
  State<_ScheduledPaperCard> createState() => _ScheduledPaperCardState();
}

class _ScheduledPaperCardState extends State<_ScheduledPaperCard> {
  late PaperGenerationPhase _phase;
  late int _total;
  late int _generated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phase = widget.paper.phase;
    _total = widget.paper.totalStudents;
    _generated = widget.paper.generatedCount;

    if (_phase == PaperGenerationPhase.generating) {
      _timer = Timer.periodic(const Duration(seconds: 5), _poll);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll(Timer timer) async {
    final result = await paperService.getStudentPapersStatus(
      paperId: widget.paper.scheduleId,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        setState(() {
          _phase = value.phase;
          _total = value.total;
          _generated = value.generated;
        });
        if (_phase == PaperGenerationPhase.complete ||
            _phase == PaperGenerationPhase.failed) {
          _timer?.cancel();
          _timer = null;
        }
      case Err():
        // Transient error — keep polling; the card will update next tick.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row + phase chip ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${paper.subjectName} — Grade ${paper.grade}'
                    '${paper.stream != null ? ' (Stream ${paper.stream})' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PhaseChip(phase: _phase, generated: _generated, total: _total),
              ],
            ),
            const SizedBox(height: 6),
            // ── Date / time / duration ──────────────────────────────────────
            Text(
              '${_formatDate(paper.date)}  ·  ${paper.timeRange}'
              '  ·  ${paper.durationMinutes} min',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            // ── Invigilator row ─────────────────────────────────────────────
            if (paper.invigilatorName != null) ...[
              const SizedBox(height: 2),
              Text(
                'Invigilator: ${paper.invigilatorName}',
                style: const TextStyle(fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'No invigilator assigned',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ],
            // ── Preview button (complete phase only) ─────────────────────────
            if (_phase == PaperGenerationPhase.complete) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                  // TODO(F2): Navigate to PaperPreviewPage when Task F2 is
                  // complete. File: ../academics/paper_preview_page.dart
                  //
                  // Replace this block with:
                  //   Navigator.push(context, MaterialPageRoute(
                  //     builder: (_) => PaperPreviewPage(paperId: paper.scheduleId),
                  //   ));
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preview — coming soon (Task F2)'),
                      duration: Duration(seconds: 2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _PhaseChip
// =============================================================================

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.phase,
    required this.generated,
    required this.total,
  });

  final PaperGenerationPhase phase;
  final int generated;
  final int total;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case PaperGenerationPhase.pending:
        return Chip(
          backgroundColor: Colors.grey.shade200,
          label: const Text(
            'Scheduled',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

      case PaperGenerationPhase.generating:
        return Chip(
          backgroundColor: Colors.amber.shade100,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.amber.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$generated/$total',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

      case PaperGenerationPhase.complete:
        return Chip(
          backgroundColor: Colors.green.shade100,
          label: Text(
            'Ready',
            style: TextStyle(fontSize: 12, color: Colors.green.shade800),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

      case PaperGenerationPhase.failed:
        return Chip(
          backgroundColor: Colors.red.shade100,
          label: Text(
            'Failed',
            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    }
  }
}
