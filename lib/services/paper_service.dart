import 'package:grpc/grpc.dart';

import '../models/event.dart';
import '../models/paper.dart';
import '../models/result.dart';
import '../proto/services/event.pb.dart' as eventpb;
import '../proto/services/event.pbgrpc.dart' as eventgrpc;
import '../proto/services/paper.pb.dart' as paperpb;
import '../proto/services/paper.pbgrpc.dart' as papergrpc;
import '../proto/services/paper_management.pb.dart' as mgmtpb;
import '../proto/services/paper_management.pbgrpc.dart' as mgmtgrpc;

/// A topic with its current taught status.
/// Returned by [PaperService.getTaughtTopics].
///
/// NOTE: The proto does NOT carry a topic name — only [topicId], [status], and
/// [taughtDate]. Callers must join against the local `topics` Drift table to
/// obtain the human-readable name.
class TaughtTopic {
  final int topicId;

  /// 0 = not_started, 1 = in_progress, 2 = completed.
  final int status;

  /// Non-null when [status] == 2 (completed). Derived from `taughtDate` days
  /// since epoch field in the proto.
  final DateTime? taughtDate;

  const TaughtTopic({
    required this.topicId,
    required this.status,
    this.taughtDate,
  });
}

/// Service wrapping the exam lifecycle gRPC services.
///
/// Uses three underlying gRPC clients:
/// - [eventgrpc.EventServiceClient] — event CRUD.
/// - [papergrpc.PaperServiceClient] — paper creation.
/// - [mgmtgrpc.PaperManagementClient] — scheduling, coverage, generation,
///   per-student paper status and PDF retrieval.
class PaperService {
  PaperService({required ClientChannel channel}) : _channel = channel;

  final ClientChannel _channel;

  // Clients are created per-call (stateless, safe — gRPC channel is reused).
  eventgrpc.EventServiceClient get _eventClient =>
      eventgrpc.EventServiceClient(_channel);

  papergrpc.PaperServiceClient get _paperClient =>
      papergrpc.PaperServiceClient(_channel);

  mgmtgrpc.PaperManagementClient get _mgmtClient =>
      mgmtgrpc.PaperManagementClient(_channel);

  CallOptions _opts(String token) => CallOptions(
    metadata: {'authorization': 'Bearer $token'},
    timeout: const Duration(seconds: 30),
  );

  // ---------------------------------------------------------------------------
  // Event lifecycle
  // ---------------------------------------------------------------------------

  /// Create an exam event. Returns the new event ID on success.
  ///
  /// [type] is an int enum: 0 = exam, 1 = mock, 2 = holiday_revision.
  /// [startDate] and [endDate] are converted to days-since-epoch (int).
  Future<Result<String, GrpcError>> createEvent({
    required String school,
    required String name,
    required int type,
    required int term,
    required int year,
    required DateTime startDate,
    required DateTime endDate,
    required String accessToken,
  }) async {
    try {
      final req = eventpb.CreateEventRequest()
        ..school = school
        ..name = name
        ..type = type
        ..term = term
        ..year = year
        ..startDate = startDate.millisecondsSinceEpoch ~/ 86400000
        ..endDate = endDate.millisecondsSinceEpoch ~/ 86400000;
      final resp = await _eventClient.createEvent(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.event.id);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('createEvent failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Paper creation
  // ---------------------------------------------------------------------------

  /// Create an exam paper within an event. Returns the new paper ID.
  ///
  /// [stream] = 0 means "all streams for this grade" (omit for un-streamed
  /// schools). [topicWeights] maps topic IDs to mark allocations; [weight] is
  /// stored as a `double` in the proto (marks as a float, e.g. 10.0).
  Future<Result<String, GrpcError>> createPaper({
    required String school,
    required String eventId,
    required int subject,
    required int grade,
    int stream = 0,
    required int type,
    required String name,
    required int totalMarks,
    required int durationMinutes,
    required DateTime date,
    int generationMode = 0,
    String instructions = '',
    List<({int topicId, int marks})> topicWeights = const [],
    required String accessToken,
  }) async {
    try {
      final req = paperpb.CreatePaperRequest()
        ..school = school
        ..subject = subject
        ..grade = grade
        ..stream = stream
        ..type = type
        ..name = name
        ..totalMarks = totalMarks
        ..durationMinutes = durationMinutes
        ..date = date.millisecondsSinceEpoch ~/ 86400000
        ..generationMode = generationMode
        ..instructions = instructions;
      if (eventId.isNotEmpty) {
        req.event = eventId;
      }
      for (final w in topicWeights) {
        req.topicWeights.add(
          paperpb.PaperTopicWeight()
            ..topicId = w.topicId
            ..weight = w.marks.toDouble(),
        );
      }
      final resp = await _paperClient.createPaper(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.paper.id);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('createPaper failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  /// Schedule a paper within an event (sets exam date/time/invigilator).
  /// Returns the new schedule ID.
  ///
  /// [stream] = 0 means "all streams". [startMinutes] and [endMinutes] are
  /// minutes since midnight. [invigilatorId] is the user UUID; omit to leave
  /// the invigilator unassigned.
  Future<Result<String, GrpcError>> schedulePaper({
    required String eventId,
    required int subject,
    required int grade,
    int stream = 0,
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
    String? invigilatorId,
    required String accessToken,
  }) async {
    try {
      final durationMinutes = endMinutes - startMinutes;
      final req = mgmtpb.SchedulePaperRequest()
        ..eventId = eventId
        ..subject = subject
        ..grade = grade
        ..stream = stream
        ..date = date.millisecondsSinceEpoch ~/ 86400000
        ..startTime = startMinutes
        ..endTime = endMinutes
        ..durationMinutes = durationMinutes;
      if (invigilatorId != null) req.invigilator = invigilatorId;
      final resp = await _mgmtClient.schedulePaper(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.scheduleId);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('schedulePaper failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Topic coverage
  // ---------------------------------------------------------------------------

  /// Fetch taught-topic statuses for a subject+grade (optionally per-stream).
  ///
  /// Returns only [topicId], [status], and [taughtDate] — the topic name is
  /// NOT present in the proto. Callers must join against the local `topics`
  /// Drift table to resolve display names.
  Future<Result<List<TaughtTopic>, GrpcError>> getTaughtTopics({
    required String school,
    required int subject,
    required int grade,
    int stream = 0,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.GetTaughtTopicsRequest()
        ..school = school
        ..subject = subject
        ..grade = grade
        ..stream = stream;
      final resp = await _mgmtClient.getTaughtTopics(
        req,
        options: _opts(accessToken),
      );
      final topics = resp.topics
          .map(
            (t) => TaughtTopic(
              topicId: t.topicId,
              status: t.status,
              taughtDate: t.taughtDate > 0
                  ? DateTime.fromMillisecondsSinceEpoch(t.taughtDate * 86400000)
                  : null,
            ),
          )
          .toList();
      return Ok(topics);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('getTaughtTopics failed: $e'));
    }
  }

  /// Update taught status for a list of topics in one call.
  ///
  /// Each update record carries [topicId] and [status]
  /// (0 = not_started, 1 = in_progress, 2 = completed).
  Future<Result<void, GrpcError>> setTaughtTopics({
    required String school,
    required int subject,
    required int grade,
    required int stream,
    required List<({int topicId, int status})> updates,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.SetTaughtTopicsRequest()
        ..school = school
        ..subject = subject
        ..grade = grade
        ..stream = stream;
      for (final u in updates) {
        req.topics.add(
          mgmtpb.TaughtTopicProto()
            ..topicId = u.topicId
            ..status = u.status,
        );
      }
      await _mgmtClient.setTaughtTopics(req, options: _opts(accessToken));
      return Ok(null);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('setTaughtTopics failed: $e'));
    }
  }

  /// Confirm the syllabus topic coverage for a scheduled paper.
  /// Returns the number of topics confirmed.
  Future<Result<int, GrpcError>> confirmExamCoverage({
    required String scheduleId,
    required List<int> topicIds,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.ConfirmExamCoverageRequest()
        ..scheduleId = scheduleId
        ..topicIds.addAll(topicIds);
      final resp = await _mgmtClient.confirmExamCoverage(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.topicsConfirmed);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('confirmExamCoverage failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Generation
  // ---------------------------------------------------------------------------

  /// Trigger assessment (exam paper) generation for an already-created paper.
  /// The paper must have been created via [createPaper] first.
  /// Returns `true` if the server accepted the generation request.
  Future<Result<bool, GrpcError>> generateAssessment({
    required String paperId,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.GenerateAssessmentRequest()..paperId = paperId;
      final resp = await _mgmtClient.generateAssessment(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.accepted);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('generateAssessment failed: $e'));
    }
  }

  /// Trigger assignment generation for an already-created paper.
  /// Returns `true` if the server accepted the generation request.
  Future<Result<bool, GrpcError>> generateAssignment({
    required String paperId,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.GenerateAssignmentRequest()..paperId = paperId;
      final resp = await _mgmtClient.generateAssignment(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.accepted);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('generateAssignment failed: $e'));
    }
  }

  /// Trigger per-student paper finalization (PDF generation) for all enrolled
  /// students on this paper. Returns the job ID for status polling.
  Future<Result<String, GrpcError>> finalizeStudentPapers({
    required String paperId,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.FinalizeStudentPapersRequest()..paperId = paperId;
      final resp = await _mgmtClient.finalizeStudentPapers(
        req,
        options: _opts(accessToken),
      );
      return Ok(resp.jobId);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('finalizeStudentPapers failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Per-student paper status & retrieval
  // ---------------------------------------------------------------------------

  /// Poll generation progress for all students on a paper.
  ///
  /// NOTE: [StudentPaperEntry.studentId] will be the string representation of
  /// the integer DB student ID (from `StudentPdfStatus.student` int field).
  /// [studentName] and [admNo] are empty — the caller must join against the
  /// local `students` Drift table to populate those fields.
  Future<Result<StudentPapersStatus, GrpcError>> getStudentPapersStatus({
    required String paperId,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.GetStudentPapersStatusRequest()..paperId = paperId;
      final resp = await _mgmtClient.getStudentPapersStatus(
        req,
        options: _opts(accessToken),
      );
      final phase = resp.complete
          ? PaperGenerationPhase.complete
          : PaperGenerationPhase.generating;
      final students = resp.statuses
          .map(
            (s) => StudentPaperEntry(
              // proto student field is an int (DB student ID) — convert to
              // String for model compatibility.
              studentId: s.student.toString(),
              studentName: '', // not in proto — join from local DB
              admNo: '', // not in proto — join from local DB
              isReady: s.generated,
              isFailed: s.error.isNotEmpty,
            ),
          )
          .toList();
      return Ok(
        StudentPapersStatus(
          phase: phase,
          total: resp.total,
          generated: resp.generated,
          students: students,
        ),
      );
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('getStudentPapersStatus failed: $e'));
    }
  }

  /// Get the presigned PDF URL for a specific student's generated paper.
  ///
  /// [studentId] must be the string representation of the integer DB student
  /// ID (as returned in [StudentPaperEntry.studentId] from
  /// [getStudentPapersStatus]).
  ///
  /// NOTE: [StudentPaperPdf.studentName] and [StudentPaperPdf.admNo] will be
  /// empty — the caller must join against the local `students` Drift table.
  Future<Result<StudentPaperPdf, GrpcError>> getStudentPaperPdf({
    required String paperId,
    required String studentId,
    required String accessToken,
  }) async {
    try {
      final req = mgmtpb.GetStudentPaperPdfRequest()
        ..paperId = paperId
        ..student = int.parse(studentId);
      final resp = await _mgmtClient.getStudentPaperPdf(
        req,
        options: _opts(accessToken),
      );
      return Ok(
        StudentPaperPdf(
          pdfUrl: resp.pdfUrl,
          // expiry is Int64 ms-since-epoch
          expiry: DateTime.fromMillisecondsSinceEpoch(resp.expiry.toInt()),
          studentName: '', // not in proto — join from local DB
          admNo: '', // not in proto — join from local DB
        ),
      );
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(GrpcError.internal('getStudentPaperPdf failed: $e'));
    }
  }
}
