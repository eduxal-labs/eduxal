/// App-wide constants for EduXal.
///
/// Token durations reflect current backend values.
/// If the backend changes them, update only this file — no logic changes needed.
library;

/// The gRPC server domain. Placeholder — will be config-driven in a later task.
const String kDomain = '192.168.8.31';

/// The gRPC server port.
const int kPort = 50051;

/// The base path for all locally cached files (profile images, school logos, etc.).
///
/// This is NOT a compile-time constant — it must be resolved at runtime via:
///   `final dir = await getApplicationDocumentsDirectory();`
///   `final kFileBasePath = dir.path;`
///
/// Use [path_provider]'s `getApplicationDocumentsDirectory()` wherever this is needed.
// ignore: constant_identifier_names — documented intentionally as a non-const reminder
const String kFileBasePath =
    ''; // Runtime value — see docs above. Do not use directly.

/// How long a verification code (OTP) remains valid after issuance.
/// OTP lifetime — show countdown in UI.
const Duration kVerificationExpiry = Duration(minutes: 15);

/// Minimum gap between resend attempts for a verification code.
/// Minimum gap between resend attempts — enforce in UI.
const Duration kResendCooldown = Duration(seconds: 90);

/// How long an access token remains valid after issuance.
/// access_token_expiry = created_at + kAccessTokenDuration
const Duration kAccessTokenDuration = Duration(days: 3);

/// How long a refresh token remains valid after issuance.
/// refresh_token_expiry = created_at + kRefreshTokenDuration
/// When this expires the user must go through full login again.
const Duration kRefreshTokenDuration = Duration(days: 30);

/// Whether the app is running in demo mode.
///
/// When `true`, the splash screen will auto-seed the local database with
/// realistic school data on first login (if no schools exist locally).
/// Set to `false` before production builds.
const bool kDemoMode = true;
