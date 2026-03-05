import 'package:flutter/widgets.dart';

import '../../models/active_term_context.dart';

/// An [InheritedNotifier] that makes [ActiveTermContext] available to all
/// descendants in the widget tree without prop drilling.
///
/// ### Providing the context
/// Wrap the dashboard content area with [ActiveTermProvider]:
///
/// ```dart
/// ActiveTermProvider(
///   context: _activeTermContext,
///   child: _DashboardShell(...),
/// )
/// ```
///
/// ### Consuming the context
/// Any descendant widget can obtain the [ActiveTermContext] via:
///
/// ```dart
/// final termCtx = ActiveTermProvider.of(context);
/// ```
///
/// The widget will automatically rebuild whenever [ActiveTermContext] calls
/// [notifyListeners] — which happens when [setTerm] or [updateTerms] is called.
///
/// ### Term-sensitive widgets
/// Widgets that depend on a specific term value should bind to the inner
/// [ValueNotifier] for fine-grained rebuilds:
///
/// ```dart
/// final termCtx = ActiveTermProvider.of(context);
/// return ValueListenableBuilder<Term?>(
///   valueListenable: termCtx.termNotifier,
///   builder: (context, term, _) {
///     if (term == null) return const SizedBox.shrink();
///     return MyWidget(term: term);
///   },
/// );
/// ```
class ActiveTermProvider extends InheritedNotifier<ActiveTermContext> {
  /// Creates an [ActiveTermProvider] that injects [termContext] into the tree.
  const ActiveTermProvider({
    super.key,
    required ActiveTermContext termContext,
    required super.child,
  }) : super(notifier: termContext);

  /// Returns the [ActiveTermContext] from the nearest [ActiveTermProvider]
  /// ancestor.
  ///
  /// The calling widget is subscribed to the [ActiveTermContext]'s
  /// [ChangeNotifier] — it will rebuild whenever the active term changes.
  ///
  /// Throws a [FlutterError] in debug mode if no [ActiveTermProvider] is found
  /// in the ancestor tree.
  static ActiveTermContext of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<ActiveTermProvider>();
    assert(
      provider != null,
      'ActiveTermProvider.of() called with a context that does not contain '
      'an ActiveTermProvider.\n'
      'Ensure that ActiveTermProvider wraps the school dashboard widget tree.',
    );
    return provider!.notifier!;
  }

  /// Returns the [ActiveTermContext] without subscribing the calling widget
  /// to rebuilds.
  ///
  /// Use this when you only need to read or mutate the context imperatively
  /// (e.g. inside a button callback) without triggering a rebuild of the
  /// enclosing widget.
  static ActiveTermContext read(BuildContext context) {
    final provider = context
        .getInheritedWidgetOfExactType<ActiveTermProvider>();
    assert(
      provider != null,
      'ActiveTermProvider.read() called with a context that does not contain '
      'an ActiveTermProvider.',
    );
    return provider!.notifier!;
  }
}
