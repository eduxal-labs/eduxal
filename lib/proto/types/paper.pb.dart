// This is a generated file - do not edit.
//
// Generated from types/paper.proto.

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

class Paper extends $pb.GeneratedMessage {
  factory Paper({
    $core.String? id,
    $core.String? school,
    $core.String? event,
    $core.int? subject,
    $core.int? grade,
    $core.int? stream,
    $core.int? type,
    $core.String? teacher,
    $core.String? name,
    $core.int? totalMarks,
    $core.int? durationMinutes,
    $core.int? date,
    $core.int? status,
    $core.String? pdfKey,
    $core.String? msKey,
    $core.int? generationMode,
    $core.String? instructions,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (event != null) result.event = event;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (type != null) result.type = type;
    if (teacher != null) result.teacher = teacher;
    if (name != null) result.name = name;
    if (totalMarks != null) result.totalMarks = totalMarks;
    if (durationMinutes != null) result.durationMinutes = durationMinutes;
    if (date != null) result.date = date;
    if (status != null) result.status = status;
    if (pdfKey != null) result.pdfKey = pdfKey;
    if (msKey != null) result.msKey = msKey;
    if (generationMode != null) result.generationMode = generationMode;
    if (instructions != null) result.instructions = instructions;
    if (created != null) result.created = created;
    if (updated != null) result.updated = updated;
    return result;
  }

  Paper._();

  factory Paper.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Paper.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Paper',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'paper'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aOS(3, _omitFieldNames ? '' : 'event')
    ..aI(4, _omitFieldNames ? '' : 'subject')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aI(7, _omitFieldNames ? '' : 'type')
    ..aOS(8, _omitFieldNames ? '' : 'teacher')
    ..aOS(9, _omitFieldNames ? '' : 'name')
    ..aI(10, _omitFieldNames ? '' : 'totalMarks')
    ..aI(11, _omitFieldNames ? '' : 'durationMinutes')
    ..aI(12, _omitFieldNames ? '' : 'date')
    ..aI(13, _omitFieldNames ? '' : 'status')
    ..aOS(14, _omitFieldNames ? '' : 'pdfKey')
    ..aOS(15, _omitFieldNames ? '' : 'msKey')
    ..aI(16, _omitFieldNames ? '' : 'generationMode')
    ..aOS(17, _omitFieldNames ? '' : 'instructions')
    ..aInt64(18, _omitFieldNames ? '' : 'created')
    ..aInt64(19, _omitFieldNames ? '' : 'updated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Paper clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Paper copyWith(void Function(Paper) updates) =>
      super.copyWith((message) => updates(message as Paper)) as Paper;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Paper create() => Paper._();
  @$core.override
  Paper createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Paper getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Paper>(create);
  static Paper? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get school => $_getSZ(1);
  @$pb.TagNumber(2)
  set school($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchool() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchool() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get event => $_getSZ(2);
  @$pb.TagNumber(3)
  set event($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEvent() => $_has(2);
  @$pb.TagNumber(3)
  void clearEvent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get subject => $_getIZ(3);
  @$pb.TagNumber(4)
  set subject($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSubject() => $_has(3);
  @$pb.TagNumber(4)
  void clearSubject() => $_clearField(4);

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
  $core.int get type => $_getIZ(6);
  @$pb.TagNumber(7)
  set type($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasType() => $_has(6);
  @$pb.TagNumber(7)
  void clearType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get teacher => $_getSZ(7);
  @$pb.TagNumber(8)
  set teacher($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTeacher() => $_has(7);
  @$pb.TagNumber(8)
  void clearTeacher() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get name => $_getSZ(8);
  @$pb.TagNumber(9)
  set name($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasName() => $_has(8);
  @$pb.TagNumber(9)
  void clearName() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get totalMarks => $_getIZ(9);
  @$pb.TagNumber(10)
  set totalMarks($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTotalMarks() => $_has(9);
  @$pb.TagNumber(10)
  void clearTotalMarks() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get durationMinutes => $_getIZ(10);
  @$pb.TagNumber(11)
  set durationMinutes($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasDurationMinutes() => $_has(10);
  @$pb.TagNumber(11)
  void clearDurationMinutes() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get date => $_getIZ(11);
  @$pb.TagNumber(12)
  set date($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDate() => $_has(11);
  @$pb.TagNumber(12)
  void clearDate() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get status => $_getIZ(12);
  @$pb.TagNumber(13)
  set status($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasStatus() => $_has(12);
  @$pb.TagNumber(13)
  void clearStatus() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get pdfKey => $_getSZ(13);
  @$pb.TagNumber(14)
  set pdfKey($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasPdfKey() => $_has(13);
  @$pb.TagNumber(14)
  void clearPdfKey() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get msKey => $_getSZ(14);
  @$pb.TagNumber(15)
  set msKey($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasMsKey() => $_has(14);
  @$pb.TagNumber(15)
  void clearMsKey() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get generationMode => $_getIZ(15);
  @$pb.TagNumber(16)
  set generationMode($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasGenerationMode() => $_has(15);
  @$pb.TagNumber(16)
  void clearGenerationMode() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get instructions => $_getSZ(16);
  @$pb.TagNumber(17)
  set instructions($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasInstructions() => $_has(16);
  @$pb.TagNumber(17)
  void clearInstructions() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get created => $_getI64(17);
  @$pb.TagNumber(18)
  set created($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasCreated() => $_has(17);
  @$pb.TagNumber(18)
  void clearCreated() => $_clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get updated => $_getI64(18);
  @$pb.TagNumber(19)
  set updated($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(19)
  $core.bool hasUpdated() => $_has(18);
  @$pb.TagNumber(19)
  void clearUpdated() => $_clearField(19);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
