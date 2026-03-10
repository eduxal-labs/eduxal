import 'dart:convert';
import 'dart:math';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart' show GeneratedMessage;

import '../database/database.dart';
import '../database/tables/enums.dart';
import '../database/tables/curriculum_subjects.dart';
import '../models/school_config.dart';
import '../proto/services/sync.pb.dart' as sync_pb;

// ============================================================
// Seeder — populates the local database with realistic demo data
// ============================================================

class Seeder {
  /// Seeds the first school (Mwangaza Academy). Skips if any schools exist.
  /// Returns true if seeding was performed, false if data already exists.
  static Future<bool> seed(AppDatabase database, String userId) async {
    final existing = await database.schools.select().get();
    if (existing.isNotEmpty) return false;

    final s = _SeederImpl(database, userId, _kMwangazaProfile, 42);
    await s.run();
    return true;
  }

  /// Seeds an additional school. Always runs (no guard).
  /// [index] selects the school profile: 0 = Mwangaza, 1 = Taaluma, etc.
  /// Returns true if seeding was performed.
  static Future<bool> seedAdditional(
    AppDatabase database,
    String userId, [
    int index = 1,
  ]) async {
    final profile = _kProfiles[index % _kProfiles.length];
    // Use a different random seed per profile so data varies
    final s = _SeederImpl(database, userId, profile, 42 + index * 1000);
    await s.run();
    return true;
  }

  /// Deletes ALL data except the accounts table and the logged-in user's
  /// row in `users`, then seeds both schools inside a single transaction.
  static Future<void> clearAndSeed(AppDatabase database, String userId) async {
    // Everything in ONE transaction to avoid "database is locked" errors
    // from the background-isolate executor contending with reactive streams.
    await database.transaction(() async {
      // ── 1. Delete in reverse-dependency order ──────────────────────
      // The current user's `users` row is preserved because `accounts`
      // references it with ON DELETE CASCADE — deleting it would wipe
      // the active session and log the user out.
      await database.delete(database.mastery).go();
      await database.delete(database.aiUsage).go();
      await database.delete(database.grades).go();
      await database.delete(database.papers).go();
      await database.delete(database.lessons).go();
      await database.delete(database.timetable).go();
      await database.delete(database.attendance).go();
      await database.delete(database.payments).go();
      await database.delete(database.invoices).go();
      await database.delete(database.fees).go();
      await database.delete(database.subjects).go();
      await database.delete(database.enrollments).go();
      await database.delete(database.classTeachers).go();
      await database.delete(database.announcements).go();
      await database.delete(database.subscriptions).go();
      await database.delete(database.discounts).go();
      await database.delete(database.scopes).go();
      await database.delete(database.roles).go();
      await database.delete(database.guardians).go();
      await database.delete(database.students).go();
      await database.delete(database.staff).go();
      await database.delete(database.teachers).go();
      await database.delete(database.owners).go();
      await database.delete(database.departments).go();
      await database.delete(database.terms).go();
      await database.delete(database.settings).go();
      await database.delete(database.plans).go();
      await database.delete(database.exams).go();
      await database.delete(database.schools).go();
      await (database.delete(
        database.users,
      )..where((u) => u.id.equals(userId).not())).go();
      await database.delete(database.logs).go();

      // ── 2. Seed both schools (inline, no nested transaction) ───────
      final s1 = _SeederImpl(database, userId, _kMwangazaProfile, 42);
      await s1.runInline();
      final s2 = _SeederImpl(database, userId, _kTaalumaProfile, 1042);
      await s2.runInline();
    });
  }

  static const _kProfiles = [_kMwangazaProfile, _kTaalumaProfile];
}

// ============================================================
// School profiles
// ============================================================

class _SchoolProfile {
  const _SchoolProfile({
    required this.name,
    required this.motto,
    required this.phone,
    required this.email,
    required this.county,
    required this.domain,
    required this.announcements,
  });
  final String name;
  final String motto;
  final String phone;
  final String email;
  final int county;
  final String domain;
  final List<(String title, String content, int audience, int daysAgo)>
  announcements;
}

const _kMwangazaProfile = _SchoolProfile(
  name: 'Mwangaza Academy',
  motto: 'Excellence Through Knowledge',
  phone: '0722100200',
  email: 'info@mwangazaacademy.sc.ke',
  county: 47, // Nairobi
  domain: 'mwangazaacademy',
  announcements: [
    (
      'Term 2 Opening',
      'Welcome back to Mwangaza Academy for Term 2, 2025. Classes begin on Monday 5th May. All students should report by 7:30 AM in full uniform.',
      0,
      60,
    ),
    (
      'Opening Term Exam Schedule',
      'The Opening Term Examination will be held from 2nd June to 6th June 2025. Timetables have been shared with class teachers. All students must carry their own stationery.',
      0,
      40,
    ),
    (
      'Inter-School Sports Day',
      'Our annual inter-school sports day is scheduled for Saturday 14th June 2025. Students participating in athletics, football, and volleyball should register with the PE department by Friday 6th June.',
      1,
      25,
    ),
    (
      'Parent-Teacher Meeting',
      'We invite all parents and guardians to the mid-term parent-teacher meeting on Saturday 21st June 2025 from 9:00 AM to 1:00 PM. Reports will be issued during the meeting.',
      2,
      15,
    ),
    (
      'Library Hours Extended',
      'The school library will now operate extended hours from 7:00 AM to 5:30 PM on weekdays to support exam preparation. Form 4 and Grade 10-11 students are encouraged to use this resource.',
      0,
      10,
    ),
  ],
);

const _kTaalumaProfile = _SchoolProfile(
  name: 'Taaluma Heights School',
  motto: 'Nurturing Tomorrow\'s Leaders',
  phone: '0733200300',
  email: 'admin@taalumaheights.sc.ke',
  county: 1, // Mombasa
  domain: 'taalumaheights',
  announcements: [
    (
      'Term 2 Opening',
      'Welcome back to Taaluma Heights School for Term 2, 2025. Classes resume Monday 5th May. Report by 7:00 AM in full school uniform. New students should collect their timetables from the admin block.',
      0,
      60,
    ),
    (
      'Mid-Term Examinations',
      'Mid-term examinations will run from 9th June to 13th June 2025. Revision timetables are available from your class teachers. Students are reminded to adhere to the exam code of conduct.',
      0,
      35,
    ),
    (
      'Science Fair 2025',
      'The annual Science & Innovation Fair will be held on Friday 20th June 2025. All Form 3 and Grade 10 students must submit their project proposals to the Science department by 6th June.',
      1,
      28,
    ),
    (
      'Fee Payment Reminder',
      'Parents are reminded that Term 2 fee balances should be cleared by 30th June 2025. M-Pesa payments can be made to paybill 567890. Contact the bursar\'s office for payment plan arrangements.',
      2,
      20,
    ),
    (
      'Co-Curricular Activities',
      'New co-curricular activities for Term 2 include Drama Club (Wednesdays), Debate Society (Thursdays), and Environmental Club (Fridays). Sign-up sheets are posted on the notice board outside the staffroom.',
      0,
      12,
    ),
  ],
);

// ============================================================
// Name pools — realistic Kenyan demographics
// ============================================================

const _kMaleIslamic = [
  'Abdi',
  'Abdalla',
  'Ahmed',
  'Ali',
  'Amin',
  'Amir',
  'Ashraf',
  'Bilal',
  'Daud',
  'Farhan',
  'Farid',
  'Habib',
  'Hamza',
  'Hassan',
  'Hussein',
  'Ibrahim',
  'Idris',
  'Ismail',
  'Jamal',
  'Khalid',
  'Mahad',
  'Mahmud',
  'Mohammed',
  'Musa',
  'Mustafa',
  'Nasir',
  'Omar',
  'Rashid',
  'Sadiq',
  'Salim',
  'Samir',
  'Sharif',
  'Suleiman',
  'Tariq',
  'Yusuf',
  'Zakariya',
];

const _kMaleOther = [
  'Brian',
  'Collins',
  'Daniel',
  'David',
  'Dennis',
  'Edwin',
  'Erick',
  'Felix',
  'George',
  'Gilbert',
  'James',
  'John',
  'Joseph',
  'Julius',
  'Kevin',
  'Kenneth',
  'Leonard',
  'Martin',
  'Moses',
  'Nicholas',
  'Ochieng',
  'Patrick',
  'Peter',
  'Robert',
  'Samuel',
  'Simon',
  'Stephen',
  'Timothy',
  'Victor',
  'Vincent',
  'William',
  'Wesley',
];

const _kFemaleIslamic = [
  'Aisha',
  'Amina',
  'Asma',
  'Dalila',
  'Fatima',
  'Habiba',
  'Hafsa',
  'Halima',
  'Hamida',
  'Hawa',
  'Jamila',
  'Khadija',
  'Layla',
  'Leila',
  'Maimuna',
  'Mariam',
  'Maryam',
  'Nasra',
  'Noor',
  'Rahma',
  'Rukia',
  'Safia',
  'Sakina',
  'Salma',
  'Samira',
  'Shadia',
  'Siti',
  'Suad',
  'Umi',
  'Yasmin',
  'Zahra',
  'Zainab',
  'Zamzam',
  'Zuhura',
];

const _kFemaleOther = [
  'Alice',
  'Ann',
  'Catherine',
  'Christine',
  'Diana',
  'Elizabeth',
  'Esther',
  'Eunice',
  'Faith',
  'Florence',
  'Grace',
  'Hannah',
  'Irene',
  'Janet',
  'Joyce',
  'Lilian',
  'Lucy',
  'Margaret',
  'Mary',
  'Mercy',
  'Nancy',
  'Pauline',
  'Priscilla',
  'Rachel',
  'Rebecca',
  'Rose',
  'Ruth',
  'Sarah',
  'Susan',
  'Tabitha',
  'Vivian',
  'Wanjiku',
  'Wambui',
];

const _kSurnames = [
  'Abdallah',
  'Abdi',
  'Ahmed',
  'Ali',
  'Hassan',
  'Hussein',
  'Ibrahim',
  'Juma',
  'Khalif',
  'Mohammed',
  'Musa',
  'Omar',
  'Osman',
  'Salim',
  'Achieng',
  'Chebet',
  'Kamau',
  'Kariuki',
  'Kemboi',
  'Kimani',
  'Kipchoge',
  'Kiplagat',
  'Korir',
  'Maina',
  'Mbugua',
  'Momanyi',
  'Mugo',
  'Muthoni',
  'Mutua',
  'Mwangi',
  'Ndungu',
  'Njoroge',
  'Nyambura',
  'Odhiambo',
  'Oduor',
  'Onyango',
  'Otieno',
  'Wafula',
  'Wairimu',
  'Wekesa',
];

// ============================================================
// Department names
// ============================================================

const _kDepartments = [
  'Science',
  'Mathematics',
  'Languages',
  'Humanities',
  'Technical',
];

// ============================================================
// Teacher profiles — name, department, role
// ============================================================

class _TeacherProfile {
  const _TeacherProfile(this.department, this.role);
  final String department;
  final String? role;
}

const _kTeacherProfiles = [
  _TeacherProfile('Science', 'Head of Science'),
  _TeacherProfile('Science', null),
  _TeacherProfile('Science', null),
  _TeacherProfile('Mathematics', 'Head of Mathematics'),
  _TeacherProfile('Mathematics', null),
  _TeacherProfile('Languages', 'Head of Languages'),
  _TeacherProfile('Languages', null),
  _TeacherProfile('Languages', null),
  _TeacherProfile('Humanities', 'Head of Humanities'),
  _TeacherProfile('Humanities', null),
  _TeacherProfile('Technical', 'Head of Technical'),
  _TeacherProfile('Technical', null),
];

// ============================================================
// Staff profiles
// ============================================================

const _kStaffRoles = [
  'Bursar',
  'Secretary',
  'Lab Technician',
  'Librarian',
  'Counselor',
];

// ============================================================
// Grade class configuration — which grades get populated with data
// ============================================================

class _GradeClass {
  const _GradeClass({
    required this.grade,
    required this.streamNames,
    required this.studentsPerStream,
    required this.curriculum,
    required this.subjectIndices,
  });
  final int grade;
  final List<String> streamNames; // name at index i => stream code i
  final int studentsPerStream;
  final CurriculumType curriculum;
  final List<int> subjectIndices;
}

// ============================================================
// Implementation
// ============================================================

class _SeederImpl {
  _SeederImpl(this._db, this._userId, this._profile, int randomSeed)
    : _rng = Random(randomSeed);

  final AppDatabase _db;
  final String _userId;
  final _SchoolProfile _profile;
  final Random _rng;

  // IDs generated during seeding, needed for cross-references
  late final String _schoolId;
  final List<String> _teacherUserIds = [];
  final List<String> _staffUserIds = [];
  final List<String> _guardianUserIds = [];
  // Map of (grade, stream) -> list of student adm numbers
  final Map<(int, int), List<int>> _enrolledStudents = {};
  // Map of teacher userId -> assigned subjects (for timetable)
  final Map<String, List<_SubjectAssignment>> _teacherSubjects = {};
  int _nextAdm = 1001; // start admission numbers
  String _roleId = '';

  // Time references
  late final BigInt _nowSec;
  late final BigInt _nowMs;
  late final int _todayDays;

  // ── Dynamic term schedule ──────────────────────────────────────────────
  // Computed once from the current date so seeded data always contains a
  // "current" term that covers today.

  /// The term that contains today — used for enrollments, subjects, timetable,
  /// attendance, exams, fees, invoices, lessons, class teachers, etc.
  late final _TermInfo _currentTerm;

  /// A completed term before the current one — used for historical data.
  late final _TermInfo _previousTerm;

  /// An even older completed term — used for deeper history.
  late final _TermInfo _olderTerm;

  /// Computes a 3-term schedule relative to today based on the Kenyan school
  /// calendar pattern:
  ///   Term 1: ~Jan 6  – Mar 28
  ///   Term 2: ~May 5  – Aug 1
  ///   Term 3: ~Sep 1  – Nov 21
  ///
  /// The "current" term is the one whose date range contains today. If today
  /// falls in a holiday gap, the current term is the upcoming one (so the
  /// seeded data is still valid when school resumes).
  void _computeTermSchedule() {
    final now = DateTime.now();
    final y = now.year;

    // Kenyan term date templates for any year.
    _TermInfo t1(int yr) =>
        _TermInfo(yr, 1, DateTime(yr, 1, 6), DateTime(yr, 3, 28));
    _TermInfo t2(int yr) =>
        _TermInfo(yr, 2, DateTime(yr, 5, 5), DateTime(yr, 8, 1));
    _TermInfo t3(int yr) =>
        _TermInfo(yr, 3, DateTime(yr, 9, 1), DateTime(yr, 11, 21));

    // Build a window of 5 terms spanning last year → this year → next year,
    // then pick the one that contains today (or the nearest upcoming one).
    final candidates = [t3(y - 1), t1(y), t2(y), t3(y), t1(y + 1)];

    // Find the current term: first term whose end >= today and start <= today,
    // or if we're in a gap, the next upcoming term.
    int currentIdx = candidates.indexWhere(
      (t) => !now.isAfter(t.end) && !now.isBefore(t.start),
    );
    if (currentIdx == -1) {
      // In a gap — pick the next term that hasn't ended yet.
      currentIdx = candidates.indexWhere((t) => now.isBefore(t.end));
    }
    if (currentIdx == -1) {
      // Fallback: last term in the list (shouldn't happen).
      currentIdx = candidates.length - 1;
    }

    _currentTerm = candidates[currentIdx];

    // Previous and older terms: walk backwards, generating from prior years
    // if needed.
    if (currentIdx >= 1) {
      _previousTerm = candidates[currentIdx - 1];
    } else {
      // Current is t3(y-1), so previous = t2(y-1)
      _previousTerm = t2(y - 1);
    }

    if (currentIdx >= 2) {
      _olderTerm = candidates[currentIdx - 2];
    } else if (currentIdx == 1) {
      _olderTerm = t3(y - 2);
    } else {
      _olderTerm = t2(y - 1);
    }
  }

  // 8-4-4 KCSE subjects — a realistic set for Forms 3/4
  static const _kcseSubjects = [
    13, // English
    14, // Kiswahili
    15, // Mathematics
    16, // Biology
    17, // Physics
    18, // Chemistry
    19, // History and Government
    20, // Geography
    21, // CRE
    30, // Computer Studies
  ];

  // CBC Lower Primary subjects (Grades 1–3)
  static const _cbcLowerPrimarySubjects = [
    1, // literacy
    2, // kiswahiliLanguage
    3, // englishLanguage
    4, // mathematicsLowerPrimary
    5, // environmentalActivities
    6, // hygieneAndNutrition
    7, // creativeArtsLowerPrimary
    8, // physicalAndHealthEducationLowerPrimary
    9, // religiousEducationCreLowerPrimary
  ];

  // CBC Upper Primary subjects (Grades 4–6)
  static const _cbcUpperPrimarySubjects = [
    14, // englishUpperPrimary
    15, // kiswahiliUpperPrimary
    16, // mathematicsUpperPrimary
    17, // integratedScienceUpperPrimary
    18, // socialStudiesUpperPrimary
    19, // creativeArtsAndCraftUpperPrimary
    20, // physicalAndHealthEducationUpperPrimary
    21, // religiousEducationCreUpperPrimary
    24, // agricultureUpperPrimary
    26, // computerScienceUpperPrimary
  ];

  // CBC Junior Secondary subjects (Grades 7–9)
  static const _cbcJuniorSecondarySubjects = [
    32, // englishJuniorSecondary
    33, // kiswahiliJuniorSecondary
    34, // mathematicsJuniorSecondary
    35, // integratedScienceJuniorSecondary
    36, // healthEducation
    37, // preTechnicalAndPreCareerEducation
    38, // socialStudiesJuniorSecondary
    39, // religiousEducationCreJuniorSecondary
    42, // businessStudiesJuniorSecondary
    43, // agricultureJuniorSecondary
    48, // computerScienceJuniorSecondary
  ];

  // CBC Senior Secondary STEM subjects (core + pathway)
  static const _cbcStemSubjects = [
    55, // English
    56, // Kiswahili
    58, // PE & Sports
    59, // Mathematics (STEM)
    60, // Physics
    61, // Chemistry
    62, // Biology
    63, // Computer Science
    64, // Agriculture
  ];

  // CBC Senior Secondary Social Sciences subjects (core + pathway)
  static const _cbcSocialSubjects = [
    55, // English
    56, // Kiswahili
    58, // PE & Sports
    74, // Mathematics (Social Sciences)
    75, // Geography
    76, // History & Citizenship
    77, // Business Studies
    78, // Economics
    79, // CRE
  ];

  // CBC Senior Secondary Arts & Sports Science subjects (core + pathway)
  static const _cbcArtsSubjects = [
    55, // English
    56, // Kiswahili
    58, // PE & Sports
    90, // generalMathematics
    91, // visualArtsAndDesign
    92, // performingArts
    93, // musicSeniorSecondary
    97, // sportsScienceAndNutrition
    98, // homeScienceSeniorSecondary
  ];

  // The 4 focus grades with demo data
  late final List<_GradeClass> _focusGrades;

  void _initFocusGrades() {
    _focusGrades = [
      // ── 8-4-4: Form 3 & Form 4 only (phasing out 2027) ───────────
      _GradeClass(
        grade: 43,
        streamNames: const ['East', 'West', 'North'],
        studentsPerStream: 23,
        curriculum: CurriculumType.eightFourFour,
        subjectIndices: _kcseSubjects,
      ),
      _GradeClass(
        grade: 44,
        streamNames: const ['East', 'West', 'North'],
        studentsPerStream: 23,
        curriculum: CurriculumType.eightFourFour,
        subjectIndices: _kcseSubjects,
      ),

      // ── CBC Lower Primary (Grades 1–3, level 1) ──────────────────
      _GradeClass(
        grade: 3, // Grade 1
        streamNames: const ['Sunrise', 'Starlight'],
        studentsPerStream: 18,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcLowerPrimarySubjects,
      ),
      _GradeClass(
        grade: 4, // Grade 2
        streamNames: const ['Sunrise', 'Starlight'],
        studentsPerStream: 18,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcLowerPrimarySubjects,
      ),
      _GradeClass(
        grade: 5, // Grade 3
        streamNames: const ['Sunrise', 'Starlight'],
        studentsPerStream: 18,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcLowerPrimarySubjects,
      ),

      // ── CBC Upper Primary (Grades 4–6, level 2) ──────────────────
      _GradeClass(
        grade: 6, // Grade 4
        streamNames: const ['Sunrise', 'Starlight'],
        studentsPerStream: 17,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcUpperPrimarySubjects,
      ),
      _GradeClass(
        grade: 7, // Grade 5
        streamNames: const ['Sunrise', 'Starlight'],
        studentsPerStream: 17,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcUpperPrimarySubjects,
      ),
      _GradeClass(
        grade: 8, // Grade 6
        streamNames: const ['Sunrise', 'Starlight'],
        studentsPerStream: 17,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcUpperPrimarySubjects,
      ),

      // ── CBC Junior Secondary (Grades 7–9, level 3) ───────────────
      _GradeClass(
        grade: 9, // Grade 7
        streamNames: const ['Alpha', 'Beta'],
        studentsPerStream: 15,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcJuniorSecondarySubjects,
      ),
      _GradeClass(
        grade: 10, // Grade 8
        streamNames: const ['Alpha', 'Beta'],
        studentsPerStream: 15,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcJuniorSecondarySubjects,
      ),
      _GradeClass(
        grade: 11, // Grade 9
        streamNames: const ['Alpha', 'Beta'],
        studentsPerStream: 15,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcJuniorSecondarySubjects,
      ),

      // ── CBC Senior Secondary (Grades 10–12, levels 4/5/6) ────────
      _GradeClass(
        grade: 12, // Grade 10 — STEM pathway
        streamNames: const ['Alpha', 'Beta', 'Gamma'],
        studentsPerStream: 12,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcStemSubjects,
      ),
      _GradeClass(
        grade: 13, // Grade 11 — Social Sciences pathway
        streamNames: const ['Alpha', 'Beta'],
        studentsPerStream: 12,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcSocialSubjects,
      ),
      _GradeClass(
        grade: 14, // Grade 12 — Arts & Sports Science pathway
        streamNames: const ['Alpha', 'Beta'],
        studentsPerStream: 12,
        curriculum: CurriculumType.cbc,
        subjectIndices: _cbcArtsSubjects,
      ),
    ];
  }

  /// Runs the full seed wrapped in its own transaction.
  /// Used by [Seeder.seed] and [Seeder.seedAdditional].
  Future<void> run() async {
    _initFocusGrades();
    final now = DateTime.now();
    _nowSec = BigInt.from(now.millisecondsSinceEpoch ~/ 1000);
    _nowMs = BigInt.from(now.millisecondsSinceEpoch);
    _todayDays = now.millisecondsSinceEpoch ~/ 86400000;
    _computeTermSchedule();

    await _db.transaction(() async {
      await _seedAll();
    });
  }

  /// Runs the full seed WITHOUT opening a transaction.
  /// Used when the caller already holds an open transaction
  /// (e.g. [Seeder.clearAndSeed]).
  Future<void> runInline() async {
    _initFocusGrades();
    final now = DateTime.now();
    _nowSec = BigInt.from(now.millisecondsSinceEpoch ~/ 1000);
    _nowMs = BigInt.from(now.millisecondsSinceEpoch);
    _todayDays = now.millisecondsSinceEpoch ~/ 86400000;
    _computeTermSchedule();

    await _seedAll();
  }

  Future<void> _seedAll() async {
    await _seedSchool();
    await _seedSettings();
    await _seedDepartments();
    await _seedTeachers();
    await _seedStaff();
    await _seedOwner();
    await _seedTerms();
    await _seedStudentsAndGuardians();
    await _seedEnrollments();
    await _seedSubjects();
    await _seedClassTeachers();
    await _seedTimetable();
    await _seedAttendance();
    await _seedExamsAndGrades();
    await _seedFees();
    await _seedInvoicesAndPayments();
    await _seedAnnouncements();
    await _seedRolesAndScopes();
    await _seedMastery();
    await _seedLessons();
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _id() => ObjectId().oid;

  String _randomName() {
    final isMale = _rng.nextDouble() < 0.45;
    final useIslamic = _rng.nextDouble() < 0.60;
    final firstName = isMale
        ? (useIslamic
              ? _kMaleIslamic[_rng.nextInt(_kMaleIslamic.length)]
              : _kMaleOther[_rng.nextInt(_kMaleOther.length)])
        : (useIslamic
              ? _kFemaleIslamic[_rng.nextInt(_kFemaleIslamic.length)]
              : _kFemaleOther[_rng.nextInt(_kFemaleOther.length)]);
    final lastName = _kSurnames[_rng.nextInt(_kSurnames.length)];
    return '$firstName $lastName';
  }

  Gender _randomGender() =>
      _rng.nextDouble() < 0.45 ? Gender.male : Gender.female;

  String _randomPhone() =>
      '07${_rng.nextInt(100000000).toString().padLeft(8, '0')}';

  BigInt _pastSec(int daysAgo) => _nowSec - BigInt.from(daysAgo * 86400);

  int _pastDays(int daysAgo) => _todayDays - daysAgo;

  /// A date of birth for a student at the given grade.
  /// Ages are based on the Kenyan education system:
  ///   CBC Grade 1 (index 3) ≈ 6 yrs, Grade 2 (4) ≈ 7, Grade 3 (5) ≈ 8
  ///   CBC Grade 4 (6) ≈ 9, Grade 5 (7) ≈ 10, Grade 6 (8) ≈ 11
  ///   CBC Grade 7 (9) ≈ 13, Grade 8 (10) ≈ 14, Grade 9 (11) ≈ 15
  ///   CBC Grade 10 (12) ≈ 16, Grade 11 (13) ≈ 17, Grade 12 (14) ≈ 18
  ///   8-4-4 Form 3 (43) ≈ 17, Form 4 (44) ≈ 18
  int _studentDob(int grade) {
    final baseAge = switch (grade) {
      3 => 6, // CBC Grade 1
      4 => 7, // CBC Grade 2
      5 => 8, // CBC Grade 3
      6 => 9, // CBC Grade 4
      7 => 10, // CBC Grade 5
      8 => 11, // CBC Grade 6
      9 => 13, // CBC Grade 7
      10 => 14, // CBC Grade 8
      11 => 15, // CBC Grade 9
      12 => 16, // CBC Grade 10
      13 => 17, // CBC Grade 11
      14 => 18, // CBC Grade 12
      43 => 17, // 8-4-4 Form 3
      44 => 18, // 8-4-4 Form 4
      _ => 14,
    };
    final ageVariation = _rng.nextInt(3) - 1; // -1 to +1 year
    final age = baseAge + ageVariation;
    final birthYear = DateTime.now().year - age;
    final birthMonth = _rng.nextInt(12) + 1;
    final birthDay = _rng.nextInt(28) + 1;
    final dt = DateTime(birthYear, birthMonth, birthDay);
    return dt.millisecondsSinceEpoch ~/ 86400000;
  }

  /// Bell-curve score: centered around [mean] with [stddev], clamped to [min]..[max].
  double _bellScore(double mean, double stddev, double min, double max) {
    // Box-Muller transform for normal distribution
    final u1 = _rng.nextDouble();
    final u2 = _rng.nextDouble();
    final z = sqrt(-2 * log(u1 == 0 ? 0.001 : u1)) * cos(2 * pi * u2);
    final v = mean + z * stddev;
    return v.clamp(min, max);
  }

  /// Write a log entry for a seeded row so it will be synced to the server.
  ///
  /// Every insert into one of the 30 synced backend tables needs a
  /// corresponding row in the `logs` table so the sync engine can push
  /// the data to the server for other users to see.
  Future<void> _log(
    SyncAction action,
    String resource,
    GeneratedMessage payload,
  ) async {
    await _db
        .into(_db.logs)
        .insert(
          LogsCompanion(
            account: Value(_userId),
            action: Value(action),
            resource: Value(resource),
            payload: Value(Uint8List.fromList(payload.writeToBuffer())),
            status: const Value(LogStatus.pending),
            created: Value(_nowMs),
          ),
        );
  }

  // ── School ──────────────────────────────────────────────────

  Future<void> _seedSchool() async {
    _schoolId = _id();
    final established = _pastDays(365 * 7);
    await _db
        .into(_db.schools)
        .insert(
          SchoolsCompanion.insert(
            id: _schoolId,
            name: _profile.name,
            motto: Value(_profile.motto),
            phone: Value(_profile.phone),
            email: Value(_profile.email),
            county: _profile.county,
            domain: Value(_profile.domain),
            established: Value(established), // ~2018
            status: const Value(SchoolStatus.active),
            created: _pastSec(365 * 7),
            updated: _nowSec,
          ),
        );
    await _log(
      SyncAction.createSchool,
      _profile.name,
      sync_pb.CreateSchoolPayload(
        id: _schoolId,
        name: _profile.name,
        motto: _profile.motto,
        phone: _profile.phone,
        email: _profile.email,
        county: _profile.county,
        domain: _profile.domain,
        established: established,
        ownerId: _userId,
      ),
    );
  }

  // ── Settings ────────────────────────────────────────────────

  Future<void> _seedSettings() async {
    final cbcGrades = <GradeConfig>[
      // CBC Lower Primary (level 1) — Grades 1–3
      GradeConfig(
        grade: 3,
        streams: const [
          GradeStream(name: 'Sunrise', code: 0),
          GradeStream(name: 'Starlight', code: 1),
        ],
      ),
      GradeConfig(
        grade: 4,
        streams: const [
          GradeStream(name: 'Sunrise', code: 0),
          GradeStream(name: 'Starlight', code: 1),
        ],
      ),
      GradeConfig(
        grade: 5,
        streams: const [
          GradeStream(name: 'Sunrise', code: 0),
          GradeStream(name: 'Starlight', code: 1),
        ],
      ),
      // CBC Upper Primary (level 2) — Grades 4–6
      GradeConfig(
        grade: 6,
        streams: const [
          GradeStream(name: 'Sunrise', code: 0),
          GradeStream(name: 'Starlight', code: 1),
        ],
      ),
      GradeConfig(
        grade: 7,
        streams: const [
          GradeStream(name: 'Sunrise', code: 0),
          GradeStream(name: 'Starlight', code: 1),
        ],
      ),
      GradeConfig(
        grade: 8,
        streams: const [
          GradeStream(name: 'Sunrise', code: 0),
          GradeStream(name: 'Starlight', code: 1),
        ],
      ),
      // CBC Junior Secondary (level 3) — Grades 7–9
      GradeConfig(
        grade: 9,
        streams: const [
          GradeStream(name: 'Alpha', code: 0),
          GradeStream(name: 'Beta', code: 1),
        ],
      ),
      GradeConfig(
        grade: 10,
        streams: const [
          GradeStream(name: 'Alpha', code: 0),
          GradeStream(name: 'Beta', code: 1),
        ],
      ),
      GradeConfig(
        grade: 11,
        streams: const [
          GradeStream(name: 'Alpha', code: 0),
          GradeStream(name: 'Beta', code: 1),
        ],
      ),
      // CBC Senior Secondary — Grade 10 (STEM, level 4)
      GradeConfig(
        grade: 12,
        streams: const [
          GradeStream(name: 'Alpha', code: 0),
          GradeStream(name: 'Beta', code: 1),
          GradeStream(name: 'Gamma', code: 2),
        ],
      ),
      // CBC Senior Secondary — Grade 11 (Social Sciences, level 5)
      GradeConfig(
        grade: 13,
        streams: const [
          GradeStream(name: 'Alpha', code: 0),
          GradeStream(name: 'Beta', code: 1),
        ],
      ),
      // CBC Senior Secondary — Grade 12 (Arts & Sports Science, level 6)
      GradeConfig(
        grade: 14,
        streams: const [
          GradeStream(name: 'Alpha', code: 0),
          GradeStream(name: 'Beta', code: 1),
        ],
      ),
    ];

    // 8-4-4: Only Form 3 and Form 4 remain (everything below is phased out)
    final eightFourFourGrades = <GradeConfig>[
      // 8-4-4 Form 3 (level 3) with demo data
      GradeConfig(
        grade: 43,
        streams: const [
          GradeStream(name: 'East', code: 0),
          GradeStream(name: 'West', code: 1),
          GradeStream(name: 'North', code: 2),
        ],
      ),
      // 8-4-4 Form 4 (level 3) with demo data
      GradeConfig(
        grade: 44,
        streams: const [
          GradeStream(name: 'East', code: 0),
          GradeStream(name: 'West', code: 1),
          GradeStream(name: 'North', code: 2),
        ],
      ),
    ];

    final config = SchoolConfig(
      curricula: [
        CurriculumConfig(type: CurriculumType.cbc, grades: cbcGrades),
        CurriculumConfig(
          type: CurriculumType.eightFourFour,
          grades: eightFourFourGrades,
        ),
      ],
    );

    await _db
        .into(_db.settings)
        .insert(
          SettingsCompanion.insert(
            school: _schoolId,
            data: jsonEncode(config.toJson()),
            mpesa: const Value(null),
            created: _pastSec(365 * 7),
            updated: _nowSec,
          ),
        );
    await _log(
      SyncAction.updateSettings,
      _profile.name,
      sync_pb.UpdateSettingsPayload(
        school: _schoolId,
        data: jsonEncode(config.toJson()),
      ),
    );
  }

  // ── Departments ─────────────────────────────────────────────

  Future<void> _seedDepartments() async {
    for (final dept in _kDepartments) {
      await _db
          .into(_db.departments)
          .insert(
            DepartmentsCompanion.insert(
              school: _schoolId,
              name: dept,
              description: Value('$dept Department'),
              created: _pastSec(365 * 5),
              updated: _nowSec,
            ),
          );
      await _log(
        SyncAction.createDepartment,
        dept,
        sync_pb.CreateDepartmentPayload(
          school: _schoolId,
          name: dept,
          description: '$dept Department',
        ),
      );
    }
  }

  // ── Teachers ────────────────────────────────────────────────

  Future<void> _seedTeachers() async {
    for (var i = 0; i < _kTeacherProfiles.length; i++) {
      final profile = _kTeacherProfiles[i];
      final userId = _id();
      _teacherUserIds.add(userId);

      // Create user
      final phone = _randomPhone();
      final name = _randomName();
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              phone: phone,
              email: Value(null),
              name: name,
              level: const Value(UserLevel.normal),
              status: const Value(UserStatus.active),
              created: _pastSec(365 * 3 + _rng.nextInt(365)),
              updated: _nowSec,
            ),
          );

      // Create teacher record
      final hiredDaysAgo = 365 * 2 + _rng.nextInt(365 * 3);
      final hired = _pastDays(hiredDaysAgo);
      await _db
          .into(_db.teachers)
          .insert(
            TeachersCompanion.insert(
              school: _schoolId,
              user: userId,
              hired: Value(hired),
              role: Value(profile.role),
              department: Value(profile.department),
              status: const Value(TeacherStatus.active),
              created: _pastSec(hiredDaysAgo),
              updated: _nowSec,
            ),
          );
      await _log(
        SyncAction.createTeacher,
        name,
        sync_pb.CreateTeacherPayload(
          school: _schoolId,
          userId: userId,
          phone: phone,
          name: name,
          hired: hired,
          role: profile.role,
          department: profile.department,
        ),
      );
    }
  }

  // ── Staff ───────────────────────────────────────────────────

  Future<void> _seedStaff() async {
    for (var i = 0; i < _kStaffRoles.length; i++) {
      final userId = _id();
      _staffUserIds.add(userId);

      final phone = _randomPhone();
      final name = _randomName();
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              phone: phone,
              email: Value(null),
              name: name,
              level: const Value(UserLevel.normal),
              status: const Value(UserStatus.active),
              created: _pastSec(365 * 2 + _rng.nextInt(365)),
              updated: _nowSec,
            ),
          );

      await _db
          .into(_db.staff)
          .insert(
            StaffCompanion.insert(
              school: _schoolId,
              user: userId,
              idnumber: Value(null),
              role: Value(_kStaffRoles[i]),
              department: Value(null),
              status: const Value(StaffStatus.active),
              created: _pastSec(365 * 2),
              updated: _nowSec,
            ),
          );
      await _log(
        SyncAction.createStaff,
        name,
        sync_pb.CreateStaffPayload(
          school: _schoolId,
          userId: userId,
          phone: phone,
          name: name,
          role: _kStaffRoles[i],
        ),
      );
    }
  }

  // ── Owner ───────────────────────────────────────────────────

  Future<void> _seedOwner() async {
    await _db
        .into(_db.owners)
        .insert(
          OwnersCompanion.insert(
            school: _schoolId,
            user: _userId,
            created: _pastSec(365 * 7),
          ),
        );
    // Owner is created as part of createSchool flow — the CreateSchoolPayload
    // already includes ownerId. No separate log needed for the owner row
    // since the server creates it automatically. But we log it anyway for
    // completeness in case the school was created without an owner payload.
    await _log(
      SyncAction.createOwner,
      _profile.name,
      sync_pb.CreateOwnerPayload(school: _schoolId, userId: _userId),
    );
  }

  // ── Terms ───────────────────────────────────────────────────

  Future<void> _seedTerms() async {
    // Three terms computed relative to today's date so that the "current"
    // term always contains today (or is the next upcoming term if today
    // falls in a holiday gap).
    await _insertTerm(
      _olderTerm.year,
      _olderTerm.term,
      _olderTerm.start,
      _olderTerm.end,
    );
    await _insertTerm(
      _previousTerm.year,
      _previousTerm.term,
      _previousTerm.start,
      _previousTerm.end,
    );
    await _insertTerm(
      _currentTerm.year,
      _currentTerm.term,
      _currentTerm.start,
      _currentTerm.end,
    );
  }

  Future<void> _insertTerm(
    int year,
    int term,
    DateTime start,
    DateTime end,
  ) async {
    final startSec = BigInt.from(start.millisecondsSinceEpoch ~/ 1000);
    final endSec = BigInt.from(end.millisecondsSinceEpoch ~/ 1000);
    await _db
        .into(_db.terms)
        .insert(
          TermsCompanion.insert(
            school: _schoolId,
            year: year,
            term: term,
            start: startSec,
            end: endSec,
            created: _pastSec(200),
            updated: _nowSec,
          ),
        );
    await _log(
      SyncAction.createTerm,
      'Year $year Term $term',
      sync_pb.CreateTermPayload(
        school: _schoolId,
        year: year,
        term: term,
        start: fixnum.Int64(startSec.toInt()),
        end: fixnum.Int64(endSec.toInt()),
      ),
    );
  }

  // ── Students & Guardians ────────────────────────────────────

  Future<void> _seedStudentsAndGuardians() async {
    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        final students = <int>[];
        for (var s = 0; s < gc.studentsPerStream; s++) {
          final adm = _nextAdm++;
          students.add(adm);

          final gender = _randomGender();
          final name = _randomName();
          final dob = _studentDob(gc.grade);
          final admitted = _pastDays(365 + _rng.nextInt(365));

          await _db
              .into(_db.students)
              .insert(
                StudentsCompanion.insert(
                  school: _schoolId,
                  adm: adm,
                  user: const Value(null),
                  name: name,
                  dob: Value(dob),
                  gender: Value(gender),
                  documents: const Value(null),
                  admitted: Value(admitted),
                  status: const Value(StudentStatus.active),
                  created: _pastSec(365),
                  updated: _nowSec,
                ),
              );
          await _log(
            SyncAction.createStudent,
            name,
            sync_pb.CreateStudentPayload(
              school: _schoolId,
              adm: adm,
              name: name,
              dob: dob,
              gender: gender.index,
              admitted: admitted,
            ),
          );

          // Create a guardian for most students.
          // ~15% of students share a guardian (siblings).
          if (_rng.nextDouble() < 0.15 && _guardianUserIds.isNotEmpty) {
            // Share an existing guardian
            final gId = _guardianUserIds[_rng.nextInt(_guardianUserIds.length)];
            final relationship = _rng.nextBool()
                ? GuardianRelationship.father
                : GuardianRelationship.mother;
            await _db
                .into(_db.guardians)
                .insert(
                  GuardiansCompanion.insert(
                    school: _schoolId,
                    user: gId,
                    student: adm,
                    relationship: relationship,
                    role: const Value(GuardianRole.secondary),
                    created: _pastSec(300),
                    updated: _nowSec,
                  ),
                );
            await _log(
              SyncAction.createGuardian,
              name,
              sync_pb.CreateGuardianPayload(
                school: _schoolId,
                userId: gId,
                student: adm,
                relationship: relationship.index,
                role: GuardianRole.secondary.index,
              ),
            );
          } else {
            // Create a new guardian user
            final gId = _id();
            _guardianUserIds.add(gId);

            final gPhone = _randomPhone();
            final gName = _randomName();
            await _db
                .into(_db.users)
                .insert(
                  UsersCompanion.insert(
                    id: gId,
                    phone: gPhone,
                    email: Value(null),
                    name: gName,
                    level: const Value(UserLevel.normal),
                    status: const Value(UserStatus.active),
                    created: _pastSec(300),
                    updated: _nowSec,
                  ),
                );

            final relationship = _rng.nextBool()
                ? GuardianRelationship.father
                : GuardianRelationship.mother;
            await _db
                .into(_db.guardians)
                .insert(
                  GuardiansCompanion.insert(
                    school: _schoolId,
                    user: gId,
                    student: adm,
                    relationship: relationship,
                    role: const Value(GuardianRole.primary),
                    created: _pastSec(300),
                    updated: _nowSec,
                  ),
                );
            await _log(
              SyncAction.createGuardian,
              gName,
              sync_pb.CreateGuardianPayload(
                school: _schoolId,
                userId: gId,
                phone: gPhone,
                name: gName,
                student: adm,
                relationship: relationship.index,
                role: GuardianRole.primary.index,
              ),
            );
          }
        }
        _enrolledStudents[(gc.grade, si)] = students;
      }
    }
  }

  // ── Enrollments ─────────────────────────────────────────────

  Future<void> _seedEnrollments() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;
    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        final students = _enrolledStudents[(gc.grade, si)]!;
        for (final adm in students) {
          await _db
              .into(_db.enrollments)
              .insert(
                EnrollmentsCompanion.insert(
                  school: _schoolId,
                  year: year,
                  term: term,
                  grade: gc.grade,
                  stream: si,
                  student: adm,
                  created: _pastSec(60),
                ),
              );
          await _log(
            SyncAction.enrollStudent,
            'Student $adm',
            sync_pb.EnrollStudentPayload(
              school: _schoolId,
              year: year,
              term: term,
              grade: gc.grade,
              stream: si,
              student: adm,
            ),
          );
        }
      }
    }
  }

  // ── Subjects ────────────────────────────────────────────────

  Future<void> _seedSubjects() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        for (var subIdx = 0; subIdx < gc.subjectIndices.length; subIdx++) {
          final subj = gc.subjectIndices[subIdx];
          // Assign a teacher round-robin from the pool
          final teacherId = _teacherUserIds[subIdx % _teacherUserIds.length];

          await _db
              .into(_db.subjects)
              .insert(
                SubjectsCompanion.insert(
                  school: _schoolId,
                  year: year,
                  term: term,
                  grade: gc.grade,
                  stream: si,
                  subject: subj,
                  teacher: teacherId,
                  created: _pastSec(60),
                ),
              );
          await _log(
            SyncAction.assignSubject,
            'Subject $subj',
            sync_pb.AssignSubjectPayload(
              school: _schoolId,
              year: year,
              term: term,
              grade: gc.grade,
              stream: si,
              subject: subj,
              teacher: teacherId,
            ),
          );

          // Track assignments for timetable
          _teacherSubjects.putIfAbsent(teacherId, () => []);
          _teacherSubjects[teacherId]!.add(
            _SubjectAssignment(gc.grade, si, subj),
          );
        }
      }
    }
  }

  // ── Class Teachers ──────────────────────────────────────────

  Future<void> _seedClassTeachers() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    var teacherIdx = 0;
    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        final tid = _teacherUserIds[teacherIdx % _teacherUserIds.length];
        teacherIdx++;

        final startDays = _pastDays(60);
        await _db
            .into(_db.classTeachers)
            .insert(
              ClassTeachersCompanion.insert(
                school: _schoolId,
                year: year,
                term: term,
                grade: gc.grade,
                stream: si,
                teacher: tid,
                start: startDays,
                end: const Value(null),
                created: _pastSec(60),
              ),
            );
        await _log(
          SyncAction.assignClassTeacher,
          'Class Teacher',
          sync_pb.AssignClassTeacherPayload(
            school: _schoolId,
            year: year,
            term: term,
            grade: gc.grade,
            stream: si,
            teacher: tid,
            start: startDays,
          ),
        );
      }
    }
  }

  // ── Timetable ───────────────────────────────────────────────

  Future<void> _seedTimetable() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    // 8 periods per day, 40 min each, starting at 08:00 with a 15 min break
    // after period 4 and a 1-hour lunch after period 6.
    // Seconds since midnight:
    // P1: 08:00-08:40  => 28800-31200
    // P2: 08:40-09:20  => 31200-33600
    // P3: 09:20-10:00  => 33600-36000
    // P4: 10:00-10:40  => 36000-38400
    // Break: 10:40-10:55
    // P5: 10:55-11:35  => 39300-41700
    // P6: 11:35-12:15  => 41700-44100
    // Lunch: 12:15-13:15
    // P7: 13:15-13:55  => 47700-50100
    // P8: 13:55-14:35  => 50100-52500

    const periodSlots = [
      (28800, 31200),
      (31200, 33600),
      (33600, 36000),
      (36000, 38400),
      (39300, 41700),
      (41700, 44100),
      (47700, 50100),
      (50100, 52500),
    ];

    // Days: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5
    const schoolDays = [
      DayOfWeek.monday,
      DayOfWeek.tuesday,
      DayOfWeek.wednesday,
      DayOfWeek.thursday,
      DayOfWeek.friday,
    ];

    // For each focus grade/stream, distribute subjects across the week.
    // Each subject gets roughly (8*5)/numSubjects = ~4 periods per week.
    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        final subjects = gc.subjectIndices.toList();
        var subjectCursor = 0;

        for (final day in schoolDays) {
          for (final (startSec, endSec) in periodSlots) {
            final subj = subjects[subjectCursor % subjects.length];
            subjectCursor++;

            // Find the teacher assigned to this subject for this class
            String? teacherId;
            for (final tid in _teacherUserIds) {
              final assignments = _teacherSubjects[tid] ?? [];
              for (final a in assignments) {
                if (a.grade == gc.grade &&
                    a.stream == si &&
                    a.subject == subj) {
                  teacherId = tid;
                  break;
                }
              }
              if (teacherId != null) break;
            }
            teacherId ??= _teacherUserIds[0];

            // Check for teacher conflict on this day+start — skip if already booked
            // (simple collision avoidance: rely on the unique index; catch and skip)
            try {
              await _db
                  .into(_db.timetable)
                  .insert(
                    TimetableCompanion.insert(
                      school: _schoolId,
                      year: year,
                      term: term,
                      grade: gc.grade,
                      stream: si,
                      subject: subj,
                      teacher: teacherId,
                      day: day,
                      start: startSec,
                      end: endSec,
                      created: _pastSec(50),
                      updated: _nowSec,
                    ),
                  );
              await _log(
                SyncAction.createTimetableEntry,
                'Timetable',
                sync_pb.CreateTimetableEntryPayload(
                  school: _schoolId,
                  year: year,
                  term: term,
                  grade: gc.grade,
                  stream: si,
                  subject: subj,
                  teacher: teacherId,
                  day: day.index,
                  start: startSec,
                  end: endSec,
                ),
              );
            } catch (_) {
              // Unique constraint violation (teacher double-booked) — skip this slot
            }
          }
        }
      }
    }
  }

  // ── Attendance ──────────────────────────────────────────────

  Future<void> _seedAttendance() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    // Generate up to 20 working days of attendance starting from the current
    // term's start date, clamped to min(today, term end).
    final termStart = _currentTerm.start;
    final today = DateTime.now();
    final clampEnd = today.isBefore(_currentTerm.end)
        ? today
        : _currentTerm.end;
    final attendanceDays = <int>[];
    var current = termStart;
    while (attendanceDays.length < 20 && !current.isAfter(clampEnd)) {
      if (current.weekday <= 5) {
        // Mon-Fri
        attendanceDays.add(current.millisecondsSinceEpoch ~/ 86400000);
      }
      current = current.add(const Duration(days: 1));
    }
    // If the term hasn't started yet (gap scenario), skip attendance seeding.
    if (attendanceDays.isEmpty) return;

    debugPrint(
      'Seeded ${attendanceDays.length} attendance days for term $year/$term',
    );

    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        final students = _enrolledStudents[(gc.grade, si)]!;
        for (final dayEpoch in attendanceDays) {
          // Collect all records for this class/stream/date into one payload
          final records = <sync_pb.AttendanceRecord>[];
          for (final adm in students) {
            // ~90% present, ~7% absent, ~3% leave
            final roll = _rng.nextDouble();
            AttendanceStatus status;
            if (roll < 0.90) {
              status = AttendanceStatus.present;
            } else if (roll < 0.97) {
              status = AttendanceStatus.absent;
            } else {
              status = AttendanceStatus.leave;
            }

            await _db
                .into(_db.attendance)
                .insert(
                  AttendanceCompanion.insert(
                    school: _schoolId,
                    year: year,
                    term: term,
                    grade: gc.grade,
                    stream: si,
                    student: adm,
                    date: dayEpoch,
                    status: status,
                    created: _pastSec(20),
                    updated: _nowSec,
                  ),
                );
            records.add(
              sync_pb.AttendanceRecord(student: adm, status: status.value),
            );
          }
          // One log per class/stream/date — batch attendance marking
          await _log(
            SyncAction.markAttendance,
            'Attendance $dayEpoch',
            sync_pb.MarkAttendancePayload(
              school: _schoolId,
              year: year,
              term: term,
              grade: gc.grade,
              stream: si,
              date: dayEpoch,
              records: records,
            ),
          );
        }
      }
    }
  }

  // ── Exams & Grades ──────────────────────────────────────────

  Future<void> _seedExamsAndGrades() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    // Per grade: "Opening Term Exam" + "CAT 1"
    // Form 4 gets "Mock KCSE" instead of "Opening Term Exam"
    // (unique index prevents two exams of the same type per grade/term)
    for (final gc in _focusGrades) {
      if (gc.grade == 44) {
        // Mock KCSE — Form 4 only (uses ExamType.exam slot)
        await _seedExam(
          gc: gc,
          year: year,
          term: term,
          name: 'Mock KCSE',
          type: ExamType.exam,
          startDaysAgo: 8,
          endDaysAgo: 3,
          gradingCoverage: 1.0,
          paperStatus: PaperStatus.marked,
        );
      } else {
        // Opening Term Exam — all grades except Form 4
        await _seedExam(
          gc: gc,
          year: year,
          term: term,
          name: 'Opening Term Exam',
          type: ExamType.exam,
          startDaysAgo: 35,
          endDaysAgo: 30,
          gradingCoverage: 0.80,
          paperStatus: PaperStatus.marked,
        );
      }

      // CAT 1
      await _seedExam(
        gc: gc,
        year: year,
        term: term,
        name: 'CAT 1',
        type: ExamType.assessment,
        startDaysAgo: 15,
        endDaysAgo: 12,
        gradingCoverage: 0.50,
        paperStatus: PaperStatus.done,
      );
    }
  }

  Future<void> _seedExam({
    required _GradeClass gc,
    required int year,
    required int term,
    required String name,
    required ExamType type,
    required int startDaysAgo,
    required int endDaysAgo,
    required double gradingCoverage,
    required PaperStatus paperStatus,
  }) async {
    final examId = _id();
    final teacherId = _teacherUserIds[0]; // exam coordinator
    final examStartDays = _pastDays(startDaysAgo);
    final examEndDays = _pastDays(endDaysAgo);

    await _db
        .into(_db.exams)
        .insert(
          ExamsCompanion.insert(
            id: examId,
            school: _schoolId,
            year: year,
            term: term,
            grade: gc.grade,
            stream: const Value(null), // all streams
            personalized: const Value(false),
            type: type,
            start: examStartDays,
            end: examEndDays,
            teacher: teacherId,
            created: _pastSec(startDaysAgo + 5),
            updated: _nowSec,
          ),
        );
    await _log(
      SyncAction.createExam,
      name,
      sync_pb.CreateExamPayload(
        id: examId,
        school: _schoolId,
        year: year,
        term: term,
        grade: gc.grade,
        personalized: false,
        type: type.index,
        start: examStartDays,
        end: examEndDays,
        teacher: teacherId,
      ),
    );

    // Create papers for each subject
    for (final subj in gc.subjectIndices) {
      // Find the teacher for this subject
      String invigilator = teacherId;
      for (final tid in _teacherUserIds) {
        final assignments = _teacherSubjects[tid] ?? [];
        if (assignments.any((a) => a.grade == gc.grade && a.subject == subj)) {
          invigilator = tid;
          break;
        }
      }

      final paperStartSec = _pastSec(startDaysAgo);
      final paperEndSec = _pastSec(endDaysAgo);
      await _db
          .into(_db.papers)
          .insert(
            PapersCompanion.insert(
              school: _schoolId,
              exam: examId,
              subject: subj,
              paper: const Value(null), // single paper per subject
              invigilator: invigilator,
              start: paperStartSec,
              end: paperEndSec,
              status: Value(paperStatus),
              created: _pastSec(startDaysAgo + 3),
              updated: _nowSec,
            ),
          );
      await _log(
        SyncAction.createPaper,
        name,
        sync_pb.CreatePaperPayload(
          school: _schoolId,
          exam: examId,
          subject: subj,
          invigilator: invigilator,
          start: fixnum.Int64(paperStartSec.toInt()),
          end: fixnum.Int64(paperEndSec.toInt()),
        ),
      );

      // Create grades for enrolled students — batch per subject
      for (var si = 0; si < gc.streamNames.length; si++) {
        final students = _enrolledStudents[(gc.grade, si)]!;
        final gradeRecords = <sync_pb.GradeRecord>[];
        for (final adm in students) {
          // Some students may not have grades (based on coverage)
          if (_rng.nextDouble() > gradingCoverage) continue;

          // Realistic bell-curve score distribution
          final score = double.parse(
            _bellScore(62.0, 15.0, 15.0, 98.0).toStringAsFixed(1),
          );
          const total = 100;

          await _db
              .into(_db.grades)
              .insert(
                GradesCompanion.insert(
                  school: _schoolId,
                  exam: examId,
                  student: adm,
                  subject: subj,
                  paper: const Value(null),
                  score: score,
                  total: total,
                  created: _pastSec(endDaysAgo),
                  updated: _nowSec,
                ),
              );
          gradeRecords.add(
            sync_pb.GradeRecord(student: adm, score: score, total: total),
          );
        }
        if (gradeRecords.isNotEmpty) {
          await _log(
            SyncAction.markGrades,
            name,
            sync_pb.MarkGradesPayload(
              school: _schoolId,
              exam: examId,
              subject: subj,
              records: gradeRecords,
            ),
          );
        }
      }
    }
  }

  // ── Fees ────────────────────────────────────────────────────

  Future<void> _seedFees() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;
    // Due date: 10 days after the current term starts.
    final dueDate = _currentTerm.start.add(const Duration(days: 10));
    final dueSec = BigInt.from(dueDate.millisecondsSinceEpoch ~/ 1000);
    final dueInt64 = fixnum.Int64(dueSec.toInt());

    for (final gc in _focusGrades) {
      // Tuition
      final tuitionId = _id();
      await _db
          .into(_db.fees)
          .insert(
            FeesCompanion.insert(
              id: tuitionId,
              school: _schoolId,
              year: year,
              term: term,
              grade: gc.grade,
              title: 'Tuition Fee',
              description: 'Term $term tuition fee',
              amount: 15000.0,
              mandatory: const Value(true),
              due: dueSec,
              created: _pastSec(70),
              updated: _nowSec,
            ),
          );
      await _log(
        SyncAction.createFee,
        'Tuition Fee',
        sync_pb.CreateFeePayload(
          id: tuitionId,
          school: _schoolId,
          year: year,
          term: term,
          grade: gc.grade,
          title: 'Tuition Fee',
          description: 'Term $term tuition fee',
          amount: 15000.0,
          mandatory: true,
          due: dueInt64,
        ),
      );

      // Activity fee
      final activityId = _id();
      await _db
          .into(_db.fees)
          .insert(
            FeesCompanion.insert(
              id: activityId,
              school: _schoolId,
              year: year,
              term: term,
              grade: gc.grade,
              title: 'Activity Fee',
              description: 'Co-curricular and sports activities',
              amount: 2000.0,
              mandatory: const Value(true),
              due: dueSec,
              created: _pastSec(70),
              updated: _nowSec,
            ),
          );
      await _log(
        SyncAction.createFee,
        'Activity Fee',
        sync_pb.CreateFeePayload(
          id: activityId,
          school: _schoolId,
          year: year,
          term: term,
          grade: gc.grade,
          title: 'Activity Fee',
          description: 'Co-curricular and sports activities',
          amount: 2000.0,
          mandatory: true,
          due: dueInt64,
        ),
      );
    }
  }

  // ── Invoices & Payments ─────────────────────────────────────

  Future<void> _seedInvoicesAndPayments() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    // Query all fees we just created
    final allFees =
        await (_db.select(_db.fees)..where(
              (f) =>
                  f.school.equals(_schoolId) &
                  f.year.equals(year) &
                  f.term.equals(term),
            ))
            .get();

    // Group fees by grade
    final feesByGrade = <int, List<Fee>>{};
    for (final f in allFees) {
      feesByGrade.putIfAbsent(f.grade, () => []).add(f);
    }

    for (final gc in _focusGrades) {
      final gradeFees = feesByGrade[gc.grade] ?? [];
      if (gradeFees.isEmpty) continue;

      for (var si = 0; si < gc.streamNames.length; si++) {
        final students = _enrolledStudents[(gc.grade, si)]!;
        for (final adm in students) {
          for (final fee in gradeFees) {
            final invoiceId = _id();
            await _db
                .into(_db.invoices)
                .insert(
                  InvoicesCompanion.insert(
                    id: invoiceId,
                    school: _schoolId,
                    year: year,
                    term: term,
                    fee: Value(fee.id),
                    description: const Value(null),
                    student: adm,
                    amount: fee.amount,
                    status: const Value(InvoiceStatus.pending),
                    due: Value(fee.due),
                    created: _pastSec(60),
                    updated: _nowSec,
                  ),
                );
            await _log(
              SyncAction.createInvoice,
              fee.title,
              sync_pb.CreateInvoicePayload(
                id: invoiceId,
                school: _schoolId,
                year: year,
                term: term,
                fee: fee.id,
                student: adm,
                amount: fee.amount,
                due: fixnum.Int64(fee.due.toInt()),
              ),
            );

            // ~60% of invoices get a payment (partial or full)
            if (_rng.nextDouble() < 0.60) {
              final payFraction = _rng.nextDouble() * 0.5 + 0.5; // 50-100%
              final payAmount = (fee.amount * payFraction * 100).round() / 100;

              final method = PaymentMethod
                  .values[_rng.nextInt(PaymentMethod.values.length)];

              final reference = method == PaymentMethod.mpesa
                  ? 'TXN${_rng.nextInt(9999999).toString().padLeft(7, '0')}'
                  : null;
              final recorder = _staffUserIds.isNotEmpty
                  ? _staffUserIds[0]
                  : null;
              final payDate = _pastDays(30 + _rng.nextInt(30));

              final paymentId = _id();
              await _db
                  .into(_db.payments)
                  .insert(
                    PaymentsCompanion.insert(
                      id: paymentId,
                      invoice: Value(invoiceId),
                      school: Value(_schoolId),
                      student: Value(adm),
                      amount: payAmount,
                      method: Value(method),
                      reference: Value(reference),
                      recorder: Value(recorder), // bursar
                      date: Value(payDate),
                      created: _pastSec(30),
                      updated: _nowSec,
                    ),
                  );
              await _log(
                SyncAction.createPayment,
                fee.title,
                sync_pb.CreatePaymentPayload(
                  id: paymentId,
                  invoice: invoiceId,
                  school: _schoolId,
                  student: adm,
                  amount: payAmount,
                  method: method.index,
                  reference: reference,
                  recorder: recorder,
                  date: payDate,
                ),
              );

              // Update invoice status based on payment
              final newStatus = payAmount >= fee.amount
                  ? InvoiceStatus.paid
                  : InvoiceStatus.partial;
              await (_db.update(
                _db.invoices,
              )..where((i) => i.id.equals(invoiceId))).write(
                InvoicesCompanion(
                  status: Value(newStatus),
                  updated: Value(_nowSec),
                ),
              );
              // Log the invoice update too
              await _log(
                SyncAction.updateInvoice,
                fee.title,
                sync_pb.UpdateInvoicePayload(
                  id: invoiceId,
                  status: newStatus.index,
                ),
              );
            }
          }
        }
      }
    }
  }

  // ── Announcements ───────────────────────────────────────────

  Future<void> _seedAnnouncements() async {
    final announcements = _profile.announcements;

    for (final (title, content, audience, daysAgo) in announcements) {
      final announcementId = _id();
      await _db
          .into(_db.announcements)
          .insert(
            AnnouncementsCompanion.insert(
              id: announcementId,
              school: _schoolId,
              title: title,
              content: content,
              grade: const Value(null),
              stream: const Value(null),
              audience: audience,
              author: Value(_userId),
              created: _pastSec(daysAgo),
              updated: _pastSec(daysAgo),
            ),
          );
      await _log(
        SyncAction.createAnnouncement,
        title,
        sync_pb.CreateAnnouncementPayload(
          id: announcementId,
          school: _schoolId,
          title: title,
          content: content,
          audience: audience,
          author: _userId,
        ),
      );
    }
  }

  // ── Roles & Scopes ─────────────────────────────────────────

  Future<void> _seedRolesAndScopes() async {
    _roleId = _id();

    // Create a "Teacher" role with teaching-related permissions.
    // Permissions blob: Resource/Action bitmask.
    // For the Teacher role we grant:
    //   Attendance (8): Read(2) + Mark(128) = 130
    //   Lessons (9): CRUD = 1+2+4+8 = 15
    //   Grades (11): Read(2) + Mark(128) + Update(4) = 134
    //   Students (5): Read(2) = 2
    //   Classes (7): Read(2) = 2
    //   Announcements (14): Read(2) = 2
    // Binary blob: [resource, lo, hi] per non-empty resource
    final permBytes = <int>[];
    void addPerm(int resource, int actionMask) {
      permBytes.add(resource);
      permBytes.add(actionMask & 0xFF); // lo byte
      permBytes.add((actionMask >> 8) & 0xFF); // hi byte
    }

    addPerm(5, 2); // Students: Read
    addPerm(7, 2); // Classes: Read
    addPerm(8, 130); // Attendance: Read + Mark
    addPerm(9, 15); // Lessons: CRUD
    addPerm(11, 134); // Grades: Read + Update + Mark
    addPerm(14, 2); // Announcements: Read

    // Note: roles.permissions is text in the schema but we store the
    // bitmask encoded as JSON for now, matching the current column type.
    final permJson = jsonEncode(permBytes);

    await _db
        .into(_db.roles)
        .insert(
          RolesCompanion.insert(
            id: _roleId,
            school: Value(_schoolId),
            name: 'Teacher',
            description: const Value('Standard teaching staff permissions'),
            permissions: permJson,
            created: _pastSec(365),
            updated: _nowSec,
          ),
        );
    await _log(
      SyncAction.createRole,
      'Teacher',
      sync_pb.CreateRolePayload(
        id: _roleId,
        school: _schoolId,
        name: 'Teacher',
        description: 'Standard teaching staff permissions',
        permissions: permBytes,
      ),
    );

    // Assign all teachers to this role
    for (final tid in _teacherUserIds) {
      await _db
          .into(_db.scopes)
          .insert(
            ScopesCompanion.insert(
              school: Value(_schoolId),
              user: tid,
              role: _roleId,
              created: _pastSec(365),
            ),
          );
      await _log(
        SyncAction.assignRole,
        'Teacher',
        sync_pb.AssignRolePayload(school: _schoolId, user: tid, role: _roleId),
      );
    }
  }

  // ── Mastery ─────────────────────────────────────────────────

  Future<void> _seedMastery() async {
    // Form 4 students get mastery data: 5 topics per subject.
    // Use firstWhere with orElse in case the grade set changes.
    final gc = _focusGrades.where((g) => g.grade == 44).firstOrNull;
    if (gc == null) return;

    for (var si = 0; si < gc.streamNames.length; si++) {
      final students = _enrolledStudents[(gc.grade, si)]!;
      for (final adm in students) {
        // Pick 4 random subjects for this student to have mastery data
        final shuffled = gc.subjectIndices.toList()..shuffle(_rng);
        final masterySubjects = shuffled.take(4);

        for (final subj in masterySubjects) {
          for (var topic = 0; topic < 5; topic++) {
            final score = double.parse(
              _bellScore(65.0, 18.0, 30.0, 98.0).toStringAsFixed(1),
            );
            await _db
                .into(_db.mastery)
                .insert(
                  MasteryCompanion.insert(
                    school: _schoolId,
                    student: adm,
                    grade: gc.grade,
                    subject: subj,
                    topic: topic,
                    score: score,
                    created: _pastSec(20),
                    updated: _nowSec,
                  ),
                );
            await _log(
              SyncAction.updateMastery,
              'Mastery',
              sync_pb.UpdateMasteryPayload(
                school: _schoolId,
                student: adm,
                grade: gc.grade,
                subject: subj,
                topic: topic,
                score: score,
              ),
            );
          }
        }
      }
    }
  }

  // ── Lessons ─────────────────────────────────────────────────

  Future<void> _seedLessons() async {
    final year = _currentTerm.year;
    final term = _currentTerm.term;

    // ~100 lesson records over the past weeks, spread across focus grades.
    // Start from the current term's start date, clamped to min(today, term end).
    final termStart = _currentTerm.start;
    final today = DateTime.now();
    final clampEnd = today.isBefore(_currentTerm.end)
        ? today
        : _currentTerm.end;
    final lessonDays = <int>[];
    var current = termStart;
    while (lessonDays.length < 25 && !current.isAfter(clampEnd)) {
      if (current.weekday <= 5) {
        lessonDays.add(current.millisecondsSinceEpoch ~/ 86400000);
      }
      current = current.add(const Duration(days: 1));
    }
    if (lessonDays.isEmpty) return;

    debugPrint(
      'Seeding lessons over ${lessonDays.length} days for term $year/$term',
    );

    var count = 0;
    for (final gc in _focusGrades) {
      for (var si = 0; si < gc.streamNames.length; si++) {
        // Each stream gets a few lesson records per day
        for (final dayEpoch in lessonDays) {
          if (count >= 100) break;

          // Pick 2-3 random subjects that had lessons this day
          final shuffled = gc.subjectIndices.toList()..shuffle(_rng);
          final todaySubjects = shuffled.take(2 + _rng.nextInt(2));

          for (final subj in todaySubjects) {
            if (count >= 100) break;

            // Find teacher for this subject
            String? teacherId;
            for (final tid in _teacherUserIds) {
              final assignments = _teacherSubjects[tid] ?? [];
              if (assignments.any(
                (a) =>
                    a.grade == gc.grade && a.stream == si && a.subject == subj,
              )) {
                teacherId = tid;
                break;
              }
            }
            teacherId ??= _teacherUserIds[0];

            try {
              await _db
                  .into(_db.lessons)
                  .insert(
                    LessonsCompanion.insert(
                      school: _schoolId,
                      year: year,
                      term: term,
                      grade: gc.grade,
                      stream: si,
                      date: dayEpoch,
                      subject: subj,
                      teacher: teacherId,
                      created: _pastSec(5),
                      updated: _nowSec,
                    ),
                  );
              await _log(
                SyncAction.createLesson,
                'Lesson',
                sync_pb.CreateLessonPayload(
                  school: _schoolId,
                  year: year,
                  term: term,
                  grade: gc.grade,
                  stream: si,
                  date: dayEpoch,
                  subject: subj,
                  teacher: teacherId,
                ),
              );
              count++;
            } catch (_) {
              // PK collision — skip
            }
          }
        }
        if (count >= 100) break;
      }
      if (count >= 100) break;
    }
  }
}

// ============================================================
// Helper data class
// ============================================================

/// Holds the computed year/term/start/end for a single school term.
class _TermInfo {
  const _TermInfo(this.year, this.term, this.start, this.end);
  final int year;
  final int term;
  final DateTime start;
  final DateTime end;
}

class _SubjectAssignment {
  const _SubjectAssignment(this.grade, this.stream, this.subject);
  final int grade;
  final int stream;
  final int subject;
}
