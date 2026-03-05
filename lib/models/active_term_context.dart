import 'package:flutter/foundation.dart';

import '../database/database.dart';

/// In-memory session object that tracks which academic term the user is
/// currently viewing within a school dashboard.
///
/// This is pure navigational state — it is never persisted to the database.
/// On re-entry the dashboard defaults to the current active term (the one
/// whose `start ≤ now ≤ end`) or the most recent term if none is active.
///
/// ### Lifecycle
/// - Created by [_SchoolDashboardScreenState._initializeSession] after the
///   term list is loaded from the [TermsDao].
/// - Provided to the widget tree via [ActiveTermProvider].
/// - Rebuilt whenever [setTerm] is called (e.g. user picks a different term
///   from the compact selector in the AppBar).
/// - Disposed when the school route is popped.
///
/// ### Reactive contract
/// Widgets that depend on the active term call [ActiveTermProvider.of(context)]
/// to obtain the [ActiveTermContext], then use [ValueListenableBuilder] on
/// [termNotifier] or listen to [addListener] directly.
///
/// All downstream Drift queries (subjects, enrollments, attendance, exams,
/// fees, etc.) must be re-issued when [currentTerm] changes.  The canonical
/// pattern is:
///
/// ```dart
/// final ctx = ActiveTermProvider.of(context);
/// return ValueListenableBuilder<Term?>(
///   valueListenable: ctx.termNotifier,
///   builder: (context, term, _) {
///     if (term == null) return const _NoTermPlaceholder();
///     return _MyTermSensitiveWidget(term: term);
///   },
/// );
/// ```
class ActiveTermContext extends ChangeNotifier {
  /// Creates an [ActiveTermContext] for [schoolId].
  ///
  /// [allTerms] is the full ordered list of terms available for this school
  /// (year desc, term asc).  It is updated whenever the underlying Drift
  /// stream emits (see [updateTerms]).
  ///
  /// [initialTerm] is the term that should be pre-selected on entry — pass the
  /// current active term if one exists, or the most recent term otherwise.
  /// Pass `null` only when the school has no terms at all.
  ActiveTermContext({
    required this.schoolId,
    required List<Term> allTerms,
    Term? initialTerm,
  }) : _allTerms = List.unmodifiable(allTerms),
       _termNotifier = ValueNotifier<Term?>(initialTerm);

  // ── Identity ───────────────────────────────────────────────────────────────

  /// The school this term context belongs to.
  final String schoolId;

  // ── Internal state ─────────────────────────────────────────────────────────

  List<Term> _allTerms;

  /// Internal [ValueNotifier] — exposed read-only via [termNotifier].
  final ValueNotifier<Term?> _termNotifier;

  // ── Public getters ─────────────────────────────────────────────────────────

  /// All terms available for this school, ordered year desc / term asc.
  ///
  /// Changes when [updateTerms] is called (e.g. the Drift stream emits after
  /// a new term is created).
  List<Term> get allTerms => _allTerms;

  /// Whether this school has any terms at all.
  ///
  /// When `false` the dashboard must hide all academic features and show a
  /// "Create First Term" blank state to owners.
  bool get hasTerms => _allTerms.isNotEmpty;

  /// The term currently being viewed.
  ///
  /// `null` only when [hasTerms] is `false`.
  Term? get currentTerm => _termNotifier.value;

  /// Read-only [ValueNotifier] that fires whenever [currentTerm] changes.
  ///
  /// Widgets bind to this via [ValueListenableBuilder] to rebuild only when the
  /// active term changes — not on every [ChangeNotifier] notification.
  ValueListenable<Term?> get termNotifier => _termNotifier;

  // ── Convenience accessors ─────────────────────────────────────────────────

  /// The year of the currently selected term, or `null` when no term is
  /// selected.
  int? get currentYear => _termNotifier.value?.year;

  /// The term number of the currently selected term, or `null` when no term
  /// is selected.
  int? get currentTermNumber => _termNotifier.value?.term;

  /// Display label for the currently selected term, e.g. "2025 · Term 2".
  ///
  /// Returns an empty string when no term is selected.
  String get currentTermLabel {
    final t = _termNotifier.value;
    if (t == null) return '';
    return '${t.year} · Term ${t.term}';
  }

  /// Returns `true` if [term] is the currently selected term.
  bool isSelected(Term term) {
    final current = _termNotifier.value;
    if (current == null) return false;
    return current.school == term.school &&
        current.year == term.year &&
        current.term == term.term;
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Switches the active term to [term].
  ///
  /// [term] must be present in [allTerms] — passing an unrecognised term is a
  /// programming error and will throw in debug mode.
  ///
  /// Does nothing if [term] is already the current term.
  void setTerm(Term term) {
    assert(
      _allTerms.any(
        (t) =>
            t.school == term.school &&
            t.year == term.year &&
            t.term == term.term,
      ),
      'setTerm: term (${term.year}, ${term.term}) is not in allTerms for '
      'school ${term.school}.',
    );
    final current = _termNotifier.value;
    if (current != null &&
        current.school == term.school &&
        current.year == term.year &&
        current.term == term.term) {
      return; // already selected — no-op
    }
    _termNotifier.value = term;
    notifyListeners();
  }

  /// Called by the dashboard state whenever the underlying Drift stream emits
  /// a new [List<Term>] (e.g. after a term is created or updated).
  ///
  /// This method:
  /// 1. Replaces [allTerms] with the new list.
  /// 2. If [currentTerm] is still present in the new list, keeps it selected.
  /// 3. If [currentTerm] is no longer in the new list (deleted), picks the
  ///    first term in the new list (most recent) — or `null` if the list is
  ///    now empty.
  /// 4. Notifies listeners so the term selector and blank-state widgets update.
  void updateTerms(List<Term> newTerms) {
    _allTerms = List.unmodifiable(newTerms);

    final current = _termNotifier.value;
    Term? next;

    if (current != null) {
      // Try to keep the same term selected.
      next = newTerms
          .where(
            (t) =>
                t.school == current.school &&
                t.year == current.year &&
                t.term == current.term,
          )
          .firstOrNull;
    }

    // Fall back to first (most recent) if current term was deleted or none
    // was selected.
    next ??= newTerms.firstOrNull;

    _termNotifier.value = next;
    notifyListeners();
  }

  // ── Disposal ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _termNotifier.dispose();
    super.dispose();
  }

  @override
  String toString() =>
      'ActiveTermContext(school: $schoolId, '
      'current: ${currentTermLabel.isEmpty ? "none" : currentTermLabel}, '
      'total: ${_allTerms.length})';
}
