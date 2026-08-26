// This is a generated file - do not edit.
//
// Generated from services/paper.proto.

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

import 'paper.pb.dart' as $0;

export 'paper.pb.dart';

@$pb.GrpcServiceName('paper_service.PaperService')
class PaperServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PaperServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CreatePaperResponse> createPaper(
    $0.CreatePaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createPaper, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPaperResponse> getPaper(
    $0.GetPaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPaper, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPapersResponse> listPapers(
    $0.ListPapersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPapers, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdatePaperResponse> updatePaper(
    $0.UpdatePaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePaper, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPaperPdfUrlResponse> getPaperPdfUrl(
    $0.GetPaperPdfUrlRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPaperPdfUrl, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPaperDocxUrlResponse> getPaperDocxUrl(
    $0.GetPaperDocxUrlRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPaperDocxUrl, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetMarkingSchemeUrlResponse> getMarkingSchemeUrl(
    $0.GetMarkingSchemeUrlRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMarkingSchemeUrl, request, options: options);
  }

  $grpc.ResponseFuture<$0.ForceSetPaperStatusResponse> forceSetPaperStatus(
    $0.ForceSetPaperStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$forceSetPaperStatus, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeletePaperResponse> deletePaper(
    $0.DeletePaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePaper, request, options: options);
  }

  // method descriptors

  static final _$createPaper =
      $grpc.ClientMethod<$0.CreatePaperRequest, $0.CreatePaperResponse>(
          '/paper_service.PaperService/CreatePaper',
          ($0.CreatePaperRequest value) => value.writeToBuffer(),
          $0.CreatePaperResponse.fromBuffer);
  static final _$getPaper =
      $grpc.ClientMethod<$0.GetPaperRequest, $0.GetPaperResponse>(
          '/paper_service.PaperService/GetPaper',
          ($0.GetPaperRequest value) => value.writeToBuffer(),
          $0.GetPaperResponse.fromBuffer);
  static final _$listPapers =
      $grpc.ClientMethod<$0.ListPapersRequest, $0.ListPapersResponse>(
          '/paper_service.PaperService/ListPapers',
          ($0.ListPapersRequest value) => value.writeToBuffer(),
          $0.ListPapersResponse.fromBuffer);
  static final _$updatePaper =
      $grpc.ClientMethod<$0.UpdatePaperRequest, $0.UpdatePaperResponse>(
          '/paper_service.PaperService/UpdatePaper',
          ($0.UpdatePaperRequest value) => value.writeToBuffer(),
          $0.UpdatePaperResponse.fromBuffer);
  static final _$getPaperPdfUrl =
      $grpc.ClientMethod<$0.GetPaperPdfUrlRequest, $0.GetPaperPdfUrlResponse>(
          '/paper_service.PaperService/GetPaperPdfUrl',
          ($0.GetPaperPdfUrlRequest value) => value.writeToBuffer(),
          $0.GetPaperPdfUrlResponse.fromBuffer);
  static final _$getPaperDocxUrl =
      $grpc.ClientMethod<$0.GetPaperDocxUrlRequest, $0.GetPaperDocxUrlResponse>(
          '/paper_service.PaperService/GetPaperDocxUrl',
          ($0.GetPaperDocxUrlRequest value) => value.writeToBuffer(),
          $0.GetPaperDocxUrlResponse.fromBuffer);
  static final _$getMarkingSchemeUrl = $grpc.ClientMethod<
          $0.GetMarkingSchemeUrlRequest, $0.GetMarkingSchemeUrlResponse>(
      '/paper_service.PaperService/GetMarkingSchemeUrl',
      ($0.GetMarkingSchemeUrlRequest value) => value.writeToBuffer(),
      $0.GetMarkingSchemeUrlResponse.fromBuffer);
  static final _$forceSetPaperStatus = $grpc.ClientMethod<
          $0.ForceSetPaperStatusRequest, $0.ForceSetPaperStatusResponse>(
      '/paper_service.PaperService/ForceSetPaperStatus',
      ($0.ForceSetPaperStatusRequest value) => value.writeToBuffer(),
      $0.ForceSetPaperStatusResponse.fromBuffer);
  static final _$deletePaper =
      $grpc.ClientMethod<$0.DeletePaperRequest, $0.DeletePaperResponse>(
          '/paper_service.PaperService/DeletePaper',
          ($0.DeletePaperRequest value) => value.writeToBuffer(),
          $0.DeletePaperResponse.fromBuffer);
}

@$pb.GrpcServiceName('paper_service.PaperService')
abstract class PaperServiceBase extends $grpc.Service {
  $core.String get $name => 'paper_service.PaperService';

  PaperServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreatePaperRequest, $0.CreatePaperResponse>(
            'CreatePaper',
            createPaper_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreatePaperRequest.fromBuffer(value),
            ($0.CreatePaperResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPaperRequest, $0.GetPaperResponse>(
        'GetPaper',
        getPaper_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetPaperRequest.fromBuffer(value),
        ($0.GetPaperResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListPapersRequest, $0.ListPapersResponse>(
        'ListPapers',
        listPapers_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListPapersRequest.fromBuffer(value),
        ($0.ListPapersResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdatePaperRequest, $0.UpdatePaperResponse>(
            'UpdatePaper',
            updatePaper_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdatePaperRequest.fromBuffer(value),
            ($0.UpdatePaperResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPaperPdfUrlRequest,
            $0.GetPaperPdfUrlResponse>(
        'GetPaperPdfUrl',
        getPaperPdfUrl_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPaperPdfUrlRequest.fromBuffer(value),
        ($0.GetPaperPdfUrlResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPaperDocxUrlRequest,
            $0.GetPaperDocxUrlResponse>(
        'GetPaperDocxUrl',
        getPaperDocxUrl_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPaperDocxUrlRequest.fromBuffer(value),
        ($0.GetPaperDocxUrlResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetMarkingSchemeUrlRequest,
            $0.GetMarkingSchemeUrlResponse>(
        'GetMarkingSchemeUrl',
        getMarkingSchemeUrl_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetMarkingSchemeUrlRequest.fromBuffer(value),
        ($0.GetMarkingSchemeUrlResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ForceSetPaperStatusRequest,
            $0.ForceSetPaperStatusResponse>(
        'ForceSetPaperStatus',
        forceSetPaperStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ForceSetPaperStatusRequest.fromBuffer(value),
        ($0.ForceSetPaperStatusResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeletePaperRequest, $0.DeletePaperResponse>(
            'DeletePaper',
            deletePaper_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeletePaperRequest.fromBuffer(value),
            ($0.DeletePaperResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreatePaperResponse> createPaper_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreatePaperRequest> $request) async {
    return createPaper($call, await $request);
  }

  $async.Future<$0.CreatePaperResponse> createPaper(
      $grpc.ServiceCall call, $0.CreatePaperRequest request);

  $async.Future<$0.GetPaperResponse> getPaper_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetPaperRequest> $request) async {
    return getPaper($call, await $request);
  }

  $async.Future<$0.GetPaperResponse> getPaper(
      $grpc.ServiceCall call, $0.GetPaperRequest request);

  $async.Future<$0.ListPapersResponse> listPapers_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListPapersRequest> $request) async {
    return listPapers($call, await $request);
  }

  $async.Future<$0.ListPapersResponse> listPapers(
      $grpc.ServiceCall call, $0.ListPapersRequest request);

  $async.Future<$0.UpdatePaperResponse> updatePaper_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdatePaperRequest> $request) async {
    return updatePaper($call, await $request);
  }

  $async.Future<$0.UpdatePaperResponse> updatePaper(
      $grpc.ServiceCall call, $0.UpdatePaperRequest request);

  $async.Future<$0.GetPaperPdfUrlResponse> getPaperPdfUrl_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPaperPdfUrlRequest> $request) async {
    return getPaperPdfUrl($call, await $request);
  }

  $async.Future<$0.GetPaperPdfUrlResponse> getPaperPdfUrl(
      $grpc.ServiceCall call, $0.GetPaperPdfUrlRequest request);

  $async.Future<$0.GetPaperDocxUrlResponse> getPaperDocxUrl_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPaperDocxUrlRequest> $request) async {
    return getPaperDocxUrl($call, await $request);
  }

  $async.Future<$0.GetPaperDocxUrlResponse> getPaperDocxUrl(
      $grpc.ServiceCall call, $0.GetPaperDocxUrlRequest request);

  $async.Future<$0.GetMarkingSchemeUrlResponse> getMarkingSchemeUrl_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetMarkingSchemeUrlRequest> $request) async {
    return getMarkingSchemeUrl($call, await $request);
  }

  $async.Future<$0.GetMarkingSchemeUrlResponse> getMarkingSchemeUrl(
      $grpc.ServiceCall call, $0.GetMarkingSchemeUrlRequest request);

  $async.Future<$0.ForceSetPaperStatusResponse> forceSetPaperStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ForceSetPaperStatusRequest> $request) async {
    return forceSetPaperStatus($call, await $request);
  }

  $async.Future<$0.ForceSetPaperStatusResponse> forceSetPaperStatus(
      $grpc.ServiceCall call, $0.ForceSetPaperStatusRequest request);

  $async.Future<$0.DeletePaperResponse> deletePaper_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePaperRequest> $request) async {
    return deletePaper($call, await $request);
  }

  $async.Future<$0.DeletePaperResponse> deletePaper(
      $grpc.ServiceCall call, $0.DeletePaperRequest request);
}
