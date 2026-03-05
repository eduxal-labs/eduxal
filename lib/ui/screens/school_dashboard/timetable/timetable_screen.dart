import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/settings_dao.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_tab_bar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Constants
// ═════════════════════════════════════════════════════════════════════════════

/// School days shown in the timetable grid — Monday through Friday.
const _kSchoolDays = [
  DayOfWeek.monday,
  DayOfWeek.tuesday,
  DayOfWeek.wednesday,
  DayOfWeek.thursday,
  DayOfWeek.friday,
];

const _kDayLabels = {
  DayOfWeek.sunday: 'Sun',
  DayOfWeek.monday: 'Mon',
  DayOfWeek.tuesday: 'Tue',
  DayOfWeek.wednesday: 'Wed',
  DayOfWeek.thursday: 'Thu',
  DayOfWeek.friday: 'Fri',
  DayOfWeek.saturday: 'Sat',
};

const _kDayLabelsFull = {
  DayOfWeek.sunday: 'Sunday',
  DayOfWeek.monday: 'Monday',
  DayOfWeek.tuesday: 'Tuesday',
  DayOfWeek.wednesday: 'Wednesday',
  DayOfWeek.thursday: 'Thursday',
  DayOfWeek.friday: 'Friday',
  DayOfWeek.saturday: 'Saturday',
};

/// Default school day start/end in seconds since midnight.
const _kDefaultDayStart = 8 * 3600; // 08:00
const _kDefaultDayEnd = 16 * 3600; // 16:00

/// Palette for subject colour coding — subtle, muted pastels.
const _kSubjectColors = [
  Color(0xFF6366F1), // indigo
  Color(0xFF06B6D4), // cyan
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFF14B8A6), // teal
  Color(0xFFF97316), // orange
  Color(0xFF3B82F6), // blue
  Color(0xFF84CC16), // lime
  Color(0xFFE11D48), // rose
];

Color _colorForSubject(int subjectCode) {
  return _kSubjectColors[subjectCode.abs() % _kSubjectColors.length];
}

// ═════════════════════════════════════════════════════════════════════════════
// Entry Point
// ═════════════════════════════════════════════════════════════════════════════

/// Top-level entry point for the Timetable section.
///
/// Role dispatch:
/// - **Owner:** Full management — rules config, generation CTA, and grid view
///   with class selector.
/// - **Teacher:** Personal weekly schedule across all assigned classes.
/// - **Student:** Class timetable for the student's enrolled class.
/// - **Guardian:** Ward's class timetable (read-only).
/// - **Staff:** School-wide timetable overview (read-only).
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
    }

    final entry = schoolContext.currentEntry.value;

    return switch (entry) {
      OwnerEntry() => _OwnerTimetableShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      TeacherEntry() => _TeacherTimetableView(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      StudentEntry(:final student) => _ClassTimetableView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: student.adm,
      ),
      GuardianEntry(:final ward) => _ClassTimetableView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: ward.adm,
      ),
      StaffEntry() => _OwnerTimetableShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER / ADMIN SHELL — Rules + Grid with class selector
// ═════════════════════════════════════════════════════════════════════════════

class _OwnerTimetableShell extends StatefulWidget {
  const _OwnerTimetableShell({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_OwnerTimetableShell> createState() => _OwnerTimetableShellState();
}

class _OwnerTimetableShellState extends State<_OwnerTimetableShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _timetableDao = TimetableDao(db);
  final _settingsDao = SettingsDao(db);

  SchoolConfig? _config;
  int? _selectedGrade;
  int? _selectedStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final row = await _settingsDao.getSettings(
      widget.schoolContext.membership.school.id,
    );
    if (row != null && mounted) {
      try {
        final json = jsonDecode(row.data);
        if (json is Map<String, dynamic>) {
          final config = SchoolConfig.fromJson(json);
          setState(() {
            _config = config;
            // Auto-select first grade+stream if available
            if (config.curricula.isNotEmpty) {
              final firstCurriculum = config.curricula.first;
              if (firstCurriculum.grades.isNotEmpty) {
                final firstGrade = firstCurriculum.grades.first;
                _selectedGrade = firstGrade.grade;
                if (firstGrade.streams.isNotEmpty) {
                  _selectedStream = firstGrade.streams.first.code;
                }
              }
            }
          });
        }
      } catch (_) {
        setState(() => _config = SchoolConfig.defaults());
      }
    } else if (mounted) {
      setState(() => _config = SchoolConfig.defaults());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_config == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    return Column(
      children: [
        EduTabBar(
          controller: _tabController,
          tabs: const [
            EduTab(label: 'Schedule'),
            EduTab(label: 'Rules'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OwnerScheduleTab(
                schoolContext: widget.schoolContext,
                termContext: widget.termContext,
                config: _config!,
                timetableDao: _timetableDao,
                selectedGrade: _selectedGrade,
                selectedStream: _selectedStream,
                onClassSelected: (grade, stream) {
                  setState(() {
                    _selectedGrade = grade;
                    _selectedStream = stream;
                  });
                },
              ),
              _RulesTab(
                schoolContext: widget.schoolContext,
                termContext: widget.termContext,
                config: _config!,
                timetableDao: _timetableDao,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER — Schedule Tab (Class selector + Grid)
// ═════════════════════════════════════════════════════════════════════════════

class _OwnerScheduleTab extends StatelessWidget {
  const _OwnerScheduleTab({
    required this.schoolContext,
    required this.termContext,
    required this.config,
    required this.timetableDao,
    required this.selectedGrade,
    required this.selectedStream,
    required this.onClassSelected,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final SchoolConfig config;
  final TimetableDao timetableDao;
  final int? selectedGrade;
  final int? selectedStream;
  final void Function(int grade, int stream) onClassSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;

    if (term == null || config.isEmpty) {
      return _EmptyConfigState(cs: cs);
    }

    // Build the class list from config
    final classes = <({int grade, int stream, String label})>[];
    for (final curriculum in config.curricula) {
      final labels = gradeLabelsFor(curriculum.type);
      for (final gc in curriculum.grades) {
        for (final s in gc.streams) {
          classes.add((
            grade: gc.grade,
            stream: s.code,
            label: '${labels[gc.grade] ?? 'Grade ${gc.grade}'} — ${s.name}',
          ));
        }
      }
    }

    if (classes.isEmpty) {
      return _EmptyConfigState(cs: cs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Class selector strip
        _ClassSelectorStrip(
          classes: classes,
          selectedGrade: selectedGrade,
          selectedStream: selectedStream,
          onClassSelected: onClassSelected,
          cs: cs,
        ),
        // Timetable grid
        Expanded(
          child: (selectedGrade != null && selectedStream != null)
              ? _TimetableGridView(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                  grade: selectedGrade!,
                  stream: selectedStream!,
                  config: config,
                  dao: timetableDao,
                )
              : Center(
                  child: Text(
                    'Select a class to view its timetable',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Class selector strip
// ─────────────────────────────────────────────────────────────────────────────

class _ClassSelectorStrip extends StatelessWidget {
  const _ClassSelectorStrip({
    required this.classes,
    required this.selectedGrade,
    required this.selectedStream,
    required this.onClassSelected,
    required this.cs,
  });

  final List<({int grade, int stream, String label})> classes;
  final int? selectedGrade;
  final int? selectedStream;
  final void Function(int grade, int stream) onClassSelected;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: classes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final c = classes[index];
          final isSelected =
              c.grade == selectedGrade && c.stream == selectedStream;
          return _ClassChip(
            label: c.label,
            isSelected: isSelected,
            cs: cs,
            onTap: () => onClassSelected(c.grade, c.stream),
          );
        },
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.label,
    required this.isSelected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RULES TAB — Timetable constraints for GA
// ═════════════════════════════════════════════════════════════════════════════

/// Key used to persist timetable rules in settings.data JSON under a
/// "timetable_rules" sub-key.
const _kRulesKey = 'timetable_rules';

class _TimetableRules {
  _TimetableRules({
    this.dayStartSeconds = _kDefaultDayStart,
    this.dayEndSeconds = _kDefaultDayEnd,
    this.lessonDurationMinutes = 40,
    this.breakDurationMinutes = 10,
    this.maxLessonsPerDayTeacher = 6,
    this.allowDoubles = false,
    this.lunchStartSeconds = 12 * 3600 + 30 * 60,
    this.lunchDurationMinutes = 60,
    this.activeDays = const [
      DayOfWeek.monday,
      DayOfWeek.tuesday,
      DayOfWeek.wednesday,
      DayOfWeek.thursday,
      DayOfWeek.friday,
    ],
  });

  int dayStartSeconds;
  int dayEndSeconds;
  int lessonDurationMinutes;
  int breakDurationMinutes;
  int maxLessonsPerDayTeacher;
  bool allowDoubles;
  int lunchStartSeconds;
  int lunchDurationMinutes;
  List<DayOfWeek> activeDays;

  factory _TimetableRules.fromJson(Map<String, dynamic> json) {
    return _TimetableRules(
      dayStartSeconds:
          (json['day_start'] as num?)?.toInt() ?? _kDefaultDayStart,
      dayEndSeconds: (json['day_end'] as num?)?.toInt() ?? _kDefaultDayEnd,
      lessonDurationMinutes: (json['lesson_duration'] as num?)?.toInt() ?? 40,
      breakDurationMinutes: (json['break_duration'] as num?)?.toInt() ?? 10,
      maxLessonsPerDayTeacher:
          (json['max_lessons_teacher'] as num?)?.toInt() ?? 6,
      allowDoubles: json['allow_doubles'] as bool? ?? false,
      lunchStartSeconds:
          (json['lunch_start'] as num?)?.toInt() ?? (12 * 3600 + 30 * 60),
      lunchDurationMinutes: (json['lunch_duration'] as num?)?.toInt() ?? 60,
      activeDays:
          (json['active_days'] as List<dynamic>?)
              ?.map((e) => DayOfWeek.values[(e as num).toInt()])
              .toList() ??
          _kSchoolDays.toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'day_start': dayStartSeconds,
    'day_end': dayEndSeconds,
    'lesson_duration': lessonDurationMinutes,
    'break_duration': breakDurationMinutes,
    'max_lessons_teacher': maxLessonsPerDayTeacher,
    'allow_doubles': allowDoubles,
    'lunch_start': lunchStartSeconds,
    'lunch_duration': lunchDurationMinutes,
    'active_days': activeDays.map((d) => d.index).toList(),
  };
}

class _RulesTab extends StatefulWidget {
  const _RulesTab({
    required this.schoolContext,
    required this.termContext,
    required this.config,
    required this.timetableDao,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final SchoolConfig config;
  final TimetableDao timetableDao;

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  final _settingsDao = SettingsDao(db);
  late _TimetableRules _rules;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _rules = _TimetableRules();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final row = await _settingsDao.getSettings(
      widget.schoolContext.membership.school.id,
    );
    if (row != null && mounted) {
      try {
        final json = jsonDecode(row.data);
        if (json is Map<String, dynamic> &&
            json[_kRulesKey] is Map<String, dynamic>) {
          _rules = _TimetableRules.fromJson(
            json[_kRulesKey] as Map<String, dynamic>,
          );
        }
      } catch (_) {
        // use defaults
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveRules() async {
    setState(() => _saving = true);
    try {
      final schoolId = widget.schoolContext.membership.school.id;
      final row = await _settingsDao.getSettings(schoolId);

      Map<String, dynamic> dataMap = {};
      if (row != null) {
        try {
          final decoded = jsonDecode(row.data);
          if (decoded is Map<String, dynamic>) {
            dataMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      dataMap[_kRulesKey] = _rules.toJson();

      // Preserve the full data map including the rules key
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;

      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      if (row != null) {
        await db.transaction(() async {
          await (db.update(
            db.settings,
          )..where((t) => t.school.equals(schoolId))).write(
            SettingsCompanion(
              data: Value(jsonEncode(dataMap)),
              updated: Value(nowSeconds),
            ),
          );
        });
      } else {
        await db
            .into(db.settings)
            .insert(
              SettingsCompanion(
                school: Value(schoolId),
                data: Value(jsonEncode(dataMap)),
                mpesa: const Value(null),
                created: Value(nowSeconds),
                updated: Value(nowSeconds),
              ),
            );
      }

      if (mounted) {
        setState(() {
          _dirty = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Timetable rules saved'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _generate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Timetable generation algorithm pending implementation.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_loading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > AppTheme.kMobileBreakpoint;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                  vertical: 16,
                ),
                child: isWide
                    ? _buildWideRulesLayout(cs, isDark)
                    : _buildNarrowRulesLayout(cs, isDark),
              ),
            ),
            _RulesActionBar(
              dirty: _dirty,
              saving: _saving,
              onSave: _saveRules,
              onGenerate: _generate,
              cs: cs,
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideRulesLayout(ColorScheme cs, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RulesSection(
            title: 'Time Configuration',
            cs: cs,
            isDark: isDark,
            children: _buildTimeRules(cs, isDark),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _RulesSection(
                title: 'Teacher Constraints',
                cs: cs,
                isDark: isDark,
                children: _buildTeacherRules(cs, isDark),
              ),
              const SizedBox(height: 16),
              _RulesSection(
                title: 'Active Days',
                cs: cs,
                isDark: isDark,
                children: _buildDayRules(cs, isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowRulesLayout(ColorScheme cs, bool isDark) {
    return Column(
      children: [
        _RulesSection(
          title: 'Time Configuration',
          cs: cs,
          isDark: isDark,
          children: _buildTimeRules(cs, isDark),
        ),
        const SizedBox(height: 16),
        _RulesSection(
          title: 'Teacher Constraints',
          cs: cs,
          isDark: isDark,
          children: _buildTeacherRules(cs, isDark),
        ),
        const SizedBox(height: 16),
        _RulesSection(
          title: 'Active Days',
          cs: cs,
          isDark: isDark,
          children: _buildDayRules(cs, isDark),
        ),
      ],
    );
  }

  List<Widget> _buildTimeRules(ColorScheme cs, bool isDark) {
    return [
      _RuleRow(
        label: 'Day starts at',
        cs: cs,
        child: _TimePickerButton(
          seconds: _rules.dayStartSeconds,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.dayStartSeconds = v);
            _markDirty();
          },
        ),
      ),
      _ruleDivider(cs),
      _RuleRow(
        label: 'Day ends at',
        cs: cs,
        child: _TimePickerButton(
          seconds: _rules.dayEndSeconds,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.dayEndSeconds = v);
            _markDirty();
          },
        ),
      ),
      _ruleDivider(cs),
      _RuleRow(
        label: 'Lesson duration',
        cs: cs,
        child: _StepperControl(
          value: _rules.lessonDurationMinutes,
          suffix: 'min',
          min: 20,
          max: 90,
          step: 5,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.lessonDurationMinutes = v);
            _markDirty();
          },
        ),
      ),
      _ruleDivider(cs),
      _RuleRow(
        label: 'Break between lessons',
        cs: cs,
        child: _StepperControl(
          value: _rules.breakDurationMinutes,
          suffix: 'min',
          min: 0,
          max: 30,
          step: 5,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.breakDurationMinutes = v);
            _markDirty();
          },
        ),
      ),
      _ruleDivider(cs),
      _RuleRow(
        label: 'Lunch break starts at',
        cs: cs,
        child: _TimePickerButton(
          seconds: _rules.lunchStartSeconds,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.lunchStartSeconds = v);
            _markDirty();
          },
        ),
      ),
      _ruleDivider(cs),
      _RuleRow(
        label: 'Lunch break duration',
        cs: cs,
        child: _StepperControl(
          value: _rules.lunchDurationMinutes,
          suffix: 'min',
          min: 15,
          max: 90,
          step: 5,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.lunchDurationMinutes = v);
            _markDirty();
          },
        ),
      ),
    ];
  }

  List<Widget> _buildTeacherRules(ColorScheme cs, bool isDark) {
    return [
      _RuleRow(
        label: 'Max lessons per day (teacher)',
        cs: cs,
        child: _StepperControl(
          value: _rules.maxLessonsPerDayTeacher,
          suffix: '',
          min: 1,
          max: 10,
          step: 1,
          cs: cs,
          onChanged: (v) {
            setState(() => _rules.maxLessonsPerDayTeacher = v);
            _markDirty();
          },
        ),
      ),
      _ruleDivider(cs),
      _RuleRow(
        label: 'Allow double lessons',
        cs: cs,
        child: Switch.adaptive(
          value: _rules.allowDoubles,
          activeTrackColor: cs.primary,
          onChanged: (v) {
            setState(() => _rules.allowDoubles = v);
            _markDirty();
          },
        ),
      ),
    ];
  }

  List<Widget> _buildDayRules(ColorScheme cs, bool isDark) {
    return DayOfWeek.values.map((day) {
      final isActive = _rules.activeDays.contains(day);
      return _DayToggle(
        day: day,
        isActive: isActive,
        cs: cs,
        onToggle: (active) {
          setState(() {
            if (active) {
              if (!_rules.activeDays.contains(day)) {
                _rules.activeDays.add(day);
              }
            } else {
              _rules.activeDays.remove(day);
            }
          });
          _markDirty();
        },
      );
    }).toList();
  }

  Widget _ruleDivider(ColorScheme cs) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: cs.outlineVariant.withValues(alpha: 0.2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rules sub-components
// ─────────────────────────────────────────────────────────────────────────────

class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.title,
    required this.cs,
    required this.isDark,
    required this.children,
  });

  final String title;
  final ColorScheme cs;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.cs, required this.child});

  final String label;
  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.seconds,
    required this.cs,
    required this.onChanged,
  });

  final int seconds;
  final ColorScheme cs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final label =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: h, minute: m),
        );
        if (picked != null) {
          onChanged(picked.hour * 3600 + picked.minute * 60);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.suffix,
    required this.min,
    required this.max,
    required this.step,
    required this.cs,
    required this.onChanged,
  });

  final int value;
  final String suffix;
  final int min;
  final int max;
  final int step;
  final ColorScheme cs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            enabled: value > min,
            cs: cs,
            onTap: () {
              if (value - step >= min) onChanged(value - step);
            },
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              suffix.isNotEmpty ? '$value $suffix' : '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: value < max,
            cs: cs,
            onTap: () {
              if (value + step <= max) onChanged(value + step);
            },
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.cs,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? cs.onSurface.withValues(alpha: 0.7)
              : cs.onSurfaceVariant.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.day,
    required this.isActive,
    required this.cs,
    required this.onToggle,
  });

  final DayOfWeek day;
  final bool isActive;
  final ColorScheme cs;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _kDayLabelsFull[day]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          Switch.adaptive(
            value: isActive,
            activeTrackColor: cs.primary,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _RulesActionBar extends StatelessWidget {
  const _RulesActionBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onGenerate,
    required this.cs,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onGenerate;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Save button
          Expanded(
            child: _ActionButton(
              label: saving ? 'Saving…' : 'Save Rules',
              icon: Icons.save_outlined,
              color: dirty
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
              cs: cs,
              onTap: dirty && !saving ? onSave : null,
            ),
          ),
          const SizedBox(width: 12),
          // Generate button
          Expanded(
            child: _GenerateButton(cs: cs, onTap: onGenerate),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.cs, required this.onTap});

  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    cs.primary.withValues(alpha: 0.25),
                    cs.primary.withValues(alpha: 0.15),
                  ]
                : [
                    cs.primary.withValues(alpha: 0.12),
                    cs.primary.withValues(alpha: 0.06),
                  ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Generate Timetable',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TIMETABLE GRID VIEW — Responsive: Desktop grid / Mobile day pager
// ═════════════════════════════════════════════════════════════════════════════

class _TimetableGridView extends StatelessWidget {
  const _TimetableGridView({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.config,
    required this.dao,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final SchoolConfig config;
  final TimetableDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimetableEntry>>(
      stream: dao.watchClassTimetable(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
      ),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > AppTheme.kMobileBreakpoint) {
              return _DesktopGrid(entries: entries, config: config);
            }
            return _MobileDayPager(entries: entries, config: config);
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DESKTOP GRID — Classic weekly grid
// ═════════════════════════════════════════════════════════════════════════════

class _DesktopGrid extends StatelessWidget {
  const _DesktopGrid({required this.entries, required this.config});

  final List<TimetableEntry> entries;
  final SchoolConfig config;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (entries.isEmpty) {
      return _EmptyTimetableState(cs: cs);
    }

    // Group by day
    final byDay = <DayOfWeek, List<TimetableEntry>>{};
    for (final entry in entries) {
      byDay.putIfAbsent(entry.slot.day, () => []).add(entry);
    }

    // Find the time range
    int minStart = _kDefaultDayStart;
    int maxEnd = _kDefaultDayEnd;
    for (final entry in entries) {
      if (entry.slot.start < minStart) minStart = entry.slot.start;
      if (entry.slot.end > maxEnd) maxEnd = entry.slot.end;
    }

    // Generate time labels (every hour)
    final timeLabels = <int>[];
    int t = (minStart ~/ 3600) * 3600;
    while (t <= maxEnd) {
      timeLabels.add(t);
      t += 3600;
    }

    final totalSeconds = maxEnd - minStart;
    final availableHeight = (timeLabels.length) * 64.0;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Day headers
            _GridHeader(cs: cs),
            // Grid body
            SizedBox(
              height: availableHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Time gutter
                  SizedBox(
                    width: 56,
                    child: _TimeGutter(
                      timeLabels: timeLabels,
                      minStart: minStart,
                      totalSeconds: totalSeconds,
                      height: availableHeight,
                      cs: cs,
                    ),
                  ),
                  // Day columns
                  ..._kSchoolDays.map((day) {
                    final dayEntries = byDay[day] ?? [];
                    return Expanded(
                      child: _DayColumn(
                        entries: dayEntries,
                        minStart: minStart,
                        totalSeconds: totalSeconds,
                        height: availableHeight,
                        config: config,
                        cs: cs,
                        isDark: isDark,
                        isLast: day == _kSchoolDays.last,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 56), // time gutter space
          ..._kSchoolDays.map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  _kDayLabels[day]!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({
    required this.timeLabels,
    required this.minStart,
    required this.totalSeconds,
    required this.height,
    required this.cs,
  });

  final List<int> timeLabels;
  final int minStart;
  final int totalSeconds;
  final double height;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: timeLabels.map((t) {
        final fraction = totalSeconds > 0 ? (t - minStart) / totalSeconds : 0.0;
        final top = fraction * height;
        final h = t ~/ 3600;
        final m = (t % 3600) ~/ 60;
        return Positioned(
          top: top - 7,
          left: 0,
          right: 4,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.entries,
    required this.minStart,
    required this.totalSeconds,
    required this.height,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.isLast,
  });

  final List<TimetableEntry> entries;
  final int minStart;
  final int totalSeconds;
  final double height;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        children: entries.map((entry) {
          final topFrac = totalSeconds > 0
              ? (entry.slot.start - minStart) / totalSeconds
              : 0.0;
          final bottomFrac = totalSeconds > 0
              ? (entry.slot.end - minStart) / totalSeconds
              : 0.0;
          final top = topFrac * height;
          final slotHeight = (bottomFrac - topFrac) * height;

          final color = _colorForSubject(entry.slot.subject);

          return Positioned(
            top: top + 1,
            left: 2,
            right: 2,
            height: slotHeight - 2,
            child: _SlotBlock(
              entry: entry,
              color: color,
              config: config,
              cs: cs,
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SlotBlock extends StatelessWidget {
  const _SlotBlock({
    required this.entry,
    required this.color,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final TimetableEntry entry;
  final Color color;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subjectLabel = _subjectLabel(entry.slot.subject, config);
    final timeLabel =
        '${_fmtTime(entry.slot.start)} – ${_fmtTime(entry.slot.end)}';

    return Tooltip(
      message: '$subjectLabel\n${entry.teacher.name}\n$timeLabel',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showTeacher = constraints.maxHeight > 40;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subjectLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? color.withValues(alpha: 0.9) : color,
                    height: 1.2,
                  ),
                ),
                if (showTeacher) ...[
                  const SizedBox(height: 1),
                  Text(
                    entry.teacher.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MOBILE DAY PAGER — Vertical timeline per day
// ═════════════════════════════════════════════════════════════════════════════

class _MobileDayPager extends StatefulWidget {
  const _MobileDayPager({required this.entries, required this.config});

  final List<TimetableEntry> entries;
  final SchoolConfig config;

  @override
  State<_MobileDayPager> createState() => _MobileDayPagerState();
}

class _MobileDayPagerState extends State<_MobileDayPager> {
  late final PageController _pageController;
  int _currentPage = 0; // Monday = 0

  @override
  void initState() {
    super.initState();
    // Start on current weekday if it's a school day, else Monday
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon..7=Sun
    _currentPage = weekday >= 1 && weekday <= 5 ? weekday - 1 : 0;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (widget.entries.isEmpty) {
      return _EmptyTimetableState(cs: cs);
    }

    // Group by day
    final byDay = <DayOfWeek, List<TimetableEntry>>{};
    for (final entry in widget.entries) {
      byDay.putIfAbsent(entry.slot.day, () => []).add(entry);
    }

    return Column(
      children: [
        // Day selector strip
        _MobileDayStrip(
          currentIndex: _currentPage,
          cs: cs,
          isDark: isDark,
          onDaySelected: (index) {
            setState(() => _currentPage = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          },
        ),
        // Day pages
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _kSchoolDays.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final day = _kSchoolDays[index];
              final dayEntries = byDay[day] ?? [];
              return _MobileDayTimeline(
                day: day,
                entries: dayEntries,
                config: widget.config,
                cs: cs,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobileDayStrip extends StatelessWidget {
  const _MobileDayStrip({
    required this.currentIndex,
    required this.cs,
    required this.isDark,
    required this.onDaySelected,
  });

  final int currentIndex;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_kSchoolDays.length, (index) {
          final isSelected = index == currentIndex;
          final day = _kSchoolDays[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.16 : 0.07,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _kDayLabels[day]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MobileDayTimeline extends StatelessWidget {
  const _MobileDayTimeline({
    required this.day,
    required this.entries,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final DayOfWeek day;
  final List<TimetableEntry> entries;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 28,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10),
            Text(
              'No lessons on ${_kDayLabelsFull[day]}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Sort by start time
    final sorted = List.of(entries)
      ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _MobileLessonCard(
          entry: sorted[index],
          config: config,
          cs: cs,
          isDark: isDark,
          index: index,
        );
      },
    );
  }
}

class _MobileLessonCard extends StatelessWidget {
  const _MobileLessonCard({
    required this.entry,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.index,
  });

  final TimetableEntry entry;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = _colorForSubject(entry.slot.subject);
    final subjectLabel = _subjectLabel(entry.slot.subject, config);
    final startLabel = _fmtTime(entry.slot.start);
    final endLabel = _fmtTime(entry.slot.end);
    final durationMin = (entry.slot.end - entry.slot.start) ~/ 60;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Colour accent bar
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          // Time column
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  endLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 40,
            color: cs.outlineVariant.withValues(alpha: 0.15),
          ),
          // Subject info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjectLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.teacher.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Duration badge
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${durationMin}m',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER VIEW — Personal weekly schedule
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherTimetableView extends StatefulWidget {
  const _TeacherTimetableView({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_TeacherTimetableView> createState() => _TeacherTimetableViewState();
}

class _TeacherTimetableViewState extends State<_TeacherTimetableView> {
  final _timetableDao = TimetableDao(db);
  final _settingsDao = SettingsDao(db);
  SchoolConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final row = await _settingsDao.getSettings(
      widget.schoolContext.membership.school.id,
    );
    if (row != null && mounted) {
      try {
        final json = jsonDecode(row.data);
        if (json is Map<String, dynamic>) {
          setState(() => _config = SchoolConfig.fromJson(json));
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _config = SchoolConfig.defaults());
  }

  String get _teacherUserId {
    final entry = widget.schoolContext.currentEntry.value;
    if (entry is TeacherEntry) return entry.teacher.user;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (term == null || _config == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    final schoolId = widget.schoolContext.membership.school.id;

    return StreamBuilder<List<TimetableData>>(
      stream: _timetableDao.watchTeacherTimetable(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        teacherUserId: _teacherUserId,
      ),
      builder: (context, snapshot) {
        final slots = snapshot.data ?? [];

        // Convert TimetableData to TimetableEntry with a "self" teacher user
        // We create a pseudo-user for display (teacher name comes from the
        // account data already visible in the dashboard).
        final teacherName = cache.currentUser?.user.name ?? 'You';
        final pseudoUser = UsersData(
          id: _teacherUserId,
          phone: '',
          name: teacherName,
          level: UserLevel.normal,
          status: UserStatus.active,
          created: BigInt.zero,
          updated: BigInt.zero,
        );

        final entries = slots
            .map((s) => TimetableEntry(slot: s, teacher: pseudoUser))
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > AppTheme.kMobileBreakpoint) {
              return _TeacherDesktopGrid(
                entries: entries,
                config: _config!,
                cs: cs,
              );
            }
            return _MobileDayPager(entries: entries, config: _config!);
          },
        );
      },
    );
  }
}

class _TeacherDesktopGrid extends StatelessWidget {
  const _TeacherDesktopGrid({
    required this.entries,
    required this.config,
    required this.cs,
  });

  final List<TimetableEntry> entries;
  final SchoolConfig config;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyTimetableState(cs: cs);
    }

    // For teacher grid we show class info instead of teacher name
    return _DesktopGrid(entries: entries, config: config);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STUDENT / GUARDIAN VIEW — Class timetable (read-only)
// ═════════════════════════════════════════════════════════════════════════════

class _ClassTimetableView extends StatefulWidget {
  const _ClassTimetableView({
    required this.schoolContext,
    required this.termContext,
    required this.studentAdm,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final int studentAdm;

  @override
  State<_ClassTimetableView> createState() => _ClassTimetableViewState();
}

class _ClassTimetableViewState extends State<_ClassTimetableView> {
  final _timetableDao = TimetableDao(db);
  final _settingsDao = SettingsDao(db);
  SchoolConfig? _config;

  // Student enrollment info for current term
  int? _grade;
  int? _stream;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_ClassTimetableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentAdm != widget.studentAdm) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final schoolId = widget.schoolContext.membership.school.id;
    final term = widget.termContext.currentTerm;

    // Load config
    final row = await _settingsDao.getSettings(schoolId);
    if (row != null) {
      try {
        final json = jsonDecode(row.data);
        if (json is Map<String, dynamic>) {
          _config = SchoolConfig.fromJson(json);
        }
      } catch (_) {}
    }
    _config ??= SchoolConfig.defaults();

    // Find student enrollment for current term
    if (term != null) {
      final enrollment =
          await (db.select(db.enrollments)..where(
                (t) =>
                    t.school.equals(schoolId) &
                    t.year.equals(term.year) &
                    t.term.equals(term.term) &
                    t.student.equals(widget.studentAdm),
              ))
              .getSingleOrNull();

      if (enrollment != null) {
        _grade = enrollment.grade;
        _stream = enrollment.stream;
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (_loading || term == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    if (_grade == null || _stream == null) {
      return _NotEnrolledState(cs: cs);
    }

    return _TimetableGridView(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: _grade!,
      stream: _stream!,
      config: _config!,
      dao: _timetableDao,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BLANK / EMPTY STATES
// ═════════════════════════════════════════════════════════════════════════════

class _NoTermState extends StatelessWidget {
  const _NoTermState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.event_busy_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No term selected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create a term to manage the timetable',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimetableState extends StatelessWidget {
  const _EmptyTimetableState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_view_week_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No timetable yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Configure rules and generate a schedule',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConfigState extends StatelessWidget {
  const _EmptyConfigState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No classes configured',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Set up grades and streams in Academics first',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEnrolledState extends StatelessWidget {
  const _NotEnrolledState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_off_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Not enrolled',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Student is not enrolled in a class this term',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═════════════════════════════════════════════════════════════════════════════

/// Formats seconds-since-midnight to HH:MM string.
String _fmtTime(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _subjectLabel(int subjectCode, SchoolConfig config) {
  // Try CBC first, then 8-4-4
  try {
    final cbcSubject = CbcSubject.values.firstWhere(
      (s) => s.index_ == subjectCode,
    );
    return cbcSubject.label;
  } catch (_) {}
  try {
    final subject844 = EightFourFourSubject.values.firstWhere(
      (s) => s.index_ == subjectCode,
    );
    return subject844.label;
  } catch (_) {}
  return 'Subject $subjectCode';
}
