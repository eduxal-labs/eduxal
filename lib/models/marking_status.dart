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

  factory MarkingStatus.fromProto(pb.MarkingStatusResponse proto) =>
      MarkingStatus(
        phase: _phaseFromProto(proto.status),
        progressCurrent: proto.progressCurrent,
        progressTotal: proto.progressTotal,
        errorMessage: proto.hasErrorMessage() ? proto.errorMessage : null,
      );
}

MarkingPhase _phaseFromProto(pbenum.MarkingStatusEnum status) =>
    switch (status) {
      pbenum.MarkingStatusEnum.QUEUED => MarkingPhase.queued,
      pbenum.MarkingStatusEnum.DOWNLOADING => MarkingPhase.downloading,
      pbenum.MarkingStatusEnum.MARKING => MarkingPhase.marking,
      pbenum.MarkingStatusEnum.COMPUTING => MarkingPhase.computing,
      pbenum.MarkingStatusEnum.COMPLETE => MarkingPhase.complete,
      pbenum.MarkingStatusEnum.FAILED => MarkingPhase.failed,
      _ => MarkingPhase.failed,
    };
