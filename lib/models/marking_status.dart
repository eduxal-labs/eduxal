import '../proto/services/question_bank.pb.dart' as pb;

/// Status of an AI marking job.
enum MarkingPhase { queued, downloading, marking, computing, complete, failed }

class MarkingStatus {
  final MarkingPhase phase;
  final int progressCurrent;
  final int progressTotal;
  final String? errorMessage;
  final String progressText;
  const MarkingStatus({
    required this.phase,
    required this.progressCurrent,
    required this.progressTotal,
    this.errorMessage,
    this.progressText = '',
  });

  double get progressFraction =>
      progressTotal > 0 ? progressCurrent / progressTotal : 0.0;

  String get displayLabel {
    if (progressText.isNotEmpty) return progressText;
    return switch (phase) {
      MarkingPhase.queued => 'Queued',
      MarkingPhase.downloading => 'Downloading images...',
      MarkingPhase.marking =>
        'Marking ($progressCurrent/$progressTotal students)...',
      MarkingPhase.computing => 'Computing results...',
      MarkingPhase.complete => 'Complete',
      MarkingPhase.failed => 'Failed: ${errorMessage ?? "Unknown error"}',
    };
  }

  factory MarkingStatus.fromProto(pb.MarkingStatusResponse proto) {
    int current = 0;
    int total = 0;
    if (proto.hasProgress()) {
      final parts = proto.progress.split('/');
      if (parts.length == 2) {
        current = int.tryParse(parts[0]) ?? 0;
        total = int.tryParse(parts[1]) ?? 0;
      }
    }
    return MarkingStatus(
      phase: phaseFromInt(proto.phase),
      progressCurrent: current,
      progressTotal: total,
      errorMessage: proto.hasError() ? proto.error : null,
    );
  }
}

/// Maps the raw proto integer phase value to [MarkingPhase].
/// Proto3 enum values: 0=QUEUED 1=DOWNLOADING 2=CACHING 3=MARKING
///                     4=AGGREGATING 5=COMPLETE 6=FAILED
MarkingPhase phaseFromInt(int phase) => switch (phase) {
  0 => MarkingPhase.queued,
  1 => MarkingPhase.downloading,
  2 => MarkingPhase.downloading, // CACHING → downloading (same UI state)
  3 => MarkingPhase.marking,
  4 => MarkingPhase.computing, // AGGREGATING → computing
  5 => MarkingPhase.complete,
  6 => MarkingPhase.failed,
  _ => MarkingPhase.failed,
};
