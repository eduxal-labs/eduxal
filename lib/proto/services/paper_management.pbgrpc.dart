// This is a generated file - do not edit.
//
// Generated from services/paper_management.proto.

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

import 'paper_management.pb.dart' as $0;

export 'paper_management.pb.dart';

@$pb.GrpcServiceName('paper_management.PaperManagement')
class PaperManagementClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PaperManagementClient(super.channel, {super.options, super.interceptors});

  /// ── Schedules ──
  $grpc.ResponseFuture<$0.SchedulePaperResponse> schedulePaper(
    $0.SchedulePaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$schedulePaper, request, options: options);
  }

  $grpc.ResponseFuture<$0.AssignInvigilatorResponse> assignInvigilator(
    $0.AssignInvigilatorRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$assignInvigilator, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListSchedulesResponse> listPaperSchedules(
    $0.ListSchedulesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPaperSchedules, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateScheduleResponse> updateSchedule(
    $0.UpdateScheduleRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSchedule, request, options: options);
  }

  /// ── Taught Topics ──
  $grpc.ResponseFuture<$0.SetTaughtTopicsResponse> setTaughtTopics(
    $0.SetTaughtTopicsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setTaughtTopics, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetTaughtTopicsResponse> getTaughtTopics(
    $0.GetTaughtTopicsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTaughtTopics, request, options: options);
  }

  /// ── Coverage ──
  $grpc.ResponseFuture<$0.ConfirmExamCoverageResponse> confirmExamCoverage(
    $0.ConfirmExamCoverageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$confirmExamCoverage, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetExamCoverageResponse> getExamCoverage(
    $0.GetExamCoverageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getExamCoverage, request, options: options);
  }

  /// ── Generation ──
  $grpc.ResponseFuture<$0.GenerateAssessmentResponse> generateAssessment(
    $0.GenerateAssessmentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateAssessment, request, options: options);
  }

  $grpc.ResponseFuture<$0.GenerateAssignmentResponse> generateAssignment(
    $0.GenerateAssignmentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateAssignment, request, options: options);
  }

  /// ── Per-student PDFs ──
  $grpc.ResponseFuture<$0.FinalizeStudentPapersResponse> finalizeStudentPapers(
    $0.FinalizeStudentPapersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$finalizeStudentPapers, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetStudentPapersStatusResponse>
      getStudentPapersStatus(
    $0.GetStudentPapersStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStudentPapersStatus, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.GetStudentPaperPdfResponse> getStudentPaperPdf(
    $0.GetStudentPaperPdfRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStudentPaperPdf, request, options: options);
  }

  // method descriptors

  static final _$schedulePaper =
      $grpc.ClientMethod<$0.SchedulePaperRequest, $0.SchedulePaperResponse>(
          '/paper_management.PaperManagement/SchedulePaper',
          ($0.SchedulePaperRequest value) => value.writeToBuffer(),
          $0.SchedulePaperResponse.fromBuffer);
  static final _$assignInvigilator = $grpc.ClientMethod<
          $0.AssignInvigilatorRequest, $0.AssignInvigilatorResponse>(
      '/paper_management.PaperManagement/AssignInvigilator',
      ($0.AssignInvigilatorRequest value) => value.writeToBuffer(),
      $0.AssignInvigilatorResponse.fromBuffer);
  static final _$listPaperSchedules =
      $grpc.ClientMethod<$0.ListSchedulesRequest, $0.ListSchedulesResponse>(
          '/paper_management.PaperManagement/ListPaperSchedules',
          ($0.ListSchedulesRequest value) => value.writeToBuffer(),
          $0.ListSchedulesResponse.fromBuffer);
  static final _$updateSchedule =
      $grpc.ClientMethod<$0.UpdateScheduleRequest, $0.UpdateScheduleResponse>(
          '/paper_management.PaperManagement/UpdateSchedule',
          ($0.UpdateScheduleRequest value) => value.writeToBuffer(),
          $0.UpdateScheduleResponse.fromBuffer);
  static final _$setTaughtTopics =
      $grpc.ClientMethod<$0.SetTaughtTopicsRequest, $0.SetTaughtTopicsResponse>(
          '/paper_management.PaperManagement/SetTaughtTopics',
          ($0.SetTaughtTopicsRequest value) => value.writeToBuffer(),
          $0.SetTaughtTopicsResponse.fromBuffer);
  static final _$getTaughtTopics =
      $grpc.ClientMethod<$0.GetTaughtTopicsRequest, $0.GetTaughtTopicsResponse>(
          '/paper_management.PaperManagement/GetTaughtTopics',
          ($0.GetTaughtTopicsRequest value) => value.writeToBuffer(),
          $0.GetTaughtTopicsResponse.fromBuffer);
  static final _$confirmExamCoverage = $grpc.ClientMethod<
          $0.ConfirmExamCoverageRequest, $0.ConfirmExamCoverageResponse>(
      '/paper_management.PaperManagement/ConfirmExamCoverage',
      ($0.ConfirmExamCoverageRequest value) => value.writeToBuffer(),
      $0.ConfirmExamCoverageResponse.fromBuffer);
  static final _$getExamCoverage =
      $grpc.ClientMethod<$0.GetExamCoverageRequest, $0.GetExamCoverageResponse>(
          '/paper_management.PaperManagement/GetExamCoverage',
          ($0.GetExamCoverageRequest value) => value.writeToBuffer(),
          $0.GetExamCoverageResponse.fromBuffer);
  static final _$generateAssessment = $grpc.ClientMethod<
          $0.GenerateAssessmentRequest, $0.GenerateAssessmentResponse>(
      '/paper_management.PaperManagement/GenerateAssessment',
      ($0.GenerateAssessmentRequest value) => value.writeToBuffer(),
      $0.GenerateAssessmentResponse.fromBuffer);
  static final _$generateAssignment = $grpc.ClientMethod<
          $0.GenerateAssignmentRequest, $0.GenerateAssignmentResponse>(
      '/paper_management.PaperManagement/GenerateAssignment',
      ($0.GenerateAssignmentRequest value) => value.writeToBuffer(),
      $0.GenerateAssignmentResponse.fromBuffer);
  static final _$finalizeStudentPapers = $grpc.ClientMethod<
          $0.FinalizeStudentPapersRequest, $0.FinalizeStudentPapersResponse>(
      '/paper_management.PaperManagement/FinalizeStudentPapers',
      ($0.FinalizeStudentPapersRequest value) => value.writeToBuffer(),
      $0.FinalizeStudentPapersResponse.fromBuffer);
  static final _$getStudentPapersStatus = $grpc.ClientMethod<
          $0.GetStudentPapersStatusRequest, $0.GetStudentPapersStatusResponse>(
      '/paper_management.PaperManagement/GetStudentPapersStatus',
      ($0.GetStudentPapersStatusRequest value) => value.writeToBuffer(),
      $0.GetStudentPapersStatusResponse.fromBuffer);
  static final _$getStudentPaperPdf = $grpc.ClientMethod<
          $0.GetStudentPaperPdfRequest, $0.GetStudentPaperPdfResponse>(
      '/paper_management.PaperManagement/GetStudentPaperPdf',
      ($0.GetStudentPaperPdfRequest value) => value.writeToBuffer(),
      $0.GetStudentPaperPdfResponse.fromBuffer);
}

@$pb.GrpcServiceName('paper_management.PaperManagement')
abstract class PaperManagementServiceBase extends $grpc.Service {
  $core.String get $name => 'paper_management.PaperManagement';

  PaperManagementServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.SchedulePaperRequest, $0.SchedulePaperResponse>(
            'SchedulePaper',
            schedulePaper_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SchedulePaperRequest.fromBuffer(value),
            ($0.SchedulePaperResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AssignInvigilatorRequest,
            $0.AssignInvigilatorResponse>(
        'AssignInvigilator',
        assignInvigilator_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AssignInvigilatorRequest.fromBuffer(value),
        ($0.AssignInvigilatorResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListSchedulesRequest, $0.ListSchedulesResponse>(
            'ListPaperSchedules',
            listPaperSchedules_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListSchedulesRequest.fromBuffer(value),
            ($0.ListSchedulesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateScheduleRequest,
            $0.UpdateScheduleResponse>(
        'UpdateSchedule',
        updateSchedule_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateScheduleRequest.fromBuffer(value),
        ($0.UpdateScheduleResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetTaughtTopicsRequest,
            $0.SetTaughtTopicsResponse>(
        'SetTaughtTopics',
        setTaughtTopics_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetTaughtTopicsRequest.fromBuffer(value),
        ($0.SetTaughtTopicsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetTaughtTopicsRequest,
            $0.GetTaughtTopicsResponse>(
        'GetTaughtTopics',
        getTaughtTopics_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetTaughtTopicsRequest.fromBuffer(value),
        ($0.GetTaughtTopicsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ConfirmExamCoverageRequest,
            $0.ConfirmExamCoverageResponse>(
        'ConfirmExamCoverage',
        confirmExamCoverage_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ConfirmExamCoverageRequest.fromBuffer(value),
        ($0.ConfirmExamCoverageResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetExamCoverageRequest,
            $0.GetExamCoverageResponse>(
        'GetExamCoverage',
        getExamCoverage_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetExamCoverageRequest.fromBuffer(value),
        ($0.GetExamCoverageResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateAssessmentRequest,
            $0.GenerateAssessmentResponse>(
        'GenerateAssessment',
        generateAssessment_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GenerateAssessmentRequest.fromBuffer(value),
        ($0.GenerateAssessmentResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateAssignmentRequest,
            $0.GenerateAssignmentResponse>(
        'GenerateAssignment',
        generateAssignment_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GenerateAssignmentRequest.fromBuffer(value),
        ($0.GenerateAssignmentResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.FinalizeStudentPapersRequest,
            $0.FinalizeStudentPapersResponse>(
        'FinalizeStudentPapers',
        finalizeStudentPapers_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.FinalizeStudentPapersRequest.fromBuffer(value),
        ($0.FinalizeStudentPapersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetStudentPapersStatusRequest,
            $0.GetStudentPapersStatusResponse>(
        'GetStudentPapersStatus',
        getStudentPapersStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetStudentPapersStatusRequest.fromBuffer(value),
        ($0.GetStudentPapersStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetStudentPaperPdfRequest,
            $0.GetStudentPaperPdfResponse>(
        'GetStudentPaperPdf',
        getStudentPaperPdf_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetStudentPaperPdfRequest.fromBuffer(value),
        ($0.GetStudentPaperPdfResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.SchedulePaperResponse> schedulePaper_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SchedulePaperRequest> $request) async {
    return schedulePaper($call, await $request);
  }

  $async.Future<$0.SchedulePaperResponse> schedulePaper(
      $grpc.ServiceCall call, $0.SchedulePaperRequest request);

  $async.Future<$0.AssignInvigilatorResponse> assignInvigilator_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AssignInvigilatorRequest> $request) async {
    return assignInvigilator($call, await $request);
  }

  $async.Future<$0.AssignInvigilatorResponse> assignInvigilator(
      $grpc.ServiceCall call, $0.AssignInvigilatorRequest request);

  $async.Future<$0.ListSchedulesResponse> listPaperSchedules_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListSchedulesRequest> $request) async {
    return listPaperSchedules($call, await $request);
  }

  $async.Future<$0.ListSchedulesResponse> listPaperSchedules(
      $grpc.ServiceCall call, $0.ListSchedulesRequest request);

  $async.Future<$0.UpdateScheduleResponse> updateSchedule_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateScheduleRequest> $request) async {
    return updateSchedule($call, await $request);
  }

  $async.Future<$0.UpdateScheduleResponse> updateSchedule(
      $grpc.ServiceCall call, $0.UpdateScheduleRequest request);

  $async.Future<$0.SetTaughtTopicsResponse> setTaughtTopics_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SetTaughtTopicsRequest> $request) async {
    return setTaughtTopics($call, await $request);
  }

  $async.Future<$0.SetTaughtTopicsResponse> setTaughtTopics(
      $grpc.ServiceCall call, $0.SetTaughtTopicsRequest request);

  $async.Future<$0.GetTaughtTopicsResponse> getTaughtTopics_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetTaughtTopicsRequest> $request) async {
    return getTaughtTopics($call, await $request);
  }

  $async.Future<$0.GetTaughtTopicsResponse> getTaughtTopics(
      $grpc.ServiceCall call, $0.GetTaughtTopicsRequest request);

  $async.Future<$0.ConfirmExamCoverageResponse> confirmExamCoverage_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ConfirmExamCoverageRequest> $request) async {
    return confirmExamCoverage($call, await $request);
  }

  $async.Future<$0.ConfirmExamCoverageResponse> confirmExamCoverage(
      $grpc.ServiceCall call, $0.ConfirmExamCoverageRequest request);

  $async.Future<$0.GetExamCoverageResponse> getExamCoverage_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetExamCoverageRequest> $request) async {
    return getExamCoverage($call, await $request);
  }

  $async.Future<$0.GetExamCoverageResponse> getExamCoverage(
      $grpc.ServiceCall call, $0.GetExamCoverageRequest request);

  $async.Future<$0.GenerateAssessmentResponse> generateAssessment_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GenerateAssessmentRequest> $request) async {
    return generateAssessment($call, await $request);
  }

  $async.Future<$0.GenerateAssessmentResponse> generateAssessment(
      $grpc.ServiceCall call, $0.GenerateAssessmentRequest request);

  $async.Future<$0.GenerateAssignmentResponse> generateAssignment_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GenerateAssignmentRequest> $request) async {
    return generateAssignment($call, await $request);
  }

  $async.Future<$0.GenerateAssignmentResponse> generateAssignment(
      $grpc.ServiceCall call, $0.GenerateAssignmentRequest request);

  $async.Future<$0.FinalizeStudentPapersResponse> finalizeStudentPapers_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.FinalizeStudentPapersRequest> $request) async {
    return finalizeStudentPapers($call, await $request);
  }

  $async.Future<$0.FinalizeStudentPapersResponse> finalizeStudentPapers(
      $grpc.ServiceCall call, $0.FinalizeStudentPapersRequest request);

  $async.Future<$0.GetStudentPapersStatusResponse> getStudentPapersStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetStudentPapersStatusRequest> $request) async {
    return getStudentPapersStatus($call, await $request);
  }

  $async.Future<$0.GetStudentPapersStatusResponse> getStudentPapersStatus(
      $grpc.ServiceCall call, $0.GetStudentPapersStatusRequest request);

  $async.Future<$0.GetStudentPaperPdfResponse> getStudentPaperPdf_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetStudentPaperPdfRequest> $request) async {
    return getStudentPaperPdf($call, await $request);
  }

  $async.Future<$0.GetStudentPaperPdfResponse> getStudentPaperPdf(
      $grpc.ServiceCall call, $0.GetStudentPaperPdfRequest request);
}
