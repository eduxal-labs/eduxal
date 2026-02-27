import 'package:grpc/grpc.dart';

/// Maps [GrpcError] codes to user-friendly messages suitable for display in the UI.
///
/// Raw gRPC error messages often contain technical details (socket errors,
/// status codes, internal descriptions) that are meaningless or alarming to
/// end users. This utility translates them into clear, actionable language.
///
/// Usage:
/// ```dart
/// case Err(error: final error):
///   setState(() {
///     _errorMessage = error.toFriendlyMessage();
///   });
/// ```
extension GrpcErrorMessage on GrpcError {
  /// Returns a human-friendly error message for this [GrpcError].
  ///
  /// The mapping prioritises the most common failure modes a mobile/desktop
  /// user will encounter:
  /// - **code 14 (UNAVAILABLE)** — network unreachable / server down.
  /// - **code 4 (DEADLINE_EXCEEDED)** — request timed out.
  /// - **code 16 (UNAUTHENTICATED)** — session expired.
  /// - **code 7 (PERMISSION_DENIED)** — not authorised for this action.
  /// - **code 3 (INVALID_ARGUMENT)** — bad user input (pass through server
  ///   message if present, since the backend formats these for humans).
  /// - **code 5 (NOT_FOUND)** — requested resource doesn't exist.
  /// - **code 6 (ALREADY_EXISTS)** — duplicate resource.
  /// - **code 8 (RESOURCE_EXHAUSTED)** — rate limited.
  ///
  /// For all other codes the server's [message] is returned if non-empty,
  /// otherwise a generic fallback.
  String toFriendlyMessage() {
    return switch (code) {
      StatusCode.unavailable =>
        'Could not reach the server. Please check your internet connection and try again.',
      StatusCode.deadlineExceeded =>
        'The request timed out. Please check your connection and try again.',
      StatusCode.unauthenticated =>
        'Your session has expired. Please log in again.',
      StatusCode.permissionDenied =>
        'You do not have permission to perform this action.',
      StatusCode.invalidArgument => _serverMessageOr(
        'The information you provided is not valid. Please check and try again.',
      ),
      StatusCode.notFound => _serverMessageOr(
        'The requested resource was not found.',
      ),
      StatusCode.alreadyExists => _serverMessageOr(
        'This resource already exists.',
      ),
      StatusCode.resourceExhausted =>
        'Too many requests. Please wait a moment and try again.',
      StatusCode.cancelled => 'The request was cancelled. Please try again.',
      StatusCode.internal =>
        'Something went wrong on our end. Please try again later.',
      StatusCode.unimplemented => 'This feature is not available yet.',
      _ => _serverMessageOr('Something went wrong. Please try again.'),
    };
  }

  /// Returns the server-provided [message] if it is non-null and non-empty,
  /// otherwise falls back to [fallback].
  String _serverMessageOr(String fallback) {
    final msg = message;
    if (msg != null && msg.trim().isNotEmpty) return msg;
    return fallback;
  }
}
