import 'authenticated.dart';

/// Returned by [Authentication.setup] on successful new-user registration.
///
/// Bundles the fully-mapped domain [Authenticated] model together with the
/// presigned S3 PUT URL so both can travel to the UI layer in one value.
///
/// Usage pattern in the setup screen:
/// ```dart
/// final result = await client.authentication.setup(token, name);
/// switch (result) {
///   case Ok(:final value):
///     await client.saveAccount(value.authenticated);
///     if (pickedImage != null && value.profileUploadUrl != null) {
///       await FileCache.upload(pickedImage, value.profileUploadUrl!);
///     }
///     // navigate to home screen
///   case Err(:final error):
///     // show error to user
/// }
/// ```
class SetupResult {
  const SetupResult({required this.authenticated, this.profileUploadUrl});

  /// The fully populated domain model for the newly registered user.
  ///
  /// Ready to be persisted via `client.saveAccount(authenticated)`.
  /// [authenticated.theme] will always be [AppThemeMode.system] on first login
  /// since the user has not set a preference yet — this is correct behaviour.
  final Authenticated authenticated;

  /// Presigned S3 PUT URL for uploading the user's profile image.
  ///
  /// Valid for approximately 1 hour from the time of issue.
  /// Use it immediately to upload a profile image if the user provided one
  /// during setup. Discard after use — it is **never** stored in the DB,
  /// in [AppCache], or anywhere else in the app.
  ///
  /// Null if the server did not return one (should not happen in the normal
  /// registration flow, but callers must handle it defensively).
  final String? profileUploadUrl;
}
