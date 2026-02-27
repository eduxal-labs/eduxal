import 'authenticated.dart';

/// The union result type returned by [Authentication.verify].
///
/// `verify` is the only auth step whose success response branches:
/// - An existing user whose phone is already registered gets an
///   [Authenticated] session immediately → [VerifyResultAuthenticated].
/// - A new (first-time) user needs to complete account setup (name, etc.)
///   and receives a short-lived registration token → [VerifyResultRegistered].
///
/// Callers switch exhaustively on this type:
/// ```dart
/// switch (result) {
///   case VerifyResultAuthenticated(:final authenticated):
///     await client.saveAccount(authenticated);
///     // navigate to home screen
///   case VerifyResultRegistered(:final token):
///     // navigate to setup screen, passing token
/// }
/// ```
sealed class VerifyResult {
  const VerifyResult();
}

/// Returned when the verified phone number belongs to an existing user.
///
/// The domain [Authenticated] is ready to be persisted via
/// `client.saveAccount(authenticated)` and used as the active session.
///
/// [profileUploadUrl] is the presigned S3 PUT URL valid for ~1 hour.
/// Use it immediately to upload a new profile image if the user chooses to
/// update their photo. Discard after use — it is never stored anywhere.
final class VerifyResultAuthenticated extends VerifyResult {
  const VerifyResultAuthenticated({
    required this.authenticated,
    this.profileUploadUrl,
  });

  /// The fully populated domain model for the now-authenticated user.
  final Authenticated authenticated;

  /// Presigned S3 PUT URL for uploading a new profile image (~1 hour validity).
  /// Null if the server did not return one.
  /// Never store this value — use it immediately or discard it.
  final String? profileUploadUrl;
}

/// Returned when the verified phone number belongs to a new (unregistered) user.
///
/// The caller must navigate to the setup screen and pass [token] to
/// [Authentication.setup] along with the user's chosen name.
///
/// [token] is short-lived — it expires quickly on the server side.
/// It must be consumed by [Authentication.setup] before it lapses.
final class VerifyResultRegistered extends VerifyResult {
  const VerifyResultRegistered({required this.token});

  /// Short-lived registration token issued by the server.
  /// Pass this to [Authentication.setup] to complete account creation.
  final String token;
}
