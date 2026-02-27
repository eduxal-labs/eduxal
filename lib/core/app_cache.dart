import '../models/authenticated.dart';

/// Lightweight in-memory cache for hot data that is read frequently during a
/// session but does not need to survive app restarts.
///
/// A single global instance is held in `client.dart` and cleared on logout.
///
/// ### Responsibilities
/// - Holds the active [Authenticated] user so `client.dart` does not have to
///   query the database on every token check.
/// - Provides a generic key-value store for any other domain that wants to
///   avoid repeated DB round-trips for rarely-changing data.
///
/// ### Lifecycle
/// 1. Populated in `client.dart` after a successful `active()` or `_refresh()`.
/// 2. [clear] is called from `client.dart`'s `logOut()` — wipes everything.
///
/// ### Thread safety
/// Dart is single-threaded (one isolate). No synchronisation is required.
class AppCache {
  /// The currently active authenticated user.
  ///
  /// Set after a successful `active()`, `_refresh()`, or `switchAccount()` call
  /// in `client.dart`. Null when no account is active or after [clear].
  Authenticated? currentUser;

  /// Generic key-value store for hot domain data.
  ///
  /// Keys are arbitrary strings. Values are untyped at storage; retrieved via
  /// the typed [get] helper which performs a safe cast.
  final Map<String, dynamic> _store = {};

  /// Retrieves a cached value by [key], cast to [T].
  ///
  /// Returns `null` if the key is absent or if the stored value is not
  /// assignable to [T] — never throws.
  ///
  /// ```dart
  /// final schools = cache.get<List<SchoolsData>>('schools');
  /// ```
  T? get<T>(String key) {
    final value = _store[key];
    if (value is T) return value;
    return null;
  }

  /// Stores [value] under [key], replacing any existing entry.
  ///
  /// ```dart
  /// cache.set<List<SchoolsData>>('schools', schools);
  /// ```
  void set<T>(String key, T value) {
    _store[key] = value;
  }

  /// Removes a single entry from the key-value store.
  ///
  /// Does nothing if [key] is not present. Does NOT clear [currentUser].
  void remove(String key) {
    _store.remove(key);
  }

  /// Clears all cached data, including [currentUser].
  ///
  /// Called by `client.dart` on logout to ensure no stale user data lingers
  /// in memory after the session ends.
  void clear() {
    currentUser = null;
    _store.clear();
  }

  @override
  String toString() =>
      'AppCache(user: ${currentUser?.user.id}, keys: ${_store.keys.toList()})';
}
