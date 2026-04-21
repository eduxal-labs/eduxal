// This is a generated file - do not edit.
//
// Generated from services/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'sync.pb.dart' as $0;

export 'sync.pb.dart';

@$pb.GrpcServiceName('sync.Sync')
class SyncClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SyncClient(super.channel, {super.options, super.interceptors});

  /// Client streams actions one at a time, server responds to each
  $grpc.ResponseStream<$0.ActionResponse> pushActions(
    $async.Stream<$0.ActionRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$pushActions, request, options: options);
  }

  /// Server streams changes to client (UNCHANGED from current)
  $grpc.ResponseStream<$0.SyncDelta> watchChanges(
    $0.WatchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$watchChanges, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$pushActions =
      $grpc.ClientMethod<$0.ActionRequest, $0.ActionResponse>(
          '/sync.Sync/PushActions',
          ($0.ActionRequest value) => value.writeToBuffer(),
          $0.ActionResponse.fromBuffer);
  static final _$watchChanges =
      $grpc.ClientMethod<$0.WatchRequest, $0.SyncDelta>(
          '/sync.Sync/WatchChanges',
          ($0.WatchRequest value) => value.writeToBuffer(),
          $0.SyncDelta.fromBuffer);
}

@$pb.GrpcServiceName('sync.Sync')
abstract class SyncServiceBase extends $grpc.Service {
  $core.String get $name => 'sync.Sync';

  SyncServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ActionRequest, $0.ActionResponse>(
        'PushActions',
        pushActions,
        true,
        true,
        ($core.List<$core.int> value) => $0.ActionRequest.fromBuffer(value),
        ($0.ActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WatchRequest, $0.SyncDelta>(
        'WatchChanges',
        watchChanges_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.WatchRequest.fromBuffer(value),
        ($0.SyncDelta value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ActionResponse> pushActions(
      $grpc.ServiceCall call, $async.Stream<$0.ActionRequest> request);

  $async.Stream<$0.SyncDelta> watchChanges_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.WatchRequest> $request) async* {
    yield* watchChanges($call, await $request);
  }

  $async.Stream<$0.SyncDelta> watchChanges(
      $grpc.ServiceCall call, $0.WatchRequest request);
}
