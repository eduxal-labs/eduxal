// This is a generated file - do not edit.
//
// Generated from services/event.proto.

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

import 'event.pb.dart' as $0;

export 'event.pb.dart';

@$pb.GrpcServiceName('event_service.EventService')
class EventServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  EventServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CreateEventResponse> createEvent(
    $0.CreateEventRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createEvent, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetEventResponse> getEvent(
    $0.GetEventRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getEvent, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListEventsResponse> listEvents(
    $0.ListEventsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listEvents, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateEventResponse> updateEvent(
    $0.UpdateEventRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateEvent, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteEventResponse> deleteEvent(
    $0.DeleteEventRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteEvent, request, options: options);
  }

  // method descriptors

  static final _$createEvent =
      $grpc.ClientMethod<$0.CreateEventRequest, $0.CreateEventResponse>(
          '/event_service.EventService/CreateEvent',
          ($0.CreateEventRequest value) => value.writeToBuffer(),
          $0.CreateEventResponse.fromBuffer);
  static final _$getEvent =
      $grpc.ClientMethod<$0.GetEventRequest, $0.GetEventResponse>(
          '/event_service.EventService/GetEvent',
          ($0.GetEventRequest value) => value.writeToBuffer(),
          $0.GetEventResponse.fromBuffer);
  static final _$listEvents =
      $grpc.ClientMethod<$0.ListEventsRequest, $0.ListEventsResponse>(
          '/event_service.EventService/ListEvents',
          ($0.ListEventsRequest value) => value.writeToBuffer(),
          $0.ListEventsResponse.fromBuffer);
  static final _$updateEvent =
      $grpc.ClientMethod<$0.UpdateEventRequest, $0.UpdateEventResponse>(
          '/event_service.EventService/UpdateEvent',
          ($0.UpdateEventRequest value) => value.writeToBuffer(),
          $0.UpdateEventResponse.fromBuffer);
  static final _$deleteEvent =
      $grpc.ClientMethod<$0.DeleteEventRequest, $0.DeleteEventResponse>(
          '/event_service.EventService/DeleteEvent',
          ($0.DeleteEventRequest value) => value.writeToBuffer(),
          $0.DeleteEventResponse.fromBuffer);
}

@$pb.GrpcServiceName('event_service.EventService')
abstract class EventServiceBase extends $grpc.Service {
  $core.String get $name => 'event_service.EventService';

  EventServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreateEventRequest, $0.CreateEventResponse>(
            'CreateEvent',
            createEvent_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateEventRequest.fromBuffer(value),
            ($0.CreateEventResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetEventRequest, $0.GetEventResponse>(
        'GetEvent',
        getEvent_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetEventRequest.fromBuffer(value),
        ($0.GetEventResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListEventsRequest, $0.ListEventsResponse>(
        'ListEvents',
        listEvents_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListEventsRequest.fromBuffer(value),
        ($0.ListEventsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateEventRequest, $0.UpdateEventResponse>(
            'UpdateEvent',
            updateEvent_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateEventRequest.fromBuffer(value),
            ($0.UpdateEventResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteEventRequest, $0.DeleteEventResponse>(
            'DeleteEvent',
            deleteEvent_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteEventRequest.fromBuffer(value),
            ($0.DeleteEventResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateEventResponse> createEvent_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateEventRequest> $request) async {
    return createEvent($call, await $request);
  }

  $async.Future<$0.CreateEventResponse> createEvent(
      $grpc.ServiceCall call, $0.CreateEventRequest request);

  $async.Future<$0.GetEventResponse> getEvent_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetEventRequest> $request) async {
    return getEvent($call, await $request);
  }

  $async.Future<$0.GetEventResponse> getEvent(
      $grpc.ServiceCall call, $0.GetEventRequest request);

  $async.Future<$0.ListEventsResponse> listEvents_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListEventsRequest> $request) async {
    return listEvents($call, await $request);
  }

  $async.Future<$0.ListEventsResponse> listEvents(
      $grpc.ServiceCall call, $0.ListEventsRequest request);

  $async.Future<$0.UpdateEventResponse> updateEvent_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateEventRequest> $request) async {
    return updateEvent($call, await $request);
  }

  $async.Future<$0.UpdateEventResponse> updateEvent(
      $grpc.ServiceCall call, $0.UpdateEventRequest request);

  $async.Future<$0.DeleteEventResponse> deleteEvent_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteEventRequest> $request) async {
    return deleteEvent($call, await $request);
  }

  $async.Future<$0.DeleteEventResponse> deleteEvent(
      $grpc.ServiceCall call, $0.DeleteEventRequest request);
}
