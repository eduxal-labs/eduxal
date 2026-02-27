import 'package:flutter/foundation.dart';

import 'membership.dart';
import 'school_permissions.dart';

/// In-memory session object for a user's active school dashboard visit.
///
/// Created when the user taps a school card (or selects an entry from the
/// picker dialog) on the home screen. Lives only for the duration of the
/// school dashboard session and is disposed when the user navigates back.
///
/// [SchoolContext] is **never persisted** — it is pure navigational state.
/// On the next app start the user always lands on the home screen and picks
/// a context by tapping a membership card.
///
/// ### Typical lifecycle
/// 1. `SchoolService.enterSchool(membership, initialEntry)` creates the context
///    (Task Group 3).
/// 2. Gemini's navigation layer provides it to the widget tree via an
///    `InheritedWidget` or provider of its choice.
/// 3. Entry-sensitive streams (lessons, grades, etc.) are re-subscribed
///    whenever [currentEntry] changes.
/// 4. Gemini's navigation layer calls [dispose] when the school route is popped.
///
/// ### Example
/// ```dart
/// final ctx = SchoolContext(
///   membership: membership,
///   permissions: permissions,
///   initialEntry: membership.entries.first,
/// );
/// ctx.switchEntry(membership.entries[1]);
/// assert(ctx.currentEntry.value == membership.entries[1]);
/// ctx.dispose();
/// ```
class SchoolContext {
  /// Creates a [SchoolContext] for [membership], entering as [initialEntry].
  ///
  /// [permissions] is computed once from the user's scopes at this school and
  /// remains constant for the entire session — switching entries does NOT
  /// recompute permissions.
  SchoolContext({
    required this.membership,
    required this.permissions,
    required MembershipEntry initialEntry,
  }) : currentEntry = ValueNotifier(initialEntry);

  /// All membership entries the user holds at this school.
  ///
  /// Used by the role-switcher UI to build the list of available entries.
  final SchoolMembership membership;

  /// Aggregated permission set for this user at this school.
  ///
  /// Computed once on entry by unioning all permission keys from every
  /// [roles] row linked to every [scopes] row for `(school, user)`.
  /// Constant for the duration of the session — never reloaded on entry switch.
  final SchoolPermissions permissions;

  /// The currently active navigation entry within this school.
  ///
  /// Widgets that depend on the active entry (e.g. a teacher's lesson list,
  /// a guardian's ward attendance) should use `ValueListenableBuilder` to
  /// rebuild when this notifier fires.
  ///
  /// Must not be accessed after [dispose] has been called.
  final ValueNotifier<MembershipEntry> currentEntry;

  /// Whether the user has more than one entry at this school.
  ///
  /// When `false`, the role-switcher UI should be hidden entirely.
  /// When `true`, the role-switcher should be shown so the user can move
  /// between entries (e.g. teacher → guardian for their own child).
  bool get canSwitch => membership.entries.length > 1;

  /// Switches the active entry to [entry].
  ///
  /// [entry] must already be present in [membership.entries] — passing an
  /// entry that does not belong to this school's membership is a programming
  /// error and will throw in debug mode.
  ///
  /// Does nothing if [entry] is already the current entry.
  void switchEntry(MembershipEntry entry) {
    assert(
      membership.entries.contains(entry),
      'switchEntry: entry $entry is not part of this school\'s membership. '
      'Available entries: ${membership.entries}',
    );
    if (currentEntry.value == entry) return;
    currentEntry.value = entry;
  }

  /// Releases the [ValueNotifier] held by [currentEntry].
  ///
  /// Must be called by Gemini's navigation layer when the school route is
  /// popped. After this call, [currentEntry] must not be read or written.
  void dispose() => currentEntry.dispose();

  @override
  String toString() =>
      'SchoolContext(school: ${membership.school.id}, '
      'entry: ${currentEntry.value.role}, '
      'canSwitch: $canSwitch)';
}
