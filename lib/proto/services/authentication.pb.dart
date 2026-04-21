// This is a generated file - do not edit.
//
// Generated from services/authentication.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../types/user.pb.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Login extends $pb.GeneratedMessage {
  factory Login({
    $core.String? phone,
  }) {
    final result = create();
    if (phone != null) result.phone = phone;
    return result;
  }

  Login._();

  factory Login.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Login.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Login',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'phone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Login clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Login copyWith(void Function(Login) updates) =>
      super.copyWith((message) => updates(message as Login)) as Login;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Login create() => Login._();
  @$core.override
  Login createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Login getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Login>(create);
  static Login? _defaultInstance;

  /// / This is the user's phone number.
  @$pb.TagNumber(1)
  $core.String get phone => $_getSZ(0);
  @$pb.TagNumber(1)
  set phone($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPhone() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhone() => $_clearField(1);
}

class Verify extends $pb.GeneratedMessage {
  factory Verify({
    $core.String? id,
    $core.String? code,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (code != null) result.code = code;
    return result;
  }

  Verify._();

  factory Verify.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Verify.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Verify',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Verify clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Verify copyWith(void Function(Verify) updates) =>
      super.copyWith((message) => updates(message as Verify)) as Verify;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Verify create() => Verify._();
  @$core.override
  Verify createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Verify getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Verify>(create);
  static Verify? _defaultInstance;

  /// / This is the verification id.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// / This is the actual code the user received.
  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);
}

class Registered extends $pb.GeneratedMessage {
  factory Registered({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  Registered._();

  factory Registered.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Registered.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Registered',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Registered clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Registered copyWith(void Function(Registered) updates) =>
      super.copyWith((message) => updates(message as Registered)) as Registered;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Registered create() => Registered._();
  @$core.override
  Registered createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Registered getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Registered>(create);
  static Registered? _defaultInstance;

  /// / This is the user's setup token for first user registration.
  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class Authenticated extends $pb.GeneratedMessage {
  factory Authenticated({
    $core.String? accessToken,
    $core.String? refreshToken,
    $2.User? user,
    $core.String? profile,
  }) {
    final result = create();
    if (accessToken != null) result.accessToken = accessToken;
    if (refreshToken != null) result.refreshToken = refreshToken;
    if (user != null) result.user = user;
    if (profile != null) result.profile = profile;
    return result;
  }

  Authenticated._();

  factory Authenticated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Authenticated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Authenticated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aOS(2, _omitFieldNames ? '' : 'refreshToken')
    ..aOM<$2.User>(3, _omitFieldNames ? '' : 'user', subBuilder: $2.User.create)
    ..aOS(4, _omitFieldNames ? '' : 'profile')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Authenticated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Authenticated copyWith(void Function(Authenticated) updates) =>
      super.copyWith((message) => updates(message as Authenticated))
          as Authenticated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Authenticated create() => Authenticated._();
  @$core.override
  Authenticated createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Authenticated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Authenticated>(create);
  static Authenticated? _defaultInstance;

  /// / This is the user's access token.
  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  /// / This is the user's refresh token.
  @$pb.TagNumber(2)
  $core.String get refreshToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set refreshToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefreshToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefreshToken() => $_clearField(2);

  /// / This is the user's information.
  @$pb.TagNumber(3)
  $2.User get user => $_getN(2);
  @$pb.TagNumber(3)
  set user($2.User value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearUser() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.User ensureUser() => $_ensure(2);

  /// / This is the user's signed profile url but only for PUT it expires after 1 hour.
  @$pb.TagNumber(4)
  $core.String get profile => $_getSZ(3);
  @$pb.TagNumber(4)
  set profile($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProfile() => $_has(3);
  @$pb.TagNumber(4)
  void clearProfile() => $_clearField(4);
}

enum Verified_Verified { registered, authenticated, notSet }

class Verified extends $pb.GeneratedMessage {
  factory Verified({
    Registered? registered,
    Authenticated? authenticated,
  }) {
    final result = create();
    if (registered != null) result.registered = registered;
    if (authenticated != null) result.authenticated = authenticated;
    return result;
  }

  Verified._();

  factory Verified.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Verified.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Verified_Verified> _Verified_VerifiedByTag =
      {
    1: Verified_Verified.registered,
    2: Verified_Verified.authenticated,
    0: Verified_Verified.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Verified',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<Registered>(1, _omitFieldNames ? '' : 'registered',
        subBuilder: Registered.create)
    ..aOM<Authenticated>(2, _omitFieldNames ? '' : 'authenticated',
        subBuilder: Authenticated.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Verified clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Verified copyWith(void Function(Verified) updates) =>
      super.copyWith((message) => updates(message as Verified)) as Verified;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Verified create() => Verified._();
  @$core.override
  Verified createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Verified getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Verified>(create);
  static Verified? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  Verified_Verified whichVerified() =>
      _Verified_VerifiedByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearVerified() => $_clearField($_whichOneof(0));

  /// / This response will be provided if the current user tied to login for the first time.
  @$pb.TagNumber(1)
  Registered get registered => $_getN(0);
  @$pb.TagNumber(1)
  set registered(Registered value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRegistered() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegistered() => $_clearField(1);
  @$pb.TagNumber(1)
  Registered ensureRegistered() => $_ensure(0);

  /// / This response will be provided if the user is not new or was earlier invited.
  @$pb.TagNumber(2)
  Authenticated get authenticated => $_getN(1);
  @$pb.TagNumber(2)
  set authenticated(Authenticated value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthenticated() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthenticated() => $_clearField(2);
  @$pb.TagNumber(2)
  Authenticated ensureAuthenticated() => $_ensure(1);
}

class Setup extends $pb.GeneratedMessage {
  factory Setup({
    $core.String? token,
    $core.String? name,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (name != null) result.name = name;
    return result;
  }

  Setup._();

  factory Setup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Setup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Setup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Setup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Setup copyWith(void Function(Setup) updates) =>
      super.copyWith((message) => updates(message as Setup)) as Setup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Setup create() => Setup._();
  @$core.override
  Setup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Setup getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Setup>(create);
  static Setup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class Refresh extends $pb.GeneratedMessage {
  factory Refresh({
    $core.String? refreshToken,
  }) {
    final result = create();
    if (refreshToken != null) result.refreshToken = refreshToken;
    return result;
  }

  Refresh._();

  factory Refresh.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Refresh.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Refresh',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refreshToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Refresh clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Refresh copyWith(void Function(Refresh) updates) =>
      super.copyWith((message) => updates(message as Refresh)) as Refresh;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Refresh create() => Refresh._();
  @$core.override
  Refresh createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Refresh getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Refresh>(create);
  static Refresh? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refreshToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set refreshToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefreshToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefreshToken() => $_clearField(1);
}

class ChangePhone extends $pb.GeneratedMessage {
  factory ChangePhone({
    $core.String? token,
    $core.String? phone,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (phone != null) result.phone = phone;
    return result;
  }

  ChangePhone._();

  factory ChangePhone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChangePhone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChangePhone',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'phone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangePhone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangePhone copyWith(void Function(ChangePhone) updates) =>
      super.copyWith((message) => updates(message as ChangePhone))
          as ChangePhone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChangePhone create() => ChangePhone._();
  @$core.override
  ChangePhone createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChangePhone getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChangePhone>(create);
  static ChangePhone? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get phone => $_getSZ(1);
  @$pb.TagNumber(2)
  set phone($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPhone() => $_has(1);
  @$pb.TagNumber(2)
  void clearPhone() => $_clearField(2);
}

class ConfirmChangePhone extends $pb.GeneratedMessage {
  factory ConfirmChangePhone({
    $core.String? token,
    $core.String? id,
    $core.String? code,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (id != null) result.id = id;
    if (code != null) result.code = code;
    return result;
  }

  ConfirmChangePhone._();

  factory ConfirmChangePhone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConfirmChangePhone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfirmChangePhone',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'authentication'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOS(3, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmChangePhone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmChangePhone copyWith(void Function(ConfirmChangePhone) updates) =>
      super.copyWith((message) => updates(message as ConfirmChangePhone))
          as ConfirmChangePhone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfirmChangePhone create() => ConfirmChangePhone._();
  @$core.override
  ConfirmChangePhone createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConfirmChangePhone getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfirmChangePhone>(create);
  static ConfirmChangePhone? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get code => $_getSZ(2);
  @$pb.TagNumber(3)
  set code($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
