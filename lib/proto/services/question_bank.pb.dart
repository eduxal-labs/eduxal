// This is a generated file - do not edit.
//
// Generated from services/question_bank.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'question_bank.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'question_bank.pbenum.dart';

class Question extends $pb.GeneratedMessage {
  factory Question({
    $core.int? id,
    $core.int? topicId,
    $core.String? text,
    $core.int? marks,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterion>? rubric,
    $core.Iterable<QuestionImage>? images,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (topicId != null) result.topicId = topicId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (rubric != null) result.rubric.addAll(rubric);
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
    ..aOS(5, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterion>(6, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
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
  $core.String get exampleAnswer => $_getSZ(4);
  @$pb.TagNumber(5)
  set exampleAnswer($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExampleAnswer() => $_has(4);
  @$pb.TagNumber(5)
  void clearExampleAnswer() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<RubricCriterion> get rubric => $_getList(5);

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

class RubricCriterion extends $pb.GeneratedMessage {
  factory RubricCriterion({
    $core.int? position,
    $core.String? criterion,
    $core.int? marks,
  }) {
    final result = create();
    if (position != null) result.position = position;
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
    ..aI(1, _omitFieldNames ? '' : 'position')
    ..aOS(2, _omitFieldNames ? '' : 'criterion')
    ..aI(3, _omitFieldNames ? '' : 'marks')
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
  $core.int get position => $_getIZ(0);
  @$pb.TagNumber(1)
  set position($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearPosition() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get criterion => $_getSZ(1);
  @$pb.TagNumber(2)
  set criterion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCriterion() => $_has(1);
  @$pb.TagNumber(2)
  void clearCriterion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get marks => $_getIZ(2);
  @$pb.TagNumber(3)
  set marks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarks() => $_clearField(3);
}

class QuestionImage extends $pb.GeneratedMessage {
  factory QuestionImage({
    $core.int? id,
    $core.int? position,
    $core.int? context,
    $core.String? key,
    $core.String? url,
    $core.String? caption,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (position != null) result.position = position;
    if (context != null) result.context = context;
    if (key != null) result.key = key;
    if (url != null) result.url = url;
    if (caption != null) result.caption = caption;
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
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'position')
    ..aI(3, _omitFieldNames ? '' : 'context')
    ..aOS(4, _omitFieldNames ? '' : 'key')
    ..aOS(5, _omitFieldNames ? '' : 'url')
    ..aOS(6, _omitFieldNames ? '' : 'caption')
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
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get position => $_getIZ(1);
  @$pb.TagNumber(2)
  set position($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearPosition() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get context => $_getIZ(2);
  @$pb.TagNumber(3)
  set context($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContext() => $_has(2);
  @$pb.TagNumber(3)
  void clearContext() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get key => $_getSZ(3);
  @$pb.TagNumber(4)
  set key($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get url => $_getSZ(4);
  @$pb.TagNumber(5)
  set url($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get caption => $_getSZ(5);
  @$pb.TagNumber(6)
  set caption($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCaption() => $_has(5);
  @$pb.TagNumber(6)
  void clearCaption() => $_clearField(6);
}

/// Global catalog operation.
/// Creates a question in the shared system-wide question bank and is not school-scoped.
/// School-scoped fields belong only to paper assembly / grading / marking requests.
class CreateQuestionRequest extends $pb.GeneratedMessage {
  factory CreateQuestionRequest({
    $core.int? topicId,
    $core.String? text,
    $core.int? marks,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterionInput>? rubric,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (rubric != null) result.rubric.addAll(rubric);
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
    ..aOS(4, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterionInput>(5, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterionInput.create)
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
  $core.String get exampleAnswer => $_getSZ(3);
  @$pb.TagNumber(4)
  set exampleAnswer($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExampleAnswer() => $_has(3);
  @$pb.TagNumber(4)
  void clearExampleAnswer() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RubricCriterionInput> get rubric => $_getList(4);
}

class RubricCriterionInput extends $pb.GeneratedMessage {
  factory RubricCriterionInput({
    $core.String? criterion,
    $core.int? marks,
  }) {
    final result = create();
    if (criterion != null) result.criterion = criterion;
    if (marks != null) result.marks = marks;
    return result;
  }

  RubricCriterionInput._();

  factory RubricCriterionInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RubricCriterionInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RubricCriterionInput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'criterion')
    ..aI(2, _omitFieldNames ? '' : 'marks')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RubricCriterionInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RubricCriterionInput copyWith(void Function(RubricCriterionInput) updates) =>
      super.copyWith((message) => updates(message as RubricCriterionInput))
          as RubricCriterionInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RubricCriterionInput create() => RubricCriterionInput._();
  @$core.override
  RubricCriterionInput createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RubricCriterionInput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RubricCriterionInput>(create);
  static RubricCriterionInput? _defaultInstance;

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
  set question(Question value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => $_clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

/// Global catalog operation.
/// Updates a question in the shared system-wide question bank and is not school-scoped.
/// School-scoped fields belong only to paper assembly / grading / marking requests.
class UpdateQuestionRequest extends $pb.GeneratedMessage {
  factory UpdateQuestionRequest({
    $core.int? questionId,
    $core.String? text,
    $core.int? marks,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterionInput>? rubric,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (rubric != null) result.rubric.addAll(rubric);
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
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aI(3, _omitFieldNames ? '' : 'marks')
    ..aOS(4, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterionInput>(5, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterionInput.create)
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
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

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
  $core.String get exampleAnswer => $_getSZ(3);
  @$pb.TagNumber(4)
  set exampleAnswer($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExampleAnswer() => $_has(3);
  @$pb.TagNumber(4)
  void clearExampleAnswer() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RubricCriterionInput> get rubric => $_getList(4);
}

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
  set question(Question value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => $_clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

/// Global catalog operation.
/// Deletes a question from the shared system-wide question bank and is not school-scoped.
/// School-scoped fields belong only to paper assembly / grading / marking requests.
class DeleteQuestionRequest extends $pb.GeneratedMessage {
  factory DeleteQuestionRequest({
    $core.int? questionId,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
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
    ..aI(1, _omitFieldNames ? '' : 'questionId')
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
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);
}

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

/// Global catalog operation.
/// Imports questions into the shared system-wide question bank and is not school-scoped.
/// School-scoped fields belong only to paper assembly / grading / marking requests.
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

class BulkImportResponse extends $pb.GeneratedMessage {
  factory BulkImportResponse({
    $core.int? questionsCreated,
    $core.Iterable<ImportError>? errors,
    $core.Iterable<$core.int>? questionIds,
    $core.int? duplicatesSkipped,
  }) {
    final result = create();
    if (questionsCreated != null) result.questionsCreated = questionsCreated;
    if (errors != null) result.errors.addAll(errors);
    if (questionIds != null) result.questionIds.addAll(questionIds);
    if (duplicatesSkipped != null) result.duplicatesSkipped = duplicatesSkipped;
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
    ..aI(1, _omitFieldNames ? '' : 'questionsCreated')
    ..pPM<ImportError>(2, _omitFieldNames ? '' : 'errors',
        subBuilder: ImportError.create)
    ..p<$core.int>(3, _omitFieldNames ? '' : 'questionIds', $pb.PbFieldType.K3)
    ..aI(4, _omitFieldNames ? '' : 'duplicatesSkipped')
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
  $core.int get questionsCreated => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionsCreated($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionsCreated() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionsCreated() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ImportError> get errors => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get questionIds => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get duplicatesSkipped => $_getIZ(3);
  @$pb.TagNumber(4)
  set duplicatesSkipped($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDuplicatesSkipped() => $_has(3);
  @$pb.TagNumber(4)
  void clearDuplicatesSkipped() => $_clearField(4);
}

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

class ImageUploadUrlsRequest extends $pb.GeneratedMessage {
  factory ImageUploadUrlsRequest({
    $core.Iterable<ImageUploadSpec>? images,
  }) {
    final result = create();
    if (images != null) result.images.addAll(images);
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
    ..pPM<ImageUploadSpec>(1, _omitFieldNames ? '' : 'images',
        subBuilder: ImageUploadSpec.create)
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
  $pb.PbList<ImageUploadSpec> get images => $_getList(0);
}

class ImageUploadSpec extends $pb.GeneratedMessage {
  factory ImageUploadSpec({
    $core.int? questionId,
    $core.int? position,
    $core.int? context,
    $core.String? caption,
    $core.String? filename,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (position != null) result.position = position;
    if (context != null) result.context = context;
    if (caption != null) result.caption = caption;
    if (filename != null) result.filename = filename;
    return result;
  }

  ImageUploadSpec._();

  factory ImageUploadSpec.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImageUploadSpec.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageUploadSpec',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..aI(2, _omitFieldNames ? '' : 'position')
    ..aI(3, _omitFieldNames ? '' : 'context')
    ..aOS(4, _omitFieldNames ? '' : 'caption')
    ..aOS(5, _omitFieldNames ? '' : 'filename')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadSpec clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadSpec copyWith(void Function(ImageUploadSpec) updates) =>
      super.copyWith((message) => updates(message as ImageUploadSpec))
          as ImageUploadSpec;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImageUploadSpec create() => ImageUploadSpec._();
  @$core.override
  ImageUploadSpec createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImageUploadSpec getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImageUploadSpec>(create);
  static ImageUploadSpec? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get position => $_getIZ(1);
  @$pb.TagNumber(2)
  set position($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearPosition() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get context => $_getIZ(2);
  @$pb.TagNumber(3)
  set context($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContext() => $_has(2);
  @$pb.TagNumber(3)
  void clearContext() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get caption => $_getSZ(3);
  @$pb.TagNumber(4)
  set caption($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCaption() => $_has(3);
  @$pb.TagNumber(4)
  void clearCaption() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get filename => $_getSZ(4);
  @$pb.TagNumber(5)
  set filename($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFilename() => $_has(4);
  @$pb.TagNumber(5)
  void clearFilename() => $_clearField(5);
}

class ImageUploadUrlsResponse extends $pb.GeneratedMessage {
  factory ImageUploadUrlsResponse({
    $core.Iterable<ImageUploadUrl>? urls,
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
    ..pPM<ImageUploadUrl>(1, _omitFieldNames ? '' : 'urls',
        subBuilder: ImageUploadUrl.create)
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
  $pb.PbList<ImageUploadUrl> get urls => $_getList(0);
}

class ImageUploadUrl extends $pb.GeneratedMessage {
  factory ImageUploadUrl({
    $core.int? questionId,
    $core.int? position,
    $core.String? key,
    $core.String? putUrl,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (position != null) result.position = position;
    if (key != null) result.key = key;
    if (putUrl != null) result.putUrl = putUrl;
    return result;
  }

  ImageUploadUrl._();

  factory ImageUploadUrl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImageUploadUrl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageUploadUrl',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..aI(2, _omitFieldNames ? '' : 'position')
    ..aOS(3, _omitFieldNames ? '' : 'key')
    ..aOS(4, _omitFieldNames ? '' : 'putUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadUrl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageUploadUrl copyWith(void Function(ImageUploadUrl) updates) =>
      super.copyWith((message) => updates(message as ImageUploadUrl))
          as ImageUploadUrl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImageUploadUrl create() => ImageUploadUrl._();
  @$core.override
  ImageUploadUrl createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImageUploadUrl getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImageUploadUrl>(create);
  static ImageUploadUrl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get position => $_getIZ(1);
  @$pb.TagNumber(2)
  set position($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearPosition() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get key => $_getSZ(2);
  @$pb.TagNumber(3)
  set key($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get putUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set putUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPutUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearPutUrl() => $_clearField(4);
}

/// School-scoped paper assembly operation.
/// The `school` field is intentional here because paper generation is school-bound,
/// unlike global question-bank catalog CRUD/import/list requests.
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

class GeneratePaperResponse extends $pb.GeneratedMessage {
  factory GeneratePaperResponse({
    $core.Iterable<PaperQuestion>? questions,
  }) {
    final result = create();
    if (questions != null) result.questions.addAll(questions);
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
    ..pPM<PaperQuestion>(1, _omitFieldNames ? '' : 'questions',
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
  $pb.PbList<PaperQuestion> get questions => $_getList(0);
}

class PaperQuestion extends $pb.GeneratedMessage {
  factory PaperQuestion({
    $core.int? position,
    Question? question,
    $core.String? section,
  }) {
    final result = create();
    if (position != null) result.position = position;
    if (question != null) result.question = question;
    if (section != null) result.section = section;
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
    ..aI(1, _omitFieldNames ? '' : 'position')
    ..aOM<Question>(2, _omitFieldNames ? '' : 'question',
        subBuilder: Question.create)
    ..aOS(3, _omitFieldNames ? '' : 'section')
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
  $core.int get position => $_getIZ(0);
  @$pb.TagNumber(1)
  set position($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearPosition() => $_clearField(1);

  @$pb.TagNumber(2)
  Question get question => $_getN(1);
  @$pb.TagNumber(2)
  set question(Question value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasQuestion() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuestion() => $_clearField(2);
  @$pb.TagNumber(2)
  Question ensureQuestion() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get section => $_getSZ(2);
  @$pb.TagNumber(3)
  set section($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSection() => $_has(2);
  @$pb.TagNumber(3)
  void clearSection() => $_clearField(3);
}

/// School-scoped paper assembly operation.
/// The `school` field is intentional here because paper regeneration is school-bound,
/// unlike global question-bank catalog CRUD/import/list requests.
class RegenerateQuestionRequest extends $pb.GeneratedMessage {
  factory RegenerateQuestionRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
    $core.int? position,
    $core.int? topicId,
    $core.int? marks,
    $core.Iterable<$core.int>? excludeIds,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (position != null) result.position = position;
    if (topicId != null) result.topicId = topicId;
    if (marks != null) result.marks = marks;
    if (excludeIds != null) result.excludeIds.addAll(excludeIds);
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
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aI(7, _omitFieldNames ? '' : 'position')
    ..aI(8, _omitFieldNames ? '' : 'topicId')
    ..aI(9, _omitFieldNames ? '' : 'marks')
    ..p<$core.int>(10, _omitFieldNames ? '' : 'excludeIds', $pb.PbFieldType.K3)
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
  $core.int get stream => $_getIZ(5);
  @$pb.TagNumber(6)
  set stream($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStream() => $_has(5);
  @$pb.TagNumber(6)
  void clearStream() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get position => $_getIZ(6);
  @$pb.TagNumber(7)
  set position($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPosition() => $_has(6);
  @$pb.TagNumber(7)
  void clearPosition() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get topicId => $_getIZ(7);
  @$pb.TagNumber(8)
  set topicId($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTopicId() => $_has(7);
  @$pb.TagNumber(8)
  void clearTopicId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get marks => $_getIZ(8);
  @$pb.TagNumber(9)
  set marks($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMarks() => $_has(8);
  @$pb.TagNumber(9)
  void clearMarks() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$core.int> get excludeIds => $_getList(9);
}

class RegenerateQuestionResponse extends $pb.GeneratedMessage {
  factory RegenerateQuestionResponse({
    PaperQuestion? replacement,
  }) {
    final result = create();
    if (replacement != null) result.replacement = replacement;
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
    ..aOM<PaperQuestion>(1, _omitFieldNames ? '' : 'replacement',
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
  PaperQuestion get replacement => $_getN(0);
  @$pb.TagNumber(1)
  set replacement(PaperQuestion value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasReplacement() => $_has(0);
  @$pb.TagNumber(1)
  void clearReplacement() => $_clearField(1);
  @$pb.TagNumber(1)
  PaperQuestion ensureReplacement() => $_ensure(0);
}

class EditPaperQuestionRequest extends $pb.GeneratedMessage {
  factory EditPaperQuestionRequest({
    $core.int? questionId,
    $core.String? text,
    $core.int? marks,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterionInput>? rubric,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (text != null) result.text = text;
    if (marks != null) result.marks = marks;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
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
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aI(3, _omitFieldNames ? '' : 'marks')
    ..aOS(4, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterionInput>(5, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterionInput.create)
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
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

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
  $core.String get exampleAnswer => $_getSZ(3);
  @$pb.TagNumber(4)
  set exampleAnswer($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExampleAnswer() => $_has(3);
  @$pb.TagNumber(4)
  void clearExampleAnswer() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RubricCriterionInput> get rubric => $_getList(4);
}

class EditPaperQuestionResponse extends $pb.GeneratedMessage {
  factory EditPaperQuestionResponse({
    Question? question,
  }) {
    final result = create();
    if (question != null) result.question = question;
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
    ..aOM<Question>(1, _omitFieldNames ? '' : 'question',
        subBuilder: Question.create)
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
  Question get question => $_getN(0);
  @$pb.TagNumber(1)
  set question(Question value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => $_clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

/// School-scoped paper assembly operation.
/// The `school` field is intentional here because paper finalization is school-bound,
/// unlike global question-bank catalog CRUD/import/list requests.
class FinalizePaperRequest extends $pb.GeneratedMessage {
  factory FinalizePaperRequest({
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
}

class FinalizePaperResponse extends $pb.GeneratedMessage {
  factory FinalizePaperResponse({
    $core.String? pdfUrl,
    $fixnum.Int64? pdfExpiry,
    $core.String? markingSchemeUrl,
    $fixnum.Int64? markingSchemeExpiry,
  }) {
    final result = create();
    if (pdfUrl != null) result.pdfUrl = pdfUrl;
    if (pdfExpiry != null) result.pdfExpiry = pdfExpiry;
    if (markingSchemeUrl != null) result.markingSchemeUrl = markingSchemeUrl;
    if (markingSchemeExpiry != null)
      result.markingSchemeExpiry = markingSchemeExpiry;
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
    ..aOS(3, _omitFieldNames ? '' : 'markingSchemeUrl')
    ..aInt64(4, _omitFieldNames ? '' : 'markingSchemeExpiry')
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

  @$pb.TagNumber(3)
  $core.String get markingSchemeUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set markingSchemeUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarkingSchemeUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarkingSchemeUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get markingSchemeExpiry => $_getI64(3);
  @$pb.TagNumber(4)
  set markingSchemeExpiry($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMarkingSchemeExpiry() => $_has(3);
  @$pb.TagNumber(4)
  void clearMarkingSchemeExpiry() => $_clearField(4);
}

/// School-scoped paper retrieval operation.
/// The `school` field is intentional here because paper PDF access is school-bound,
/// unlike global question-bank catalog CRUD/import/list requests.
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

/// Returns the currently assembled question list for a paper, ordered by position.
/// Returns an empty list if no paper has been generated yet for this identity.
class GetPaperQuestionsRequest extends $pb.GeneratedMessage {
  factory GetPaperQuestionsRequest({
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

  GetPaperQuestionsRequest._();

  factory GetPaperQuestionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperQuestionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperQuestionsRequest',
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
  GetPaperQuestionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperQuestionsRequest copyWith(
          void Function(GetPaperQuestionsRequest) updates) =>
      super.copyWith((message) => updates(message as GetPaperQuestionsRequest))
          as GetPaperQuestionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperQuestionsRequest create() => GetPaperQuestionsRequest._();
  @$core.override
  GetPaperQuestionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperQuestionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperQuestionsRequest>(create);
  static GetPaperQuestionsRequest? _defaultInstance;

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

class GetPaperQuestionsResponse extends $pb.GeneratedMessage {
  factory GetPaperQuestionsResponse({
    $core.Iterable<PaperQuestion>? questions,
  }) {
    final result = create();
    if (questions != null) result.questions.addAll(questions);
    return result;
  }

  GetPaperQuestionsResponse._();

  factory GetPaperQuestionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPaperQuestionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPaperQuestionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..pPM<PaperQuestion>(1, _omitFieldNames ? '' : 'questions',
        subBuilder: PaperQuestion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperQuestionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPaperQuestionsResponse copyWith(
          void Function(GetPaperQuestionsResponse) updates) =>
      super.copyWith((message) => updates(message as GetPaperQuestionsResponse))
          as GetPaperQuestionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPaperQuestionsResponse create() => GetPaperQuestionsResponse._();
  @$core.override
  GetPaperQuestionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPaperQuestionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPaperQuestionsResponse>(create);
  static GetPaperQuestionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PaperQuestion> get questions => $_getList(0);
}

class SetPaperQuestionSectionRequest extends $pb.GeneratedMessage {
  factory SetPaperQuestionSectionRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
    $core.int? position,
    $core.String? section,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (position != null) result.position = position;
    if (section != null) result.section = section;
    return result;
  }

  SetPaperQuestionSectionRequest._();

  factory SetPaperQuestionSectionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetPaperQuestionSectionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPaperQuestionSectionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aI(7, _omitFieldNames ? '' : 'position')
    ..aOS(8, _omitFieldNames ? '' : 'section')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPaperQuestionSectionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPaperQuestionSectionRequest copyWith(
          void Function(SetPaperQuestionSectionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SetPaperQuestionSectionRequest))
          as SetPaperQuestionSectionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetPaperQuestionSectionRequest create() =>
      SetPaperQuestionSectionRequest._();
  @$core.override
  SetPaperQuestionSectionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetPaperQuestionSectionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPaperQuestionSectionRequest>(create);
  static SetPaperQuestionSectionRequest? _defaultInstance;

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
  $core.int get position => $_getIZ(6);
  @$pb.TagNumber(7)
  set position($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPosition() => $_has(6);
  @$pb.TagNumber(7)
  void clearPosition() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get section => $_getSZ(7);
  @$pb.TagNumber(8)
  set section($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSection() => $_has(7);
  @$pb.TagNumber(8)
  void clearSection() => $_clearField(8);
}

class SetPaperQuestionSectionResponse extends $pb.GeneratedMessage {
  factory SetPaperQuestionSectionResponse() => create();

  SetPaperQuestionSectionResponse._();

  factory SetPaperQuestionSectionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetPaperQuestionSectionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPaperQuestionSectionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPaperQuestionSectionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPaperQuestionSectionResponse copyWith(
          void Function(SetPaperQuestionSectionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SetPaperQuestionSectionResponse))
          as SetPaperQuestionSectionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetPaperQuestionSectionResponse create() =>
      SetPaperQuestionSectionResponse._();
  @$core.override
  SetPaperQuestionSectionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetPaperQuestionSectionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPaperQuestionSectionResponse>(
          create);
  static SetPaperQuestionSectionResponse? _defaultInstance;
}

/// Global catalog operation.
/// Lists questions from the shared system-wide question bank and is not school-scoped.
/// School-scoped fields belong only to paper assembly / grading / marking requests.
class ListQuestionsRequest extends $pb.GeneratedMessage {
  factory ListQuestionsRequest({
    $core.int? topicId,
    $core.int? minMarks,
    $core.int? maxMarks,
    $core.int? offset,
    $core.int? limit,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (minMarks != null) result.minMarks = minMarks;
    if (maxMarks != null) result.maxMarks = maxMarks;
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
    ..aI(2, _omitFieldNames ? '' : 'minMarks')
    ..aI(3, _omitFieldNames ? '' : 'maxMarks')
    ..aI(4, _omitFieldNames ? '' : 'offset')
    ..aI(5, _omitFieldNames ? '' : 'limit')
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
  $core.int get minMarks => $_getIZ(1);
  @$pb.TagNumber(2)
  set minMarks($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMinMarks() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinMarks() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxMarks => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxMarks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get offset => $_getIZ(3);
  @$pb.TagNumber(4)
  set offset($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOffset() => $_has(3);
  @$pb.TagNumber(4)
  void clearOffset() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get limit => $_getIZ(4);
  @$pb.TagNumber(5)
  set limit($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearLimit() => $_clearField(5);
}

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

/// Global catalog operation.
/// Fetches a question from the shared system-wide question bank and is not school-scoped.
/// School-scoped fields belong only to paper assembly / grading / marking requests.
class GetQuestionRequest extends $pb.GeneratedMessage {
  factory GetQuestionRequest({
    $core.int? questionId,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
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
    ..aI(1, _omitFieldNames ? '' : 'questionId')
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
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);
}

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
  set question(Question value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => $_clearField(1);
  @$pb.TagNumber(1)
  Question ensureQuestion() => $_ensure(0);
}

/// School-scoped grading/marking operation.
/// The `school` field is intentional here because question-grade lookup is school-bound,
/// unlike global question-bank catalog CRUD/import/list requests.
class GetQuestionGradesRequest extends $pb.GeneratedMessage {
  factory GetQuestionGradesRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? student,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (student != null) result.student = student;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
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
    ..aI(6, _omitFieldNames ? '' : 'grade')
    ..aI(7, _omitFieldNames ? '' : 'stream')
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

  @$pb.TagNumber(6)
  $core.int get grade => $_getIZ(5);
  @$pb.TagNumber(6)
  set grade($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGrade() => $_has(5);
  @$pb.TagNumber(6)
  void clearGrade() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get stream => $_getIZ(6);
  @$pb.TagNumber(7)
  set stream($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStream() => $_has(6);
  @$pb.TagNumber(7)
  void clearStream() => $_clearField(7);
}

class GetQuestionGradesResponse extends $pb.GeneratedMessage {
  factory GetQuestionGradesResponse({
    $core.Iterable<QuestionGradeDetail>? grades,
  }) {
    final result = create();
    if (grades != null) result.grades.addAll(grades);
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
    ..pPM<QuestionGradeDetail>(1, _omitFieldNames ? '' : 'grades',
        subBuilder: QuestionGradeDetail.create)
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
  $pb.PbList<QuestionGradeDetail> get grades => $_getList(0);
}

class QuestionGradeDetail extends $pb.GeneratedMessage {
  factory QuestionGradeDetail({
    $core.int? questionId,
    $core.String? questionText,
    $core.int? questionMarks,
    $core.double? score,
    $core.String? feedback,
    $core.Iterable<RubricCriterion>? rubric,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (questionText != null) result.questionText = questionText;
    if (questionMarks != null) result.questionMarks = questionMarks;
    if (score != null) result.score = score;
    if (feedback != null) result.feedback = feedback;
    if (rubric != null) result.rubric.addAll(rubric);
    return result;
  }

  QuestionGradeDetail._();

  factory QuestionGradeDetail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuestionGradeDetail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuestionGradeDetail',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..aOS(2, _omitFieldNames ? '' : 'questionText')
    ..aI(3, _omitFieldNames ? '' : 'questionMarks')
    ..aD(4, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..aOS(5, _omitFieldNames ? '' : 'feedback')
    ..pPM<RubricCriterion>(6, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionGradeDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionGradeDetail copyWith(void Function(QuestionGradeDetail) updates) =>
      super.copyWith((message) => updates(message as QuestionGradeDetail))
          as QuestionGradeDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuestionGradeDetail create() => QuestionGradeDetail._();
  @$core.override
  QuestionGradeDetail createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuestionGradeDetail getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuestionGradeDetail>(create);
  static QuestionGradeDetail? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get questionText => $_getSZ(1);
  @$pb.TagNumber(2)
  set questionText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuestionText() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuestionText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get questionMarks => $_getIZ(2);
  @$pb.TagNumber(3)
  set questionMarks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuestionMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuestionMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get score => $_getN(3);
  @$pb.TagNumber(4)
  set score($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasScore() => $_has(3);
  @$pb.TagNumber(4)
  void clearScore() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get feedback => $_getSZ(4);
  @$pb.TagNumber(5)
  set feedback($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFeedback() => $_has(4);
  @$pb.TagNumber(5)
  void clearFeedback() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<RubricCriterion> get rubric => $_getList(5);
}

/// School-scoped grading/marking operation.
/// The `school` field is intentional here because marking status is school-bound,
/// unlike global question-bank catalog CRUD/import/list requests.
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

class MarkingStatusResponse extends $pb.GeneratedMessage {
  factory MarkingStatusResponse({
    MarkingPhase? phase,
    $core.String? progress,
    $core.String? error,
    $fixnum.Int64? estimatedCompletion,
  }) {
    final result = create();
    if (phase != null) result.phase = phase;
    if (progress != null) result.progress = progress;
    if (error != null) result.error = error;
    if (estimatedCompletion != null)
      result.estimatedCompletion = estimatedCompletion;
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
    ..aE<MarkingPhase>(1, _omitFieldNames ? '' : 'phase',
        enumValues: MarkingPhase.values)
    ..aOS(2, _omitFieldNames ? '' : 'progress')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..aInt64(4, _omitFieldNames ? '' : 'estimatedCompletion')
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
  MarkingPhase get phase => $_getN(0);
  @$pb.TagNumber(1)
  set phase(MarkingPhase value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhase() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhase() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get progress => $_getSZ(1);
  @$pb.TagNumber(2)
  set progress($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get estimatedCompletion => $_getI64(3);
  @$pb.TagNumber(4)
  set estimatedCompletion($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEstimatedCompletion() => $_has(3);
  @$pb.TagNumber(4)
  void clearEstimatedCompletion() => $_clearField(4);
}

class ClearPaperQuestionsRequest extends $pb.GeneratedMessage {
  factory ClearPaperQuestionsRequest({
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

  ClearPaperQuestionsRequest._();

  factory ClearPaperQuestionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClearPaperQuestionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearPaperQuestionsRequest',
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
  ClearPaperQuestionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearPaperQuestionsRequest copyWith(
          void Function(ClearPaperQuestionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ClearPaperQuestionsRequest))
          as ClearPaperQuestionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearPaperQuestionsRequest create() => ClearPaperQuestionsRequest._();
  @$core.override
  ClearPaperQuestionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClearPaperQuestionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearPaperQuestionsRequest>(create);
  static ClearPaperQuestionsRequest? _defaultInstance;

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

class ClearPaperQuestionsResponse extends $pb.GeneratedMessage {
  factory ClearPaperQuestionsResponse({
    $core.int? questionsDeleted,
    $core.bool? pdfDeleted,
  }) {
    final result = create();
    if (questionsDeleted != null) result.questionsDeleted = questionsDeleted;
    if (pdfDeleted != null) result.pdfDeleted = pdfDeleted;
    return result;
  }

  ClearPaperQuestionsResponse._();

  factory ClearPaperQuestionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClearPaperQuestionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearPaperQuestionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'questionsDeleted')
    ..aOB(2, _omitFieldNames ? '' : 'pdfDeleted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearPaperQuestionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearPaperQuestionsResponse copyWith(
          void Function(ClearPaperQuestionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ClearPaperQuestionsResponse))
          as ClearPaperQuestionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearPaperQuestionsResponse create() =>
      ClearPaperQuestionsResponse._();
  @$core.override
  ClearPaperQuestionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClearPaperQuestionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearPaperQuestionsResponse>(create);
  static ClearPaperQuestionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get questionsDeleted => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionsDeleted($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionsDeleted() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionsDeleted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get pdfDeleted => $_getBF(1);
  @$pb.TagNumber(2)
  set pdfDeleted($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPdfDeleted() => $_has(1);
  @$pb.TagNumber(2)
  void clearPdfDeleted() => $_clearField(2);
}

class CopyPaperToStreamsRequest extends $pb.GeneratedMessage {
  factory CopyPaperToStreamsRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? sourceStream,
    $core.Iterable<$core.int>? targetStreams,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (sourceStream != null) result.sourceStream = sourceStream;
    if (targetStreams != null) result.targetStreams.addAll(targetStreams);
    return result;
  }

  CopyPaperToStreamsRequest._();

  factory CopyPaperToStreamsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CopyPaperToStreamsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CopyPaperToStreamsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'sourceStream')
    ..p<$core.int>(
        7, _omitFieldNames ? '' : 'targetStreams', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPaperToStreamsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPaperToStreamsRequest copyWith(
          void Function(CopyPaperToStreamsRequest) updates) =>
      super.copyWith((message) => updates(message as CopyPaperToStreamsRequest))
          as CopyPaperToStreamsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CopyPaperToStreamsRequest create() => CopyPaperToStreamsRequest._();
  @$core.override
  CopyPaperToStreamsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CopyPaperToStreamsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CopyPaperToStreamsRequest>(create);
  static CopyPaperToStreamsRequest? _defaultInstance;

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
  $core.int get sourceStream => $_getIZ(5);
  @$pb.TagNumber(6)
  set sourceStream($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSourceStream() => $_has(5);
  @$pb.TagNumber(6)
  void clearSourceStream() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.int> get targetStreams => $_getList(6);
}

class StreamCopyResult extends $pb.GeneratedMessage {
  factory StreamCopyResult({
    $core.int? stream,
    $core.bool? success,
    $core.String? pdfUrl,
    $fixnum.Int64? pdfExpiry,
    $core.String? markingSchemeUrl,
    $fixnum.Int64? markingSchemeExpiry,
    $core.String? error,
  }) {
    final result = create();
    if (stream != null) result.stream = stream;
    if (success != null) result.success = success;
    if (pdfUrl != null) result.pdfUrl = pdfUrl;
    if (pdfExpiry != null) result.pdfExpiry = pdfExpiry;
    if (markingSchemeUrl != null) result.markingSchemeUrl = markingSchemeUrl;
    if (markingSchemeExpiry != null)
      result.markingSchemeExpiry = markingSchemeExpiry;
    if (error != null) result.error = error;
    return result;
  }

  StreamCopyResult._();

  factory StreamCopyResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamCopyResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamCopyResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'stream')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..aOS(3, _omitFieldNames ? '' : 'pdfUrl')
    ..aInt64(4, _omitFieldNames ? '' : 'pdfExpiry')
    ..aOS(5, _omitFieldNames ? '' : 'markingSchemeUrl')
    ..aInt64(6, _omitFieldNames ? '' : 'markingSchemeExpiry')
    ..aOS(7, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamCopyResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamCopyResult copyWith(void Function(StreamCopyResult) updates) =>
      super.copyWith((message) => updates(message as StreamCopyResult))
          as StreamCopyResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamCopyResult create() => StreamCopyResult._();
  @$core.override
  StreamCopyResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamCopyResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamCopyResult>(create);
  static StreamCopyResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get stream => $_getIZ(0);
  @$pb.TagNumber(1)
  set stream($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStream() => $_has(0);
  @$pb.TagNumber(1)
  void clearStream() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get pdfUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set pdfUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPdfUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearPdfUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get pdfExpiry => $_getI64(3);
  @$pb.TagNumber(4)
  set pdfExpiry($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPdfExpiry() => $_has(3);
  @$pb.TagNumber(4)
  void clearPdfExpiry() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get markingSchemeUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set markingSchemeUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMarkingSchemeUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearMarkingSchemeUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get markingSchemeExpiry => $_getI64(5);
  @$pb.TagNumber(6)
  set markingSchemeExpiry($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMarkingSchemeExpiry() => $_has(5);
  @$pb.TagNumber(6)
  void clearMarkingSchemeExpiry() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get error => $_getSZ(6);
  @$pb.TagNumber(7)
  set error($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasError() => $_has(6);
  @$pb.TagNumber(7)
  void clearError() => $_clearField(7);
}

class CopyPaperToStreamsResponse extends $pb.GeneratedMessage {
  factory CopyPaperToStreamsResponse({
    $core.Iterable<StreamCopyResult>? results,
  }) {
    final result = create();
    if (results != null) result.results.addAll(results);
    return result;
  }

  CopyPaperToStreamsResponse._();

  factory CopyPaperToStreamsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CopyPaperToStreamsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CopyPaperToStreamsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..pPM<StreamCopyResult>(1, _omitFieldNames ? '' : 'results',
        subBuilder: StreamCopyResult.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPaperToStreamsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPaperToStreamsResponse copyWith(
          void Function(CopyPaperToStreamsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CopyPaperToStreamsResponse))
          as CopyPaperToStreamsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CopyPaperToStreamsResponse create() => CopyPaperToStreamsResponse._();
  @$core.override
  CopyPaperToStreamsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CopyPaperToStreamsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CopyPaperToStreamsResponse>(create);
  static CopyPaperToStreamsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StreamCopyResult> get results => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
