import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../client.dart';
import '../../database/database.dart';
import '../../database/daos/terms_dao.dart';
import '../theme/app_theme.dart';
import 'date_range_picker.dart';
import 'term_buttons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

Future<Term?> showCreateTermModal({
  required BuildContext context,
  required String schoolId,
}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<Term>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _CreateTermDialog(schoolId: schoolId),
    );
  }
  return showModalBottomSheet<Term>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateTermSheet(schoolId: schoolId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point — edit existing term
// ─────────────────────────────────────────────────────────────────────────────

Future<Term?> showEditTermModal({
  required BuildContext context,
  required String schoolId,
  required Term term,
}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<Term>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _CreateTermDialog(schoolId: schoolId, existingTerm: term),
    );
  }
  return showModalBottomSheet<Term>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateTermSheet(schoolId: schoolId, existingTerm: term),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop dialog wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTermDialog extends StatelessWidget {
  const _CreateTermDialog({required this.schoolId, this.existingTerm});
  final String schoolId;
  final Term? existingTerm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18222E) : cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2A3848)
                  : cs.outlineVariant.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.14),
                blurRadius: isDark ? 40 : 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _CreateTermForm(
              schoolId: schoolId,
              existingTerm: existingTerm,
              onCreated: (term) => Navigator.of(context).pop(term),
              onCancel: () => Navigator.of(context).pop(),
              onDeleted: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile bottom-sheet wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTermSheet extends StatelessWidget {
  const _CreateTermSheet({required this.schoolId, this.existingTerm});
  final String schoolId;
  final Term? existingTerm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18222E) : cs.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF2A3848)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: _CreateTermForm(
          schoolId: schoolId,
          existingTerm: existingTerm,
          onCreated: (term) => Navigator.of(context).pop(term),
          onCancel: () => Navigator.of(context).pop(),
          onDeleted: () => Navigator.of(context).pop(),
          isSheet: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form widget
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTermForm extends StatefulWidget {
  const _CreateTermForm({
    required this.schoolId,
    required this.onCreated,
    required this.onCancel,
    this.existingTerm,
    this.onDeleted,
    this.isSheet = false,
  });

  final String schoolId;
  final Term? existingTerm;
  final ValueChanged<Term> onCreated;
  final VoidCallback onCancel;
  final VoidCallback? onDeleted;
  final bool isSheet;

  @override
  State<_CreateTermForm> createState() => _CreateTermFormState();
}

class _CreateTermFormState extends State<_CreateTermForm> {
  // ── Mode ─────────────────────────────────────────────────────────────────
  bool get _isEditMode => widget.existingTerm != null;
  bool get _busy => _saving || _deleting;

  // ── Academic year drum ───────────────────────────────────────────────────
  static const int _yearSpread = 10;
  late final int _baseYear;
  late final FixedExtentScrollController _yearScrollCtrl;
  late int _selectedYear;
  List<int> get _years =>
      List.generate(_yearSpread * 2 + 1, (i) => _baseYear - _yearSpread + i);

  // ── Term toggle ──────────────────────────────────────────────────────────
  int? _selectedTerm;

  // ── Date range ───────────────────────────────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  bool _calendarOpen = false;

  // ── Submission ───────────────────────────────────────────────────────────
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTerm;
    if (existing != null) {
      // Edit mode — prefill from existing term.
      _baseYear = existing.year;
      _selectedYear = existing.year;
      _selectedTerm = existing.term;
      _startDate = DateTime.fromMillisecondsSinceEpoch(
        existing.start.toInt() * 1000,
      );
      _endDate = DateTime.fromMillisecondsSinceEpoch(
        existing.end.toInt() * 1000,
      );
      final idx = _years.indexOf(existing.year);
      _yearScrollCtrl = FixedExtentScrollController(
        initialItem: idx >= 0 ? idx : _yearSpread,
      );
    } else {
      _baseYear = DateTime.now().year;
      _selectedYear = _baseYear;
      _yearScrollCtrl = FixedExtentScrollController(initialItem: _yearSpread);
    }
  }

  @override
  void dispose() {
    _yearScrollCtrl.dispose();
    super.dispose();
  }

  // ── Calendar day tap handler ──────────────────────────────────────────────
  //
  // First tap sets start. Second tap sets end (must be after start).
  // Third tap resets and starts fresh with the tapped day as new start.

  void _onDayTapped(DateTime day) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // Fresh selection — start a new range.
        _startDate = day;
        _endDate = null;
      } else if (day.isAfter(_startDate!)) {
        // Complete the range — auto-close the calendar.
        _endDate = day;
        _calendarOpen = false;
      } else if (day.isBefore(_startDate!)) {
        // Tapped before the start — move start.
        _startDate = day;
      } else {
        // Same day tapped again — reset.
        _startDate = null;
        _endDate = null;
      }
      _error = null;
    });
  }

  void _toggleCalendar() {
    setState(() => _calendarOpen = !_calendarOpen);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedTerm == null) {
      setState(() => _error = 'Please select a term.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please select the term date range.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      setState(() => _error = 'End date must be after start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      setState(() {
        _saving = false;
        _error = 'No active account. Please log in again.';
      });
      return;
    }

    final dao = TermsDao(db);

    if (_isEditMode) {
      await _performUpdate(dao, accountId);
    } else {
      await _performCreate(dao, accountId);
    }
  }

  Future<void> _performCreate(TermsDao dao, String accountId) async {
    final exists = await dao.termExists(
      schoolId: widget.schoolId,
      year: _selectedYear,
      termNumber: _selectedTerm!,
    );
    if (exists) {
      setState(() {
        _saving = false;
        _error =
            'Term $_selectedTerm of $_selectedYear already exists for this school.';
      });
      return;
    }

    final startSec = BigInt.from(_startDate!.millisecondsSinceEpoch ~/ 1000);
    final endSec = BigInt.from(
      (_endDate!.millisecondsSinceEpoch ~/ 1000) + 86399,
    );
    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    try {
      await dao.createTerm(
        term: TermsCompanion(
          school: Value(widget.schoolId),
          year: Value(_selectedYear),
          term: Value(_selectedTerm!),
          start: Value(startSec),
          end: Value(endSec),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        accountId: accountId,
      );

      final created = await dao.getTerm(
        schoolId: widget.schoolId,
        year: _selectedYear,
        termNumber: _selectedTerm!,
      );
      if (created != null && mounted) widget.onCreated(created);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to create term. Please try again.';
        });
      }
    }
  }

  Future<void> _performUpdate(TermsDao dao, String accountId) async {
    final existing = widget.existingTerm!;
    final startSec = BigInt.from(_startDate!.millisecondsSinceEpoch ~/ 1000);
    final endSec = BigInt.from(
      (_endDate!.millisecondsSinceEpoch ~/ 1000) + 86399,
    );
    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    try {
      await dao.updateTerm(
        schoolId: widget.schoolId,
        year: existing.year,
        termNumber: existing.term,
        changes: TermsCompanion(
          start: Value(startSec),
          end: Value(endSec),
          updated: Value(nowSec),
        ),
        accountId: accountId,
      );

      final updated = await dao.getTerm(
        schoolId: widget.schoolId,
        year: existing.year,
        termNumber: existing.term,
      );
      if (updated != null && mounted) widget.onCreated(updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to update term. Please try again.';
        });
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final existing = widget.existingTerm;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        final dCs = Theme.of(ctx).colorScheme;
        final dIsDark = dCs.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: dIsDark ? const Color(0xFF18222E) : dCs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dIsDark
                    ? const Color(0xFF2A3848)
                    : dCs.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dIsDark ? 0.50 : 0.14),
                  blurRadius: dIsDark ? 40 : 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: dIsDark ? 0.22 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: dCs.error.withValues(
                            alpha: dIsDark ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: dCs.error.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Delete Term ${existing.term} of ${existing.year}?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: dCs.onSurface,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This will permanently remove this term and all '
                    'associated data — enrollments, subjects, attendance, '
                    'exams, fees, and grades. This cannot be undone.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: dCs.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(false),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: dCs.onSurfaceVariant.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _DeleteConfirmButton(
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      setState(() {
        _deleting = false;
        _error = 'No active account. Please log in again.';
      });
      return;
    }

    try {
      final dao = TermsDao(db);
      await dao.deleteTerm(
        schoolId: widget.schoolId,
        year: existing.year,
        termNumber: existing.term,
        accountId: accountId,
      );
      if (mounted) widget.onDeleted?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'Failed to delete term. Please try again.';
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    final hasRange = _startDate != null && _endDate != null;
    final hasStart = _startDate != null && _endDate == null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle (sheet only) ────────────────────────────────────────
          if (widget.isSheet)
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode
                            ? 'Edit Term ${widget.existingTerm!.term} · ${widget.existingTerm!.year}'
                            : 'New Academic Term',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isEditMode
                            ? 'Update the term date range.'
                            : 'Select the year, term, and date range.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 17,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  tooltip: 'Cancel',
                  onPressed: widget.onCancel,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _Divider(isDark: isDark, cs: cs),
          ),

          // ── Form body ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1 — academic year drum + term toggle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _YearPicker(
                        years: _years,
                        selected: _selectedYear,
                        scrollCtrl: _yearScrollCtrl,
                        isDark: isDark,
                        cs: cs,
                        indigo: indigo,
                        enabled: !_busy && !_isEditMode,
                        onChanged: (y) => setState(() {
                          _selectedYear = y;
                          _error = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(label: 'Term', cs: cs),
                          const SizedBox(height: 5),
                          TermButtonGroup(
                            selected: _selectedTerm,
                            isDark: isDark,
                            cs: cs,
                            indigo: indigo,
                            enabled: !_busy && !_isEditMode,
                            onChanged: (v) => setState(() {
                              _selectedTerm = v;
                              _error = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Date range trigger button ────────────────────────────
                _FieldLabel(label: 'Date Range', cs: cs),
                const SizedBox(height: 5),
                DateRangeTrigger(
                  startDate: _startDate,
                  endDate: _endDate,
                  isOpen: _calendarOpen,
                  hasError:
                      _error != null &&
                      (_startDate == null || _endDate == null),
                  enabled: !_busy,
                  isDark: isDark,
                  cs: cs,
                  indigo: indigo,
                  onTap: _busy ? null : _toggleCalendar,
                ),

                // ── Collapsible calendar ─────────────────────────────────
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DateRangeCalendar(
                      startDate: _startDate,
                      endDate: _endDate,
                      onDayTapped: _busy ? null : _onDayTapped,
                      isDark: isDark,
                      cs: cs,
                      indigo: indigo,
                    ),
                  ),
                  crossFadeState: _calendarOpen
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeInOut,
                ),

                // ── Hint text when selecting ─────────────────────────────
                if (_calendarOpen && hasStart && !hasRange)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Now tap the end date',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: indigo.withValues(alpha: 0.70),
                      ),
                    ),
                  ),

                // Error banner
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBanner(message: _error!, cs: cs, isDark: isDark),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────
          _Divider(isDark: isDark, cs: cs),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                // Delete button — only shown in edit mode
                if (_isEditMode)
                  _DeleteIconButton(
                    deleting: _deleting,
                    onTap: _busy ? null : _confirmDelete,
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _busy ? null : widget.onCancel,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _busy
                            ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                            : cs.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ConfirmButton(saving: _saving, onTap: _busy ? null : _submit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  YEAR DRUM-ROLL
// ═════════════════════════════════════════════════════════════════════════════

class _YearPicker extends StatelessWidget {
  const _YearPicker({
    required this.years,
    required this.selected,
    required this.scrollCtrl,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.enabled,
    required this.onChanged,
  });

  final List<int> years;
  final int selected;
  final FixedExtentScrollController scrollCtrl;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final border = cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Year', cs: cs),
        const SizedBox(height: 5),
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ListWheelScrollView.useDelegate(
                  controller: scrollCtrl,
                  physics: enabled
                      ? const FixedExtentScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemExtent: 32,
                  perspective: 0.003,
                  diameterRatio: 1.6,
                  squeeze: 1.0,
                  onSelectedItemChanged: enabled ? onChanged : null,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: years.length,
                    builder: (context, index) {
                      final year = years[index];
                      final isSelected = year == selected;
                      return Center(
                        child: Text(
                          year.toString(),
                          style: TextStyle(
                            fontSize: isSelected ? 15 : 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? indigo
                                : cs.onSurfaceVariant.withValues(
                                    alpha: enabled ? 0.55 : 0.3,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Selection highlight band
                IgnorePointer(
                  child: Center(
                    child: Container(
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: indigo.withValues(alpha: isDark ? 0.10 : 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                // Top fade
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [fill, fill.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [fill, fill.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CONFIRM BUTTON
// ═════════════════════════════════════════════════════════════════════════════

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const green = AppTheme.brandGreen;
    final effectiveColor = saving ? green.withValues(alpha: 0.5) : green;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: saving
            ? []
            : [
                BoxShadow(
                  color: green.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(
            Colors.white.withValues(alpha: 0.08),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: saving
                  ? SizedBox(
                      key: const ValueKey('spin'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    )
                  : const Icon(
                      key: ValueKey('check'),
                      Icons.check,
                      size: 17,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DELETE ICON BUTTON — red trash icon shown in footer during edit mode
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({required this.deleting, required this.onTap});

  final bool deleting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final errorColor = cs.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: errorColor.withValues(alpha: isDark ? 0.30 : 0.20),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(
            errorColor.withValues(alpha: 0.08),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: deleting
                  ? SizedBox(
                      key: const ValueKey('del-spin'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          errorColor.withValues(alpha: 0.75),
                        ),
                      ),
                    )
                  : Icon(
                      key: const ValueKey('del-icon'),
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: errorColor.withValues(alpha: 0.80),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DELETE CONFIRM BUTTON — used inside the delete confirmation dialog
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteConfirmButton extends StatelessWidget {
  const _DeleteConfirmButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: cs.error.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(
            Colors.white.withValues(alpha: 0.08),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ERROR BANNER
// ═════════════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.cs,
    required this.isDark,
  });

  final String message;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.error.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: cs.error.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.error.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FIELD LABEL
// ═════════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  THIN HORIZONTAL DIVIDER
// ═════════════════════════════════════════════════════════════════════════════

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark, required this.cs});

  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.45),
    );
  }
}
