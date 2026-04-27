// This is a generated file - do not edit.
//
// Generated from services/event.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../types/event.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class CreateEventRequest extends $pb.GeneratedMessage {
  factory CreateEventRequest({
    $core.String? school,
    $core.String? name,
    $core.int? type,
    $core.int? term,
    $core.int? year,
    $core.int? startDate,
    $core.int? endDate,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (term != null) result.term = term;
    if (year != null) result.year = year;
    if (startDate != null) result.startDate = startDate;
    if (endDate != null) result.endDate = endDate;
    return result;
  }

  CreateEventRequest._();

  factory CreateEventRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateEventRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateEventRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'type')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'year')
    ..aI(6, _omitFieldNames ? '' : 'startDate')
    ..aI(7, _omitFieldNames ? '' : 'endDate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateEventRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateEventRequest copyWith(void Function(CreateEventRequest) updates) =>
      super.copyWith((message) => updates(message as CreateEventRequest))
          as CreateEventRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateEventRequest create() => CreateEventRequest._();
  @$core.override
  CreateEventRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateEventRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateEventRequest>(create);
  static CreateEventRequest? _defaultInstance;

  /// / The school this event belongs to.
  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  /// / The name of the event.
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// / The type of the event.
  @$pb.TagNumber(3)
  $core.int get type => $_getIZ(2);
  @$pb.TagNumber(3)
  set type($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  /// / The term in which the event occurs.
  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  /// / The year in which the event occurs.
  @$pb.TagNumber(5)
  $core.int get year => $_getIZ(4);
  @$pb.TagNumber(5)
  set year($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasYear() => $_has(4);
  @$pb.TagNumber(5)
  void clearYear() => $_clearField(5);

  /// / The start date of the event (days since Unix epoch).
  @$pb.TagNumber(6)
  $core.int get startDate => $_getIZ(5);
  @$pb.TagNumber(6)
  set startDate($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartDate() => $_clearField(6);

  /// / The end date of the event (days since Unix epoch).
  @$pb.TagNumber(7)
  $core.int get endDate => $_getIZ(6);
  @$pb.TagNumber(7)
  set endDate($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEndDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearEndDate() => $_clearField(7);
}

class CreateEventResponse extends $pb.GeneratedMessage {
  factory CreateEventResponse({
    $1.Event? event,
  }) {
    final result = create();
    if (event != null) result.event = event;
    return result;
  }

  CreateEventResponse._();

  factory CreateEventResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateEventResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateEventResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOM<$1.Event>(1, _omitFieldNames ? '' : 'event',
        subBuilder: $1.Event.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateEventResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateEventResponse copyWith(void Function(CreateEventResponse) updates) =>
      super.copyWith((message) => updates(message as CreateEventResponse))
          as CreateEventResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateEventResponse create() => CreateEventResponse._();
  @$core.override
  CreateEventResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateEventResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateEventResponse>(create);
  static CreateEventResponse? _defaultInstance;

  /// / The newly created event.
  @$pb.TagNumber(1)
  $1.Event get event => $_getN(0);
  @$pb.TagNumber(1)
  set event($1.Event value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvent() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Event ensureEvent() => $_ensure(0);
}

class GetEventRequest extends $pb.GeneratedMessage {
  factory GetEventRequest({
    $core.String? eventId,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  GetEventRequest._();

  factory GetEventRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetEventRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetEventRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEventRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEventRequest copyWith(void Function(GetEventRequest) updates) =>
      super.copyWith((message) => updates(message as GetEventRequest))
          as GetEventRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetEventRequest create() => GetEventRequest._();
  @$core.override
  GetEventRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetEventRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetEventRequest>(create);
  static GetEventRequest? _defaultInstance;

  /// / The id of the event to retrieve.
  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);
}

class GetEventResponse extends $pb.GeneratedMessage {
  factory GetEventResponse({
    $1.Event? event,
  }) {
    final result = create();
    if (event != null) result.event = event;
    return result;
  }

  GetEventResponse._();

  factory GetEventResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetEventResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetEventResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOM<$1.Event>(1, _omitFieldNames ? '' : 'event',
        subBuilder: $1.Event.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEventResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetEventResponse copyWith(void Function(GetEventResponse) updates) =>
      super.copyWith((message) => updates(message as GetEventResponse))
          as GetEventResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetEventResponse create() => GetEventResponse._();
  @$core.override
  GetEventResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetEventResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetEventResponse>(create);
  static GetEventResponse? _defaultInstance;

  /// / The retrieved event.
  @$pb.TagNumber(1)
  $1.Event get event => $_getN(0);
  @$pb.TagNumber(1)
  set event($1.Event value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvent() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Event ensureEvent() => $_ensure(0);
}

class ListEventsRequest extends $pb.GeneratedMessage {
  factory ListEventsRequest({
    $core.String? school,
    $core.int? year,
    $core.int? term,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    return result;
  }

  ListEventsRequest._();

  factory ListEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListEventsRequest copyWith(void Function(ListEventsRequest) updates) =>
      super.copyWith((message) => updates(message as ListEventsRequest))
          as ListEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListEventsRequest create() => ListEventsRequest._();
  @$core.override
  ListEventsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListEventsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListEventsRequest>(create);
  static ListEventsRequest? _defaultInstance;

  /// / The school whose events to list.
  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  /// / Optional filter by year.
  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  /// / Optional filter by term.
  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);
}

class ListEventsResponse extends $pb.GeneratedMessage {
  factory ListEventsResponse({
    $core.Iterable<$1.Event>? events,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    return result;
  }

  ListEventsResponse._();

  factory ListEventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..pPM<$1.Event>(1, _omitFieldNames ? '' : 'events',
        subBuilder: $1.Event.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListEventsResponse copyWith(void Function(ListEventsResponse) updates) =>
      super.copyWith((message) => updates(message as ListEventsResponse))
          as ListEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListEventsResponse create() => ListEventsResponse._();
  @$core.override
  ListEventsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListEventsResponse>(create);
  static ListEventsResponse? _defaultInstance;

  /// / The list of matching events.
  @$pb.TagNumber(1)
  $pb.PbList<$1.Event> get events => $_getList(0);
}

class UpdateEventRequest extends $pb.GeneratedMessage {
  factory UpdateEventRequest({
    $core.String? eventId,
    $core.String? name,
    $core.int? type,
    $core.int? term,
    $core.int? year,
    $core.int? startDate,
    $core.int? endDate,
    $core.int? status,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (term != null) result.term = term;
    if (year != null) result.year = year;
    if (startDate != null) result.startDate = startDate;
    if (endDate != null) result.endDate = endDate;
    if (status != null) result.status = status;
    return result;
  }

  UpdateEventRequest._();

  factory UpdateEventRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateEventRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateEventRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'type')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'year')
    ..aI(6, _omitFieldNames ? '' : 'startDate')
    ..aI(7, _omitFieldNames ? '' : 'endDate')
    ..aI(8, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateEventRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateEventRequest copyWith(void Function(UpdateEventRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateEventRequest))
          as UpdateEventRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateEventRequest create() => UpdateEventRequest._();
  @$core.override
  UpdateEventRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateEventRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateEventRequest>(create);
  static UpdateEventRequest? _defaultInstance;

  /// / The id of the event to update.
  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  /// / Updated name.
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// / Updated type.
  @$pb.TagNumber(3)
  $core.int get type => $_getIZ(2);
  @$pb.TagNumber(3)
  set type($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  /// / Updated term.
  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  /// / Updated year.
  @$pb.TagNumber(5)
  $core.int get year => $_getIZ(4);
  @$pb.TagNumber(5)
  set year($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasYear() => $_has(4);
  @$pb.TagNumber(5)
  void clearYear() => $_clearField(5);

  /// / Updated start date (days since Unix epoch).
  @$pb.TagNumber(6)
  $core.int get startDate => $_getIZ(5);
  @$pb.TagNumber(6)
  set startDate($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartDate() => $_clearField(6);

  /// / Updated end date (days since Unix epoch).
  @$pb.TagNumber(7)
  $core.int get endDate => $_getIZ(6);
  @$pb.TagNumber(7)
  set endDate($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEndDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearEndDate() => $_clearField(7);

  /// / Updated status.
  @$pb.TagNumber(8)
  $core.int get status => $_getIZ(7);
  @$pb.TagNumber(8)
  set status($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);
}

class UpdateEventResponse extends $pb.GeneratedMessage {
  factory UpdateEventResponse({
    $1.Event? event,
  }) {
    final result = create();
    if (event != null) result.event = event;
    return result;
  }

  UpdateEventResponse._();

  factory UpdateEventResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateEventResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateEventResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOM<$1.Event>(1, _omitFieldNames ? '' : 'event',
        subBuilder: $1.Event.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateEventResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateEventResponse copyWith(void Function(UpdateEventResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateEventResponse))
          as UpdateEventResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateEventResponse create() => UpdateEventResponse._();
  @$core.override
  UpdateEventResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateEventResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateEventResponse>(create);
  static UpdateEventResponse? _defaultInstance;

  /// / The updated event.
  @$pb.TagNumber(1)
  $1.Event get event => $_getN(0);
  @$pb.TagNumber(1)
  set event($1.Event value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvent() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Event ensureEvent() => $_ensure(0);
}

class DeleteEventRequest extends $pb.GeneratedMessage {
  factory DeleteEventRequest({
    $core.String? eventId,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  DeleteEventRequest._();

  factory DeleteEventRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteEventRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteEventRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteEventRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteEventRequest copyWith(void Function(DeleteEventRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteEventRequest))
          as DeleteEventRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteEventRequest create() => DeleteEventRequest._();
  @$core.override
  DeleteEventRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteEventRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteEventRequest>(create);
  static DeleteEventRequest? _defaultInstance;

  /// / The id of the event to delete.
  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);
}

class DeleteEventResponse extends $pb.GeneratedMessage {
  factory DeleteEventResponse() => create();

  DeleteEventResponse._();

  factory DeleteEventResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteEventResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteEventResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event_service'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteEventResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteEventResponse copyWith(void Function(DeleteEventResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteEventResponse))
          as DeleteEventResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteEventResponse create() => DeleteEventResponse._();
  @$core.override
  DeleteEventResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteEventResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteEventResponse>(create);
  static DeleteEventResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
