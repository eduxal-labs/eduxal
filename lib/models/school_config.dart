import '../database/database.dart';
import '../database/tables/curriculum_subjects.dart';

// ============================================================
// Grade Stream — a named stream within a grade
// ============================================================

/// A stream within a grade — [name] is the display label, [code] is the
/// integer stored in enrollments.stream / attendance.stream / etc.
class GradeStream {
  const GradeStream({required this.name, required this.code});

  final String name; // e.g. "Green", "Blue", "A", "North"
  final int code; // e.g. 1, 2, 3 — the smallint stored in the DB

  factory GradeStream.fromJson(Map<String, dynamic> j) =>
      GradeStream(name: j['name'] as String, code: (j['code'] as num).toInt());

  Map<String, dynamic> toJson() => {'name': name, 'code': code};

  GradeStream copyWith({String? name, int? code}) =>
      GradeStream(name: name ?? this.name, code: code ?? this.code);
}

// ============================================================
// Grade Config — one grade with its stream definitions
// ============================================================

/// One grade within a curriculum that the school has enabled, together with
/// its stream definitions.
class GradeConfig {
  const GradeConfig({required this.grade, required this.streams});

  final int grade; // DB grade integer — see grade numbering in kCbcGradeLabels
  final List<GradeStream> streams; // ordered by code ascending

  factory GradeConfig.fromJson(Map<String, dynamic> j) => GradeConfig(
    grade: (j['grade'] as num).toInt(),
    streams: (j['streams'] as List<dynamic>? ?? [])
        .map((e) => GradeStream.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'grade': grade,
    'streams': streams.map((s) => s.toJson()).toList(),
  };

  GradeConfig copyWith({int? grade, List<GradeStream>? streams}) =>
      GradeConfig(grade: grade ?? this.grade, streams: streams ?? this.streams);
}

// ============================================================
// Curriculum Config — one curriculum entry inside SchoolConfig
// ============================================================

/// One curriculum entry inside [SchoolConfig].
class CurriculumConfig {
  const CurriculumConfig({required this.type, required this.grades});

  final CurriculumType type; // CurriculumType.cbc or .eightFourFour
  final List<GradeConfig> grades; // sorted by grade ascending

  factory CurriculumConfig.fromJson(Map<String, dynamic> j) {
    final rawType = (j['type'] as num).toInt();
    final type = CurriculumType.values.firstWhere(
      (e) => e.index_ == rawType,
      orElse: () => CurriculumType.cbc,
    );
    return CurriculumConfig(
      type: type,
      grades: (j['grades'] as List<dynamic>? ?? [])
          .map((e) => GradeConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.index_,
    'grades': grades.map((g) => g.toJson()).toList(),
  };

  CurriculumConfig copyWith({
    CurriculumType? type,
    List<GradeConfig>? grades,
  }) =>
      CurriculumConfig(type: type ?? this.type, grades: grades ?? this.grades);
}

// ============================================================
// SchoolConfig — top-level settings config (version 2)
// ============================================================

/// Top-level settings config stored in settings.data JSON.
///
/// A school may enable both curricula simultaneously.
///
/// JSON shape (version 2):
/// ```json
/// {
///   "version": 2,
///   "curricula": [
///     {
///       "type": 0,
///       "grades": [
///         {
///           "grade": 3,
///           "streams": [
///             {"name": "Green", "code": 1},
///             {"name": "Blue",  "code": 2}
///           ]
///         }
///       ]
///     }
///   ]
/// }
/// ```
class SchoolConfig {
  const SchoolConfig({required this.curricula});

  final List<CurriculumConfig> curricula;

  bool get isEmpty => curricula.isEmpty;

  bool get hasCbc => curricula.any((c) => c.type == CurriculumType.cbc);

  bool get has844 =>
      curricula.any((c) => c.type == CurriculumType.eightFourFour);

  CurriculumConfig? configFor(CurriculumType type) =>
      curricula.where((c) => c.type == type).firstOrNull;

  /// Empty config — no curricula enabled.
  factory SchoolConfig.defaults() => const SchoolConfig(curricula: []);

  factory SchoolConfig.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version < 2) {
      // Discard legacy v1 config — it used a different shape.
      return SchoolConfig.defaults();
    }
    return SchoolConfig(
      curricula: (json['curricula'] as List<dynamic>? ?? [])
          .map((e) => CurriculumConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'curricula': curricula.map((c) => c.toJson()).toList(),
  };

  SchoolConfig copyWith({List<CurriculumConfig>? curricula}) =>
      SchoolConfig(curricula: curricula ?? this.curricula);
}

// ============================================================
// Grade numbering maps
// ============================================================

/// CBC grade number → display label.
///
/// PP1=1, PP2=2, Grade 1–9 = 3–11, Grade 10–12 = 12–14.
const Map<int, String> kCbcGradeLabels = {
  1: 'PP1',
  2: 'PP2',
  3: 'Grade 1',
  4: 'Grade 2',
  5: 'Grade 3',
  6: 'Grade 4',
  7: 'Grade 5',
  8: 'Grade 6',
  9: 'Grade 7',
  10: 'Grade 8',
  11: 'Grade 9',
  12: 'Grade 10',
  13: 'Grade 11',
  14: 'Grade 12',
};

/// 8-4-4 grade number → display label.
///
/// Standard 1–8 = 1–8, Form 1–4 = 41–44.
const Map<int, String> kEightFourFourGradeLabels = {
  1: 'Standard 1',
  2: 'Standard 2',
  3: 'Standard 3',
  4: 'Standard 4',
  5: 'Standard 5',
  6: 'Standard 6',
  7: 'Standard 7',
  8: 'Standard 8',
  41: 'Form 1',
  42: 'Form 2',
  43: 'Form 3',
  44: 'Form 4',
};

/// Returns the grade label map for [type].
Map<int, String> gradeLabelsFor(CurriculumType type) =>
    type == CurriculumType.cbc ? kCbcGradeLabels : kEightFourFourGradeLabels;

// ============================================================
// Shared curriculum-detection helpers
// ============================================================

/// Determines the [CurriculumType] for a given grade number.
///
/// Grades ≥ 41 (Form 1–4) are unambiguously 8-4-4.
/// Grades ≥ 9 (Grade 9–12) are unambiguously CBC.
/// Grades 1–8 are ambiguous — resolved by checking [allGrades] for any
/// 8-4-4-only grades (≥ 41). If none exist (or [allGrades] is empty),
/// defaults to CBC.
CurriculumType curriculumForGrade(int grade, {Set<int> allGrades = const {}}) {
  if (grade >= 41) return CurriculumType.eightFourFour;
  if (grade >= 9) return CurriculumType.cbc;
  if (allGrades.any((g) => g >= 41)) return CurriculumType.eightFourFour;
  return CurriculumType.cbc;
}

/// Builds a [SchoolConfig] from raw [SchoolStream] rows using the
/// curriculum-detection heuristic in [curriculumForGrade].
SchoolConfig buildConfigFromStreams(List<SchoolStream> allStreams) {
  if (allStreams.isEmpty) return SchoolConfig.defaults();

  final allGrades = allStreams.map((s) => s.grade).toSet();
  final byGrade = <int, List<SchoolStream>>{};
  for (final s in allStreams) {
    byGrade.putIfAbsent(s.grade, () => []).add(s);
  }

  final cbcGrades = <GradeConfig>[];
  final eftGrades = <GradeConfig>[];

  for (final entry in byGrade.entries) {
    final gradeNum = entry.key;
    final streamRows = entry.value
      ..sort((a, b) => a.stream.compareTo(b.stream));
    final gradeStreams = streamRows
        .map((s) => GradeStream(name: s.name, code: s.stream))
        .toList();
    final gc = GradeConfig(grade: gradeNum, streams: gradeStreams);
    if (curriculumForGrade(gradeNum, allGrades: allGrades) ==
        CurriculumType.cbc) {
      cbcGrades.add(gc);
    } else {
      eftGrades.add(gc);
    }
  }

  cbcGrades.sort((a, b) => a.grade.compareTo(b.grade));
  eftGrades.sort((a, b) => a.grade.compareTo(b.grade));

  final curricula = <CurriculumConfig>[];
  if (cbcGrades.isNotEmpty) {
    curricula.add(
      CurriculumConfig(type: CurriculumType.cbc, grades: cbcGrades),
    );
  }
  if (eftGrades.isNotEmpty) {
    curricula.add(
      CurriculumConfig(type: CurriculumType.eightFourFour, grades: eftGrades),
    );
  }

  return SchoolConfig(curricula: curricula);
}
