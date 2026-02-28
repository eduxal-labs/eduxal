// This is a generated file - do not edit.
//
// Generated from services/authentication.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import '../types/verification.pb.dart' as $1;
import 'authentication.pb.dart' as $0;

export 'authentication.pb.dart';

@$pb.GrpcServiceName('authentication.Authentication')
class AuthenticationClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthenticationClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$1.Verification> login(
    $0.Login request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$login, request, options: options);
  }

  $grpc.ResponseFuture<$0.Verified> verify(
    $0.Verify request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$verify, request, options: options);
  }

  $grpc.ResponseFuture<$0.Authenticated> setup(
    $0.Setup request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setup, request, options: options);
  }

  $grpc.ResponseFuture<$0.Authenticated> refresh(
    $0.Refresh request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$refresh, request, options: options);
  }

  $grpc.ResponseFuture<$1.Verification> changePhone(
    $0.ChangePhone request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$changePhone, request, options: options);
  }

  $grpc.ResponseFuture<$0.Authenticated> confirmChangePhone(
    $0.ConfirmChangePhone request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$confirmChangePhone, request, options: options);
  }

  // method descriptors

  static final _$login = $grpc.ClientMethod<$0.Login, $1.Verification>(
      '/authentication.Authentication/login',
      ($0.Login value) => value.writeToBuffer(),
      $1.Verification.fromBuffer);
  static final _$verify = $grpc.ClientMethod<$0.Verify, $0.Verified>(
      '/authentication.Authentication/verify',
      ($0.Verify value) => value.writeToBuffer(),
      $0.Verified.fromBuffer);
  static final _$setup = $grpc.ClientMethod<$0.Setup, $0.Authenticated>(
      '/authentication.Authentication/setup',
      ($0.Setup value) => value.writeToBuffer(),
      $0.Authenticated.fromBuffer);
  static final _$refresh = $grpc.ClientMethod<$0.Refresh, $0.Authenticated>(
      '/authentication.Authentication/refresh',
      ($0.Refresh value) => value.writeToBuffer(),
      $0.Authenticated.fromBuffer);
  static final _$changePhone =
      $grpc.ClientMethod<$0.ChangePhone, $1.Verification>(
          '/authentication.Authentication/changePhone',
          ($0.ChangePhone value) => value.writeToBuffer(),
          $1.Verification.fromBuffer);
  static final _$confirmChangePhone =
      $grpc.ClientMethod<$0.ConfirmChangePhone, $0.Authenticated>(
          '/authentication.Authentication/confirmChangePhone',
          ($0.ConfirmChangePhone value) => value.writeToBuffer(),
          $0.Authenticated.fromBuffer);
}

@$pb.GrpcServiceName('authentication.Authentication')
abstract class AuthenticationServiceBase extends $grpc.Service {
  $core.String get $name => 'authentication.Authentication';

  AuthenticationServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Login, $1.Verification>(
        'login',
        login_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Login.fromBuffer(value),
        ($1.Verification value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Verify, $0.Verified>(
        'verify',
        verify_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Verify.fromBuffer(value),
        ($0.Verified value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Setup, $0.Authenticated>(
        'setup',
        setup_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Setup.fromBuffer(value),
        ($0.Authenticated value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Refresh, $0.Authenticated>(
        'refresh',
        refresh_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Refresh.fromBuffer(value),
        ($0.Authenticated value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ChangePhone, $1.Verification>(
        'changePhone',
        changePhone_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ChangePhone.fromBuffer(value),
        ($1.Verification value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ConfirmChangePhone, $0.Authenticated>(
        'confirmChangePhone',
        confirmChangePhone_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ConfirmChangePhone.fromBuffer(value),
        ($0.Authenticated value) => value.writeToBuffer()));
  }

  $async.Future<$1.Verification> login_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Login> $request) async {
    return login($call, await $request);
  }

  $async.Future<$1.Verification> login(
      $grpc.ServiceCall call, $0.Login request);

  $async.Future<$0.Verified> verify_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Verify> $request) async {
    return verify($call, await $request);
  }

  $async.Future<$0.Verified> verify($grpc.ServiceCall call, $0.Verify request);

  $async.Future<$0.Authenticated> setup_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Setup> $request) async {
    return setup($call, await $request);
  }

  $async.Future<$0.Authenticated> setup(
      $grpc.ServiceCall call, $0.Setup request);

  $async.Future<$0.Authenticated> refresh_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Refresh> $request) async {
    return refresh($call, await $request);
  }

  $async.Future<$0.Authenticated> refresh(
      $grpc.ServiceCall call, $0.Refresh request);

  $async.Future<$1.Verification> changePhone_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ChangePhone> $request) async {
    return changePhone($call, await $request);
  }

  $async.Future<$1.Verification> changePhone(
      $grpc.ServiceCall call, $0.ChangePhone request);

  $async.Future<$0.Authenticated> confirmChangePhone_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ConfirmChangePhone> $request) async {
    return confirmChangePhone($call, await $request);
  }

  $async.Future<$0.Authenticated> confirmChangePhone(
      $grpc.ServiceCall call, $0.ConfirmChangePhone request);
}
