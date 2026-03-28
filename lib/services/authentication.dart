import 'dart:io';

import 'package:grpc/grpc.dart';

import '../client.dart' show accessToken, refreshToken;
import '../core/constants.dart';
import '../database/database.dart' show UsersData;
import '../database/daos/users_dao.dart';
import '../database/tables/enums.dart';
import '../models/authenticated.dart' as domain;
import '../models/result.dart';
import '../models/setup_result.dart';
import '../models/verify_result.dart';
import '../proto/services/authentication.pb.dart' as proto_auth;
import '../proto/services/authentication.pbgrpc.dart';
import '../proto/types/verification.pb.dart';
import '../cache/file_cache.dart';

/// Thin gRPC wrapper around [AuthenticationClient].
///
/// Every method maps a request to a proto call and converts the response into
/// a [Result]. No DB writes are performed here — all persistence is delegated
/// to `client.dart` methods (`saveAccount`, etc.) which receive the domain
/// [domain.Authenticated] returned by these methods.
///
/// Exception: profile image downloads are triggered here (fire-and-forget) via
/// [_downloadProfileIfPresent], because the proto object carrying the GET URL
/// is only in scope inside these methods.
///
/// Error handling: every gRPC call is wrapped in a two-level try/catch:
/// 1. `on GrpcError` — catches normal gRPC-level failures (status codes,
///    server-returned errors, etc.) and wraps them in [Err].
/// 2. `catch` — catches anything the gRPC stack did not absorb: most
///    commonly [SocketException] (no network), [TlsException], OS-level
///    I/O errors, or HTTP/2 framing errors. These are converted into a
///    synthetic `GrpcError` with [StatusCode.unavailable] so that all
///    callers only ever see a [Result<T, GrpcError>] — never an uncaught
///    exception.
class Authentication {
  /// [channel] is the shared gRPC [ClientChannel] owned by `client.dart`.
  /// [_usersDao] is needed only to satisfy the [domain.Authenticated] factory
  /// which requires a [UsersData] instance — no DB writes happen here.
  Authentication(ClientChannel channel, UsersDao usersDao)
    : _client = AuthenticationClient(channel),
      _usersDao = usersDao;

  final AuthenticationClient _client;
  // ignore: unused_field — reserved for future use (e.g. local user lookups)
  final UsersDao _usersDao;

  // ─────────────────────────────────────────────────────────────────────────
  // login
  // ─────────────────────────────────────────────────────────────────────────

  /// Initiates a phone-number login by requesting a verification code.
  ///
  /// Returns [Ok] with the [Verification] proto on success. The caller passes
  /// the [Verification.id] to [verify] once the user submits the received code.
  ///
  /// Returns [Err] with the raw [GrpcError] on any gRPC-level failure.
  Future<Result<Verification, GrpcError>> login(String phone) async {
    try {
      final request = proto_auth.Login(phone: phone);
      final verification = await _client.login(request);
      return Ok(verification);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(_toUnavailable(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // verify
  // ─────────────────────────────────────────────────────────────────────────

  /// Submits the OTP code the user received and returns a [VerifyResult].
  ///
  /// The server responds with a `Verified` oneof:
  /// - `authenticated` → existing user; maps to [VerifyResultAuthenticated].
  /// - `registered`    → new user; maps to [VerifyResultRegistered] with the
  ///   short-lived setup token.
  ///
  /// On [VerifyResultAuthenticated], the profile image download is triggered
  /// fire-and-forget using the GET URL from the proto, before it goes out of
  /// scope.
  ///
  /// Returns [Err] with the raw [GrpcError] on any gRPC-level failure.
  Future<Result<VerifyResult, GrpcError>> verify(
    String verificationId,
    String code,
  ) async {
    try {
      final request = proto_auth.Verify(id: verificationId, code: code);
      final verified = await _client.verify(request);

      if (verified.hasAuthenticated()) {
        final proto = verified.authenticated;
        final mapped = _mapProtoAuthenticated(proto);

        // Fire-and-forget: download the profile image while the GET URL is
        // still in scope. Does not block or affect the auth result.
        _downloadProfileIfPresent(
          proto.user.id,
          proto.user.hasProfile() ? proto.user.profile : null,
        );

        return Ok(
          VerifyResultAuthenticated(
            authenticated: mapped,
            profileUploadUrl: proto.hasProfile() ? proto.profile : null,
            profileReadUrl: proto.user.hasProfile() ? proto.user.profile : null,
          ),
        );
      } else {
        // verified.hasRegistered() — new user, needs setup step.
        return Ok(VerifyResultRegistered(token: verified.registered.token));
      }
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(_toUnavailable(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // setup
  // ─────────────────────────────────────────────────────────────────────────

  /// Completes new-user account creation.
  ///
  /// [token] is the short-lived registration token from [VerifyResultRegistered].
  /// [name] is the display name the user chose during onboarding.
  ///
  /// Returns [Ok] with a [SetupResult] on success. The [SetupResult] carries
  /// both the domain [domain.Authenticated] (ready to persist via
  /// `client.saveAccount()`) and the presigned S3 PUT URL for profile upload.
  ///
  /// Returns [Err] with the raw [GrpcError] on any gRPC-level failure.
  Future<Result<SetupResult, GrpcError>> setup(
    String token,
    String name,
  ) async {
    try {
      final request = proto_auth.Setup(token: token, name: name);
      final proto = await _client.setup(request);
      final mapped = _mapProtoAuthenticated(proto);

      // Capture the PUT URL from the proto before it goes out of scope.
      // It is passed back to the caller inside SetupResult — never stored.
      final putUrl = proto.hasProfile() ? proto.profile : null;

      // Fire-and-forget: the new user may already have a profile image if
      // the server populated one during setup. Download it if present.
      _downloadProfileIfPresent(
        proto.user.id,
        proto.user.hasProfile() ? proto.user.profile : null,
      );

      return Ok(SetupResult(authenticated: mapped, profileUploadUrl: putUrl));
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(_toUnavailable(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // refresh
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtains a new access token using the current in-memory [refreshToken].
  ///
  /// The [refreshToken] global in `client.dart` must already be set before
  /// this is called — [Client._refresh] sets it immediately before invoking
  /// this method.
  ///
  /// Returns [Ok] with the refreshed domain [domain.Authenticated] on success.
  /// Returns [Err] with the raw [GrpcError] on any gRPC-level failure (e.g.
  /// the refresh token has been revoked server-side).
  Future<Result<domain.Authenticated, GrpcError>> refresh() async {
    try {
      final request = proto_auth.Refresh(refreshToken: refreshToken);
      final proto = await _client.refresh(
        request,
        options: CallOptions(timeout: const Duration(seconds: 5)),
      );
      final mapped = _mapProtoAuthenticated(proto);

      // Fire-and-forget: re-download profile image on token refresh in case
      // the user updated their profile image from another device.
      _downloadProfileIfPresent(
        proto.user.id,
        proto.user.hasProfile() ? proto.user.profile : null,
      );

      return Ok(mapped);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(_toUnavailable(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // changePhone
  // ─────────────────────────────────────────────────────────────────────────

  /// Initiates a phone number change for the currently authenticated user.
  ///
  /// Sends an OTP to [newPhone]. On success returns [Ok] with a [Verification]
  /// whose [Verification.id] must be passed to [confirmChangePhone] along with
  /// the received code.
  ///
  /// [accessToken] must already be set in memory (i.e. the user is logged in).
  ///
  /// Returns [Err] with the raw [GrpcError] on any gRPC-level failure.
  Future<Result<Verification, GrpcError>> changePhone(String newPhone) async {
    try {
      final request = proto_auth.ChangePhone(
        token: accessToken,
        phone: newPhone,
      );
      final verification = await _client.changePhone(request);
      return Ok(verification);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(_toUnavailable(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // confirmChangePhone
  // ─────────────────────────────────────────────────────────────────────────

  /// Confirms the phone number change by submitting the OTP the user received
  /// on [newPhone].
  ///
  /// [verificationId] is the [Verification.id] returned by [changePhone].
  /// [code] is the 6-digit OTP entered by the user.
  ///
  /// On success the server returns a fresh [proto_auth.Authenticated] with the
  /// new phone number and updated tokens. The domain model is built via
  /// [_mapProtoAuthenticated] and returned inside [Ok] — the caller
  /// (`AccountScreen`) is responsible for persisting it via
  /// `client.saveAccount()`.
  ///
  /// Returns [Err] with the raw [GrpcError] on any gRPC-level failure.
  Future<Result<domain.Authenticated, GrpcError>> confirmChangePhone(
    String verificationId,
    String code,
  ) async {
    try {
      final request = proto_auth.ConfirmChangePhone(
        token: accessToken,
        id: verificationId,
        code: code,
      );
      final proto = await _client.confirmChangePhone(request);
      final mapped = _mapProtoAuthenticated(proto);

      // Fire-and-forget: re-download profile image in case the server
      // returns an updated GET URL after the phone change.
      _downloadProfileIfPresent(
        proto.user.id,
        proto.user.hasProfile() ? proto.user.profile : null,
      );

      return Ok(mapped);
    } on GrpcError catch (e) {
      return Err(e);
    } catch (e) {
      return Err(_toUnavailable(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Converts any non-[GrpcError] exception into a synthetic
  /// [GrpcError] with [StatusCode.unavailable].
  ///
  /// This is the catch-all for:
  /// - [SocketException] — device has no network.
  /// - [TlsException] — TLS handshake failure (e.g. bad cert).
  /// - [HttpException] — HTTP-layer error before gRPC could parse it.
  /// - Any other OS / platform exception that escapes the gRPC stack.
  ///
  /// By normalising everything to [StatusCode.unavailable] the UI can always
  /// use `error.toFriendlyMessage()` from `core/grpc_errors.dart` without
  /// special-casing socket errors.
  GrpcError _toUnavailable(Object e) {
    if (e is SocketException) {
      return GrpcError.unavailable(
        'No internet connection. Please check your network and try again.',
      );
    }
    if (e is TlsException) {
      return GrpcError.unavailable(
        'Secure connection failed. Please try again.',
      );
    }
    // Generic fallback — include the runtime type for debuggability without
    // leaking raw exception messages to the user (toFriendlyMessage handles
    // the display string).
    return GrpcError.unavailable('Network error (${e.runtimeType})');
  }

  /// Maps a proto [proto_auth.Authenticated] response to the domain
  /// [domain.Authenticated] model.
  ///
  /// Mapping rules:
  /// - Token expiry values are computed locally from `now`:
  ///   - [domain.Authenticated.tokenExpiry]        = now + [kAccessTokenDuration]
  ///   - [domain.Authenticated.refreshTokenExpiry] = now + [kRefreshTokenDuration]
  /// - [proto_auth.Authenticated.profile] (presigned PUT URL) is intentionally
  ///   NOT stored in the domain model — the caller is responsible for capturing
  ///   it from the proto before this method is called (see [verify], [setup]).
  /// - [proto.user.profile] (presigned GET URL) is NOT stored — the file is
  ///   downloaded to the local constant path by [_downloadProfileIfPresent].
  /// - Proto [Level] and [Status] enum values are mapped by integer index,
  ///   which aligns exactly with domain [UserLevel] and [UserStatus] index order.
  /// - [proto.user.created] / [proto.user.updated] are [Int64] (fixnum) —
  ///   converted to [BigInt] for the [UsersData] constructor.
  domain.Authenticated _mapProtoAuthenticated(proto_auth.Authenticated proto) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tokenExpiry = now + kAccessTokenDuration.inMilliseconds;
    final refreshTokenExpiry = now + kRefreshTokenDuration.inMilliseconds;

    final protoUser = proto.user;

    // Build the UsersData row directly. This is safe to construct without
    // going through the DB — it will be written to the users table by
    // client.dart's saveAccount() via Authenticated.toUserCompanion().
    //
    // NOTE: UsersData is constructed directly here (not via fromRows) to
    // avoid a dependency on AccountsData whose shape differs between the
    // current stale .g.dart and the post-code-gen version. The companion
    // approach via toUserCompanion() is used for all DB writes.
    final userData = UsersData(
      id: protoUser.id,
      phone: protoUser.phone,
      name: protoUser.name,
      email: protoUser.hasEmail() ? protoUser.email : null,
      // Map proto Level index → domain UserLevel index (values are aligned).
      level: UserLevel.values[protoUser.level.value],
      // Map proto Status index → domain UserStatus index (values are aligned).
      status: UserStatus.values[protoUser.status.value],
      // Proto Int64 (fixnum) → BigInt for the Drift-generated data class.
      created: BigInt.from(protoUser.created.toInt()),
      updated: BigInt.from(now),
    );

    // Construct Authenticated directly rather than via fromRows(), because
    // fromRows() requires an AccountsData instance whose constructor signature
    // differs between the stale .g.dart and the post-regen version. Building
    // the domain model directly is always safe — fromRows() is only used when
    // reading back from the DB (where .g.dart always matches the live schema).
    return domain.Authenticated(
      user: userData,
      accessToken: proto.accessToken,
      refreshToken: proto.refreshToken,
      tokenExpiry: tokenExpiry,
      refreshTokenExpiry: refreshTokenExpiry,
      lastSyncedAt: null,
      theme:
          AppThemeMode.system, // default on first login; overwritten on refresh
      created: now,
      updated: now,
    );
  }

  /// Downloads the user's profile image to the local constant path if [url]
  /// is non-null and non-empty.
  ///
  /// This call is **fire-and-forget** — it does not block or affect the auth
  /// flow. Any download error is silently swallowed; the UI will fall back to
  /// the avatar placeholder when no local file exists.
  void _downloadProfileIfPresent(String userId, String? url) {
    if (url == null || url.isEmpty) return;
    // Intentionally not awaited — profile download must not delay auth.
    FileCache.download(url, FileCache.profilePath(userId)).catchError((_) {
      // Silently ignore — the file will be downloaded on the next successful
      // auth if the network request fails here.
      return null;
    });
  }
}
