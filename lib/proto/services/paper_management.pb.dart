// This is a generated file - do not edit.
//
// Generated from services/paper_management.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class SchedulePaperRequest extends $pb.GeneratedMessage {
  factory SchedulePaperRequest({
    $core.String? eventId,
    $core.int? subject,
    $core.int? grade,
    $core.int? stream,
    $core.int? date,
    $core.int? startTime,
    $core.int? endTime,
    $core.int? durationMinutes,
    $core.String? invigilator,
    $fixnum.Int64? revealAt,
    $fixnum.Int64? generateAt,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (date != null) result.date = date;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (durationMinutes != null) result.durationMinutes = durationMinutes;
    if (invigilator != null) result.invigilator = invigilator;
    if (revealAt != null) result.revealAt = revealAt;
    if (generateAt != null) result.generateAt = generateAt;
    return result;
  }

  SchedulePaperRequest._();

  factory SchedulePaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulePaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulePaperRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..aI(2, _omitFieldNames ? '' : 'subject')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aI(4, _omitFieldNames ? '' : 'stream')
    ..aI(5, _omitFieldNames ? '' : 'date')
    ..aI(6, _omitFieldNames ? '' : 'startTime')
    ..aI(7, _omitFieldNames ? '' : 'endTime')
    ..aI(8, _omitFieldNames ? '' : 'durationMinutes')
    ..aOS(9, _omitFieldNames ? '' : 'invigilator')
    ..aInt64(10, _omitFieldNames ? '' : 'revealAt')
    ..aInt64(11, _omitFieldNames ? '' : 'generateAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulePaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulePaperRequest copyWith(void Function(SchedulePaperRequest) updates) =>
      super.copyWith((message) => updates(message as SchedulePaperRequest))
          as SchedulePaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulePaperRequest create() => SchedulePaperRequest._();
  @$core.override
  SchedulePaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulePaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulePaperRequest>(create);
  static SchedulePaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get subject => $_getIZ(1);
  @$pb.TagNumber(2)
  set subject($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubject() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubject() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get grade => $_getIZ(2);
  @$pb.TagNumber(3)
  set grade($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGrade() => $_has(2);
  @$pb.TagNumber(3)
  void clearGrade() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get stream => $_getIZ(3);
  @$pb.TagNumber(4)
  set stream($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStream() => $_has(3);
  @$pb.TagNumber(4)
  void clearStream() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get date => $_getIZ(4);
  @$pb.TagNumber(5)
  set date($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDate() => $_has(4);
  @$pb.TagNumber(5)
  void clearDate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get startTime => $_getIZ(5);
  @$pb.TagNumber(6)
  set startTime($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartTime() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get endTime => $_getIZ(6);
  @$pb.TagNumber(7)
  set endTime($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEndTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearEndTime() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get durationMinutes => $_getIZ(7);
  @$pb.TagNumber(8)
  set durationMinutes($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDurationMinutes() => $_has(7);
  @$pb.TagNumber(8)
  void clearDurationMinutes() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get invigilator => $_getSZ(8);
  @$pb.TagNumber(9)
  set invigilator($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasInvigilator() => $_has(8);
  @$pb.TagNumber(9)
  void clearInvigilator() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get revealAt => $_getI64(9);
  @$pb.TagNumber(10)
  set revealAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasRevealAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearRevealAt() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get generateAt => $_getI64(10);
  @$pb.TagNumber(11)
  set generateAt($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasGenerateAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearGenerateAt() => $_clearField(11);
}

class SchedulePaperResponse extends $pb.GeneratedMessage {
  factory SchedulePaperResponse({
    $core.String? scheduleId,
  }) {
    final result = create();
    if (scheduleId != null) result.scheduleId = scheduleId;
    return result;
  }

  SchedulePaperResponse._();

  factory SchedulePaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulePaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulePaperResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'scheduleId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulePaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulePaperResponse copyWith(
          void Function(SchedulePaperResponse) updates) =>
      super.copyWith((message) => updates(message as SchedulePaperResponse))
          as SchedulePaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulePaperResponse create() => SchedulePaperResponse._();
  @$core.override
  SchedulePaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulePaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulePaperResponse>(create);
  static SchedulePaperResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get scheduleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set scheduleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduleId() => $_clearField(1);
}

class AssignInvigilatorRequest extends $pb.GeneratedMessage {
  factory AssignInvigilatorRequest({
    $core.String? scheduleId,
    $core.String? invigilator,
  }) {
    final result = create();
    if (scheduleId != null) result.scheduleId = scheduleId;
    if (invigilator != null) result.invigilator = invigilator;
    return result;
  }

  AssignInvigilatorRequest._();

  factory AssignInvigilatorRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssignInvigilatorRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssignInvigilatorRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'scheduleId')
    ..aOS(2, _omitFieldNames ? '' : 'invigilator')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignInvigilatorRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignInvigilatorRequest copyWith(
          void Function(AssignInvigilatorRequest) updates) =>
      super.copyWith((message) => updates(message as AssignInvigilatorRequest))
          as AssignInvigilatorRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssignInvigilatorRequest create() => AssignInvigilatorRequest._();
  @$core.override
  AssignInvigilatorRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssignInvigilatorRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssignInvigilatorRequest>(create);
  static AssignInvigilatorRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get scheduleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set scheduleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get invigilator => $_getSZ(1);
  @$pb.TagNumber(2)
  set invigilator($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInvigilator() => $_has(1);
  @$pb.TagNumber(2)
  void clearInvigilator() => $_clearField(2);
}

class AssignInvigilatorResponse extends $pb.GeneratedMessage {
  factory AssignInvigilatorResponse() => create();

  AssignInvigilatorResponse._();

  factory AssignInvigilatorResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssignInvigilatorResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssignInvigilatorResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignInvigilatorResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignInvigilatorResponse copyWith(
          void Function(AssignInvigilatorResponse) updates) =>
      super.copyWith((message) => updates(message as AssignInvigilatorResponse))
          as AssignInvigilatorResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssignInvigilatorResponse create() => AssignInvigilatorResponse._();
  @$core.override
  AssignInvigilatorResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssignInvigilatorResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssignInvigilatorResponse>(create);
  static AssignInvigilatorResponse? _defaultInstance;
}

class PaperScheduleProto extends $pb.GeneratedMessage {
  factory PaperScheduleProto({
    $core.String? id,
    $core.String? event,
    $core.int? subject,
    $core.int? grade,
    $core.int? stream,
    $core.int? date,
    $core.int? startTime,
    $core.int? endTime,
    $core.int? durationMinutes,
    $core.String? invigilator,
    $core.String? paper,
    $core.int? generationStatus,
    $fixnum.Int64? revealAt,
    $fixnum.Int64? generateAt,
    $fixnum.Int64? created,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (event != null) result.event = event;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (date != null) result.date = date;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (durationMinutes != null) result.durationMinutes = durationMinutes;
    if (invigilator != null) result.invigilator = invigilator;
    if (paper != null) result.paper = paper;
    if (generationStatus != null) result.generationStatus = generationStatus;
    if (revealAt != null) result.revealAt = revealAt;
    if (generateAt != null) result.generateAt = generateAt;
    if (created != null) result.created = created;
    return result;
  }

  PaperScheduleProto._();

  factory PaperScheduleProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaperScheduleProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaperScheduleProto',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'event')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'date')
    ..aI(7, _omitFieldNames ? '' : 'startTime')
    ..aI(8, _omitFieldNames ? '' : 'endTime')
    ..aI(9, _omitFieldNames ? '' : 'durationMinutes')
    ..aOS(10, _omitFieldNames ? '' : 'invigilator')
    ..aOS(11, _omitFieldNames ? '' : 'paper')
    ..aI(12, _omitFieldNames ? '' : 'generationStatus')
    ..aInt64(13, _omitFieldNames ? '' : 'revealAt')
    ..aInt64(14, _omitFieldNames ? '' : 'generateAt')
    ..aInt64(15, _omitFieldNames ? '' : 'created')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperScheduleProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperScheduleProto copyWith(void Function(PaperScheduleProto) updates) =>
      super.copyWith((message) => updates(message as PaperScheduleProto))
          as PaperScheduleProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaperScheduleProto create() => PaperScheduleProto._();
  @$core.override
  PaperScheduleProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaperScheduleProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaperScheduleProto>(create);
  static PaperScheduleProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get event => $_getSZ(1);
  @$pb.TagNumber(2)
  set event($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEvent() => $_has(1);
  @$pb.TagNumber(2)
  void clearEvent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get grade => $_getIZ(3);
  @$pb.TagNumber(4)
  set grade($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGrade() => $_has(3);
  @$pb.TagNumber(4)
  void clearGrade() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get stream => $_getIZ(4);
  @$pb.TagNumber(5)
  set stream($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStream() => $_has(4);
  @$pb.TagNumber(5)
  void clearStream() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get date => $_getIZ(5);
  @$pb.TagNumber(6)
  set date($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearDate() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get startTime => $_getIZ(6);
  @$pb.TagNumber(7)
  set startTime($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStartTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearStartTime() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get endTime => $_getIZ(7);
  @$pb.TagNumber(8)
  set endTime($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEndTime() => $_has(7);
  @$pb.TagNumber(8)
  void clearEndTime() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get durationMinutes => $_getIZ(8);
  @$pb.TagNumber(9)
  set durationMinutes($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDurationMinutes() => $_has(8);
  @$pb.TagNumber(9)
  void clearDurationMinutes() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get invigilator => $_getSZ(9);
  @$pb.TagNumber(10)
  set invigilator($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasInvigilator() => $_has(9);
  @$pb.TagNumber(10)
  void clearInvigilator() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get paper => $_getSZ(10);
  @$pb.TagNumber(11)
  set paper($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPaper() => $_has(10);
  @$pb.TagNumber(11)
  void clearPaper() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get generationStatus => $_getIZ(11);
  @$pb.TagNumber(12)
  set generationStatus($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasGenerationStatus() => $_has(11);
  @$pb.TagNumber(12)
  void clearGenerationStatus() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get revealAt => $_getI64(12);
  @$pb.TagNumber(13)
  set revealAt($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRevealAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearRevealAt() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get generateAt => $_getI64(13);
  @$pb.TagNumber(14)
  set generateAt($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasGenerateAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearGenerateAt() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get created => $_getI64(14);
  @$pb.TagNumber(15)
  set created($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasCreated() => $_has(14);
  @$pb.TagNumber(15)
  void clearCreated() => $_clearField(15);
}

class ListSchedulesRequest extends $pb.GeneratedMessage {
  factory ListSchedulesRequest({
    $core.String? eventId,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  ListSchedulesRequest._();

  factory ListSchedulesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSchedulesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSchedulesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSchedulesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSchedulesRequest copyWith(void Function(ListSchedulesRequest) updates) =>
      super.copyWith((message) => updates(message as ListSchedulesRequest))
          as ListSchedulesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSchedulesRequest create() => ListSchedulesRequest._();
  @$core.override
  ListSchedulesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSchedulesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSchedulesRequest>(create);
  static ListSchedulesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);
}

class ListSchedulesResponse extends $pb.GeneratedMessage {
  factory ListSchedulesResponse({
    $core.Iterable<PaperScheduleProto>? schedules,
  }) {
    final result = create();
    if (schedules != null) result.schedules.addAll(schedules);
    return result;
  }

  ListSchedulesResponse._();

  factory ListSchedulesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSchedulesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSchedulesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..pPM<PaperScheduleProto>(1, _omitFieldNames ? '' : 'schedules',
        subBuilder: PaperScheduleProto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSchedulesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSchedulesResponse copyWith(
          void Function(ListSchedulesResponse) updates) =>
      super.copyWith((message) => updates(message as ListSchedulesResponse))
          as ListSchedulesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSchedulesResponse create() => ListSchedulesResponse._();
  @$core.override
  ListSchedulesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSchedulesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSchedulesResponse>(create);
  static ListSchedulesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PaperScheduleProto> get schedules => $_getList(0);
}

class UpdateScheduleRequest extends $pb.GeneratedMessage {
  factory UpdateScheduleRequest({
    $core.String? scheduleId,
    $core.int? date,
    $core.int? startTime,
    $core.int? endTime,
    $core.int? durationMinutes,
    $fixnum.Int64? revealAt,
    $fixnum.Int64? generateAt,
  }) {
    final result = create();
    if (scheduleId != null) result.scheduleId = scheduleId;
    if (date != null) result.date = date;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (durationMinutes != null) result.durationMinutes = durationMinutes;
    if (revealAt != null) result.revealAt = revealAt;
    if (generateAt != null) result.generateAt = generateAt;
    return result;
  }

  UpdateScheduleRequest._();

  factory UpdateScheduleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateScheduleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateScheduleRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'scheduleId')
    ..aI(2, _omitFieldNames ? '' : 'date')
    ..aI(3, _omitFieldNames ? '' : 'startTime')
    ..aI(4, _omitFieldNames ? '' : 'endTime')
    ..aI(5, _omitFieldNames ? '' : 'durationMinutes')
    ..aInt64(6, _omitFieldNames ? '' : 'revealAt')
    ..aInt64(7, _omitFieldNames ? '' : 'generateAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateScheduleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateScheduleRequest copyWith(
          void Function(UpdateScheduleRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateScheduleRequest))
          as UpdateScheduleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateScheduleRequest create() => UpdateScheduleRequest._();
  @$core.override
  UpdateScheduleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateScheduleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateScheduleRequest>(create);
  static UpdateScheduleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get scheduleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set scheduleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get date => $_getIZ(1);
  @$pb.TagNumber(2)
  set date($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get startTime => $_getIZ(2);
  @$pb.TagNumber(3)
  set startTime($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get endTime => $_getIZ(3);
  @$pb.TagNumber(4)
  set endTime($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndTime() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get durationMinutes => $_getIZ(4);
  @$pb.TagNumber(5)
  set durationMinutes($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMinutes() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMinutes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get revealAt => $_getI64(5);
  @$pb.TagNumber(6)
  set revealAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRevealAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearRevealAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get generateAt => $_getI64(6);
  @$pb.TagNumber(7)
  set generateAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGenerateAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearGenerateAt() => $_clearField(7);
}

class UpdateScheduleResponse extends $pb.GeneratedMessage {
  factory UpdateScheduleResponse({
    PaperScheduleProto? schedule,
  }) {
    final result = create();
    if (schedule != null) result.schedule = schedule;
    return result;
  }

  UpdateScheduleResponse._();

  factory UpdateScheduleResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateScheduleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateScheduleResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOM<PaperScheduleProto>(1, _omitFieldNames ? '' : 'schedule',
        subBuilder: PaperScheduleProto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateScheduleResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateScheduleResponse copyWith(
          void Function(UpdateScheduleResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateScheduleResponse))
          as UpdateScheduleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateScheduleResponse create() => UpdateScheduleResponse._();
  @$core.override
  UpdateScheduleResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateScheduleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateScheduleResponse>(create);
  static UpdateScheduleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PaperScheduleProto get schedule => $_getN(0);
  @$pb.TagNumber(1)
  set schedule(PaperScheduleProto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSchedule() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchedule() => $_clearField(1);
  @$pb.TagNumber(1)
  PaperScheduleProto ensureSchedule() => $_ensure(0);
}

class TaughtTopicProto extends $pb.GeneratedMessage {
  factory TaughtTopicProto({
    $core.int? topicId,
    $core.int? status,
    $core.int? taughtDate,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (status != null) result.status = status;
    if (taughtDate != null) result.taughtDate = taughtDate;
    return result;
  }

  TaughtTopicProto._();

  factory TaughtTopicProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TaughtTopicProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaughtTopicProto',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'topicId')
    ..aI(2, _omitFieldNames ? '' : 'status')
    ..aI(3, _omitFieldNames ? '' : 'taughtDate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaughtTopicProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaughtTopicProto copyWith(void Function(TaughtTopicProto) updates) =>
      super.copyWith((message) => updates(message as TaughtTopicProto))
          as TaughtTopicProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TaughtTopicProto create() => TaughtTopicProto._();
  @$core.override
  TaughtTopicProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TaughtTopicProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaughtTopicProto>(create);
  static TaughtTopicProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get topicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set topicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get status => $_getIZ(1);
  @$pb.TagNumber(2)
  set status($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get taughtDate => $_getIZ(2);
  @$pb.TagNumber(3)
  set taughtDate($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTaughtDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearTaughtDate() => $_clearField(3);
}

class SetTaughtTopicsRequest extends $pb.GeneratedMessage {
  factory SetTaughtTopicsRequest({
    $core.String? school,
    $core.int? subject,
    $core.int? grade,
    $core.int? stream,
    $core.Iterable<TaughtTopicProto>? topics,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (topics != null) result.topics.addAll(topics);
    return result;
  }

  SetTaughtTopicsRequest._();

  factory SetTaughtTopicsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetTaughtTopicsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetTaughtTopicsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'subject')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aI(4, _omitFieldNames ? '' : 'stream')
    ..pPM<TaughtTopicProto>(5, _omitFieldNames ? '' : 'topics',
        subBuilder: TaughtTopicProto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTaughtTopicsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTaughtTopicsRequest copyWith(
          void Function(SetTaughtTopicsRequest) updates) =>
      super.copyWith((message) => updates(message as SetTaughtTopicsRequest))
          as SetTaughtTopicsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetTaughtTopicsRequest create() => SetTaughtTopicsRequest._();
  @$core.override
  SetTaughtTopicsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetTaughtTopicsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetTaughtTopicsRequest>(create);
  static SetTaughtTopicsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get subject => $_getIZ(1);
  @$pb.TagNumber(2)
  set subject($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubject() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubject() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get grade => $_getIZ(2);
  @$pb.TagNumber(3)
  set grade($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGrade() => $_has(2);
  @$pb.TagNumber(3)
  void clearGrade() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get stream => $_getIZ(3);
  @$pb.TagNumber(4)
  set stream($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStream() => $_has(3);
  @$pb.TagNumber(4)
  void clearStream() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<TaughtTopicProto> get topics => $_getList(4);
}

class SetTaughtTopicsResponse extends $pb.GeneratedMessage {
  factory SetTaughtTopicsResponse() => create();

  SetTaughtTopicsResponse._();

  factory SetTaughtTopicsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetTaughtTopicsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetTaughtTopicsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTaughtTopicsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTaughtTopicsResponse copyWith(
          void Function(SetTaughtTopicsResponse) updates) =>
      super.copyWith((message) => updates(message as SetTaughtTopicsResponse))
          as SetTaughtTopicsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetTaughtTopicsResponse create() => SetTaughtTopicsResponse._();
  @$core.override
  SetTaughtTopicsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetTaughtTopicsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetTaughtTopicsResponse>(create);
  static SetTaughtTopicsResponse? _defaultInstance;
}

class GetTaughtTopicsRequest extends $pb.GeneratedMessage {
  factory GetTaughtTopicsRequest({
    $core.String? school,
    $core.int? subject,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  GetTaughtTopicsRequest._();

  factory GetTaughtTopicsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTaughtTopicsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTaughtTopicsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'subject')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aI(4, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaughtTopicsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaughtTopicsRequest copyWith(
          void Function(GetTaughtTopicsRequest) updates) =>
      super.copyWith((message) => updates(message as GetTaughtTopicsRequest))
          as GetTaughtTopicsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTaughtTopicsRequest create() => GetTaughtTopicsRequest._();
  @$core.override
  GetTaughtTopicsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTaughtTopicsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTaughtTopicsRequest>(create);
  static GetTaughtTopicsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get subject => $_getIZ(1);
  @$pb.TagNumber(2)
  set subject($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubject() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubject() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get grade => $_getIZ(2);
  @$pb.TagNumber(3)
  set grade($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGrade() => $_has(2);
  @$pb.TagNumber(3)
  void clearGrade() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get stream => $_getIZ(3);
  @$pb.TagNumber(4)
  set stream($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStream() => $_has(3);
  @$pb.TagNumber(4)
  void clearStream() => $_clearField(4);
}

class GetTaughtTopicsResponse extends $pb.GeneratedMessage {
  factory GetTaughtTopicsResponse({
    $core.Iterable<TaughtTopicProto>? topics,
  }) {
    final result = create();
    if (topics != null) result.topics.addAll(topics);
    return result;
  }

  GetTaughtTopicsResponse._();

  factory GetTaughtTopicsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTaughtTopicsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTaughtTopicsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..pPM<TaughtTopicProto>(1, _omitFieldNames ? '' : 'topics',
        subBuilder: TaughtTopicProto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaughtTopicsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaughtTopicsResponse copyWith(
          void Function(GetTaughtTopicsResponse) updates) =>
      super.copyWith((message) => updates(message as GetTaughtTopicsResponse))
          as GetTaughtTopicsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTaughtTopicsResponse create() => GetTaughtTopicsResponse._();
  @$core.override
  GetTaughtTopicsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTaughtTopicsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTaughtTopicsResponse>(create);
  static GetTaughtTopicsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TaughtTopicProto> get topics => $_getList(0);
}

class ConfirmExamCoverageRequest extends $pb.GeneratedMessage {
  factory ConfirmExamCoverageRequest({
    $core.String? scheduleId,
    $core.Iterable<$core.int>? topicIds,
  }) {
    final result = create();
    if (scheduleId != null) result.scheduleId = scheduleId;
    if (topicIds != null) result.topicIds.addAll(topicIds);
    return result;
  }

  ConfirmExamCoverageRequest._();

  factory ConfirmExamCoverageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConfirmExamCoverageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfirmExamCoverageRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'scheduleId')
    ..p<$core.int>(2, _omitFieldNames ? '' : 'topicIds', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmExamCoverageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmExamCoverageRequest copyWith(
          void Function(ConfirmExamCoverageRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ConfirmExamCoverageRequest))
          as ConfirmExamCoverageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfirmExamCoverageRequest create() => ConfirmExamCoverageRequest._();
  @$core.override
  ConfirmExamCoverageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConfirmExamCoverageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfirmExamCoverageRequest>(create);
  static ConfirmExamCoverageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get scheduleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set scheduleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get topicIds => $_getList(1);
}

class ConfirmExamCoverageResponse extends $pb.GeneratedMessage {
  factory ConfirmExamCoverageResponse({
    $core.int? topicsConfirmed,
  }) {
    final result = create();
    if (topicsConfirmed != null) result.topicsConfirmed = topicsConfirmed;
    return result;
  }

  ConfirmExamCoverageResponse._();

  factory ConfirmExamCoverageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConfirmExamCoverageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfirmExamCoverageResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'topicsConfirmed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmExamCoverageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmExamCoverageResponse copyWith(
          void Function(ConfirmExamCoverageResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ConfirmExamCoverageResponse))
          as ConfirmExamCoverageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfirmExamCoverageResponse create() =>
      ConfirmExamCoverageResponse._();
  @$core.override
  ConfirmExamCoverageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConfirmExamCoverageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfirmExamCoverageResponse>(create);
  static ConfirmExamCoverageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get topicsConfirmed => $_getIZ(0);
  @$pb.TagNumber(1)
  set topicsConfirmed($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicsConfirmed() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicsConfirmed() => $_clearField(1);
}

class GetExamCoverageRequest extends $pb.GeneratedMessage {
  factory GetExamCoverageRequest({
    $core.String? scheduleId,
  }) {
    final result = create();
    if (scheduleId != null) result.scheduleId = scheduleId;
    return result;
  }

  GetExamCoverageRequest._();

  factory GetExamCoverageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetExamCoverageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetExamCoverageRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'scheduleId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExamCoverageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExamCoverageRequest copyWith(
          void Function(GetExamCoverageRequest) updates) =>
      super.copyWith((message) => updates(message as GetExamCoverageRequest))
          as GetExamCoverageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetExamCoverageRequest create() => GetExamCoverageRequest._();
  @$core.override
  GetExamCoverageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetExamCoverageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetExamCoverageRequest>(create);
  static GetExamCoverageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get scheduleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set scheduleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduleId() => $_clearField(1);
}

class GetExamCoverageResponse extends $pb.GeneratedMessage {
  factory GetExamCoverageResponse({
    $core.Iterable<$core.int>? topicIds,
  }) {
    final result = create();
    if (topicIds != null) result.topicIds.addAll(topicIds);
    return result;
  }

  GetExamCoverageResponse._();

  factory GetExamCoverageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetExamCoverageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetExamCoverageResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'topicIds', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExamCoverageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExamCoverageResponse copyWith(
          void Function(GetExamCoverageResponse) updates) =>
      super.copyWith((message) => updates(message as GetExamCoverageResponse))
          as GetExamCoverageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetExamCoverageResponse create() => GetExamCoverageResponse._();
  @$core.override
  GetExamCoverageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetExamCoverageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetExamCoverageResponse>(create);
  static GetExamCoverageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get topicIds => $_getList(0);
}

class GenerateAssessmentRequest extends $pb.GeneratedMessage {
  factory GenerateAssessmentRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  GenerateAssessmentRequest._();

  factory GenerateAssessmentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateAssessmentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateAssessmentRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssessmentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssessmentRequest copyWith(
          void Function(GenerateAssessmentRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateAssessmentRequest))
          as GenerateAssessmentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateAssessmentRequest create() => GenerateAssessmentRequest._();
  @$core.override
  GenerateAssessmentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateAssessmentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateAssessmentRequest>(create);
  static GenerateAssessmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class GenerateAssessmentResponse extends $pb.GeneratedMessage {
  factory GenerateAssessmentResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = create();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  GenerateAssessmentResponse._();

  factory GenerateAssessmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateAssessmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateAssessmentResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssessmentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssessmentResponse copyWith(
          void Function(GenerateAssessmentResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GenerateAssessmentResponse))
          as GenerateAssessmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateAssessmentResponse create() => GenerateAssessmentResponse._();
  @$core.override
  GenerateAssessmentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateAssessmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateAssessmentResponse>(create);
  static GenerateAssessmentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class GenerateAssignmentRequest extends $pb.GeneratedMessage {
  factory GenerateAssignmentRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  GenerateAssignmentRequest._();

  factory GenerateAssignmentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateAssignmentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateAssignmentRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssignmentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssignmentRequest copyWith(
          void Function(GenerateAssignmentRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateAssignmentRequest))
          as GenerateAssignmentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateAssignmentRequest create() => GenerateAssignmentRequest._();
  @$core.override
  GenerateAssignmentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateAssignmentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateAssignmentRequest>(create);
  static GenerateAssignmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class GenerateAssignmentResponse extends $pb.GeneratedMessage {
  factory GenerateAssignmentResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = create();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  GenerateAssignmentResponse._();

  factory GenerateAssignmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateAssignmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateAssignmentResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssignmentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateAssignmentResponse copyWith(
          void Function(GenerateAssignmentResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GenerateAssignmentResponse))
          as GenerateAssignmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateAssignmentResponse create() => GenerateAssignmentResponse._();
  @$core.override
  GenerateAssignmentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateAssignmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateAssignmentResponse>(create);
  static GenerateAssignmentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class FinalizeStudentPapersRequest extends $pb.GeneratedMessage {
  factory FinalizeStudentPapersRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  FinalizeStudentPapersRequest._();

  factory FinalizeStudentPapersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizeStudentPapersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizeStudentPapersRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeStudentPapersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeStudentPapersRequest copyWith(
          void Function(FinalizeStudentPapersRequest) updates) =>
      super.copyWith(
              (message) => updates(message as FinalizeStudentPapersRequest))
          as FinalizeStudentPapersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizeStudentPapersRequest create() =>
      FinalizeStudentPapersRequest._();
  @$core.override
  FinalizeStudentPapersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FinalizeStudentPapersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizeStudentPapersRequest>(create);
  static FinalizeStudentPapersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class FinalizeStudentPapersResponse extends $pb.GeneratedMessage {
  factory FinalizeStudentPapersResponse({
    $core.String? jobId,
  }) {
    final result = create();
    if (jobId != null) result.jobId = jobId;
    return result;
  }

  FinalizeStudentPapersResponse._();

  factory FinalizeStudentPapersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizeStudentPapersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizeStudentPapersResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'jobId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeStudentPapersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeStudentPapersResponse copyWith(
          void Function(FinalizeStudentPapersResponse) updates) =>
      super.copyWith(
              (message) => updates(message as FinalizeStudentPapersResponse))
          as FinalizeStudentPapersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizeStudentPapersResponse create() =>
      FinalizeStudentPapersResponse._();
  @$core.override
  FinalizeStudentPapersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FinalizeStudentPapersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizeStudentPapersResponse>(create);
  static FinalizeStudentPapersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get jobId => $_getSZ(0);
  @$pb.TagNumber(1)
  set jobId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJobId() => $_has(0);
  @$pb.TagNumber(1)
  void clearJobId() => $_clearField(1);
}

class GetStudentPapersStatusRequest extends $pb.GeneratedMessage {
  factory GetStudentPapersStatusRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  GetStudentPapersStatusRequest._();

  factory GetStudentPapersStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStudentPapersStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStudentPapersStatusRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPapersStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPapersStatusRequest copyWith(
          void Function(GetStudentPapersStatusRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetStudentPapersStatusRequest))
          as GetStudentPapersStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStudentPapersStatusRequest create() =>
      GetStudentPapersStatusRequest._();
  @$core.override
  GetStudentPapersStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStudentPapersStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStudentPapersStatusRequest>(create);
  static GetStudentPapersStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class StudentPdfStatus extends $pb.GeneratedMessage {
  factory StudentPdfStatus({
    $core.int? student,
    $core.bool? generated,
    $core.String? error,
  }) {
    final result = create();
    if (student != null) result.student = student;
    if (generated != null) result.generated = generated;
    if (error != null) result.error = error;
    return result;
  }

  StudentPdfStatus._();

  factory StudentPdfStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudentPdfStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudentPdfStatus',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'student')
    ..aOB(2, _omitFieldNames ? '' : 'generated')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentPdfStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentPdfStatus copyWith(void Function(StudentPdfStatus) updates) =>
      super.copyWith((message) => updates(message as StudentPdfStatus))
          as StudentPdfStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudentPdfStatus create() => StudentPdfStatus._();
  @$core.override
  StudentPdfStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudentPdfStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudentPdfStatus>(create);
  static StudentPdfStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get student => $_getIZ(0);
  @$pb.TagNumber(1)
  set student($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStudent() => $_has(0);
  @$pb.TagNumber(1)
  void clearStudent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get generated => $_getBF(1);
  @$pb.TagNumber(2)
  set generated($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGenerated() => $_has(1);
  @$pb.TagNumber(2)
  void clearGenerated() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
}

class GetStudentPapersStatusResponse extends $pb.GeneratedMessage {
  factory GetStudentPapersStatusResponse({
    $core.String? jobId,
    $core.bool? complete,
    $core.int? total,
    $core.int? generated,
    $core.Iterable<StudentPdfStatus>? statuses,
  }) {
    final result = create();
    if (jobId != null) result.jobId = jobId;
    if (complete != null) result.complete = complete;
    if (total != null) result.total = total;
    if (generated != null) result.generated = generated;
    if (statuses != null) result.statuses.addAll(statuses);
    return result;
  }

  GetStudentPapersStatusResponse._();

  factory GetStudentPapersStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStudentPapersStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStudentPapersStatusResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'jobId')
    ..aOB(2, _omitFieldNames ? '' : 'complete')
    ..aI(3, _omitFieldNames ? '' : 'total')
    ..aI(4, _omitFieldNames ? '' : 'generated')
    ..pPM<StudentPdfStatus>(5, _omitFieldNames ? '' : 'statuses',
        subBuilder: StudentPdfStatus.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPapersStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPapersStatusResponse copyWith(
          void Function(GetStudentPapersStatusResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetStudentPapersStatusResponse))
          as GetStudentPapersStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStudentPapersStatusResponse create() =>
      GetStudentPapersStatusResponse._();
  @$core.override
  GetStudentPapersStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStudentPapersStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStudentPapersStatusResponse>(create);
  static GetStudentPapersStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get jobId => $_getSZ(0);
  @$pb.TagNumber(1)
  set jobId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJobId() => $_has(0);
  @$pb.TagNumber(1)
  void clearJobId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get complete => $_getBF(1);
  @$pb.TagNumber(2)
  set complete($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasComplete() => $_has(1);
  @$pb.TagNumber(2)
  void clearComplete() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get total => $_getIZ(2);
  @$pb.TagNumber(3)
  set total($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotal() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get generated => $_getIZ(3);
  @$pb.TagNumber(4)
  set generated($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGenerated() => $_has(3);
  @$pb.TagNumber(4)
  void clearGenerated() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<StudentPdfStatus> get statuses => $_getList(4);
}

class GetStudentPaperPdfRequest extends $pb.GeneratedMessage {
  factory GetStudentPaperPdfRequest({
    $core.String? paperId,
    $core.int? student,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (student != null) result.student = student;
    return result;
  }

  GetStudentPaperPdfRequest._();

  factory GetStudentPaperPdfRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStudentPaperPdfRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStudentPaperPdfRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'student')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPaperPdfRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPaperPdfRequest copyWith(
          void Function(GetStudentPaperPdfRequest) updates) =>
      super.copyWith((message) => updates(message as GetStudentPaperPdfRequest))
          as GetStudentPaperPdfRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStudentPaperPdfRequest create() => GetStudentPaperPdfRequest._();
  @$core.override
  GetStudentPaperPdfRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStudentPaperPdfRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStudentPaperPdfRequest>(create);
  static GetStudentPaperPdfRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get student => $_getIZ(1);
  @$pb.TagNumber(2)
  set student($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStudent() => $_has(1);
  @$pb.TagNumber(2)
  void clearStudent() => $_clearField(2);
}

class GetStudentPaperPdfResponse extends $pb.GeneratedMessage {
  factory GetStudentPaperPdfResponse({
    $core.String? pdfUrl,
    $fixnum.Int64? expiry,
  }) {
    final result = create();
    if (pdfUrl != null) result.pdfUrl = pdfUrl;
    if (expiry != null) result.expiry = expiry;
    return result;
  }

  GetStudentPaperPdfResponse._();

  factory GetStudentPaperPdfResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStudentPaperPdfResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStudentPaperPdfResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'paper_management'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pdfUrl')
    ..aInt64(2, _omitFieldNames ? '' : 'expiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPaperPdfResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStudentPaperPdfResponse copyWith(
          void Function(GetStudentPaperPdfResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetStudentPaperPdfResponse))
          as GetStudentPaperPdfResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStudentPaperPdfResponse create() => GetStudentPaperPdfResponse._();
  @$core.override
  GetStudentPaperPdfResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStudentPaperPdfResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStudentPaperPdfResponse>(create);
  static GetStudentPaperPdfResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pdfUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set pdfUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPdfUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearPdfUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiry => $_getI64(1);
  @$pb.TagNumber(2)
  set expiry($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiry() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiry() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
