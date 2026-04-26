import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Action;

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/daos/catalog_dao.dart';

import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../../models/timetable_rules.dart';
import '../../../../core/extensions.dart';
import '../../../../services/timetable_generator.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../../services/authorization_service.dart';
import '../../../widgets/edu_tab_bar.dart';
import 'lesson_management.dart';
import 'timetable_grid.dart';
import 'timetable_shared.dart';
import 'timetable_wizard.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TIMETABLE SCREEN — Entry point that delegates to role-specific views
// ═════════════════════════════════════════════════════════════════════════════

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const NoTermState();
    }

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: schoolContext.currentEntry,
      builder: (context, entry, _) {
        return switch (entry) {
          OwnerEntry() => _OwnerTimetableShell(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          TeacherEntry() =>
            schoolContext.permissions.can(Resource.classes, Action.update)
                ? _OwnerTimetableShell(
                    schoolContext: schoolContext,
                    termContext: termCtx,
                  )
                : _TeacherTimetableView(
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
          StaffEntry() =>
            schoolContext.permissions.can(Resource.classes, Action.update)
                ? _OwnerTimetableShell(
                    schoolContext: schoolContext,
                    termContext: termCtx,
                  )
                : _StaffReadOnlyTimetableView(
                    schoolContext: schoolContext,
                    termContext: termCtx,
                  ),
        };
      },
    );
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
    with TickerProviderStateMixin {
  final _timetableDao = TimetableDao(db);
  final _catalogDao = CatalogDao(db);

  SchoolConfig? _config;
  TimetableRules? _rules;
  bool _generating = false;
  bool _deleting = false;
  bool _hasTimetable = false;

  late TabController _tabController;
  int _currentTabIndex = 0;

  // Track term to detect changes in didUpdateWidget
  int? _lastYear;
  int? _lastTerm;

  StreamSubscription<bool>? _hasTimetableSub;
  StreamSubscription<List<SchoolStream>>? _configSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _currentTabIndex = _tabController.index);
        }
      });
    final term = widget.termContext.currentTerm;
    _lastYear = term?.year;
    _lastTerm = term?.term;
    _loadConfig();
    _subscribeHasTimetable();
  }

  @override
  void didUpdateWidget(_OwnerTimetableShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final term = widget.termContext.currentTerm;
    final newYear = term?.year;
    final newTerm = term?.term;
    if (newYear != _lastYear || newTerm != _lastTerm) {
      _lastYear = newYear;
      _lastTerm = newTerm;
      _hasTimetableSub?.cancel();
      _hasTimetable = false;
      _rules = null;
      _subscribeHasTimetable();
      _loadConfig();
    }
  }

  void _subscribeHasTimetable() {
    final term = widget.termContext.currentTerm;
    if (term == null) return;
    final schoolId = widget.schoolContext.membership.school.id;
    _hasTimetableSub = _timetableDao
        .watchHasTimetable(schoolId: schoolId, year: term.year, term: term.term)
        .listen((has) {
          if (mounted) setState(() => _hasTimetable = has);
        });
  }

  Future<void> _loadConfig() async {
    final term = widget.termContext.currentTerm;
    final schoolId = widget.schoolContext.membership.school.id;
    final rules = term != null
        ? await FileCache.loadTimetableRules(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
          )
        : TimetableRules.defaults();
    if (!mounted) return;
    setState(() => _rules = rules);

    // Reactively build SchoolConfig from the school's streams table.
    // This mirrors the pattern used by _ExamsTabState._loadConfig().
    _configSub?.cancel();
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      allStreams,
    ) {
      if (!mounted) return;
      setState(() => _config = buildConfigFromStreams(allStreams));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hasTimetableSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }

  Future<void> _openRulesSheet() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _rules == null) return;

    final result = await showTimetableWizardDialog(
      context: context,
      initialRules: _rules!,
      schoolContext: widget.schoolContext,
      termContext: widget.termContext,
      config: _config ?? SchoolConfig.defaults(),
    );

    if (result == null || !mounted) return;

    // Rules were already saved to disk inside the dialog (_save).
    // Only reload the in-memory copy and optionally re-run generation.
    if (mounted) setState(() => _rules = result.rules);

    if (result.shouldGenerate) {
      await _runGeneration(result.rules);
    }
  }

  Future<void> _openGenerateLessonsDialog() async {
    final term = widget.termContext.currentTerm;
    if (term == null) return;
    await showGenerateLessonsDialog(
      context,
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      timetableDao: _timetableDao,
      config: _config ?? SchoolConfig.defaults(),
    );
  }

  Future<void> _deleteTimetable() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _deleting || _generating) return;

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete Timetable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All timetable entries for this term will be permanently '
                  'removed. This cannot be undone.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final account = cache.currentUser;
      if (account == null) return;
      await _timetableDao.clearTermTimetable(
        schoolId: widget.schoolContext.membership.school.id,
        year: term.year,
        term: term.term,
        accountId: account.user.id,
      );
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _runGeneration(TimetableRules rules) async {
    final term = widget.termContext.currentTerm;
    if (term == null || _generating) return;

    setState(() => _generating = true);

    try {
      final schoolId = widget.schoolContext.membership.school.id;

      final assignments = await _timetableDao.getSubjectTeachersForTerm(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
      );

      if (assignments.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No subjects assigned for this term. Assign subjects to classes first.',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      final input = GeneratorInput(assignments: assignments, rules: rules);
      final result = await compute(runTimetableGenerator, input);

      if (!mounted) return;

      if (result is GeneratorFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate timetable: ${result.reason}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      final success = result as GeneratorSuccess;
      final account = cache.currentUser;
      if (account == null || !mounted) return;

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final companions = success.slots
          .map(
            (s) => TimetableCompanion(
              school: Value(s.school),
              year: Value(s.year),
              term: Value(s.term),
              grade: Value(s.grade),
              stream: Value(s.stream),
              subject: Value(s.subjectId),
              teacher: Value(s.teacherUserId),
              day: Value(s.day),
              start: Value(s.startSeconds),
              end: Value(s.endSeconds),
              created: Value(now),
              updated: Value(now),
            ),
          )
          .toList();

      // Clear ALL existing entries for this term — not just the classes present
      // in the new output.  If a previous generation included classes that are
      // no longer in the subject assignments, those stale rows would otherwise
      // remain and cause phantom teacher conflicts in the displayed timetable.
      await _timetableDao.clearTermTimetable(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        accountId: account.user.id,
      );

      await _timetableDao.insertSlots(
        slots: companions,
        accountId: account.user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timetable generated — ${success.slots.length} slots '
              '(${success.iterations} iterations, ${success.elapsed.inMilliseconds}ms)',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (_config == null || _rules == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    final schoolId = widget.schoolContext.membership.school.id;

    final entry = widget.schoolContext.currentEntry.value;
    final perms = widget.schoolContext.permissions;
    final canManage =
        entry is OwnerEntry || perms.can(Resource.classes, Action.update);
    final canDelete =
        entry is OwnerEntry || perms.can(Resource.classes, Action.delete);
    // Generate timetable clears all existing entries (delete) then inserts new
    // ones (update) — requires both classes.update AND classes.delete.
    final canGenerate =
        entry is OwnerEntry ||
        (perms.can(Resource.classes, Action.update) &&
            perms.can(Resource.classes, Action.delete));
    // Generate lessons creates records in the lessons table — requires
    // classes.update (to read timetable context) AND lessons.create.
    final canGenerateLessons =
        entry is OwnerEntry ||
        (perms.can(Resource.classes, Action.update) &&
            perms.can(Resource.lessons, Action.create));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EduTabBar(
            controller: _tabController,
            tabs: const [
              EduTab(label: 'Timetable'),
              EduTab(label: 'Lessons'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 0: School-wide cross-matrix timetable ────────────
                if (term == null)
                  const NoTermState()
                else if (_config!.isEmpty)
                  EmptyConfigState(cs: cs)
                else
                  SchoolWideMatrixTab(
                    schoolId: schoolId,
                    year: term.year,
                    term: term.term,
                    config: _config!,
                    timetableDao: _timetableDao,
                  ),
                // ── Tab 1: All lessons for the school this term ──────────
                if (term != null)
                  LessonsTab(
                    schoolId: schoolId,
                    year: term.year,
                    term: term.term,
                    timetableDao: _timetableDao,
                    config: _config ?? SchoolConfig.defaults(),
                  )
                else
                  const NoTermState(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _currentTabIndex == 0 && (canGenerate || canManage || canDelete)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Delete FAB — shown only when a timetable exists and user can delete
                if (_hasTimetable) ...[
                  if (canDelete)
                    FloatingActionButton.small(
                      heroTag: 'timetable_delete',
                      onPressed: (_deleting || _generating)
                          ? null
                          : _deleteTimetable,
                      backgroundColor: _deleting
                          ? cs.errorContainer.withValues(alpha: 0.5)
                          : cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                      elevation: 2,
                      tooltip: 'Delete timetable',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                      ),
                      child: _deleting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: cs.onErrorContainer,
                              ),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 18),
                    ),
                  if (canDelete) const SizedBox(height: 12),
                  // Generate Lessons FAB — requires classes.update + lessons.create
                  if (canGenerateLessons)
                    GenerateLessonsFab(
                      heroTag: 'timetable_gen_lessons',
                      onTap: _openGenerateLessonsDialog,
                      cs: cs,
                    ),
                ] else ...[
                  // No timetable yet — show the wizard FAB (requires classes.update + classes.delete)
                  if (canGenerate)
                    GenerateFab(
                      heroTag: 'timetable_generate',
                      onTap: _openRulesSheet,
                      generating: _generating,
                      cs: cs,
                    ),
                ],
              ],
            )
          : null,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER VIEW — Personal timetable (read-only)
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
  final _catalogDao = CatalogDao(db);
  SchoolConfig? _config;
  StreamSubscription<List<SchoolStream>>? _configSub;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final schoolId = widget.schoolContext.membership.school.id;
    _configSub?.cancel();
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      streams,
    ) {
      if (mounted) setState(() => _config = buildConfigFromStreams(streams));
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
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
    final currentUser = cache.currentUser;

    if (term == null || _config == null || currentUser == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    final schoolId = widget.schoolContext.membership.school.id;

    // Use actual user data from the authenticated account instead of
    // constructing a pseudo-user with empty phone / zero timestamps.
    final actualUser = currentUser.user;

    return StreamBuilder<List<TimetableData>>(
      stream: _timetableDao.watchTeacherTimetable(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        teacherUserId: _teacherUserId,
      ),
      builder: (context, snapshot) {
        final slots = snapshot.data ?? [];

        final entries = slots
            .map(
              (s) => TimetableEntry(
                slot: s,
                teacher: actualUser,
                subjectName: subjectLabel(s.subject, _config!),
              ),
            )
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > AppTheme.kMobileBreakpoint) {
              return TeacherDesktopGrid(
                entries: entries,
                config: _config!,
                cs: cs,
              );
            }
            return TeacherMobilePager(entries: entries, config: _config!);
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAFF READ-ONLY VIEW — School-wide matrix, no admin controls
// ═════════════════════════════════════════════════════════════════════════════

class _StaffReadOnlyTimetableView extends StatefulWidget {
  const _StaffReadOnlyTimetableView({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_StaffReadOnlyTimetableView> createState() =>
      _StaffReadOnlyTimetableViewState();
}

class _StaffReadOnlyTimetableViewState
    extends State<_StaffReadOnlyTimetableView> {
  final _timetableDao = TimetableDao(db);
  final _catalogDao = CatalogDao(db);
  SchoolConfig? _config;
  StreamSubscription<List<SchoolStream>>? _configSub;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final schoolId = widget.schoolContext.membership.school.id;
    _configSub?.cancel();
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      streams,
    ) {
      if (mounted) setState(() => _config = buildConfigFromStreams(streams));
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (_config == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    if (term == null) return const NoTermState();
    if (_config!.isEmpty) return EmptyConfigState(cs: cs);

    return SchoolWideMatrixTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      config: _config!,
      timetableDao: _timetableDao,
    );
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
  final _catalogDao = CatalogDao(db);
  SchoolConfig? _config;
  StreamSubscription<List<SchoolStream>>? _configSub;

  // Student enrollment info for current term
  int? _grade;
  int? _stream;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribeConfig();
    _loadData();
  }

  void _subscribeConfig() {
    final schoolId = widget.schoolContext.membership.school.id;
    _configSub?.cancel();
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      streams,
    ) {
      if (mounted) setState(() => _config = buildConfigFromStreams(streams));
    });
  }

  @override
  void didUpdateWidget(_ClassTimetableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTerm = oldWidget.termContext.currentTerm;
    final newTerm = widget.termContext.currentTerm;
    if (oldWidget.studentAdm != widget.studentAdm ||
        oldTerm?.year != newTerm?.year ||
        oldTerm?.term != newTerm?.term) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    _grade = null;
    _stream = null;
    setState(() => _loading = true);

    final schoolId = widget.schoolContext.membership.school.id;
    final term = widget.termContext.currentTerm;

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
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (_loading || term == null || _config == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    if (_grade == null) {
      return NotEnrolledState(cs: cs);
    }

    return TimetableGridView(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: _grade!,
      stream: _stream,
      config: _config!,
      dao: _timetableDao,
    );
  }
}
