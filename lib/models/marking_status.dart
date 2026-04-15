import '../proto/services/question_bank.pb.dart' as pb;
import '../proto/services/question_bank.pbenum.dart' as pbenum;

/// Status of an AI marking job.
enum MarkingPhase { queued, downloading, marking, computing, complete, failed }

class MarkingStatus {
  final MarkingPhase phase;
  final int progressCurrent;
  final int progressTotal;
  final String? errorMessage;
  const MarkingStatus({
    required this.phase,
    required this.progressCurrent,
    required this.progressTotal,
    this.errorMessage,
  });

  double get progressFraction =>
      progressTotal > 0 ? progressCurrent / progressTotal : 0.0;

  String get displayLabel => switch (phase) {
    MarkingPhase.queued => 'Queued',
    MarkingPhase.downloading => 'Downloading images...',
    MarkingPhase.marking =>
      'Marking ($progressCurrent/$progressTotal students)...',
    MarkingPhase.computing => 'Computing results...',
    MarkingPhase.complete => 'Complete',
    MarkingPhase.failed => 'Failed: ${errorMessage ?? "Unknown error"}',
  };

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
      phase: _phaseFromProto(proto.phase),
      progressCurrent: current,
      progressTotal: total,
      errorMessage: proto.hasError() ? proto.error : null,
    );
  }
}

MarkingPhase _phaseFromProto(pbenum.MarkingPhase phase) => switch (phase) {
  pbenum.MarkingPhase.QUEUED => MarkingPhase.queued,
  pbenum.MarkingPhase.DOWNLOADING => MarkingPhase.downloading,
  pbenum.MarkingPhase.CACHING => MarkingPhase.downloading,
  pbenum.MarkingPhase.MARKING => MarkingPhase.marking,
  pbenum.MarkingPhase.AGGREGATING => MarkingPhase.computing,
  pbenum.MarkingPhase.COMPLETE => MarkingPhase.complete,
  pbenum.MarkingPhase.FAILED => MarkingPhase.failed,
  _ => MarkingPhase.failed,
};
