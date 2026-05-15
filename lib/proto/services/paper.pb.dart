// This is a generated file - do not edit.
//
// Generated from services/paper.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../types/paper.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PaperTopicWeight extends $pb.GeneratedMessage {
  factory PaperTopicWeight({
    $core.int? topicId,
    $core.double? weight,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (weight != null) result.weight = weight;
    return result;
  }

  PaperTopicWeight._();

  factory PaperTopicWeight.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaperTopicWeight.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaperTopicWeight',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'topicId')
    ..aD(2, _omitFieldNames ? '' : 'weight', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperTopicWeight clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperTopicWeight copyWith(void Function(PaperTopicWeight) updates) =>
      super.copyWith((message) => updates(message as PaperTopicWeight))
          as PaperTopicWeight;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaperTopicWeight create() => PaperTopicWeight._();
  @$core.override
  PaperTopicWeight createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaperTopicWeight getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaperTopicWeight>(create);
  static PaperTopicWeight? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get topicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set topicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get weight => $_getN(1);
  @$pb.TagNumber(2)
  set weight($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearWeight() => $_clearField(2);
}

class CreatePaperRequest extends $pb.GeneratedMessage {
  factory CreatePaperRequest({
    $core.String? school,
    $core.String? event,
    $core.int? subject,
    $core.int? grade,
    $core.int? stream,
    $core.int? type,
    $core.String? name,
    $core.int? totalMarks,
    $core.int? durationMinutes,
    $core.int? date,
    $core.int? generationMode,
    $core.String? instructions,
    $core.Iterable<PaperTopicWeight>? topicWeights,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (event != null) result.event = event;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (type != null) result.type = type;
    if (name != null) result.name = name;
    if (totalMarks != null) result.totalMarks = totalMarks;
    if (durationMinutes != null) result.durationMinutes = durationMinutes;
    if (date != null) result.date = date;
    if (generationMode != null) result.generationMode = generationMode;
    if (instructions != null) result.instructions = instructions;
    if (topicWeights != null) result.topicWeights.addAll(topicWeights);
    return result;
  }

  CreatePaperRequest._();

  factory CreatePaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'event')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'type')
    ..aOS(7, _omitFieldNames ? '' : 'name')
    ..aI(8, _omitFieldNames ? '' : 'totalMarks')
    ..aI(9, _omitFieldNames ? '' : 'durationMinutes')
    ..aI(10, _omitFieldNames ? '' : 'date')
    ..aI(11, _omitFieldNames ? '' : 'generationMode')
    ..aOS(12, _omitFieldNames ? '' : 'instructions')
    ..pPM<PaperTopicWeight>(13, _omitFieldNames ? '' : 'topicWeights',
        subBuilder: PaperTopicWeight.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaperRequest copyWith(void Function(CreatePaperRequest) updates) =>
      super.copyWith((message) => updates(message as CreatePaperRequest))
          as CreatePaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePaperRequest create() => CreatePaperRequest._();
  @$core.override
  CreatePaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePaperRequest>(create);
  static CreatePaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

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
  $core.int get type => $_getIZ(5);
  @$pb.TagNumber(6)
  set type($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasType() => $_has(5);
  @$pb.TagNumber(6)
  void clearType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get name => $_getSZ(6);
  @$pb.TagNumber(7)
  set name($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasName() => $_has(6);
  @$pb.TagNumber(7)
  void clearName() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get totalMarks => $_getIZ(7);
  @$pb.TagNumber(8)
  set totalMarks($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTotalMarks() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalMarks() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get durationMinutes => $_getIZ(8);
  @$pb.TagNumber(9)
  set durationMinutes($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDurationMinutes() => $_has(8);
  @$pb.TagNumber(9)
  void clearDurationMinutes() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get date => $_getIZ(9);
  @$pb.TagNumber(10)
  set date($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDate() => $_has(9);
  @$pb.TagNumber(10)
  void clearDate() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get generationMode => $_getIZ(10);
  @$pb.TagNumber(11)
  set generationMode($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasGenerationMode() => $_has(10);
  @$pb.TagNumber(11)
  void clearGenerationMode() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get instructions => $_getSZ(11);
  @$pb.TagNumber(12)
  set instructions($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasInstructions() => $_has(11);
  @$pb.TagNumber(12)
  void clearInstructions() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<PaperTopicWeight> get topicWeights => $_getList(12);
}

class CreatePaperResponse extends $pb.GeneratedMessage {
  factory CreatePaperResponse({
    $1.Paper? paper,
  }) {
    final result = create();
    if (paper != null) result.paper = paper;
    return result;
  }

  CreatePaperResponse._();

  factory CreatePaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOM<$1.Paper>(1, _omitFieldNames ? '' : 'paper',
        subBuilder: $1.Paper.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaperResponse copyWith(void Function(CreatePaperResponse) updates) =>
      super.copyWith((message) => updates(message as CreatePaperResponse))
          as CreatePaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePaperResponse create() => CreatePaperResponse._();
  @$core.override
  CreatePaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePaperResponse>(create);
  static CreatePaperResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Paper get paper => $_getN(0);
  @$pb.TagNumber(1)
  set paper($1.Paper value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPaper() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaper() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Paper ensurePaper() => $_ensure(0);
}

class GetPaperRequest extends $pb.GeneratedMessage {
  factory GetPaperRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  GetPaperRequest._();

  factory GetPaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperRequest copyWith(void Function(GetPaperRequest) updates) =>
      super.copyWith((message) => updates(message as GetPaperRequest))
          as GetPaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperRequest create() => GetPaperRequest._();
  @$core.override
  GetPaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperRequest>(create);
  static GetPaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class GetPaperResponse extends $pb.GeneratedMessage {
  factory GetPaperResponse({
    $1.Paper? paper,
  }) {
    final result = create();
    if (paper != null) result.paper = paper;
    return result;
  }

  GetPaperResponse._();

  factory GetPaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOM<$1.Paper>(1, _omitFieldNames ? '' : 'paper',
        subBuilder: $1.Paper.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperResponse copyWith(void Function(GetPaperResponse) updates) =>
      super.copyWith((message) => updates(message as GetPaperResponse))
          as GetPaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperResponse create() => GetPaperResponse._();
  @$core.override
  GetPaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperResponse>(create);
  static GetPaperResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Paper get paper => $_getN(0);
  @$pb.TagNumber(1)
  set paper($1.Paper value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPaper() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaper() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Paper ensurePaper() => $_ensure(0);
}

class ListPapersRequest extends $pb.GeneratedMessage {
  factory ListPapersRequest({
    $core.String? school,
    $core.String? event,
    $core.int? grade,
    $core.int? subject,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (event != null) result.event = event;
    if (grade != null) result.grade = grade;
    if (subject != null) result.subject = subject;
    return result;
  }

  ListPapersRequest._();

  factory ListPapersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPapersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPapersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'event')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aI(4, _omitFieldNames ? '' : 'subject')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPapersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPapersRequest copyWith(void Function(ListPapersRequest) updates) =>
      super.copyWith((message) => updates(message as ListPapersRequest))
          as ListPapersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPapersRequest create() => ListPapersRequest._();
  @$core.override
  ListPapersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPapersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPapersRequest>(create);
  static ListPapersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get event => $_getSZ(1);
  @$pb.TagNumber(2)
  set event($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEvent() => $_has(1);
  @$pb.TagNumber(2)
  void clearEvent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get grade => $_getIZ(2);
  @$pb.TagNumber(3)
  set grade($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGrade() => $_has(2);
  @$pb.TagNumber(3)
  void clearGrade() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get subject => $_getIZ(3);
  @$pb.TagNumber(4)
  set subject($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSubject() => $_has(3);
  @$pb.TagNumber(4)
  void clearSubject() => $_clearField(4);
}

class ListPapersResponse extends $pb.GeneratedMessage {
  factory ListPapersResponse({
    $core.Iterable<$1.Paper>? papers,
  }) {
    final result = create();
    if (papers != null) result.papers.addAll(papers);
    return result;
  }

  ListPapersResponse._();

  factory ListPapersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPapersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPapersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..pPM<$1.Paper>(1, _omitFieldNames ? '' : 'papers',
        subBuilder: $1.Paper.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPapersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPapersResponse copyWith(void Function(ListPapersResponse) updates) =>
      super.copyWith((message) => updates(message as ListPapersResponse))
          as ListPapersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPapersResponse create() => ListPapersResponse._();
  @$core.override
  ListPapersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPapersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPapersResponse>(create);
  static ListPapersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$1.Paper> get papers => $_getList(0);
}

class UpdatePaperRequest extends $pb.GeneratedMessage {
  factory UpdatePaperRequest({
    $core.String? paperId,
    $core.String? name,
    $core.int? totalMarks,
    $core.int? durationMinutes,
    $core.int? date,
    $core.String? instructions,
    $core.int? generationMode,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (name != null) result.name = name;
    if (totalMarks != null) result.totalMarks = totalMarks;
    if (durationMinutes != null) result.durationMinutes = durationMinutes;
    if (date != null) result.date = date;
    if (instructions != null) result.instructions = instructions;
    if (generationMode != null) result.generationMode = generationMode;
    return result;
  }

  UpdatePaperRequest._();

  factory UpdatePaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'totalMarks')
    ..aI(4, _omitFieldNames ? '' : 'durationMinutes')
    ..aI(5, _omitFieldNames ? '' : 'date')
    ..aOS(6, _omitFieldNames ? '' : 'instructions')
    ..aI(7, _omitFieldNames ? '' : 'generationMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaperRequest copyWith(void Function(UpdatePaperRequest) updates) =>
      super.copyWith((message) => updates(message as UpdatePaperRequest))
          as UpdatePaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePaperRequest create() => UpdatePaperRequest._();
  @$core.override
  UpdatePaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePaperRequest>(create);
  static UpdatePaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalMarks => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalMarks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get durationMinutes => $_getIZ(3);
  @$pb.TagNumber(4)
  set durationMinutes($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationMinutes() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationMinutes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get date => $_getIZ(4);
  @$pb.TagNumber(5)
  set date($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDate() => $_has(4);
  @$pb.TagNumber(5)
  void clearDate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get instructions => $_getSZ(5);
  @$pb.TagNumber(6)
  set instructions($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInstructions() => $_has(5);
  @$pb.TagNumber(6)
  void clearInstructions() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get generationMode => $_getIZ(6);
  @$pb.TagNumber(7)
  set generationMode($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGenerationMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearGenerationMode() => $_clearField(7);
}

class UpdatePaperResponse extends $pb.GeneratedMessage {
  factory UpdatePaperResponse({
    $1.Paper? paper,
  }) {
    final result = create();
    if (paper != null) result.paper = paper;
    return result;
  }

  UpdatePaperResponse._();

  factory UpdatePaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOM<$1.Paper>(1, _omitFieldNames ? '' : 'paper',
        subBuilder: $1.Paper.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaperResponse copyWith(void Function(UpdatePaperResponse) updates) =>
      super.copyWith((message) => updates(message as UpdatePaperResponse))
          as UpdatePaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePaperResponse create() => UpdatePaperResponse._();
  @$core.override
  UpdatePaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePaperResponse>(create);
  static UpdatePaperResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Paper get paper => $_getN(0);
  @$pb.TagNumber(1)
  set paper($1.Paper value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPaper() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaper() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Paper ensurePaper() => $_ensure(0);
}

class GetPaperPdfUrlRequest extends $pb.GeneratedMessage {
  factory GetPaperPdfUrlRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  GetPaperPdfUrlRequest._();

  factory GetPaperPdfUrlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperPdfUrlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperPdfUrlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfUrlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfUrlRequest copyWith(
          void Function(GetPaperPdfUrlRequest) updates) =>
      super.copyWith((message) => updates(message as GetPaperPdfUrlRequest))
          as GetPaperPdfUrlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperPdfUrlRequest create() => GetPaperPdfUrlRequest._();
  @$core.override
  GetPaperPdfUrlRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperPdfUrlRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperPdfUrlRequest>(create);
  static GetPaperPdfUrlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class GetPaperPdfUrlResponse extends $pb.GeneratedMessage {
  factory GetPaperPdfUrlResponse({
    $core.String? url,
    $fixnum.Int64? expiry,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (expiry != null) result.expiry = expiry;
    return result;
  }

  GetPaperPdfUrlResponse._();

  factory GetPaperPdfUrlResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperPdfUrlResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperPdfUrlResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aInt64(2, _omitFieldNames ? '' : 'expiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfUrlResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfUrlResponse copyWith(
          void Function(GetPaperPdfUrlResponse) updates) =>
      super.copyWith((message) => updates(message as GetPaperPdfUrlResponse))
          as GetPaperPdfUrlResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperPdfUrlResponse create() => GetPaperPdfUrlResponse._();
  @$core.override
  GetPaperPdfUrlResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperPdfUrlResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperPdfUrlResponse>(create);
  static GetPaperPdfUrlResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiry => $_getI64(1);
  @$pb.TagNumber(2)
  set expiry($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiry() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiry() => $_clearField(2);
}

class GetMarkingSchemeUrlRequest extends $pb.GeneratedMessage {
  factory GetMarkingSchemeUrlRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  GetMarkingSchemeUrlRequest._();

  factory GetMarkingSchemeUrlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMarkingSchemeUrlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMarkingSchemeUrlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMarkingSchemeUrlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMarkingSchemeUrlRequest copyWith(
          void Function(GetMarkingSchemeUrlRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetMarkingSchemeUrlRequest))
          as GetMarkingSchemeUrlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMarkingSchemeUrlRequest create() => GetMarkingSchemeUrlRequest._();
  @$core.override
  GetMarkingSchemeUrlRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMarkingSchemeUrlRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMarkingSchemeUrlRequest>(create);
  static GetMarkingSchemeUrlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class GetMarkingSchemeUrlResponse extends $pb.GeneratedMessage {
  factory GetMarkingSchemeUrlResponse({
    $core.String? url,
    $fixnum.Int64? expiry,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (expiry != null) result.expiry = expiry;
    return result;
  }

  GetMarkingSchemeUrlResponse._();

  factory GetMarkingSchemeUrlResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMarkingSchemeUrlResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMarkingSchemeUrlResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aInt64(2, _omitFieldNames ? '' : 'expiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMarkingSchemeUrlResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMarkingSchemeUrlResponse copyWith(
          void Function(GetMarkingSchemeUrlResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetMarkingSchemeUrlResponse))
          as GetMarkingSchemeUrlResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMarkingSchemeUrlResponse create() =>
      GetMarkingSchemeUrlResponse._();
  @$core.override
  GetMarkingSchemeUrlResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMarkingSchemeUrlResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMarkingSchemeUrlResponse>(create);
  static GetMarkingSchemeUrlResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiry => $_getI64(1);
  @$pb.TagNumber(2)
  set expiry($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiry() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiry() => $_clearField(2);
}

class ForceSetPaperStatusRequest extends $pb.GeneratedMessage {
  factory ForceSetPaperStatusRequest({
    $core.String? paperId,
    $core.int? status,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (status != null) result.status = status;
    return result;
  }

  ForceSetPaperStatusRequest._();

  factory ForceSetPaperStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ForceSetPaperStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForceSetPaperStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForceSetPaperStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForceSetPaperStatusRequest copyWith(
          void Function(ForceSetPaperStatusRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ForceSetPaperStatusRequest))
          as ForceSetPaperStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ForceSetPaperStatusRequest create() => ForceSetPaperStatusRequest._();
  @$core.override
  ForceSetPaperStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ForceSetPaperStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ForceSetPaperStatusRequest>(create);
  static ForceSetPaperStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get status => $_getIZ(1);
  @$pb.TagNumber(2)
  set status($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

class ForceSetPaperStatusResponse extends $pb.GeneratedMessage {
  factory ForceSetPaperStatusResponse({
    $1.Paper? paper,
  }) {
    final result = create();
    if (paper != null) result.paper = paper;
    return result;
  }

  ForceSetPaperStatusResponse._();

  factory ForceSetPaperStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ForceSetPaperStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForceSetPaperStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOM<$1.Paper>(1, _omitFieldNames ? '' : 'paper',
        subBuilder: $1.Paper.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForceSetPaperStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForceSetPaperStatusResponse copyWith(
          void Function(ForceSetPaperStatusResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ForceSetPaperStatusResponse))
          as ForceSetPaperStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ForceSetPaperStatusResponse create() =>
      ForceSetPaperStatusResponse._();
  @$core.override
  ForceSetPaperStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ForceSetPaperStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ForceSetPaperStatusResponse>(create);
  static ForceSetPaperStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Paper get paper => $_getN(0);
  @$pb.TagNumber(1)
  set paper($1.Paper value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPaper() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaper() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Paper ensurePaper() => $_ensure(0);
}

class DeletePaperRequest extends $pb.GeneratedMessage {
  factory DeletePaperRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    return result;
  }

  DeletePaperRequest._();

  factory DeletePaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaperRequest copyWith(void Function(DeletePaperRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePaperRequest))
          as DeletePaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePaperRequest create() => DeletePaperRequest._();
  @$core.override
  DeletePaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePaperRequest>(create);
  static DeletePaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class DeletePaperResponse extends $pb.GeneratedMessage {
  factory DeletePaperResponse() => create();

  DeletePaperResponse._();

  factory DeletePaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper_service'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaperResponse copyWith(void Function(DeletePaperResponse) updates) =>
      super.copyWith((message) => updates(message as DeletePaperResponse))
          as DeletePaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePaperResponse create() => DeletePaperResponse._();
  @$core.override
  DeletePaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePaperResponse>(create);
  static DeletePaperResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
