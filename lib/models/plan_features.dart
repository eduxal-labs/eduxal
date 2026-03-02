// ─────────────────────────────────────────────────────────────────────────────
// Plan feature definitions (D11)
// ─────────────────────────────────────────────────────────────────────────────

class PlanFeature {
  final String key;
  final String title;
  final String description;
  const PlanFeature(this.key, this.title, this.description);
}

const List<PlanFeature> kPlanFeatures = [
  PlanFeature(
    'attendance_recording',
    'Smart Attendance',
    'Effortless daily attendance tracking with real-time parent notifications '
        'and automated absence reports.',
  ),
  PlanFeature(
    'timetable_management',
    'Dynamic Timetable',
    'Intelligent timetable creation and management with conflict detection '
        'and teacher workload balancing.',
  ),
  PlanFeature(
    'push_notifications',
    'Instant Notifications',
    'Real-time push notifications keeping parents, teachers, and students '
        'connected to every school event.',
  ),
  PlanFeature(
    'sms_notifications',
    'SMS Alerts',
    'Reliable SMS notifications for critical updates — reaches every parent '
        'even without a smartphone.',
  ),
  PlanFeature(
    'ai_marking',
    'AI-Powered Marking',
    'Let artificial intelligence grade assignments and exams in seconds — '
        'freeing teachers to focus on what matters.',
  ),
  PlanFeature(
    'ai_exam_setter',
    'AI Exam Generator',
    'Generate curriculum-aligned exams and assessments instantly with AI — '
        'balanced difficulty, zero bias.',
  ),
  PlanFeature(
    'ai_tutor',
    'Personal AI Tutor',
    'Every student gets a tireless AI tutor that adapts to their learning pace '
        'and masters their weak spots.',
  ),
  PlanFeature(
    'report_cards',
    'Automated Report Cards',
    'Beautiful, accurate report cards generated automatically from grades — '
        'print-ready or share digitally.',
  ),
  PlanFeature(
    'fee_management',
    'Fee & Invoice Manager',
    'Complete fee structure setup, automated invoicing, payment tracking, '
        'and overdue reminders in one place.',
  ),
  PlanFeature(
    'mpesa_payments',
    'M-Pesa Integration',
    'Accept school fee payments directly via M-Pesa — instant reconciliation, '
        'zero paperwork, happy parents.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Grade level encoding (D12)
// ─────────────────────────────────────────────────────────────────────────────

enum GradeLevel {
  ppOne(0, 'PP1', 'Pre-Primary 1'),
  ppTwo(1, 'PP2', 'Pre-Primary 2'),
  grade1(2, 'Grade 1', 'Grade 1'),
  grade2(3, 'Grade 2', 'Grade 2'),
  grade3(4, 'Grade 3', 'Grade 3'),
  grade4(5, 'Grade 4', 'Grade 4'),
  grade5(6, 'Grade 5', 'Grade 5'),
  grade6(7, 'Grade 6', 'Grade 6'),
  grade7(8, 'Grade 7', 'Junior Secondary 1'),
  grade8(9, 'Grade 8', 'Junior Secondary 2'),
  grade9(10, 'Grade 9', 'Junior Secondary 3'),
  grade10(11, 'Grade 10', 'Senior Secondary 1'),
  grade11(12, 'Grade 11', 'Senior Secondary 2'),
  grade12(13, 'Grade 12', 'Senior Secondary 3'),
  form3(14, 'Form 3', 'Form 3 (Legacy 8-4-4)'),
  form4(15, 'Form 4', 'Form 4 (Legacy 8-4-4)');

  const GradeLevel(this.bit, this.label, this.description);

  final int bit;
  final String label;
  final String description;

  int get mask => 1 << bit;
}

/// Returns a comma-separated string of grade level labels for a bitmask.
String gradeLabel(int levels) {
  if (levels == 0) return 'None';
  final labels = <String>[];
  for (final level in GradeLevel.values) {
    if (levels & level.mask != 0) {
      labels.add(level.label);
    }
  }
  return labels.isEmpty ? 'None' : labels.join(', ');
}

// ─────────────────────────────────────────────────────────────────────────────
// CBC Grade Level Groups
// ─────────────────────────────────────────────────────────────────────────────

class GradeLevelGroup {
  const GradeLevelGroup(this.name, this.levels);
  final String name;
  final List<GradeLevel> levels;
}

const kCbcGroups = [
  GradeLevelGroup('Pre-Primary', [GradeLevel.ppOne, GradeLevel.ppTwo]),
  GradeLevelGroup('Lower Primary', [
    GradeLevel.grade1,
    GradeLevel.grade2,
    GradeLevel.grade3,
  ]),
  GradeLevelGroup('Upper Primary', [
    GradeLevel.grade4,
    GradeLevel.grade5,
    GradeLevel.grade6,
  ]),
  GradeLevelGroup('Junior Secondary', [
    GradeLevel.grade7,
    GradeLevel.grade8,
    GradeLevel.grade9,
  ]),
  GradeLevelGroup('Senior Secondary', [
    GradeLevel.grade10,
    GradeLevel.grade11,
    GradeLevel.grade12,
  ]),
  GradeLevelGroup('Legacy 8-4-4', [GradeLevel.form3, GradeLevel.form4]),
];
