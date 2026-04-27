import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../models/result.dart';
import '../../../../services/paper_service.dart';
import '../../../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _TopicRow {
  _TopicRow({
    required this.topicId,
    required this.topicName,
    required this.status,
    this.taughtDate,
  });

  final int topicId;
  final String topicName;
  int status; // 0=not_started, 1=in_progress, 2=completed
  DateTime? taughtDate;
  bool saving = false;
}

// ---------------------------------------------------------------------------
// Page widget
// ---------------------------------------------------------------------------

class TaughtTopicsPage extends StatefulWidget {
  const TaughtTopicsPage({
    super.key,
    required this.schoolId,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    this.streams = const [],
  });

  final String schoolId;
  final int subjectId;
  final String subjectName;
  final int grade;

  /// Stream codes this teacher covers. If length > 1, a stream selector is
  /// shown. Empty or length == 1 means no selector; stream=0 is used for all
  /// API calls.
  final List<int> streams;

  @override
  State<TaughtTopicsPage> createState() => _TaughtTopicsPageState();
}

class _TaughtTopicsPageState extends State<TaughtTopicsPage> {
  int? _selectedStream; // null → "All streams" (stream=0 in API)
  bool _loading = false;
  String? _error;
  List<_TopicRow> _topics = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Load topic names from local DB (filtered by subject + grade).
      final dbTopics = await db.catalogDao
          .watchTopicsBySubjectAndGrade(
            subjectId: widget.subjectId,
            grade: widget.grade,
          )
          .first;

      // 2. Fetch taught statuses from the server.
      final result = await paperService.getTaughtTopics(
        school: widget.schoolId,
        subject: widget.subjectId,
        grade: widget.grade,
        stream: _selectedStream ?? 0,
        accessToken: accessToken,
      );

      if (!mounted) return;

      switch (result) {
        case Ok(:final value):
          // 3. Merge: map topicId → TaughtTopic for O(1) lookup.
          final statusMap = <int, TaughtTopic>{
            for (final t in value) t.topicId: t,
          };

          final rows = dbTopics.map((t) {
            final taught = statusMap[t.id];
            return _TopicRow(
              topicId: t.id,
              topicName: t.name,
              status: taught?.status ?? 0,
              taughtDate: taught?.taughtDate,
            );
          }).toList();

          setState(() {
            _topics = rows;
            _loading = false;
          });

        case Err(:final error):
          setState(() {
            _error = error.message ?? 'Failed to load topics';
            _loading = false;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Status cycling
  // -------------------------------------------------------------------------

  Future<void> _cycleStatus(int topicId) async {
    final idx = _topics.indexWhere((t) => t.topicId == topicId);
    if (idx == -1) return;

    final row = _topics[idx];
    if (row.saving) return;

    final previousStatus = row.status;
    final previousDate = row.taughtDate;
    final newStatus = (previousStatus + 1) % 3;

    // Optimistic UI update.
    setState(() {
      row.status = newStatus;
      row.saving = true;
      if (newStatus != 2) row.taughtDate = null;
    });

    final result = await paperService.setTaughtTopics(
      school: widget.schoolId,
      subject: widget.subjectId,
      grade: widget.grade,
      stream: _selectedStream ?? 0,
      updates: [(topicId: topicId, status: newStatus)],
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        setState(() {
          row.saving = false;
          if (newStatus == 2) {
            row.taughtDate = DateTime.now();
          }
        });

      case Err(:final error):
        // Revert optimistic update on error.
        setState(() {
          row.status = previousStatus;
          row.taughtDate = previousDate;
          row.saving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message ?? 'Failed to update topic status'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text('${widget.subjectName} — Grade ${widget.grade} Topics'),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stream selector — only when teacher covers multiple streams.
          if (widget.streams.length > 1)
            _StreamSelector(
              streams: widget.streams,
              selected: _selectedStream,
              cs: cs,
              isDark: isDark,
              onChanged: (val) {
                setState(() => _selectedStream = val);
                _load();
              },
            ),
          Expanded(child: _buildBody(cs, isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: cs.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No topics found for this subject and grade.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _topics.length,
      separatorBuilder: (_, __) => AppTheme.tableRowDivider(isDark, cs),
      itemBuilder: (context, index) {
        final row = _topics[index];
        return _TopicTile(
          index: index,
          row: row,
          onCycle: () => _cycleStatus(row.topicId),
          formatDate: _formatDate,
          cs: cs,
          isDark: isDark,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stream selector
// ---------------------------------------------------------------------------

class _StreamSelector extends StatelessWidget {
  const _StreamSelector({
    required this.streams,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final List<int> streams;
  final int? selected;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.nestedBg(isDark, cs),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SegmentedButton<int?>(
        segments: [
          const ButtonSegment<int?>(value: null, label: Text('All')),
          ...streams.map(
            (code) =>
                ButtonSegment<int?>(value: code, label: Text('Stream $code')),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (set) => onChanged(set.first),
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topic tile
// ---------------------------------------------------------------------------

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.index,
    required this.row,
    required this.onCycle,
    required this.formatDate,
    required this.cs,
    required this.isDark,
  });

  final int index;
  final _TopicRow row;
  final VoidCallback onCycle;
  final String Function(DateTime) formatDate;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.primary,
          ),
        ),
      ),
      title: Text(
        row.topicName,
        style: const TextStyle(fontWeight: FontWeight.w400),
      ),
      subtitle: row.status == 2 && row.taughtDate != null
          ? Text(
              'Covered ${formatDate(row.taughtDate!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            )
          : null,
      trailing: row.saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          : _StatusChip(status: row.status, onTap: onCycle),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip — tap to cycle through the three statuses
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.onTap});

  final int status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      1 => ('In progress', const Color(0xFFB45309)), // amber-700
      2 => ('Completed ✓', const Color(0xFF16A34A)), // green-600
      _ => ('Not started', const Color(0xFF6B7280)), // grey-500
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
