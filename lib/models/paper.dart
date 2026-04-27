import 'event.dart' show PaperGenerationPhase;

/// A per-student generated paper entry, from GetStudentPapersStatus RPC.
class StudentPaperEntry {
  final String studentId;
  final String studentName;
  final String admNo;
  final bool isReady;
  final bool isFailed;
  final String? pdfUrl; // null until generation completes
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
