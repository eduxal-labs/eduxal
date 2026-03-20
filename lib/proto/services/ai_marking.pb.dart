// This is a generated file - do not edit.
//
// Generated from services/ai_marking.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class UploadUrlsRequest extends $pb.GeneratedMessage {
  factory UploadUrlsRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? schemeCount,
    $core.Iterable<StudentSheetCount>? students,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (schemeCount != null) result.schemeCount = schemeCount;
    if (students != null) result.students.addAll(students);
    return result;
  }

  UploadUrlsRequest._();

  factory UploadUrlsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadUrlsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadUrlsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'schemeCount')
    ..pPM<StudentSheetCount>(6, _omitFieldNames ? '' : 'students',
        subBuilder: StudentSheetCount.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadUrlsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadUrlsRequest copyWith(void Function(UploadUrlsRequest) updates) =>
      super.copyWith((message) => updates(message as UploadUrlsRequest))
          as UploadUrlsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadUrlsRequest create() => UploadUrlsRequest._();
  @$core.override
  UploadUrlsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadUrlsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadUrlsRequest>(create);
  static UploadUrlsRequest? _defaultInstance;

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
  $core.int get schemeCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set schemeCount($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSchemeCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearSchemeCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<StudentSheetCount> get students => $_getList(5);
}

class StudentSheetCount extends $pb.GeneratedMessage {
  factory StudentSheetCount({
    $core.int? adm,
    $core.int? count,
  }) {
    final result = create();
    if (adm != null) result.adm = adm;
    if (count != null) result.count = count;
    return result;
  }

  StudentSheetCount._();

  factory StudentSheetCount.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudentSheetCount.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudentSheetCount',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'adm')
    ..aI(2, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentSheetCount clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentSheetCount copyWith(void Function(StudentSheetCount) updates) =>
      super.copyWith((message) => updates(message as StudentSheetCount))
          as StudentSheetCount;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudentSheetCount create() => StudentSheetCount._();
  @$core.override
  StudentSheetCount createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudentSheetCount getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudentSheetCount>(create);
  static StudentSheetCount? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get adm => $_getIZ(0);
  @$pb.TagNumber(1)
  set adm($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAdm() => $_has(0);
  @$pb.TagNumber(1)
  void clearAdm() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class UploadUrlsResponse extends $pb.GeneratedMessage {
  factory UploadUrlsResponse({
    $core.Iterable<SignedUrl>? schemeUrls,
    $core.Iterable<StudentSignedUrls>? studentUrls,
  }) {
    final result = create();
    if (schemeUrls != null) result.schemeUrls.addAll(schemeUrls);
    if (studentUrls != null) result.studentUrls.addAll(studentUrls);
    return result;
  }

  UploadUrlsResponse._();

  factory UploadUrlsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadUrlsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadUrlsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..pPM<SignedUrl>(1, _omitFieldNames ? '' : 'schemeUrls',
        subBuilder: SignedUrl.create)
    ..pPM<StudentSignedUrls>(2, _omitFieldNames ? '' : 'studentUrls',
        subBuilder: StudentSignedUrls.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadUrlsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadUrlsResponse copyWith(void Function(UploadUrlsResponse) updates) =>
      super.copyWith((message) => updates(message as UploadUrlsResponse))
          as UploadUrlsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadUrlsResponse create() => UploadUrlsResponse._();
  @$core.override
  UploadUrlsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadUrlsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadUrlsResponse>(create);
  static UploadUrlsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SignedUrl> get schemeUrls => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<StudentSignedUrls> get studentUrls => $_getList(1);
}

class SignedUrl extends $pb.GeneratedMessage {
  factory SignedUrl({
    $core.String? key,
    $core.String? url,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (url != null) result.url = url;
    return result;
  }

  SignedUrl._();

  factory SignedUrl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignedUrl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignedUrl',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedUrl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedUrl copyWith(void Function(SignedUrl) updates) =>
      super.copyWith((message) => updates(message as SignedUrl)) as SignedUrl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignedUrl create() => SignedUrl._();
  @$core.override
  SignedUrl createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignedUrl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignedUrl>(create);
  static SignedUrl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);
}

class StudentSignedUrls extends $pb.GeneratedMessage {
  factory StudentSignedUrls({
    $core.int? adm,
    $core.Iterable<SignedUrl>? urls,
  }) {
    final result = create();
    if (adm != null) result.adm = adm;
    if (urls != null) result.urls.addAll(urls);
    return result;
  }

  StudentSignedUrls._();

  factory StudentSignedUrls.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudentSignedUrls.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudentSignedUrls',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'adm')
    ..pPM<SignedUrl>(2, _omitFieldNames ? '' : 'urls',
        subBuilder: SignedUrl.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentSignedUrls clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentSignedUrls copyWith(void Function(StudentSignedUrls) updates) =>
      super.copyWith((message) => updates(message as StudentSignedUrls))
          as StudentSignedUrls;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudentSignedUrls create() => StudentSignedUrls._();
  @$core.override
  StudentSignedUrls createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudentSignedUrls getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudentSignedUrls>(create);
  static StudentSignedUrls? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get adm => $_getIZ(0);
  @$pb.TagNumber(1)
  set adm($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAdm() => $_has(0);
  @$pb.TagNumber(1)
  void clearAdm() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SignedUrl> get urls => $_getList(1);
}

class MarkPaperRequest extends $pb.GeneratedMessage {
  factory MarkPaperRequest({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? grade,
    $core.int? stream,
    $core.int? totalMarks,
    $core.Iterable<$core.String>? schemeKeys,
    $core.Iterable<StudentMarkTarget>? students,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (totalMarks != null) result.totalMarks = totalMarks;
    if (schemeKeys != null) result.schemeKeys.addAll(schemeKeys);
    if (students != null) result.students.addAll(students);
    return result;
  }

  MarkPaperRequest._();

  factory MarkPaperRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkPaperRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkPaperRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aI(7, _omitFieldNames ? '' : 'totalMarks')
    ..pPS(8, _omitFieldNames ? '' : 'schemeKeys')
    ..pPM<StudentMarkTarget>(9, _omitFieldNames ? '' : 'students',
        subBuilder: StudentMarkTarget.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkPaperRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkPaperRequest copyWith(void Function(MarkPaperRequest) updates) =>
      super.copyWith((message) => updates(message as MarkPaperRequest))
          as MarkPaperRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkPaperRequest create() => MarkPaperRequest._();
  @$core.override
  MarkPaperRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkPaperRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkPaperRequest>(create);
  static MarkPaperRequest? _defaultInstance;

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
  $pb.PbList<$core.String> get schemeKeys => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<StudentMarkTarget> get students => $_getList(8);
}

class StudentMarkTarget extends $pb.GeneratedMessage {
  factory StudentMarkTarget({
    $core.int? adm,
    $core.Iterable<$core.String>? keys,
  }) {
    final result = create();
    if (adm != null) result.adm = adm;
    if (keys != null) result.keys.addAll(keys);
    return result;
  }

  StudentMarkTarget._();

  factory StudentMarkTarget.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudentMarkTarget.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudentMarkTarget',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'adm')
    ..pPS(2, _omitFieldNames ? '' : 'keys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentMarkTarget clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentMarkTarget copyWith(void Function(StudentMarkTarget) updates) =>
      super.copyWith((message) => updates(message as StudentMarkTarget))
          as StudentMarkTarget;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudentMarkTarget create() => StudentMarkTarget._();
  @$core.override
  StudentMarkTarget createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudentMarkTarget getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudentMarkTarget>(create);
  static StudentMarkTarget? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get adm => $_getIZ(0);
  @$pb.TagNumber(1)
  set adm($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAdm() => $_has(0);
  @$pb.TagNumber(1)
  void clearAdm() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get keys => $_getList(1);
}

class MarkPaperResponse extends $pb.GeneratedMessage {
  factory MarkPaperResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = create();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  MarkPaperResponse._();

  factory MarkPaperResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkPaperResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkPaperResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ai_marking'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkPaperResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkPaperResponse copyWith(void Function(MarkPaperResponse) updates) =>
      super.copyWith((message) => updates(message as MarkPaperResponse))
          as MarkPaperResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkPaperResponse create() => MarkPaperResponse._();
  @$core.override
  MarkPaperResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkPaperResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkPaperResponse>(create);
  static MarkPaperResponse? _defaultInstance;

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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
