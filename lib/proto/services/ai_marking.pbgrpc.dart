// This is a generated file - do not edit.
//
// Generated from services/ai_marking.proto.

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

import 'ai_marking.pb.dart' as $0;

export 'ai_marking.pb.dart';

@$pb.GrpcServiceName('ai_marking.AiMarking')
class AiMarkingClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AiMarkingClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.UploadUrlsResponse> requestUploadUrls(
    $0.UploadUrlsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$requestUploadUrls, request, options: options);
  }

  $grpc.ResponseFuture<$0.MarkPaperResponse> markPaper(
    $0.MarkPaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$markPaper, request, options: options);
  }

  // method descriptors

  static final _$requestUploadUrls =
      $grpc.ClientMethod<$0.UploadUrlsRequest, $0.UploadUrlsResponse>(
          '/ai_marking.AiMarking/RequestUploadUrls',
          ($0.UploadUrlsRequest value) => value.writeToBuffer(),
          $0.UploadUrlsResponse.fromBuffer);
  static final _$markPaper =
      $grpc.ClientMethod<$0.MarkPaperRequest, $0.MarkPaperResponse>(
          '/ai_marking.AiMarking/MarkPaper',
          ($0.MarkPaperRequest value) => value.writeToBuffer(),
          $0.MarkPaperResponse.fromBuffer);
}

@$pb.GrpcServiceName('ai_marking.AiMarking')
abstract class AiMarkingServiceBase extends $grpc.Service {
  $core.String get $name => 'ai_marking.AiMarking';

  AiMarkingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.UploadUrlsRequest, $0.UploadUrlsResponse>(
        'RequestUploadUrls',
        requestUploadUrls_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UploadUrlsRequest.fromBuffer(value),
        ($0.UploadUrlsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.MarkPaperRequest, $0.MarkPaperResponse>(
        'MarkPaper',
        markPaper_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.MarkPaperRequest.fromBuffer(value),
        ($0.MarkPaperResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.UploadUrlsResponse> requestUploadUrls_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UploadUrlsRequest> $request) async {
    return requestUploadUrls($call, await $request);
  }

  $async.Future<$0.UploadUrlsResponse> requestUploadUrls(
      $grpc.ServiceCall call, $0.UploadUrlsRequest request);

  $async.Future<$0.MarkPaperResponse> markPaper_Pre($grpc.ServiceCall $call,
      $async.Future<$0.MarkPaperRequest> $request) async {
    return markPaper($call, await $request);
  }

  $async.Future<$0.MarkPaperResponse> markPaper(
      $grpc.ServiceCall call, $0.MarkPaperRequest request);
}
