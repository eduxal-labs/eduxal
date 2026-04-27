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

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Question extends $pb.GeneratedMessage {
  factory Question({
    $core.int? id,
    $core.int? topicId,
    $core.String? body,
    $core.int? bodyFormat,
    $core.String? stimulus,
    $core.int? type,
    $core.int? difficulty,
    $core.int? cognitiveLevel,
    $core.int? marks,
    $core.int? maxMarks,
    $core.int? answerSpaceType,
    $core.int? answerLines,
    $core.int? answerBoxHeightMm,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterion>? rubric,
    $core.Iterable<QuestionPart>? parts,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (topicId != null) result.topicId = topicId;
    if (body != null) result.body = body;
    if (bodyFormat != null) result.bodyFormat = bodyFormat;
    if (stimulus != null) result.stimulus = stimulus;
    if (type != null) result.type = type;
    if (difficulty != null) result.difficulty = difficulty;
    if (cognitiveLevel != null) result.cognitiveLevel = cognitiveLevel;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (answerSpaceType != null) result.answerSpaceType = answerSpaceType;
    if (answerLines != null) result.answerLines = answerLines;
    if (answerBoxHeightMm != null) result.answerBoxHeightMm = answerBoxHeightMm;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (rubric != null) result.rubric.addAll(rubric);
    if (parts != null) result.parts.addAll(parts);
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
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..aI(4, _omitFieldNames ? '' : 'bodyFormat')
    ..aOS(5, _omitFieldNames ? '' : 'stimulus')
    ..aI(6, _omitFieldNames ? '' : 'type')
    ..aI(7, _omitFieldNames ? '' : 'difficulty')
    ..aI(8, _omitFieldNames ? '' : 'cognitiveLevel')
    ..aI(9, _omitFieldNames ? '' : 'marks')
    ..aI(10, _omitFieldNames ? '' : 'maxMarks')
    ..aI(11, _omitFieldNames ? '' : 'answerSpaceType')
    ..aI(12, _omitFieldNames ? '' : 'answerLines')
    ..aI(13, _omitFieldNames ? '' : 'answerBoxHeightMm')
    ..aOS(14, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterion>(15, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..pPM<QuestionPart>(16, _omitFieldNames ? '' : 'parts',
        subBuilder: QuestionPart.create)
    ..aInt64(17, _omitFieldNames ? '' : 'created')
    ..aInt64(18, _omitFieldNames ? '' : 'updated')
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
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get bodyFormat => $_getIZ(3);
  @$pb.TagNumber(4)
  set bodyFormat($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBodyFormat() => $_has(3);
  @$pb.TagNumber(4)
  void clearBodyFormat() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get stimulus => $_getSZ(4);
  @$pb.TagNumber(5)
  set stimulus($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStimulus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStimulus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get type => $_getIZ(5);
  @$pb.TagNumber(6)
  set type($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasType() => $_has(5);
  @$pb.TagNumber(6)
  void clearType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get difficulty => $_getIZ(6);
  @$pb.TagNumber(7)
  set difficulty($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDifficulty() => $_has(6);
  @$pb.TagNumber(7)
  void clearDifficulty() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get cognitiveLevel => $_getIZ(7);
  @$pb.TagNumber(8)
  set cognitiveLevel($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCognitiveLevel() => $_has(7);
  @$pb.TagNumber(8)
  void clearCognitiveLevel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get marks => $_getIZ(8);
  @$pb.TagNumber(9)
  set marks($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMarks() => $_has(8);
  @$pb.TagNumber(9)
  void clearMarks() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get maxMarks => $_getIZ(9);
  @$pb.TagNumber(10)
  set maxMarks($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMaxMarks() => $_has(9);
  @$pb.TagNumber(10)
  void clearMaxMarks() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get answerSpaceType => $_getIZ(10);
  @$pb.TagNumber(11)
  set answerSpaceType($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAnswerSpaceType() => $_has(10);
  @$pb.TagNumber(11)
  void clearAnswerSpaceType() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get answerLines => $_getIZ(11);
  @$pb.TagNumber(12)
  set answerLines($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAnswerLines() => $_has(11);
  @$pb.TagNumber(12)
  void clearAnswerLines() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get answerBoxHeightMm => $_getIZ(12);
  @$pb.TagNumber(13)
  set answerBoxHeightMm($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAnswerBoxHeightMm() => $_has(12);
  @$pb.TagNumber(13)
  void clearAnswerBoxHeightMm() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get exampleAnswer => $_getSZ(13);
  @$pb.TagNumber(14)
  set exampleAnswer($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasExampleAnswer() => $_has(13);
  @$pb.TagNumber(14)
  void clearExampleAnswer() => $_clearField(14);

  @$pb.TagNumber(15)
  $pb.PbList<RubricCriterion> get rubric => $_getList(14);

  @$pb.TagNumber(16)
  $pb.PbList<QuestionPart> get parts => $_getList(15);

  @$pb.TagNumber(17)
  $fixnum.Int64 get created => $_getI64(16);
  @$pb.TagNumber(17)
  set created($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasCreated() => $_has(16);
  @$pb.TagNumber(17)
  void clearCreated() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get updated => $_getI64(17);
  @$pb.TagNumber(18)
  set updated($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasUpdated() => $_has(17);
  @$pb.TagNumber(18)
  void clearUpdated() => $_clearField(18);
}

class RubricCriterion extends $pb.GeneratedMessage {
  factory RubricCriterion({
    $core.int? position,
    $core.String? criterion,
    $core.int? marks,
    $core.int? maxMarks,
    $core.bool? required,
  }) {
    final result = create();
    if (position != null) result.position = position;
    if (criterion != null) result.criterion = criterion;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (required != null) result.required = required;
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
    ..aI(4, _omitFieldNames ? '' : 'maxMarks')
    ..aOB(5, _omitFieldNames ? '' : 'required')
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

  @$pb.TagNumber(4)
  $core.int get maxMarks => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxMarks($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxMarks() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxMarks() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get required => $_getBF(4);
  @$pb.TagNumber(5)
  set required($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRequired() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequired() => $_clearField(5);
}

class QuestionPart extends $pb.GeneratedMessage {
  factory QuestionPart({
    $core.int? position,
    $core.String? label,
    $core.String? body,
    $core.int? bodyFormat,
    $core.int? marks,
    $core.int? maxMarks,
    $core.int? answerSpaceType,
    $core.int? answerLines,
    $core.int? answerBoxHeightMm,
    $core.String? exampleAnswer,
    $core.String? stimulus,
    $core.Iterable<RubricCriterion>? rubric,
  }) {
    final result = create();
    if (position != null) result.position = position;
    if (label != null) result.label = label;
    if (body != null) result.body = body;
    if (bodyFormat != null) result.bodyFormat = bodyFormat;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (answerSpaceType != null) result.answerSpaceType = answerSpaceType;
    if (answerLines != null) result.answerLines = answerLines;
    if (answerBoxHeightMm != null) result.answerBoxHeightMm = answerBoxHeightMm;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (stimulus != null) result.stimulus = stimulus;
    if (rubric != null) result.rubric.addAll(rubric);
    return result;
  }

  QuestionPart._();

  factory QuestionPart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuestionPart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuestionPart',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'position')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..aI(4, _omitFieldNames ? '' : 'bodyFormat')
    ..aI(5, _omitFieldNames ? '' : 'marks')
    ..aI(6, _omitFieldNames ? '' : 'maxMarks')
    ..aI(7, _omitFieldNames ? '' : 'answerSpaceType')
    ..aI(8, _omitFieldNames ? '' : 'answerLines')
    ..aI(9, _omitFieldNames ? '' : 'answerBoxHeightMm')
    ..aOS(10, _omitFieldNames ? '' : 'exampleAnswer')
    ..aOS(11, _omitFieldNames ? '' : 'stimulus')
    ..pPM<RubricCriterion>(12, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionPart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionPart copyWith(void Function(QuestionPart) updates) =>
      super.copyWith((message) => updates(message as QuestionPart))
          as QuestionPart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuestionPart create() => QuestionPart._();
  @$core.override
  QuestionPart createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuestionPart getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuestionPart>(create);
  static QuestionPart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get position => $_getIZ(0);
  @$pb.TagNumber(1)
  set position($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearPosition() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get bodyFormat => $_getIZ(3);
  @$pb.TagNumber(4)
  set bodyFormat($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBodyFormat() => $_has(3);
  @$pb.TagNumber(4)
  void clearBodyFormat() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get marks => $_getIZ(4);
  @$pb.TagNumber(5)
  set marks($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMarks() => $_has(4);
  @$pb.TagNumber(5)
  void clearMarks() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get maxMarks => $_getIZ(5);
  @$pb.TagNumber(6)
  set maxMarks($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMaxMarks() => $_has(5);
  @$pb.TagNumber(6)
  void clearMaxMarks() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get answerSpaceType => $_getIZ(6);
  @$pb.TagNumber(7)
  set answerSpaceType($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAnswerSpaceType() => $_has(6);
  @$pb.TagNumber(7)
  void clearAnswerSpaceType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get answerLines => $_getIZ(7);
  @$pb.TagNumber(8)
  set answerLines($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAnswerLines() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnswerLines() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get answerBoxHeightMm => $_getIZ(8);
  @$pb.TagNumber(9)
  set answerBoxHeightMm($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAnswerBoxHeightMm() => $_has(8);
  @$pb.TagNumber(9)
  void clearAnswerBoxHeightMm() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get exampleAnswer => $_getSZ(9);
  @$pb.TagNumber(10)
  set exampleAnswer($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExampleAnswer() => $_has(9);
  @$pb.TagNumber(10)
  void clearExampleAnswer() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get stimulus => $_getSZ(10);
  @$pb.TagNumber(11)
  set stimulus($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStimulus() => $_has(10);
  @$pb.TagNumber(11)
  void clearStimulus() => $_clearField(11);

  @$pb.TagNumber(12)
  $pb.PbList<RubricCriterion> get rubric => $_getList(11);
}

class RubricCriterionInput extends $pb.GeneratedMessage {
  factory RubricCriterionInput({
    $core.String? criterion,
    $core.int? marks,
    $core.int? maxMarks,
    $core.bool? required,
  }) {
    final result = create();
    if (criterion != null) result.criterion = criterion;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (required != null) result.required = required;
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
    ..aI(3, _omitFieldNames ? '' : 'maxMarks')
    ..aOB(4, _omitFieldNames ? '' : 'required')
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

  @$pb.TagNumber(3)
  $core.int get maxMarks => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxMarks($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxMarks() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxMarks() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get required => $_getBF(3);
  @$pb.TagNumber(4)
  set required($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRequired() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequired() => $_clearField(4);
}

class QuestionPartInput extends $pb.GeneratedMessage {
  factory QuestionPartInput({
    $core.String? label,
    $core.String? body,
    $core.int? bodyFormat,
    $core.int? marks,
    $core.int? maxMarks,
    $core.int? answerSpaceType,
    $core.int? answerLines,
    $core.int? answerBoxHeightMm,
    $core.String? exampleAnswer,
    $core.String? stimulus,
    $core.Iterable<RubricCriterionInput>? rubric,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (body != null) result.body = body;
    if (bodyFormat != null) result.bodyFormat = bodyFormat;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (answerSpaceType != null) result.answerSpaceType = answerSpaceType;
    if (answerLines != null) result.answerLines = answerLines;
    if (answerBoxHeightMm != null) result.answerBoxHeightMm = answerBoxHeightMm;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (stimulus != null) result.stimulus = stimulus;
    if (rubric != null) result.rubric.addAll(rubric);
    return result;
  }

  QuestionPartInput._();

  factory QuestionPartInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuestionPartInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuestionPartInput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'question_bank'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..aI(3, _omitFieldNames ? '' : 'bodyFormat')
    ..aI(4, _omitFieldNames ? '' : 'marks')
    ..aI(5, _omitFieldNames ? '' : 'maxMarks')
    ..aI(6, _omitFieldNames ? '' : 'answerSpaceType')
    ..aI(7, _omitFieldNames ? '' : 'answerLines')
    ..aI(8, _omitFieldNames ? '' : 'answerBoxHeightMm')
    ..aOS(9, _omitFieldNames ? '' : 'exampleAnswer')
    ..aOS(10, _omitFieldNames ? '' : 'stimulus')
    ..pPM<RubricCriterionInput>(11, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterionInput.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionPartInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuestionPartInput copyWith(void Function(QuestionPartInput) updates) =>
      super.copyWith((message) => updates(message as QuestionPartInput))
          as QuestionPartInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuestionPartInput create() => QuestionPartInput._();
  @$core.override
  QuestionPartInput createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuestionPartInput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuestionPartInput>(create);
  static QuestionPartInput? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get bodyFormat => $_getIZ(2);
  @$pb.TagNumber(3)
  set bodyFormat($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBodyFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearBodyFormat() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get marks => $_getIZ(3);
  @$pb.TagNumber(4)
  set marks($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMarks() => $_has(3);
  @$pb.TagNumber(4)
  void clearMarks() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get maxMarks => $_getIZ(4);
  @$pb.TagNumber(5)
  set maxMarks($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMaxMarks() => $_has(4);
  @$pb.TagNumber(5)
  void clearMaxMarks() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get answerSpaceType => $_getIZ(5);
  @$pb.TagNumber(6)
  set answerSpaceType($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAnswerSpaceType() => $_has(5);
  @$pb.TagNumber(6)
  void clearAnswerSpaceType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get answerLines => $_getIZ(6);
  @$pb.TagNumber(7)
  set answerLines($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAnswerLines() => $_has(6);
  @$pb.TagNumber(7)
  void clearAnswerLines() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get answerBoxHeightMm => $_getIZ(7);
  @$pb.TagNumber(8)
  set answerBoxHeightMm($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAnswerBoxHeightMm() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnswerBoxHeightMm() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get exampleAnswer => $_getSZ(8);
  @$pb.TagNumber(9)
  set exampleAnswer($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasExampleAnswer() => $_has(8);
  @$pb.TagNumber(9)
  void clearExampleAnswer() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get stimulus => $_getSZ(9);
  @$pb.TagNumber(10)
  set stimulus($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStimulus() => $_has(9);
  @$pb.TagNumber(10)
  void clearStimulus() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<RubricCriterionInput> get rubric => $_getList(10);
}

class CreateQuestionRequest extends $pb.GeneratedMessage {
  factory CreateQuestionRequest({
    $core.int? topicId,
    $core.String? body,
    $core.int? bodyFormat,
    $core.String? stimulus,
    $core.int? type,
    $core.int? difficulty,
    $core.int? cognitiveLevel,
    $core.int? marks,
    $core.int? maxMarks,
    $core.int? answerSpaceType,
    $core.int? answerLines,
    $core.int? answerBoxHeightMm,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterionInput>? rubric,
    $core.Iterable<QuestionPartInput>? parts,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (body != null) result.body = body;
    if (bodyFormat != null) result.bodyFormat = bodyFormat;
    if (stimulus != null) result.stimulus = stimulus;
    if (type != null) result.type = type;
    if (difficulty != null) result.difficulty = difficulty;
    if (cognitiveLevel != null) result.cognitiveLevel = cognitiveLevel;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (answerSpaceType != null) result.answerSpaceType = answerSpaceType;
    if (answerLines != null) result.answerLines = answerLines;
    if (answerBoxHeightMm != null) result.answerBoxHeightMm = answerBoxHeightMm;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (rubric != null) result.rubric.addAll(rubric);
    if (parts != null) result.parts.addAll(parts);
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
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..aI(3, _omitFieldNames ? '' : 'bodyFormat')
    ..aOS(4, _omitFieldNames ? '' : 'stimulus')
    ..aI(5, _omitFieldNames ? '' : 'type')
    ..aI(6, _omitFieldNames ? '' : 'difficulty')
    ..aI(7, _omitFieldNames ? '' : 'cognitiveLevel')
    ..aI(8, _omitFieldNames ? '' : 'marks')
    ..aI(9, _omitFieldNames ? '' : 'maxMarks')
    ..aI(10, _omitFieldNames ? '' : 'answerSpaceType')
    ..aI(11, _omitFieldNames ? '' : 'answerLines')
    ..aI(12, _omitFieldNames ? '' : 'answerBoxHeightMm')
    ..aOS(13, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterionInput>(14, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterionInput.create)
    ..pPM<QuestionPartInput>(15, _omitFieldNames ? '' : 'parts',
        subBuilder: QuestionPartInput.create)
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
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get bodyFormat => $_getIZ(2);
  @$pb.TagNumber(3)
  set bodyFormat($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBodyFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearBodyFormat() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get stimulus => $_getSZ(3);
  @$pb.TagNumber(4)
  set stimulus($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStimulus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStimulus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get type => $_getIZ(4);
  @$pb.TagNumber(5)
  set type($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get difficulty => $_getIZ(5);
  @$pb.TagNumber(6)
  set difficulty($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDifficulty() => $_has(5);
  @$pb.TagNumber(6)
  void clearDifficulty() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get cognitiveLevel => $_getIZ(6);
  @$pb.TagNumber(7)
  set cognitiveLevel($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCognitiveLevel() => $_has(6);
  @$pb.TagNumber(7)
  void clearCognitiveLevel() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get marks => $_getIZ(7);
  @$pb.TagNumber(8)
  set marks($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMarks() => $_has(7);
  @$pb.TagNumber(8)
  void clearMarks() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get maxMarks => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxMarks($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxMarks() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxMarks() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get answerSpaceType => $_getIZ(9);
  @$pb.TagNumber(10)
  set answerSpaceType($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAnswerSpaceType() => $_has(9);
  @$pb.TagNumber(10)
  void clearAnswerSpaceType() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get answerLines => $_getIZ(10);
  @$pb.TagNumber(11)
  set answerLines($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAnswerLines() => $_has(10);
  @$pb.TagNumber(11)
  void clearAnswerLines() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get answerBoxHeightMm => $_getIZ(11);
  @$pb.TagNumber(12)
  set answerBoxHeightMm($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAnswerBoxHeightMm() => $_has(11);
  @$pb.TagNumber(12)
  void clearAnswerBoxHeightMm() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get exampleAnswer => $_getSZ(12);
  @$pb.TagNumber(13)
  set exampleAnswer($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasExampleAnswer() => $_has(12);
  @$pb.TagNumber(13)
  void clearExampleAnswer() => $_clearField(13);

  @$pb.TagNumber(14)
  $pb.PbList<RubricCriterionInput> get rubric => $_getList(13);

  @$pb.TagNumber(15)
  $pb.PbList<QuestionPartInput> get parts => $_getList(14);
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

class ListQuestionsRequest extends $pb.GeneratedMessage {
  factory ListQuestionsRequest({
    $core.int? topicId,
    $core.int? page,
    $core.int? pageSize,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (page != null) result.page = page;
    if (pageSize != null) result.pageSize = pageSize;
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
    ..aI(2, _omitFieldNames ? '' : 'page')
    ..aI(3, _omitFieldNames ? '' : 'pageSize')
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
  $core.int get page => $_getIZ(1);
  @$pb.TagNumber(2)
  set page($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get pageSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageSize($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageSize() => $_clearField(3);
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

class UpdateQuestionRequest extends $pb.GeneratedMessage {
  factory UpdateQuestionRequest({
    $core.int? questionId,
    $core.int? topicId,
    $core.String? body,
    $core.int? bodyFormat,
    $core.String? stimulus,
    $core.int? type,
    $core.int? difficulty,
    $core.int? cognitiveLevel,
    $core.int? marks,
    $core.int? maxMarks,
    $core.int? answerSpaceType,
    $core.int? answerLines,
    $core.int? answerBoxHeightMm,
    $core.String? exampleAnswer,
    $core.Iterable<RubricCriterionInput>? rubric,
    $core.Iterable<QuestionPartInput>? parts,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (topicId != null) result.topicId = topicId;
    if (body != null) result.body = body;
    if (bodyFormat != null) result.bodyFormat = bodyFormat;
    if (stimulus != null) result.stimulus = stimulus;
    if (type != null) result.type = type;
    if (difficulty != null) result.difficulty = difficulty;
    if (cognitiveLevel != null) result.cognitiveLevel = cognitiveLevel;
    if (marks != null) result.marks = marks;
    if (maxMarks != null) result.maxMarks = maxMarks;
    if (answerSpaceType != null) result.answerSpaceType = answerSpaceType;
    if (answerLines != null) result.answerLines = answerLines;
    if (answerBoxHeightMm != null) result.answerBoxHeightMm = answerBoxHeightMm;
    if (exampleAnswer != null) result.exampleAnswer = exampleAnswer;
    if (rubric != null) result.rubric.addAll(rubric);
    if (parts != null) result.parts.addAll(parts);
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
    ..aI(2, _omitFieldNames ? '' : 'topicId')
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..aI(4, _omitFieldNames ? '' : 'bodyFormat')
    ..aOS(5, _omitFieldNames ? '' : 'stimulus')
    ..aI(6, _omitFieldNames ? '' : 'type')
    ..aI(7, _omitFieldNames ? '' : 'difficulty')
    ..aI(8, _omitFieldNames ? '' : 'cognitiveLevel')
    ..aI(9, _omitFieldNames ? '' : 'marks')
    ..aI(10, _omitFieldNames ? '' : 'maxMarks')
    ..aI(11, _omitFieldNames ? '' : 'answerSpaceType')
    ..aI(12, _omitFieldNames ? '' : 'answerLines')
    ..aI(13, _omitFieldNames ? '' : 'answerBoxHeightMm')
    ..aOS(14, _omitFieldNames ? '' : 'exampleAnswer')
    ..pPM<RubricCriterionInput>(15, _omitFieldNames ? '' : 'rubric',
        subBuilder: RubricCriterionInput.create)
    ..pPM<QuestionPartInput>(16, _omitFieldNames ? '' : 'parts',
        subBuilder: QuestionPartInput.create)
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
  $core.int get topicId => $_getIZ(1);
  @$pb.TagNumber(2)
  set topicId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTopicId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTopicId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get bodyFormat => $_getIZ(3);
  @$pb.TagNumber(4)
  set bodyFormat($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBodyFormat() => $_has(3);
  @$pb.TagNumber(4)
  void clearBodyFormat() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get stimulus => $_getSZ(4);
  @$pb.TagNumber(5)
  set stimulus($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStimulus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStimulus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get type => $_getIZ(5);
  @$pb.TagNumber(6)
  set type($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasType() => $_has(5);
  @$pb.TagNumber(6)
  void clearType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get difficulty => $_getIZ(6);
  @$pb.TagNumber(7)
  set difficulty($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDifficulty() => $_has(6);
  @$pb.TagNumber(7)
  void clearDifficulty() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get cognitiveLevel => $_getIZ(7);
  @$pb.TagNumber(8)
  set cognitiveLevel($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCognitiveLevel() => $_has(7);
  @$pb.TagNumber(8)
  void clearCognitiveLevel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get marks => $_getIZ(8);
  @$pb.TagNumber(9)
  set marks($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMarks() => $_has(8);
  @$pb.TagNumber(9)
  void clearMarks() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get maxMarks => $_getIZ(9);
  @$pb.TagNumber(10)
  set maxMarks($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMaxMarks() => $_has(9);
  @$pb.TagNumber(10)
  void clearMaxMarks() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get answerSpaceType => $_getIZ(10);
  @$pb.TagNumber(11)
  set answerSpaceType($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAnswerSpaceType() => $_has(10);
  @$pb.TagNumber(11)
  void clearAnswerSpaceType() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get answerLines => $_getIZ(11);
  @$pb.TagNumber(12)
  set answerLines($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAnswerLines() => $_has(11);
  @$pb.TagNumber(12)
  void clearAnswerLines() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get answerBoxHeightMm => $_getIZ(12);
  @$pb.TagNumber(13)
  set answerBoxHeightMm($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAnswerBoxHeightMm() => $_has(12);
  @$pb.TagNumber(13)
  void clearAnswerBoxHeightMm() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get exampleAnswer => $_getSZ(13);
  @$pb.TagNumber(14)
  set exampleAnswer($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasExampleAnswer() => $_has(13);
  @$pb.TagNumber(14)
  void clearExampleAnswer() => $_clearField(14);

  @$pb.TagNumber(15)
  $pb.PbList<RubricCriterionInput> get rubric => $_getList(14);

  @$pb.TagNumber(16)
  $pb.PbList<QuestionPartInput> get parts => $_getList(15);
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

class BulkImportRequest extends $pb.GeneratedMessage {
  factory BulkImportRequest({
    $core.Iterable<CreateQuestionRequest>? questions,
  }) {
    final result = create();
    if (questions != null) result.questions.addAll(questions);
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
    ..pPM<CreateQuestionRequest>(1, _omitFieldNames ? '' : 'questions',
        subBuilder: CreateQuestionRequest.create)
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
  $pb.PbList<CreateQuestionRequest> get questions => $_getList(0);
}

class BulkImportResponse extends $pb.GeneratedMessage {
  factory BulkImportResponse({
    $core.int? created,
    $core.int? skipped,
  }) {
    final result = create();
    if (created != null) result.created = created;
    if (skipped != null) result.skipped = skipped;
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
    ..aI(1, _omitFieldNames ? '' : 'created')
    ..aI(2, _omitFieldNames ? '' : 'skipped')
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
  $core.int get created => $_getIZ(0);
  @$pb.TagNumber(1)
  set created($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCreated() => $_has(0);
  @$pb.TagNumber(1)
  void clearCreated() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get skipped => $_getIZ(1);
  @$pb.TagNumber(2)
  set skipped($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkipped() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkipped() => $_clearField(2);
}

class ImageUploadUrlsRequest extends $pb.GeneratedMessage {
  factory ImageUploadUrlsRequest({
    $core.int? questionId,
    $core.int? count,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (count != null) result.count = count;
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
    ..aI(2, _omitFieldNames ? '' : 'count')
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
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class ImageUploadUrlsResponse extends $pb.GeneratedMessage {
  factory ImageUploadUrlsResponse({
    $core.Iterable<$core.String>? urls,
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
    ..pPS(1, _omitFieldNames ? '' : 'urls')
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
  $pb.PbList<$core.String> get urls => $_getList(0);
}

class TopicAllocation extends $pb.GeneratedMessage {
  factory TopicAllocation({
    $core.int? topicId,
    $core.int? totalMarks,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (totalMarks != null) result.totalMarks = totalMarks;
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
    ..aI(2, _omitFieldNames ? '' : 'totalMarks')
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
  $core.int get totalMarks => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalMarks($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalMarks() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalMarks() => $_clearField(2);
}

class GeneratePaperRequest extends $pb.GeneratedMessage {
  factory GeneratePaperRequest({
    $core.String? paperId,
    $core.int? totalMarks,
    $core.Iterable<TopicAllocation>? topicAllocations,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'totalMarks')
    ..pPM<TopicAllocation>(3, _omitFieldNames ? '' : 'topicAllocations',
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
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalMarks => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalMarks($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalMarks() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalMarks() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<TopicAllocation> get topicAllocations => $_getList(2);
}

class GeneratePaperResponse extends $pb.GeneratedMessage {
  factory GeneratePaperResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
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
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
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
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class GetPaperQuestionsRequest extends $pb.GeneratedMessage {
  factory GetPaperQuestionsRequest({
    $core.String? paperId,
    $core.int? student,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (student != null) result.student = student;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'student')
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

class GetPaperQuestionsResponse extends $pb.GeneratedMessage {
  factory GetPaperQuestionsResponse({
    $core.Iterable<Question>? questions,
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
    ..pPM<Question>(1, _omitFieldNames ? '' : 'questions',
        subBuilder: Question.create)
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
  $pb.PbList<Question> get questions => $_getList(0);
}

class RegenerateQuestionRequest extends $pb.GeneratedMessage {
  factory RegenerateQuestionRequest({
    $core.String? paperId,
    $core.int? student,
    $core.int? position,
    $core.int? topicId,
    $core.int? marks,
    $core.Iterable<$core.int>? excludeIds,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (student != null) result.student = student;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'student')
    ..aI(3, _omitFieldNames ? '' : 'position')
    ..aI(4, _omitFieldNames ? '' : 'topicId')
    ..aI(5, _omitFieldNames ? '' : 'marks')
    ..p<$core.int>(6, _omitFieldNames ? '' : 'excludeIds', $pb.PbFieldType.K3)
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

  @$pb.TagNumber(3)
  $core.int get position => $_getIZ(2);
  @$pb.TagNumber(3)
  set position($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosition() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get topicId => $_getIZ(3);
  @$pb.TagNumber(4)
  set topicId($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTopicId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTopicId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get marks => $_getIZ(4);
  @$pb.TagNumber(5)
  set marks($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMarks() => $_has(4);
  @$pb.TagNumber(5)
  void clearMarks() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.int> get excludeIds => $_getList(5);
}

class RegenerateQuestionResponse extends $pb.GeneratedMessage {
  factory RegenerateQuestionResponse({
    Question? question,
  }) {
    final result = create();
    if (question != null) result.question = question;
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
    ..aOM<Question>(1, _omitFieldNames ? '' : 'question',
        subBuilder: Question.create)
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

class ClearPaperQuestionsRequest extends $pb.GeneratedMessage {
  factory ClearPaperQuestionsRequest({
    $core.String? paperId,
    $core.int? student,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (student != null) result.student = student;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'student')
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

class ClearPaperQuestionsResponse extends $pb.GeneratedMessage {
  factory ClearPaperQuestionsResponse() => create();

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
}

class FinalizePaperRequest extends $pb.GeneratedMessage {
  factory FinalizePaperRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
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
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class FinalizePaperResponse extends $pb.GeneratedMessage {
  factory FinalizePaperResponse({
    $core.String? pdfKey,
    $core.String? msKey,
  }) {
    final result = create();
    if (pdfKey != null) result.pdfKey = pdfKey;
    if (msKey != null) result.msKey = msKey;
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
    ..aOS(1, _omitFieldNames ? '' : 'pdfKey')
    ..aOS(2, _omitFieldNames ? '' : 'msKey')
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
  $core.String get pdfKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set pdfKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPdfKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPdfKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set msKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsKey() => $_clearField(2);
}

class MarkingStatusRequest extends $pb.GeneratedMessage {
  factory MarkingStatusRequest({
    $core.String? paperId,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
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
  $core.String get paperId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paperId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaperId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaperId() => $_clearField(1);
}

class MarkingStatusResponse extends $pb.GeneratedMessage {
  factory MarkingStatusResponse({
    $core.int? phase,
    $core.String? progress,
    $core.String? error,
    $core.int? totalStudents,
    $core.int? markedStudents,
  }) {
    final result = create();
    if (phase != null) result.phase = phase;
    if (progress != null) result.progress = progress;
    if (error != null) result.error = error;
    if (totalStudents != null) result.totalStudents = totalStudents;
    if (markedStudents != null) result.markedStudents = markedStudents;
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
    ..aI(1, _omitFieldNames ? '' : 'phase')
    ..aOS(2, _omitFieldNames ? '' : 'progress')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..aI(4, _omitFieldNames ? '' : 'totalStudents')
    ..aI(5, _omitFieldNames ? '' : 'markedStudents')
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
  $core.int get phase => $_getIZ(0);
  @$pb.TagNumber(1)
  set phase($core.int value) => $_setSignedInt32(0, value);
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
  $core.int get totalStudents => $_getIZ(3);
  @$pb.TagNumber(4)
  set totalStudents($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalStudents() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalStudents() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get markedStudents => $_getIZ(4);
  @$pb.TagNumber(5)
  set markedStudents($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMarkedStudents() => $_has(4);
  @$pb.TagNumber(5)
  void clearMarkedStudents() => $_clearField(5);
}

class QuestionGrade extends $pb.GeneratedMessage {
  factory QuestionGrade({
    $core.int? questionId,
    $core.double? score,
    $core.String? feedback,
  }) {
    final result = create();
    if (questionId != null) result.questionId = questionId;
    if (score != null) result.score = score;
    if (feedback != null) result.feedback = feedback;
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
    ..aI(1, _omitFieldNames ? '' : 'questionId')
    ..aD(2, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..aOS(3, _omitFieldNames ? '' : 'feedback')
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
  $core.int get questionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set questionId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get score => $_getN(1);
  @$pb.TagNumber(2)
  set score($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScore() => $_has(1);
  @$pb.TagNumber(2)
  void clearScore() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get feedback => $_getSZ(2);
  @$pb.TagNumber(3)
  set feedback($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFeedback() => $_has(2);
  @$pb.TagNumber(3)
  void clearFeedback() => $_clearField(3);
}

class GetQuestionGradesRequest extends $pb.GeneratedMessage {
  factory GetQuestionGradesRequest({
    $core.String? paperId,
    $core.int? student,
  }) {
    final result = create();
    if (paperId != null) result.paperId = paperId;
    if (student != null) result.student = student;
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
    ..aOS(1, _omitFieldNames ? '' : 'paperId')
    ..aI(2, _omitFieldNames ? '' : 'student')
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

class GetQuestionGradesResponse extends $pb.GeneratedMessage {
  factory GetQuestionGradesResponse({
    $core.Iterable<QuestionGrade>? grades,
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
    ..pPM<QuestionGrade>(1, _omitFieldNames ? '' : 'grades',
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
  $pb.PbList<QuestionGrade> get grades => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
