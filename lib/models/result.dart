/// A discriminated union representing either a successful value ([Ok])
/// or a failure value ([Err]).
///
/// All service methods return `Future<Result<T, E>>` or `Stream<Result<T, E>>`.
/// Consume with a switch expression — no raw try/catch in widgets.
///
/// Example:
/// ```dart
/// Result<int, String> r = Ok(42);
/// switch (r) {
///   case Ok(:final value): print(value);
///   case Err(:final error): print(error);
/// }
/// ```
sealed class Result<T, E> {
  const Result();
}

/// Represents a successful outcome carrying [value] of type [T].
final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

/// Represents a failed outcome carrying [error] of type [E].
final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}
