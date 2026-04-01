// This is a generated file - do not edit.
//
// Generated from services/question_bank.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'question_bank.pbenum.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'question_bank.pbenum.dart';

// ============================================================================
// RubricCriterion
// ============================================================================

class RubricCriterion extends $pb.GeneratedMessage {
  factory RubricCriterion({
    $core.String? criterion,
    $core.int? marks,
  }) {
    final result = create();
    if (criterion != null) result.criterion = criterion;
    if (marks != null) result.marks = marks;
    return result;
  }

  RubricCriterion._();

  factory RubricCriterion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RubricCriterion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RubricCriterion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'criterion')
    ..aI(2, _omitFieldNames ? '' : 'marks')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RubricCriterion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RubricCriterion copyWith(void Function(RubricCriterion) updates) =>
      super.copyWith((message) => updates(message as RubricCriterion))
          as RubricCriterion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RubricCriterion create() => RubricCriterion._();
  @$core.override
  RubricCriterion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RubricCriterion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RubricCriterion>(create);
  static RubricCriterion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get criterion => $_getSZ(0);
  @$pb.TagNumber(1)
  set criterion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCriterion() => $_has(0);
  @$pb.TagNumber(1)
  void clearCriterion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get marks => $_getIZ(1);
  @$pb.TagNumber(2)
  set marks($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMarks() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarks() => $_clearField(2);
}

// ============================================================================
// QuestionImage
// ============================================================================

class QuestionImage extends $pb.GeneratedMessage {
  factory QuestionImage({
    $1.ImageContext? context,
    $core.String? filename,
    $core.String? caption,
    $core.String? description,
    $core.String? getUrl,
  }) {
    final result = create();
    if (context != null) result.context = context;
    if (filename != null) result.filename = filename;
    if (caption != null) result.caption = caption;
    if (description != null) result.description = description;
    if (getUrl != null) result.getUrl = getUrl;
    return result;
  }

  QuestionImage._();

  factory QuestionImage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuestionImage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuestionImage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..e<$1.ImageContext>(
        1, _omitFieldNames ? '' : 'context', $pb.PbFieldType.OE,
        defaultOrMaker: $1.ImageContext.QUESTION,
        valueOf: $1.ImageContext.valueOf,
        enumValues: $1.ImageContext.values)
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..aOS(3, _omitFieldNames ? '' : 'caption')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..aOS(5, _omitFieldNames ? '' : 'getUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionImage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionImage copyWith(void Function(QuestionImage) updates) =>
      super.copyWith((message) => updates(message as QuestionImage))
          as QuestionImage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuestionImage create() => QuestionImage._();
  @$core.override
  QuestionImage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuestionImage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuestionImage>(create);
  static QuestionImage? _defaultInstance;

  @$pb.TagNumber(1)
  $1.ImageContext get context => $_getN(0);
  @$pb.TagNumber(1)
  set context($1.ImageContext value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get caption => $_getSZ(2);
  @$pb.TagNumber(3)
  set caption($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCaption() => $_has(2);
  @$pb.TagNumber(3)
  void clearCaption() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get getUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set getUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGetUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearGetUrl() => $_clearField(5);
}

// ============================================================================
// Question
// ============================================================================

class Question extends $pb.GeneratedMessage {
  factory Question({
    $core.int? id,
    $core.int? topicId,
    $core.String? text,
    $core.int? marks,
    $core.Iterable<RubricCriterion>? rubric,
    $core.String? exampleAnswer,
    $core.Iterable<QuestionImage>? images,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (topicId != null) result.topicId = topicId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (rubric != null) result.rubric.addAll(rubric);
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (images != null) result.images.addAll(images);
    if (created != null) result.created = created;
    if (updated != null) result.updated = updated;
    return result;
  }

  Question._();

  factory Question.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Question.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Question',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'topicId')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aI(4, _omitFieldNames ? '' : 'marks')
    ..pPM<RubricCriterion>(5, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..aOS(6, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<QuestionImage>(7, _omitFieldNames ? '' : 'images',
        subBuilder: QuestionImage.create)
    ..aInt64(8, _omitFieldNames ? '' : 'created')
    ..aInt64(9, _omitFieldNames ? '' : 'updated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Question clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Question copyWith(void Function(Question) updates) =>
      super.copyWith((message) => updates(message as Question)) as Question;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Question create() => Question._();
  @$core.override
  Question createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Question getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Question>(create);
  static Question? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get topicId => $_getIZ(1);
  @$pb.TagNumber(2)
  set topicId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTopicId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTopicId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get marks => $_getIZ(3);
  @$pb.TagNumber(4)
  set marks($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMarks() => $_has(3);
  @$pb.TagNumber(4)
  void clearMarks() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RubricCriterion> get rubric => $_getList(4);

  @$pb.TagNumber(6)
  $core.String get exampleAnswer => $_getSZ(5);
  @$pb.TagNumber(6)
  set exampleAnswer($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExampleAnswer() => $_has(5);
  @$pb.TagNumber(6)
  void clearExampleAnswer() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<QuestionImage> get images => $_getList(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get created => $_getI64(7);
  @$pb.TagNumber(8)
  set created($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreated() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreated() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get updated => $_getI64(8);
  @$pb.TagNumber(9)
  set updated($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdated() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdated() => $_clearField(9);
}

// ============================================================================
// CreateQuestionRequest
// ============================================================================

class CreateQuestionRequest extends $pb.GeneratedMessage {
  factory CreateQuestionRequest({
    $core.int? topicId,
    $core.String? text,
    $core.int? marks,
    $core.Iterable<RubricCriterion>? rubric,
    $core.String? exampleAnswer,
    $core.Iterable<QuestionImage>? images,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (rubric != null) result.rubric.addAll(rubric);
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (images != null) result.images.addAll(images);
    return result;
  }

  CreateQuestionRequest._();

  factory CreateQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aI(3, _omitFieldNames ? '' : 'marks')
    ..pPM<RubricCriterion>(4, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..aOS(5, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<QuestionImage>(6, _omitFieldNames ? '' : 'images',
        subBuilder: QuestionImage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateQuestionRequest copyWith(
          void Function(CreateQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as CreateQuestionRequest))
          as CreateQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateQuestionRequest create() => CreateQuestionRequest._();
  @$core.override
  CreateQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateQuestionRequest>(create);
  static CreateQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get topicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set topicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get marks => $_getIZ(2);
  @$pb.TagNumber(3)
  set marks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RubricCriterion> get rubric => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get exampleAnswer => $_getSZ(4);
  @$pb.TagNumber(5)
  set exampleAnswer($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExampleAnswer() => $_has(4);
  @$pb.TagNumber(5)
  void clearExampleAnswer() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<QuestionImage> get images => $_getList(5);
}

// ============================================================================
// CreateQuestionResponse
// ============================================================================

class CreateQuestionResponse extends $pb.GeneratedMessage {
  factory CreateQuestionResponse({
    Question? question,
  }) {
    final result = create();
    if (question != null) result.question = question;
    return result;
  }

  CreateQuestionResponse._();

  factory CreateQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOM<Question>(1, _omitFieldNames ? '' : 'question',
        subBuilder: Question.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateQuestionResponse copyWith(
          void Function(CreateQuestionResponse) updates) =>
      super.copyWith((message) => updates(message as CreateQuestionResponse))
          as CreateQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateQuestionResponse create() => CreateQuestionResponse._();
  @$core.override
  CreateQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateQuestionResponse>(create);
  static CreateQuestionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Question get question => $_getN(0);
  @$pb.TagNumber(1)
  set question(Question value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

// ============================================================================
// UpdateQuestionRequest
// ============================================================================

class UpdateQuestionRequest extends $pb.GeneratedMessage {
  factory UpdateQuestionRequest({
    $core.int? id,
    $core.String? text,
    $core.int? marks,
    $core.Iterable<RubricCriterion>? rubric,
    $core.String? exampleAnswer,
    $core.Iterable<QuestionImage>? images,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (rubric != null) result.rubric.addAll(rubric);
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (images != null) result.images.addAll(images);
    return result;
  }

  UpdateQuestionRequest._();

  factory UpdateQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aI(3, _omitFieldNames ? '' : 'marks')
    ..pPM<RubricCriterion>(4, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..aOS(5, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<QuestionImage>(6, _omitFieldNames ? '' : 'images',
        subBuilder: QuestionImage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateQuestionRequest copyWith(
          void Function(UpdateQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateQuestionRequest))
          as UpdateQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateQuestionRequest create() => UpdateQuestionRequest._();
  @$core.override
  UpdateQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateQuestionRequest>(create);
  static UpdateQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get marks => $_getIZ(2);
  @$pb.TagNumber(3)
  set marks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RubricCriterion> get rubric => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get exampleAnswer => $_getSZ(4);
  @$pb.TagNumber(5)
  set exampleAnswer($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExampleAnswer() => $_has(4);
  @$pb.TagNumber(5)
  void clearExampleAnswer() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<QuestionImage> get images => $_getList(5);
}

// ============================================================================
// UpdateQuestionResponse
// ============================================================================

class UpdateQuestionResponse extends $pb.GeneratedMessage {
  factory UpdateQuestionResponse({
    Question? question,
  }) {
    final result = create();
    if (question != null) result.question = question;
    return result;
  }

  UpdateQuestionResponse._();

  factory UpdateQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOM<Question>(1, _omitFieldNames ? '' : 'question',
        subBuilder: Question.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateQuestionResponse copyWith(
          void Function(UpdateQuestionResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateQuestionResponse))
          as UpdateQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateQuestionResponse create() => UpdateQuestionResponse._();
  @$core.override
  UpdateQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateQuestionResponse>(create);
  static UpdateQuestionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Question get question => $_getN(0);
  @$pb.TagNumber(1)
  set question(Question value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

// ============================================================================
// DeleteQuestionRequest
// ============================================================================

class DeleteQuestionRequest extends $pb.GeneratedMessage {
  factory DeleteQuestionRequest({
    $core.int? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteQuestionRequest._();

  factory DeleteQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteQuestionRequest copyWith(
          void Function(DeleteQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteQuestionRequest))
          as DeleteQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteQuestionRequest create() => DeleteQuestionRequest._();
  @$core.override
  DeleteQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteQuestionRequest>(create);
  static DeleteQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

// ============================================================================
// DeleteQuestionResponse
// ============================================================================

class DeleteQuestionResponse extends $pb.GeneratedMessage {
  factory DeleteQuestionResponse() => create();

  DeleteQuestionResponse._();

  factory DeleteQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteQuestionResponse copyWith(
          void Function(DeleteQuestionResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteQuestionResponse))
          as DeleteQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteQuestionResponse create() => DeleteQuestionResponse._();
  @$core.override
  DeleteQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteQuestionResponse>(create);
  static DeleteQuestionResponse? _defaultInstance;
}

// ============================================================================
// ImportError
// ============================================================================

class ImportError extends $pb.GeneratedMessage {
  factory ImportError({
    $core.int? index,
    $core.String? message,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (message != null) result.message = message;
    return result;
  }

  ImportError._();

  factory ImportError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImportError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportError',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportError clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportError copyWith(void Function(ImportError) updates) =>
      super.copyWith((message) => updates(message as ImportError))
          as ImportError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImportError create() => ImportError._();
  @$core.override
  ImportError createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImportError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportError>(create);
  static ImportError? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

// ============================================================================
// BulkImportRequest
// ============================================================================

class BulkImportRequest extends $pb.GeneratedMessage {
  factory BulkImportRequest({
    $core.String? jsonContent,
  }) {
    final result = create();
    if (jsonContent != null) result.jsonContent = jsonContent;
    return result;
  }

  BulkImportRequest._();

  factory BulkImportRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BulkImportRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BulkImportRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'jsonContent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BulkImportRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BulkImportRequest copyWith(void Function(BulkImportRequest) updates) =>
      super.copyWith((message) => updates(message as BulkImportRequest))
          as BulkImportRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BulkImportRequest create() => BulkImportRequest._();
  @$core.override
  BulkImportRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BulkImportRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BulkImportRequest>(create);
  static BulkImportRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get jsonContent => $_getSZ(0);
  @$pb.TagNumber(1)
  set jsonContent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJsonContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearJsonContent() => $_clearField(1);
}

// ============================================================================
// BulkImportResponse
// ============================================================================

class BulkImportResponse extends $pb.GeneratedMessage {
  factory BulkImportResponse({
    $core.int? createdCount,
    $core.Iterable<ImportError>? errors,
  }) {
    final result = create();
    if (createdCount != null) result.createdCount = createdCount;
    if (errors != null) result.errors.addAll(errors);
    return result;
  }

  BulkImportResponse._();

  factory BulkImportResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BulkImportResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BulkImportResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'createdCount')
    ..pPM<ImportError>(2, _omitFieldNames ? '' : 'errors',
        subBuilder: ImportError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BulkImportResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BulkImportResponse copyWith(void Function(BulkImportResponse) updates) =>
      super.copyWith((message) => updates(message as BulkImportResponse))
          as BulkImportResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BulkImportResponse create() => BulkImportResponse._();
  @$core.override
  BulkImportResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BulkImportResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BulkImportResponse>(create);
  static BulkImportResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get createdCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set createdCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCreatedCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearCreatedCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ImportError> get errors => $_getList(1);
}

// ============================================================================
// ImageUploadUrlsRequest
// ============================================================================

class ImageUploadUrlsRequest extends $pb.GeneratedMessage {
  factory ImageUploadUrlsRequest({
    $core.int? questionId,
    $core.Iterable<$core.String>? filenames,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (filenames != null) result.filenames.addAll(filenames);
    return result;
  }

  ImageUploadUrlsRequest._();

  factory ImageUploadUrlsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImageUploadUrlsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageUploadUrlsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..pPS(2, _omitFieldNames ? '' : 'filenames')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadUrlsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadUrlsRequest copyWith(
          void Function(ImageUploadUrlsRequest) updates) =>
      super.copyWith((message) => updates(message as ImageUploadUrlsRequest))
          as ImageUploadUrlsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImageUploadUrlsRequest create() => ImageUploadUrlsRequest._();
  @$core.override
  ImageUploadUrlsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImageUploadUrlsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImageUploadUrlsRequest>(create);
  static ImageUploadUrlsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get filenames => $_getList(1);
}

// ============================================================================
// SignedImageUrl
// ============================================================================

class SignedImageUrl extends $pb.GeneratedMessage {
  factory SignedImageUrl({
    $core.String? filename,
    $core.String? putUrl,
    $core.String? getUrl,
    $fixnum.Int64? expiry,
  }) {
    final result = create();
    if (filename != null) result.filename = filename;
    if (putUrl != null) result.putUrl = putUrl;
    if (getUrl != null) result.getUrl = getUrl;
    if (expiry != null) result.expiry = expiry;
    return result;
  }

  SignedImageUrl._();

  factory SignedImageUrl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignedImageUrl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignedImageUrl',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'filename')
    ..aOS(2, _omitFieldNames ? '' : 'putUrl')
    ..aOS(3, _omitFieldNames ? '' : 'getUrl')
    ..aInt64(4, _omitFieldNames ? '' : 'expiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedImageUrl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedImageUrl copyWith(void Function(SignedImageUrl) updates) =>
      super.copyWith((message) => updates(message as SignedImageUrl))
          as SignedImageUrl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignedImageUrl create() => SignedImageUrl._();
  @$core.override
  SignedImageUrl createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignedImageUrl getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignedImageUrl>(create);
  static SignedImageUrl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get filename => $_getSZ(0);
  @$pb.TagNumber(1)
  set filename($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFilename() => $_has(0);
  @$pb.TagNumber(1)
  void clearFilename() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get putUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set putUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPutUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearPutUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get getUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set getUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGetUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearGetUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get expiry => $_getI64(3);
  @$pb.TagNumber(4)
  set expiry($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiry() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiry() => $_clearField(4);
}

// ============================================================================
// ImageUploadUrlsResponse
// ============================================================================

class ImageUploadUrlsResponse extends $pb.GeneratedMessage {
  factory ImageUploadUrlsResponse({
    $core.Iterable<SignedImageUrl>? urls,
  }) {
    final result = create();
    if (urls != null) result.urls.addAll(urls);
    return result;
  }

  ImageUploadUrlsResponse._();

  factory ImageUploadUrlsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImageUploadUrlsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageUploadUrlsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..pPM<SignedImageUrl>(1, _omitFieldNames ? '' : 'urls',
        subBuilder: SignedImageUrl.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadUrlsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadUrlsResponse copyWith(
          void Function(ImageUploadUrlsResponse) updates) =>
      super.copyWith((message) => updates(message as ImageUploadUrlsResponse))
          as ImageUploadUrlsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImageUploadUrlsResponse create() => ImageUploadUrlsResponse._();
  @$core.override
  ImageUploadUrlsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImageUploadUrlsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImageUploadUrlsResponse>(create);
  static ImageUploadUrlsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SignedImageUrl> get urls => $_getList(0);
}

// ============================================================================
// TopicAllocation
// ============================================================================

class TopicAllocation extends $pb.GeneratedMessage {
  factory TopicAllocation({
    $core.int? topicId,
    $core.int? marks,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (marks != null) result.marks = marks;
    return result;
  }

  TopicAllocation._();

  factory TopicAllocation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TopicAllocation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TopicAllocation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'topicId')
    ..aI(2, _omitFieldNames ? '' : 'marks')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicAllocation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicAllocation copyWith(void Function(TopicAllocation) updates) =>
      super.copyWith((message) => updates(message as TopicAllocation))
          as TopicAllocation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TopicAllocation create() => TopicAllocation._();
  @$core.override
  TopicAllocation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TopicAllocation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TopicAllocation>(create);
  static TopicAllocation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get topicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set topicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get marks => $_getIZ(1);
  @$pb.TagNumber(2)
  set marks($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMarks() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarks() => $_clearField(2);
}

// ============================================================================
// GeneratePaperRequest
// ============================================================================

class GeneratePaperRequest extends $pb.GeneratedMessage {
  factory GeneratePaperRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
    $core.int? totalMarks,
    $core.Iterable<TopicAllocation>? topicAllocations,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (totalMarks != null) result.totalMarks = totalMarks;
    if (topicAllocations != null)
      result.topicAllocations.addAll(topicAllocations);
    return result;
  }

  GeneratePaperRequest._();

  factory GeneratePaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GeneratePaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GeneratePaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aI(7, _omitFieldNames ? '' : 'totalMarks')
    ..pPM<TopicAllocation>(8, _omitFieldNames ? '' : 'topicAllocations',
        subBuilder: TopicAllocation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePaperRequest copyWith(void Function(GeneratePaperRequest) updates) =>
      super.copyWith((message) => updates(message as GeneratePaperRequest))
          as GeneratePaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GeneratePaperRequest create() => GeneratePaperRequest._();
  @$core.override
  GeneratePaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GeneratePaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GeneratePaperRequest>(create);
  static GeneratePaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get paper => $_getIZ(3);
  @$pb.TagNumber(4)
  set paper($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPaper() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaper() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get stream => $_getIZ(5);
  @$pb.TagNumber(6)
  set stream($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStream() => $_has(5);
  @$pb.TagNumber(6)
  void clearStream() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get totalMarks => $_getIZ(6);
  @$pb.TagNumber(7)
  set totalMarks($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalMarks() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalMarks() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<TopicAllocation> get topicAllocations => $_getList(7);
}

// ============================================================================
// PaperQuestion
// ============================================================================

class PaperQuestion extends $pb.GeneratedMessage {
  factory PaperQuestion({
    $core.String? id,
    $core.int? questionId,
    $core.String? text,
    $core.int? marks,
    $core.Iterable<RubricCriterion>? rubric,
    $core.Iterable<QuestionImage>? images,
    $core.int? order,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (questionId != null) result.questionId = questionId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (rubric != null) result.rubric.addAll(rubric);
    if (images != null) result.images.addAll(images);
    if (order != null) result.order = order;
    return result;
  }

  PaperQuestion._();

  factory PaperQuestion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaperQuestion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaperQuestion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'questionId')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aI(4, _omitFieldNames ? '' : 'marks')
    ..pPM<RubricCriterion>(5, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..pPM<QuestionImage>(6, _omitFieldNames ? '' : 'images',
        subBuilder: QuestionImage.create)
    ..aI(7, _omitFieldNames ? '' : 'order')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperQuestion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperQuestion copyWith(void Function(PaperQuestion) updates) =>
      super.copyWith((message) => updates(message as PaperQuestion))
          as PaperQuestion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaperQuestion create() => PaperQuestion._();
  @$core.override
  PaperQuestion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaperQuestion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaperQuestion>(create);
  static PaperQuestion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get questionId => $_getIZ(1);
  @$pb.TagNumber(2)
  set questionId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuestionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuestionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get marks => $_getIZ(3);
  @$pb.TagNumber(4)
  set marks($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMarks() => $_has(3);
  @$pb.TagNumber(4)
  void clearMarks() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RubricCriterion> get rubric => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<QuestionImage> get images => $_getList(5);

  @$pb.TagNumber(7)
  $core.int get order => $_getIZ(6);
  @$pb.TagNumber(7)
  set order($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOrder() => $_has(6);
  @$pb.TagNumber(7)
  void clearOrder() => $_clearField(7);
}

// ============================================================================
// GeneratePaperResponse
// ============================================================================

class GeneratePaperResponse extends $pb.GeneratedMessage {
  factory GeneratePaperResponse({
    $core.Iterable<PaperQuestion>? paperQuestions,
  }) {
    final result = create();
    if (paperQuestions != null) result.paperQuestions.addAll(paperQuestions);
    return result;
  }

  GeneratePaperResponse._();

  factory GeneratePaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GeneratePaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GeneratePaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..pPM<PaperQuestion>(1, _omitFieldNames ? '' : 'paperQuestions',
        subBuilder: PaperQuestion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePaperResponse copyWith(
          void Function(GeneratePaperResponse) updates) =>
      super.copyWith((message) => updates(message as GeneratePaperResponse))
          as GeneratePaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GeneratePaperResponse create() => GeneratePaperResponse._();
  @$core.override
  GeneratePaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GeneratePaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GeneratePaperResponse>(create);
  static GeneratePaperResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PaperQuestion> get paperQuestions => $_getList(0);
}

// ============================================================================
// RegenerateQuestionRequest
// ============================================================================

class RegenerateQuestionRequest extends $pb.GeneratedMessage {
  factory RegenerateQuestionRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.String? paperQuestionId,
    $core.int? topicId,
    $core.int? marks,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (paperQuestionId != null) result.paperQuestionId = paperQuestionId;
    if (topicId != null) result.topicId = topicId;
    if (marks != null) result.marks = marks;
    return result;
  }

  RegenerateQuestionRequest._();

  factory RegenerateQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegenerateQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegenerateQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aOS(6, _omitFieldNames ? '' : 'paperQuestionId')
    ..aI(7, _omitFieldNames ? '' : 'topicId')
    ..aI(8, _omitFieldNames ? '' : 'marks')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegenerateQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegenerateQuestionRequest copyWith(
          void Function(RegenerateQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as RegenerateQuestionRequest))
          as RegenerateQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegenerateQuestionRequest create() => RegenerateQuestionRequest._();
  @$core.override
  RegenerateQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegenerateQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegenerateQuestionRequest>(create);
  static RegenerateQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get paper => $_getIZ(3);
  @$pb.TagNumber(4)
  set paper($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPaper() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaper() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get paperQuestionId => $_getSZ(5);
  @$pb.TagNumber(6)
  set paperQuestionId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPaperQuestionId() => $_has(5);
  @$pb.TagNumber(6)
  void clearPaperQuestionId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get topicId => $_getIZ(6);
  @$pb.TagNumber(7)
  set topicId($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTopicId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTopicId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get marks => $_getIZ(7);
  @$pb.TagNumber(8)
  set marks($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMarks() => $_has(7);
  @$pb.TagNumber(8)
  void clearMarks() => $_clearField(8);
}

// ============================================================================
// RegenerateQuestionResponse
// ============================================================================

class RegenerateQuestionResponse extends $pb.GeneratedMessage {
  factory RegenerateQuestionResponse({
    PaperQuestion? paperQuestion,
  }) {
    final result = create();
    if (paperQuestion != null) result.paperQuestion = paperQuestion;
    return result;
  }

  RegenerateQuestionResponse._();

  factory RegenerateQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegenerateQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegenerateQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOM<PaperQuestion>(1, _omitFieldNames ? '' : 'paperQuestion',
        subBuilder: PaperQuestion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegenerateQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegenerateQuestionResponse copyWith(
          void Function(RegenerateQuestionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RegenerateQuestionResponse))
          as RegenerateQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegenerateQuestionResponse create() => RegenerateQuestionResponse._();
  @$core.override
  RegenerateQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegenerateQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegenerateQuestionResponse>(create);
  static RegenerateQuestionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PaperQuestion get paperQuestion => $_getN(0);
  @$pb.TagNumber(1)
  set paperQuestion(PaperQuestion value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperQuestion() => clearField(1);
  @$pb.TagNumber(1)
  PaperQuestion ensurePaperQuestion() => $_ensure(0);
}

// ============================================================================
// EditPaperQuestionRequest
// ============================================================================

class EditPaperQuestionRequest extends $pb.GeneratedMessage {
  factory EditPaperQuestionRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.String? paperQuestionId,
    $core.String? text,
    $core.int? marks,
    $core.Iterable<RubricCriterion>? rubric,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (paperQuestionId != null) result.paperQuestionId = paperQuestionId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (rubric != null) result.rubric.addAll(rubric);
    return result;
  }

  EditPaperQuestionRequest._();

  factory EditPaperQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditPaperQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditPaperQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aOS(5, _omitFieldNames ? '' : 'paperQuestionId')
    ..aOS(6, _omitFieldNames ? '' : 'text')
    ..aI(7, _omitFieldNames ? '' : 'marks')
    ..pPM<RubricCriterion>(8, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditPaperQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditPaperQuestionRequest copyWith(
          void Function(EditPaperQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as EditPaperQuestionRequest))
          as EditPaperQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditPaperQuestionRequest create() => EditPaperQuestionRequest._();
  @$core.override
  EditPaperQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditPaperQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditPaperQuestionRequest>(create);
  static EditPaperQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get paper => $_getIZ(3);
  @$pb.TagNumber(4)
  set paper($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPaper() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaper() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get paperQuestionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set paperQuestionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPaperQuestionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearPaperQuestionId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get text => $_getSZ(5);
  @$pb.TagNumber(6)
  set text($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasText() => $_has(5);
  @$pb.TagNumber(6)
  void clearText() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get marks => $_getIZ(6);
  @$pb.TagNumber(7)
  set marks($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMarks() => $_has(6);
  @$pb.TagNumber(7)
  void clearMarks() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<RubricCriterion> get rubric => $_getList(7);
}

// ============================================================================
// EditPaperQuestionResponse
// ============================================================================

class EditPaperQuestionResponse extends $pb.GeneratedMessage {
  factory EditPaperQuestionResponse({
    PaperQuestion? paperQuestion,
  }) {
    final result = create();
    if (paperQuestion != null) result.paperQuestion = paperQuestion;
    return result;
  }

  EditPaperQuestionResponse._();

  factory EditPaperQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditPaperQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditPaperQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOM<PaperQuestion>(1, _omitFieldNames ? '' : 'paperQuestion',
        subBuilder: PaperQuestion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditPaperQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditPaperQuestionResponse copyWith(
          void Function(EditPaperQuestionResponse) updates) =>
      super.copyWith((message) => updates(message as EditPaperQuestionResponse))
          as EditPaperQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditPaperQuestionResponse create() => EditPaperQuestionResponse._();
  @$core.override
  EditPaperQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditPaperQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditPaperQuestionResponse>(create);
  static EditPaperQuestionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PaperQuestion get paperQuestion => $_getN(0);
  @$pb.TagNumber(1)
  set paperQuestion(PaperQuestion value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperQuestion() => clearField(1);
  @$pb.TagNumber(1)
  PaperQuestion ensurePaperQuestion() => $_ensure(0);
}

// ============================================================================
// FinalizePaperRequest
// ============================================================================

class FinalizePaperRequest extends $pb.GeneratedMessage {
  factory FinalizePaperRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
    $core.Iterable<$core.String>? paperQuestionIds,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (paperQuestionIds != null)
      result.paperQuestionIds.addAll(paperQuestionIds);
    return result;
  }

  FinalizePaperRequest._();

  factory FinalizePaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizePaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizePaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..pPS(7, _omitFieldNames ? '' : 'paperQuestionIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizePaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizePaperRequest copyWith(void Function(FinalizePaperRequest) updates) =>
      super.copyWith((message) => updates(message as FinalizePaperRequest))
          as FinalizePaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizePaperRequest create() => FinalizePaperRequest._();
  @$core.override
  FinalizePaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FinalizePaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizePaperRequest>(create);
  static FinalizePaperRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get paper => $_getIZ(3);
  @$pb.TagNumber(4)
  set paper($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPaper() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaper() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get stream => $_getIZ(5);
  @$pb.TagNumber(6)
  set stream($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStream() => $_has(5);
  @$pb.TagNumber(6)
  void clearStream() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get paperQuestionIds => $_getList(6);
}

// ============================================================================
// FinalizePaperResponse
// ============================================================================

class FinalizePaperResponse extends $pb.GeneratedMessage {
  factory FinalizePaperResponse({
    $core.String? pdfUrl,
    $fixnum.Int64? pdfExpiry,
  }) {
    final result = create();
    if (pdfUrl != null) result.pdfUrl = pdfUrl;
    if (pdfExpiry != null) result.pdfExpiry = pdfExpiry;
    return result;
  }

  FinalizePaperResponse._();

  factory FinalizePaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizePaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizePaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pdfUrl')
    ..aInt64(2, _omitFieldNames ? '' : 'pdfExpiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizePaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizePaperResponse copyWith(
          void Function(FinalizePaperResponse) updates) =>
      super.copyWith((message) => updates(message as FinalizePaperResponse))
          as FinalizePaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizePaperResponse create() => FinalizePaperResponse._();
  @$core.override
  FinalizePaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FinalizePaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizePaperResponse>(create);
  static FinalizePaperResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pdfUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set pdfUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPdfUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearPdfUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get pdfExpiry => $_getI64(1);
  @$pb.TagNumber(2)
  set pdfExpiry($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPdfExpiry() => $_has(1);
  @$pb.TagNumber(2)
  void clearPdfExpiry() => $_clearField(2);
}

// ============================================================================
// GetPaperPdfRequest
// ============================================================================

class GetPaperPdfRequest extends $pb.GeneratedMessage {
  factory GetPaperPdfRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  GetPaperPdfRequest._();

  factory GetPaperPdfRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperPdfRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperPdfRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfRequest copyWith(void Function(GetPaperPdfRequest) updates) =>
      super.copyWith((message) => updates(message as GetPaperPdfRequest))
          as GetPaperPdfRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperPdfRequest create() => GetPaperPdfRequest._();
  @$core.override
  GetPaperPdfRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperPdfRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperPdfRequest>(create);
  static GetPaperPdfRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get paper => $_getIZ(3);
  @$pb.TagNumber(4)
  set paper($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPaper() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaper() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get stream => $_getIZ(5);
  @$pb.TagNumber(6)
  set stream($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStream() => $_has(5);
  @$pb.TagNumber(6)
  void clearStream() => $_clearField(6);
}

// ============================================================================
// GetPaperPdfResponse
// ============================================================================

class GetPaperPdfResponse extends $pb.GeneratedMessage {
  factory GetPaperPdfResponse({
    $core.String? pdfUrl,
    $fixnum.Int64? pdfExpiry,
  }) {
    final result = create();
    if (pdfUrl != null) result.pdfUrl = pdfUrl;
    if (pdfExpiry != null) result.pdfExpiry = pdfExpiry;
    return result;
  }

  GetPaperPdfResponse._();

  factory GetPaperPdfResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperPdfResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperPdfResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pdfUrl')
    ..aInt64(2, _omitFieldNames ? '' : 'pdfExpiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperPdfResponse copyWith(void Function(GetPaperPdfResponse) updates) =>
      super.copyWith((message) => updates(message as GetPaperPdfResponse))
          as GetPaperPdfResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperPdfResponse create() => GetPaperPdfResponse._();
  @$core.override
  GetPaperPdfResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperPdfResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperPdfResponse>(create);
  static GetPaperPdfResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pdfUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set pdfUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPdfUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearPdfUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get pdfExpiry => $_getI64(1);
  @$pb.TagNumber(2)
  set pdfExpiry($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPdfExpiry() => $_has(1);
  @$pb.TagNumber(2)
  void clearPdfExpiry() => $_clearField(2);
}

// ============================================================================
// ListQuestionsRequest
// ============================================================================

class ListQuestionsRequest extends $pb.GeneratedMessage {
  factory ListQuestionsRequest({
    $core.int? topicId,
    $core.int? offset,
    $core.int? limit,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    return result;
  }

  ListQuestionsRequest._();

  factory ListQuestionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListQuestionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListQuestionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'topicId')
    ..aI(2, _omitFieldNames ? '' : 'offset')
    ..aI(3, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListQuestionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListQuestionsRequest copyWith(void Function(ListQuestionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListQuestionsRequest))
          as ListQuestionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListQuestionsRequest create() => ListQuestionsRequest._();
  @$core.override
  ListQuestionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListQuestionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListQuestionsRequest>(create);
  static ListQuestionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get topicId => $_getIZ(0);
  @$pb.TagNumber(1)
  set topicId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

// ============================================================================
// ListQuestionsResponse
// ============================================================================

class ListQuestionsResponse extends $pb.GeneratedMessage {
  factory ListQuestionsResponse({
    $core.Iterable<Question>? questions,
    $core.int? total,
  }) {
    final result = create();
    if (questions != null) result.questions.addAll(questions);
    if (total != null) result.total = total;
    return result;
  }

  ListQuestionsResponse._();

  factory ListQuestionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListQuestionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListQuestionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..pPM<Question>(1, _omitFieldNames ? '' : 'questions',
        subBuilder: Question.create)
    ..aI(2, _omitFieldNames ? '' : 'total')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListQuestionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListQuestionsResponse copyWith(
          void Function(ListQuestionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListQuestionsResponse))
          as ListQuestionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListQuestionsResponse create() => ListQuestionsResponse._();
  @$core.override
  ListQuestionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListQuestionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListQuestionsResponse>(create);
  static ListQuestionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Question> get questions => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get total => $_getIZ(1);
  @$pb.TagNumber(2)
  set total($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotal() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotal() => $_clearField(2);
}

// ============================================================================
// GetQuestionRequest
// ============================================================================

class GetQuestionRequest extends $pb.GeneratedMessage {
  factory GetQuestionRequest({
    $core.int? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetQuestionRequest._();

  factory GetQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionRequest copyWith(void Function(GetQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as GetQuestionRequest))
          as GetQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetQuestionRequest create() => GetQuestionRequest._();
  @$core.override
  GetQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetQuestionRequest>(create);
  static GetQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

// ============================================================================
// GetQuestionResponse
// ============================================================================

class GetQuestionResponse extends $pb.GeneratedMessage {
  factory GetQuestionResponse({
    Question? question,
  }) {
    final result = create();
    if (question != null) result.question = question;
    return result;
  }

  GetQuestionResponse._();

  factory GetQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOM<Question>(1, _omitFieldNames ? '' : 'question',
        subBuilder: Question.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionResponse copyWith(void Function(GetQuestionResponse) updates) =>
      super.copyWith((message) => updates(message as GetQuestionResponse))
          as GetQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetQuestionResponse create() => GetQuestionResponse._();
  @$core.override
  GetQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetQuestionResponse>(create);
  static GetQuestionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Question get question => $_getN(0);
  @$pb.TagNumber(1)
  set question(Question value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

// ============================================================================
// GetQuestionGradesRequest
// ============================================================================

class GetQuestionGradesRequest extends $pb.GeneratedMessage {
  factory GetQuestionGradesRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? student,
    $core.int? subject,
    $core.int? paper,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (student != null) result.student = student;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    return result;
  }

  GetQuestionGradesRequest._();

  factory GetQuestionGradesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetQuestionGradesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetQuestionGradesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'student')
    ..aI(4, _omitFieldNames ? '' : 'subject')
    ..aI(5, _omitFieldNames ? '' : 'paper')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionGradesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionGradesRequest copyWith(
          void Function(GetQuestionGradesRequest) updates) =>
      super.copyWith((message) => updates(message as GetQuestionGradesRequest))
          as GetQuestionGradesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetQuestionGradesRequest create() => GetQuestionGradesRequest._();
  @$core.override
  GetQuestionGradesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetQuestionGradesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetQuestionGradesRequest>(create);
  static GetQuestionGradesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get student => $_getIZ(2);
  @$pb.TagNumber(3)
  set student($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStudent() => $_has(2);
  @$pb.TagNumber(3)
  void clearStudent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get subject => $_getIZ(3);
  @$pb.TagNumber(4)
  set subject($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSubject() => $_has(3);
  @$pb.TagNumber(4)
  void clearSubject() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get paper => $_getIZ(4);
  @$pb.TagNumber(5)
  set paper($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPaper() => $_has(4);
  @$pb.TagNumber(5)
  void clearPaper() => $_clearField(5);
}

// ============================================================================
// RubricResult
// ============================================================================

class RubricResult extends $pb.GeneratedMessage {
  factory RubricResult({
    $core.String? criterion,
    $core.bool? satisfied,
    $core.double? marksAwarded,
    $core.int? marksAvailable,
  }) {
    final result = create();
    if (criterion != null) result.criterion = criterion;
    if (satisfied != null) result.satisfied = satisfied;
    if (marksAwarded != null) result.marksAwarded = marksAwarded;
    if (marksAvailable != null) result.marksAvailable = marksAvailable;
    return result;
  }

  RubricResult._();

  factory RubricResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RubricResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RubricResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'criterion')
    ..aOB(2, _omitFieldNames ? '' : 'satisfied')
    ..a<$core.double>(
        3, _omitFieldNames ? '' : 'marksAwarded', $pb.PbFieldType.OD)
    ..aI(4, _omitFieldNames ? '' : 'marksAvailable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RubricResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RubricResult copyWith(void Function(RubricResult) updates) =>
      super.copyWith((message) => updates(message as RubricResult))
          as RubricResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RubricResult create() => RubricResult._();
  @$core.override
  RubricResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RubricResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RubricResult>(create);
  static RubricResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get criterion => $_getSZ(0);
  @$pb.TagNumber(1)
  set criterion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCriterion() => $_has(0);
  @$pb.TagNumber(1)
  void clearCriterion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get satisfied => $_getBF(1);
  @$pb.TagNumber(2)
  set satisfied($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSatisfied() => $_has(1);
  @$pb.TagNumber(2)
  void clearSatisfied() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get marksAwarded => $_getN(2);
  @$pb.TagNumber(3)
  set marksAwarded($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarksAwarded() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarksAwarded() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get marksAvailable => $_getIZ(3);
  @$pb.TagNumber(4)
  set marksAvailable($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMarksAvailable() => $_has(3);
  @$pb.TagNumber(4)
  void clearMarksAvailable() => $_clearField(4);
}

// ============================================================================
// QuestionGrade
// ============================================================================

class QuestionGrade extends $pb.GeneratedMessage {
  factory QuestionGrade({
    $core.String? questionText,
    $core.double? marksAwarded,
    $core.int? totalMarks,
    $core.String? feedback,
    $core.Iterable<RubricResult>? rubricResults,
  }) {
    final result = create();
    if (questionText != null) result.questionText = questionText;
    if (marksAwarded != null) result.marksAwarded = marksAwarded;
    if (totalMarks != null) result.totalMarks = totalMarks;
    if (feedback != null) result.feedback = feedback;
    if (rubricResults != null) result.rubricResults.addAll(rubricResults);
    return result;
  }

  QuestionGrade._();

  factory QuestionGrade.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuestionGrade.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuestionGrade',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'questionText')
    ..a<$core.double>(
        2, _omitFieldNames ? '' : 'marksAwarded', $pb.PbFieldType.OD)
    ..aI(3, _omitFieldNames ? '' : 'totalMarks')
    ..aOS(4, _omitFieldNames ? '' : 'feedback')
    ..pPM<RubricResult>(5, _omitFieldNames ? '' : 'rubricResults',
        subBuilder: RubricResult.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionGrade clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionGrade copyWith(void Function(QuestionGrade) updates) =>
      super.copyWith((message) => updates(message as QuestionGrade))
          as QuestionGrade;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuestionGrade create() => QuestionGrade._();
  @$core.override
  QuestionGrade createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuestionGrade getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuestionGrade>(create);
  static QuestionGrade? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get questionText => $_getSZ(0);
  @$pb.TagNumber(1)
  set questionText($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionText() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get marksAwarded => $_getN(1);
  @$pb.TagNumber(2)
  set marksAwarded($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMarksAwarded() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarksAwarded() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalMarks => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalMarks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get feedback => $_getSZ(3);
  @$pb.TagNumber(4)
  set feedback($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFeedback() => $_has(3);
  @$pb.TagNumber(4)
  void clearFeedback() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RubricResult> get rubricResults => $_getList(4);
}

// ============================================================================
// GetQuestionGradesResponse
// ============================================================================

class GetQuestionGradesResponse extends $pb.GeneratedMessage {
  factory GetQuestionGradesResponse({
    $core.Iterable<QuestionGrade>? questionGrades,
  }) {
    final result = create();
    if (questionGrades != null) result.questionGrades.addAll(questionGrades);
    return result;
  }

  GetQuestionGradesResponse._();

  factory GetQuestionGradesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetQuestionGradesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetQuestionGradesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..pPM<QuestionGrade>(1, _omitFieldNames ? '' : 'questionGrades',
        subBuilder: QuestionGrade.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionGradesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQuestionGradesResponse copyWith(
          void Function(GetQuestionGradesResponse) updates) =>
      super.copyWith((message) => updates(message as GetQuestionGradesResponse))
          as GetQuestionGradesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetQuestionGradesResponse create() => GetQuestionGradesResponse._();
  @$core.override
  GetQuestionGradesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetQuestionGradesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetQuestionGradesResponse>(create);
  static GetQuestionGradesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<QuestionGrade> get questionGrades => $_getList(0);
}

// ============================================================================
// MarkingStatusRequest
// ============================================================================

class MarkingStatusRequest extends $pb.GeneratedMessage {
  factory MarkingStatusRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  MarkingStatusRequest._();

  factory MarkingStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkingStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkingStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkingStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkingStatusRequest copyWith(void Function(MarkingStatusRequest) updates) =>
      super.copyWith((message) => updates(message as MarkingStatusRequest))
          as MarkingStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkingStatusRequest create() => MarkingStatusRequest._();
  @$core.override
  MarkingStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkingStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkingStatusRequest>(create);
  static MarkingStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exam => $_getSZ(1);
  @$pb.TagNumber(2)
  set exam($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExam() => $_has(1);
  @$pb.TagNumber(2)
  void clearExam() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get paper => $_getIZ(3);
  @$pb.TagNumber(4)
  set paper($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPaper() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaper() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get stream => $_getIZ(5);
  @$pb.TagNumber(6)
  set stream($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStream() => $_has(5);
  @$pb.TagNumber(6)
  void clearStream() => $_clearField(6);
}

// ============================================================================
// MarkingStatusResponse
// ============================================================================

class MarkingStatusResponse extends $pb.GeneratedMessage {
  factory MarkingStatusResponse({
    $1.MarkingStatusEnum? status,
    $core.int? progressCurrent,
    $core.int? progressTotal,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (progressCurrent != null) result.progressCurrent = progressCurrent;
    if (progressTotal != null) result.progressTotal = progressTotal;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  MarkingStatusResponse._();

  factory MarkingStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkingStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkingStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..e<$1.MarkingStatusEnum>(
        1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE,
        defaultOrMaker: $1.MarkingStatusEnum.QUEUED,
        valueOf: $1.MarkingStatusEnum.valueOf,
        enumValues: $1.MarkingStatusEnum.values)
    ..aI(2, _omitFieldNames ? '' : 'progressCurrent')
    ..aI(3, _omitFieldNames ? '' : 'progressTotal')
    ..aOS(4, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkingStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkingStatusResponse copyWith(
          void Function(MarkingStatusResponse) updates) =>
      super.copyWith((message) => updates(message as MarkingStatusResponse))
          as MarkingStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkingStatusResponse create() => MarkingStatusResponse._();
  @$core.override
  MarkingStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkingStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkingStatusResponse>(create);
  static MarkingStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $1.MarkingStatusEnum get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.MarkingStatusEnum value) => setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get progressCurrent => $_getIZ(1);
  @$pb.TagNumber(2)
  set progressCurrent($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgressCurrent() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgressCurrent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get progressTotal => $_getIZ(2);
  @$pb.TagNumber(3)
  set progressTotal($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProgressTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearProgressTotal() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get errorMessage => $_getSZ(3);
  @$pb.TagNumber(4)
  set errorMessage($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasErrorMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearErrorMessage() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
