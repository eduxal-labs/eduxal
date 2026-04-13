// This is a generated file - do not edit.
//
// Generated from services/question_bank.proto.

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

import 'question_bank.pb.dart' as $0;

export 'question_bank.pb.dart';

@$pb.GrpcServiceName('question_bank.QuestionBank')
class QuestionBankClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  QuestionBankClient(super.channel, {super.options, super.interceptors});

  /// === System User Operations (question management) ===
  $grpc.ResponseFuture<$0.CreateQuestionResponse> createQuestion(
    $0.CreateQuestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createQuestion, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateQuestionResponse> updateQuestion(
    $0.UpdateQuestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateQuestion, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteQuestionResponse> deleteQuestion(
    $0.DeleteQuestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteQuestion, request, options: options);
  }

  $grpc.ResponseFuture<$0.BulkImportResponse> bulkImportQuestions(
    $0.BulkImportRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$bulkImportQuestions, request, options: options);
  }

  $grpc.ResponseFuture<$0.ImageUploadUrlsResponse> requestImageUploadUrls(
    $0.ImageUploadUrlsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$requestImageUploadUrls, request,
        options: options);
  }

  /// === Teacher Operations (exam paper assembly) ===
  $grpc.ResponseFuture<$0.GeneratePaperResponse> generatePaper(
    $0.GeneratePaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generatePaper, request, options: options);
  }

  $grpc.ResponseFuture<$0.RegenerateQuestionResponse> regenerateQuestion(
    $0.RegenerateQuestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$regenerateQuestion, request, options: options);
  }

  $grpc.ResponseFuture<$0.EditPaperQuestionResponse> editPaperQuestion(
    $0.EditPaperQuestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$editPaperQuestion, request, options: options);
  }

  $grpc.ResponseFuture<$0.FinalizePaperResponse> finalizePaper(
    $0.FinalizePaperRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$finalizePaper, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPaperPdfResponse> getPaperPdf(
    $0.GetPaperPdfRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPaperPdf, request, options: options);
  }

  /// === Read Operations ===
  $grpc.ResponseFuture<$0.ListQuestionsResponse> listQuestions(
    $0.ListQuestionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listQuestions, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetQuestionResponse> getQuestion(
    $0.GetQuestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getQuestion, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetQuestionGradesResponse> getQuestionGrades(
    $0.GetQuestionGradesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getQuestionGrades, request, options: options);
  }

  $grpc.ResponseFuture<$0.MarkingStatusResponse> getMarkingStatus(
    $0.MarkingStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMarkingStatus, request, options: options);
  }

  // method descriptors

  static final _$createQuestion =
      $grpc.ClientMethod<$0.CreateQuestionRequest, $0.CreateQuestionResponse>(
          '/question_bank.QuestionBank/CreateQuestion',
          ($0.CreateQuestionRequest value) => value.writeToBuffer(),
          $0.CreateQuestionResponse.fromBuffer);
  static final _$updateQuestion =
      $grpc.ClientMethod<$0.UpdateQuestionRequest, $0.UpdateQuestionResponse>(
          '/question_bank.QuestionBank/UpdateQuestion',
          ($0.UpdateQuestionRequest value) => value.writeToBuffer(),
          $0.UpdateQuestionResponse.fromBuffer);
  static final _$deleteQuestion =
      $grpc.ClientMethod<$0.DeleteQuestionRequest, $0.DeleteQuestionResponse>(
          '/question_bank.QuestionBank/DeleteQuestion',
          ($0.DeleteQuestionRequest value) => value.writeToBuffer(),
          $0.DeleteQuestionResponse.fromBuffer);
  static final _$bulkImportQuestions =
      $grpc.ClientMethod<$0.BulkImportRequest, $0.BulkImportResponse>(
          '/question_bank.QuestionBank/BulkImportQuestions',
          ($0.BulkImportRequest value) => value.writeToBuffer(),
          $0.BulkImportResponse.fromBuffer);
  static final _$requestImageUploadUrls =
      $grpc.ClientMethod<$0.ImageUploadUrlsRequest, $0.ImageUploadUrlsResponse>(
          '/question_bank.QuestionBank/RequestImageUploadUrls',
          ($0.ImageUploadUrlsRequest value) => value.writeToBuffer(),
          $0.ImageUploadUrlsResponse.fromBuffer);
  static final _$generatePaper =
      $grpc.ClientMethod<$0.GeneratePaperRequest, $0.GeneratePaperResponse>(
          '/question_bank.QuestionBank/GeneratePaper',
          ($0.GeneratePaperRequest value) => value.writeToBuffer(),
          $0.GeneratePaperResponse.fromBuffer);
  static final _$regenerateQuestion = $grpc.ClientMethod<
          $0.RegenerateQuestionRequest, $0.RegenerateQuestionResponse>(
      '/question_bank.QuestionBank/RegenerateQuestion',
      ($0.RegenerateQuestionRequest value) => value.writeToBuffer(),
      $0.RegenerateQuestionResponse.fromBuffer);
  static final _$editPaperQuestion = $grpc.ClientMethod<
          $0.EditPaperQuestionRequest, $0.EditPaperQuestionResponse>(
      '/question_bank.QuestionBank/EditPaperQuestion',
      ($0.EditPaperQuestionRequest value) => value.writeToBuffer(),
      $0.EditPaperQuestionResponse.fromBuffer);
  static final _$finalizePaper =
      $grpc.ClientMethod<$0.FinalizePaperRequest, $0.FinalizePaperResponse>(
          '/question_bank.QuestionBank/FinalizePaper',
          ($0.FinalizePaperRequest value) => value.writeToBuffer(),
          $0.FinalizePaperResponse.fromBuffer);
  static final _$getPaperPdf =
      $grpc.ClientMethod<$0.GetPaperPdfRequest, $0.GetPaperPdfResponse>(
          '/question_bank.QuestionBank/GetPaperPdf',
          ($0.GetPaperPdfRequest value) => value.writeToBuffer(),
          $0.GetPaperPdfResponse.fromBuffer);
  static final _$listQuestions =
      $grpc.ClientMethod<$0.ListQuestionsRequest, $0.ListQuestionsResponse>(
          '/question_bank.QuestionBank/ListQuestions',
          ($0.ListQuestionsRequest value) => value.writeToBuffer(),
          $0.ListQuestionsResponse.fromBuffer);
  static final _$getQuestion =
      $grpc.ClientMethod<$0.GetQuestionRequest, $0.GetQuestionResponse>(
          '/question_bank.QuestionBank/GetQuestion',
          ($0.GetQuestionRequest value) => value.writeToBuffer(),
          $0.GetQuestionResponse.fromBuffer);
  static final _$getQuestionGrades = $grpc.ClientMethod<
          $0.GetQuestionGradesRequest, $0.GetQuestionGradesResponse>(
      '/question_bank.QuestionBank/GetQuestionGrades',
      ($0.GetQuestionGradesRequest value) => value.writeToBuffer(),
      $0.GetQuestionGradesResponse.fromBuffer);
  static final _$getMarkingStatus =
      $grpc.ClientMethod<$0.MarkingStatusRequest, $0.MarkingStatusResponse>(
          '/question_bank.QuestionBank/GetMarkingStatus',
          ($0.MarkingStatusRequest value) => value.writeToBuffer(),
          $0.MarkingStatusResponse.fromBuffer);
}

@$pb.GrpcServiceName('question_bank.QuestionBank')
abstract class QuestionBankServiceBase extends $grpc.Service {
  $core.String get $name => 'question_bank.QuestionBank';

  QuestionBankServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateQuestionRequest,
            $0.CreateQuestionResponse>(
        'CreateQuestion',
        createQuestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateQuestionRequest.fromBuffer(value),
        ($0.CreateQuestionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateQuestionRequest,
            $0.UpdateQuestionResponse>(
        'UpdateQuestion',
        updateQuestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateQuestionRequest.fromBuffer(value),
        ($0.UpdateQuestionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteQuestionRequest,
            $0.DeleteQuestionResponse>(
        'DeleteQuestion',
        deleteQuestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteQuestionRequest.fromBuffer(value),
        ($0.DeleteQuestionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BulkImportRequest, $0.BulkImportResponse>(
        'BulkImportQuestions',
        bulkImportQuestions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BulkImportRequest.fromBuffer(value),
        ($0.BulkImportResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ImageUploadUrlsRequest,
            $0.ImageUploadUrlsResponse>(
        'RequestImageUploadUrls',
        requestImageUploadUrls_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ImageUploadUrlsRequest.fromBuffer(value),
        ($0.ImageUploadUrlsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GeneratePaperRequest, $0.GeneratePaperResponse>(
            'GeneratePaper',
            generatePaper_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GeneratePaperRequest.fromBuffer(value),
            ($0.GeneratePaperResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RegenerateQuestionRequest,
            $0.RegenerateQuestionResponse>(
        'RegenerateQuestion',
        regenerateQuestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RegenerateQuestionRequest.fromBuffer(value),
        ($0.RegenerateQuestionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EditPaperQuestionRequest,
            $0.EditPaperQuestionResponse>(
        'EditPaperQuestion',
        editPaperQuestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.EditPaperQuestionRequest.fromBuffer(value),
        ($0.EditPaperQuestionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.FinalizePaperRequest, $0.FinalizePaperResponse>(
            'FinalizePaper',
            finalizePaper_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.FinalizePaperRequest.fromBuffer(value),
            ($0.FinalizePaperResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetPaperPdfRequest, $0.GetPaperPdfResponse>(
            'GetPaperPdf',
            getPaperPdf_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetPaperPdfRequest.fromBuffer(value),
            ($0.GetPaperPdfResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListQuestionsRequest, $0.ListQuestionsResponse>(
            'ListQuestions',
            listQuestions_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListQuestionsRequest.fromBuffer(value),
            ($0.ListQuestionsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetQuestionRequest, $0.GetQuestionResponse>(
            'GetQuestion',
            getQuestion_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetQuestionRequest.fromBuffer(value),
            ($0.GetQuestionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetQuestionGradesRequest,
            $0.GetQuestionGradesResponse>(
        'GetQuestionGrades',
        getQuestionGrades_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetQuestionGradesRequest.fromBuffer(value),
        ($0.GetQuestionGradesResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.MarkingStatusRequest, $0.MarkingStatusResponse>(
            'GetMarkingStatus',
            getMarkingStatus_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.MarkingStatusRequest.fromBuffer(value),
            ($0.MarkingStatusResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateQuestionResponse> createQuestion_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CreateQuestionRequest> $request) async {
    return createQuestion($call, await $request);
  }

  $async.Future<$0.CreateQuestionResponse> createQuestion(
      $grpc.ServiceCall call, $0.CreateQuestionRequest request);

  $async.Future<$0.UpdateQuestionResponse> updateQuestion_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateQuestionRequest> $request) async {
    return updateQuestion($call, await $request);
  }

  $async.Future<$0.UpdateQuestionResponse> updateQuestion(
      $grpc.ServiceCall call, $0.UpdateQuestionRequest request);

  $async.Future<$0.DeleteQuestionResponse> deleteQuestion_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteQuestionRequest> $request) async {
    return deleteQuestion($call, await $request);
  }

  $async.Future<$0.DeleteQuestionResponse> deleteQuestion(
      $grpc.ServiceCall call, $0.DeleteQuestionRequest request);

  $async.Future<$0.BulkImportResponse> bulkImportQuestions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BulkImportRequest> $request) async {
    return bulkImportQuestions($call, await $request);
  }

  $async.Future<$0.BulkImportResponse> bulkImportQuestions(
      $grpc.ServiceCall call, $0.BulkImportRequest request);

  $async.Future<$0.ImageUploadUrlsResponse> requestImageUploadUrls_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ImageUploadUrlsRequest> $request) async {
    return requestImageUploadUrls($call, await $request);
  }

  $async.Future<$0.ImageUploadUrlsResponse> requestImageUploadUrls(
      $grpc.ServiceCall call, $0.ImageUploadUrlsRequest request);

  $async.Future<$0.GeneratePaperResponse> generatePaper_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GeneratePaperRequest> $request) async {
    return generatePaper($call, await $request);
  }

  $async.Future<$0.GeneratePaperResponse> generatePaper(
      $grpc.ServiceCall call, $0.GeneratePaperRequest request);

  $async.Future<$0.RegenerateQuestionResponse> regenerateQuestion_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RegenerateQuestionRequest> $request) async {
    return regenerateQuestion($call, await $request);
  }

  $async.Future<$0.RegenerateQuestionResponse> regenerateQuestion(
      $grpc.ServiceCall call, $0.RegenerateQuestionRequest request);

  $async.Future<$0.EditPaperQuestionResponse> editPaperQuestion_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.EditPaperQuestionRequest> $request) async {
    return editPaperQuestion($call, await $request);
  }

  $async.Future<$0.EditPaperQuestionResponse> editPaperQuestion(
      $grpc.ServiceCall call, $0.EditPaperQuestionRequest request);

  $async.Future<$0.FinalizePaperResponse> finalizePaper_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.FinalizePaperRequest> $request) async {
    return finalizePaper($call, await $request);
  }

  $async.Future<$0.FinalizePaperResponse> finalizePaper(
      $grpc.ServiceCall call, $0.FinalizePaperRequest request);

  $async.Future<$0.GetPaperPdfResponse> getPaperPdf_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetPaperPdfRequest> $request) async {
    return getPaperPdf($call, await $request);
  }

  $async.Future<$0.GetPaperPdfResponse> getPaperPdf(
      $grpc.ServiceCall call, $0.GetPaperPdfRequest request);

  $async.Future<$0.ListQuestionsResponse> listQuestions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListQuestionsRequest> $request) async {
    return listQuestions($call, await $request);
  }

  $async.Future<$0.ListQuestionsResponse> listQuestions(
      $grpc.ServiceCall call, $0.ListQuestionsRequest request);

  $async.Future<$0.GetQuestionResponse> getQuestion_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetQuestionRequest> $request) async {
    return getQuestion($call, await $request);
  }

  $async.Future<$0.GetQuestionResponse> getQuestion(
      $grpc.ServiceCall call, $0.GetQuestionRequest request);

  $async.Future<$0.GetQuestionGradesResponse> getQuestionGrades_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetQuestionGradesRequest> $request) async {
    return getQuestionGrades($call, await $request);
  }

  $async.Future<$0.GetQuestionGradesResponse> getQuestionGrades(
      $grpc.ServiceCall call, $0.GetQuestionGradesRequest request);

  $async.Future<$0.MarkingStatusResponse> getMarkingStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.MarkingStatusRequest> $request) async {
    return getMarkingStatus($call, await $request);
  }

  $async.Future<$0.MarkingStatusResponse> getMarkingStatus(
      $grpc.ServiceCall call, $0.MarkingStatusRequest request);
}
