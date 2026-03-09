// This is a generated file - do not edit.
//
// Generated from services/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class MutationBatch extends $pb.GeneratedMessage {
  factory MutationBatch({
    $core.String? batchId,
    $core.Iterable<Mutation>? mutations,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (mutations != null) result.mutations.addAll(mutations);
    return result;
  }

  MutationBatch._();

  factory MutationBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MutationBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MutationBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..pPM<Mutation>(2, _omitFieldNames ? '' : 'mutations',
        subBuilder: Mutation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MutationBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MutationBatch copyWith(void Function(MutationBatch) updates) =>
      super.copyWith((message) => updates(message as MutationBatch))
          as MutationBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MutationBatch create() => MutationBatch._();
  @$core.override
  MutationBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MutationBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MutationBatch>(create);
  static MutationBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Mutation> get mutations => $_getList(1);
}

class Mutation extends $pb.GeneratedMessage {
  factory Mutation({
    $core.int? table,
    $core.int? operation,
    $core.String? rowKey,
    InsertData? insert,
    UpdateData? update,
  }) {
    final result = create();
    if (table != null) result.table = table;
    if (operation != null) result.operation = operation;
    if (rowKey != null) result.rowKey = rowKey;
    if (insert != null) result.insert = insert;
    if (update != null) result.update = update;
    return result;
  }

  Mutation._();

  factory Mutation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Mutation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Mutation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'table')
    ..aI(2, _omitFieldNames ? '' : 'operation')
    ..aOS(3, _omitFieldNames ? '' : 'rowKey')
    ..aOM<InsertData>(4, _omitFieldNames ? '' : 'insert',
        subBuilder: InsertData.create)
    ..aOM<UpdateData>(5, _omitFieldNames ? '' : 'update',
        subBuilder: UpdateData.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Mutation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Mutation copyWith(void Function(Mutation) updates) =>
      super.copyWith((message) => updates(message as Mutation)) as Mutation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Mutation create() => Mutation._();
  @$core.override
  Mutation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Mutation getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Mutation>(create);
  static Mutation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get table => $_getIZ(0);
  @$pb.TagNumber(1)
  set table($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTable() => $_has(0);
  @$pb.TagNumber(1)
  void clearTable() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get operation => $_getIZ(1);
  @$pb.TagNumber(2)
  set operation($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOperation() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperation() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get rowKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set rowKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRowKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearRowKey() => $_clearField(3);

  @$pb.TagNumber(4)
  InsertData get insert => $_getN(3);
  @$pb.TagNumber(4)
  set insert(InsertData value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasInsert() => $_has(3);
  @$pb.TagNumber(4)
  void clearInsert() => $_clearField(4);
  @$pb.TagNumber(4)
  InsertData ensureInsert() => $_ensure(3);

  @$pb.TagNumber(5)
  UpdateData get update => $_getN(4);
  @$pb.TagNumber(5)
  set update(UpdateData value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUpdate() => $_has(4);
  @$pb.TagNumber(5)
  void clearUpdate() => $_clearField(5);
  @$pb.TagNumber(5)
  UpdateData ensureUpdate() => $_ensure(4);
}

class PushAck extends $pb.GeneratedMessage {
  factory PushAck({
    $core.String? batchId,
    $core.bool? success,
    $core.String? error,
    $fixnum.Int64? serverSeq,
    $core.Iterable<MutationResult>? results,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    if (serverSeq != null) result.serverSeq = serverSeq;
    if (results != null) result.results.addAll(results);
    return result;
  }

  PushAck._();

  factory PushAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PushAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PushAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..aInt64(4, _omitFieldNames ? '' : 'serverSeq')
    ..pPM<MutationResult>(5, _omitFieldNames ? '' : 'results',
        subBuilder: MutationResult.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushAck copyWith(void Function(PushAck) updates) =>
      super.copyWith((message) => updates(message as PushAck)) as PushAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PushAck create() => PushAck._();
  @$core.override
  PushAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PushAck getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PushAck>(create);
  static PushAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get serverSeq => $_getI64(3);
  @$pb.TagNumber(4)
  set serverSeq($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasServerSeq() => $_has(3);
  @$pb.TagNumber(4)
  void clearServerSeq() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<MutationResult> get results => $_getList(4);
}

class MutationResult extends $pb.GeneratedMessage {
  factory MutationResult({
    $core.int? index,
    $core.bool? success,
    $core.String? error,
    $core.int? code,
    $core.Iterable<FileUrl>? fileUrls,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    if (code != null) result.code = code;
    if (fileUrls != null) result.fileUrls.addAll(fileUrls);
    return result;
  }

  MutationResult._();

  factory MutationResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MutationResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MutationResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..aI(4, _omitFieldNames ? '' : 'code')
    ..pPM<FileUrl>(5, _omitFieldNames ? '' : 'fileUrls',
        subBuilder: FileUrl.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MutationResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MutationResult copyWith(void Function(MutationResult) updates) =>
      super.copyWith((message) => updates(message as MutationResult))
          as MutationResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MutationResult create() => MutationResult._();
  @$core.override
  MutationResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MutationResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MutationResult>(create);
  static MutationResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get code => $_getIZ(3);
  @$pb.TagNumber(4)
  set code($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<FileUrl> get fileUrls => $_getList(4);
}

class WatchRequest extends $pb.GeneratedMessage {
  factory WatchRequest({
    $fixnum.Int64? lastSeq,
  }) {
    final result = create();
    if (lastSeq != null) result.lastSeq = lastSeq;
    return result;
  }

  WatchRequest._();

  factory WatchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WatchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'lastSeq')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchRequest copyWith(void Function(WatchRequest) updates) =>
      super.copyWith((message) => updates(message as WatchRequest))
          as WatchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WatchRequest create() => WatchRequest._();
  @$core.override
  WatchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WatchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchRequest>(create);
  static WatchRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get lastSeq => $_getI64(0);
  @$pb.TagNumber(1)
  set lastSeq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLastSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearLastSeq() => $_clearField(1);
}

class SyncDelta extends $pb.GeneratedMessage {
  factory SyncDelta({
    $fixnum.Int64? seq,
    $core.int? table,
    $core.int? operation,
    $core.String? rowKey,
    InsertData? data,
    $core.Iterable<FileUrl>? fileUrls,
  }) {
    final result = create();
    if (seq != null) result.seq = seq;
    if (table != null) result.table = table;
    if (operation != null) result.operation = operation;
    if (rowKey != null) result.rowKey = rowKey;
    if (data != null) result.data = data;
    if (fileUrls != null) result.fileUrls.addAll(fileUrls);
    return result;
  }

  SyncDelta._();

  factory SyncDelta.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncDelta.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncDelta',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'seq')
    ..aI(2, _omitFieldNames ? '' : 'table')
    ..aI(3, _omitFieldNames ? '' : 'operation')
    ..aOS(4, _omitFieldNames ? '' : 'rowKey')
    ..aOM<InsertData>(5, _omitFieldNames ? '' : 'data',
        subBuilder: InsertData.create)
    ..pPM<FileUrl>(6, _omitFieldNames ? '' : 'fileUrls',
        subBuilder: FileUrl.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncDelta clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncDelta copyWith(void Function(SyncDelta) updates) =>
      super.copyWith((message) => updates(message as SyncDelta)) as SyncDelta;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncDelta create() => SyncDelta._();
  @$core.override
  SyncDelta createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncDelta getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncDelta>(create);
  static SyncDelta? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seq => $_getI64(0);
  @$pb.TagNumber(1)
  set seq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeq() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get table => $_getIZ(1);
  @$pb.TagNumber(2)
  set table($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTable() => $_has(1);
  @$pb.TagNumber(2)
  void clearTable() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get operation => $_getIZ(2);
  @$pb.TagNumber(3)
  set operation($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOperation() => $_has(2);
  @$pb.TagNumber(3)
  void clearOperation() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get rowKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set rowKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRowKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearRowKey() => $_clearField(4);

  @$pb.TagNumber(5)
  InsertData get data => $_getN(4);
  @$pb.TagNumber(5)
  set data(InsertData value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasData() => $_has(4);
  @$pb.TagNumber(5)
  void clearData() => $_clearField(5);
  @$pb.TagNumber(5)
  InsertData ensureData() => $_ensure(4);

  @$pb.TagNumber(6)
  $pb.PbList<FileUrl> get fileUrls => $_getList(5);
}

class FileUrl extends $pb.GeneratedMessage {
  factory FileUrl({
    $core.String? path,
    $core.String? putUrl,
    $core.String? getUrl,
    $fixnum.Int64? expiry,
  }) {
    final result = create();
    if (path != null) result.path = path;
    if (putUrl != null) result.putUrl = putUrl;
    if (getUrl != null) result.getUrl = getUrl;
    if (expiry != null) result.expiry = expiry;
    return result;
  }

  FileUrl._();

  factory FileUrl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FileUrl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FileUrl',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'putUrl')
    ..aOS(3, _omitFieldNames ? '' : 'getUrl')
    ..aInt64(4, _omitFieldNames ? '' : 'expiry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileUrl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileUrl copyWith(void Function(FileUrl) updates) =>
      super.copyWith((message) => updates(message as FileUrl)) as FileUrl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FileUrl create() => FileUrl._();
  @$core.override
  FileUrl createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FileUrl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileUrl>(create);
  static FileUrl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

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

enum InsertData_Row {
  user,
  school,
  owner,
  student,
  guardian,
  department,
  teacher,
  staffMember,
  term,
  classTeacher,
  enrollment,
  subject,
  attendance,
  timetable,
  lesson,
  exam,
  paper,
  grade,
  fee,
  invoice,
  payment,
  announcement,
  mastery,
  aiUsage,
  settings,
  role,
  scope,
  plan,
  subscription,
  discount,
  notSet
}

class InsertData extends $pb.GeneratedMessage {
  factory InsertData({
    UserInsert? user,
    SchoolInsert? school,
    OwnerInsert? owner,
    StudentInsert? student,
    GuardianInsert? guardian,
    DepartmentInsert? department,
    TeacherInsert? teacher,
    StaffInsert? staffMember,
    TermInsert? term,
    ClassTeacherInsert? classTeacher,
    EnrollmentInsert? enrollment,
    SubjectInsert? subject,
    AttendanceInsert? attendance,
    TimetableInsert? timetable,
    LessonInsert? lesson,
    ExamInsert? exam,
    PaperInsert? paper,
    GradeInsert? grade,
    FeeInsert? fee,
    InvoiceInsert? invoice,
    PaymentInsert? payment,
    AnnouncementInsert? announcement,
    MasteryInsert? mastery,
    AiUsageInsert? aiUsage,
    SettingsInsert? settings,
    RoleInsert? role,
    ScopeInsert? scope,
    PlanInsert? plan,
    SubscriptionInsert? subscription,
    DiscountInsert? discount,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (school != null) result.school = school;
    if (owner != null) result.owner = owner;
    if (student != null) result.student = student;
    if (guardian != null) result.guardian = guardian;
    if (department != null) result.department = department;
    if (teacher != null) result.teacher = teacher;
    if (staffMember != null) result.staffMember = staffMember;
    if (term != null) result.term = term;
    if (classTeacher != null) result.classTeacher = classTeacher;
    if (enrollment != null) result.enrollment = enrollment;
    if (subject != null) result.subject = subject;
    if (attendance != null) result.attendance = attendance;
    if (timetable != null) result.timetable = timetable;
    if (lesson != null) result.lesson = lesson;
    if (exam != null) result.exam = exam;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (fee != null) result.fee = fee;
    if (invoice != null) result.invoice = invoice;
    if (payment != null) result.payment = payment;
    if (announcement != null) result.announcement = announcement;
    if (mastery != null) result.mastery = mastery;
    if (aiUsage != null) result.aiUsage = aiUsage;
    if (settings != null) result.settings = settings;
    if (role != null) result.role = role;
    if (scope != null) result.scope = scope;
    if (plan != null) result.plan = plan;
    if (subscription != null) result.subscription = subscription;
    if (discount != null) result.discount = discount;
    return result;
  }

  InsertData._();

  factory InsertData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InsertData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, InsertData_Row> _InsertData_RowByTag = {
    1: InsertData_Row.user,
    2: InsertData_Row.school,
    3: InsertData_Row.owner,
    4: InsertData_Row.student,
    5: InsertData_Row.guardian,
    6: InsertData_Row.department,
    7: InsertData_Row.teacher,
    8: InsertData_Row.staffMember,
    9: InsertData_Row.term,
    10: InsertData_Row.classTeacher,
    11: InsertData_Row.enrollment,
    12: InsertData_Row.subject,
    13: InsertData_Row.attendance,
    14: InsertData_Row.timetable,
    15: InsertData_Row.lesson,
    16: InsertData_Row.exam,
    17: InsertData_Row.paper,
    18: InsertData_Row.grade,
    19: InsertData_Row.fee,
    20: InsertData_Row.invoice,
    21: InsertData_Row.payment,
    22: InsertData_Row.announcement,
    23: InsertData_Row.mastery,
    24: InsertData_Row.aiUsage,
    25: InsertData_Row.settings,
    26: InsertData_Row.role,
    27: InsertData_Row.scope,
    28: InsertData_Row.plan,
    29: InsertData_Row.subscription,
    30: InsertData_Row.discount,
    0: InsertData_Row.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InsertData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..oo(0, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30
    ])
    ..aOM<UserInsert>(1, _omitFieldNames ? '' : 'user',
        subBuilder: UserInsert.create)
    ..aOM<SchoolInsert>(2, _omitFieldNames ? '' : 'school',
        subBuilder: SchoolInsert.create)
    ..aOM<OwnerInsert>(3, _omitFieldNames ? '' : 'owner',
        subBuilder: OwnerInsert.create)
    ..aOM<StudentInsert>(4, _omitFieldNames ? '' : 'student',
        subBuilder: StudentInsert.create)
    ..aOM<GuardianInsert>(5, _omitFieldNames ? '' : 'guardian',
        subBuilder: GuardianInsert.create)
    ..aOM<DepartmentInsert>(6, _omitFieldNames ? '' : 'department',
        subBuilder: DepartmentInsert.create)
    ..aOM<TeacherInsert>(7, _omitFieldNames ? '' : 'teacher',
        subBuilder: TeacherInsert.create)
    ..aOM<StaffInsert>(8, _omitFieldNames ? '' : 'staffMember',
        subBuilder: StaffInsert.create)
    ..aOM<TermInsert>(9, _omitFieldNames ? '' : 'term',
        subBuilder: TermInsert.create)
    ..aOM<ClassTeacherInsert>(10, _omitFieldNames ? '' : 'classTeacher',
        subBuilder: ClassTeacherInsert.create)
    ..aOM<EnrollmentInsert>(11, _omitFieldNames ? '' : 'enrollment',
        subBuilder: EnrollmentInsert.create)
    ..aOM<SubjectInsert>(12, _omitFieldNames ? '' : 'subject',
        subBuilder: SubjectInsert.create)
    ..aOM<AttendanceInsert>(13, _omitFieldNames ? '' : 'attendance',
        subBuilder: AttendanceInsert.create)
    ..aOM<TimetableInsert>(14, _omitFieldNames ? '' : 'timetable',
        subBuilder: TimetableInsert.create)
    ..aOM<LessonInsert>(15, _omitFieldNames ? '' : 'lesson',
        subBuilder: LessonInsert.create)
    ..aOM<ExamInsert>(16, _omitFieldNames ? '' : 'exam',
        subBuilder: ExamInsert.create)
    ..aOM<PaperInsert>(17, _omitFieldNames ? '' : 'paper',
        subBuilder: PaperInsert.create)
    ..aOM<GradeInsert>(18, _omitFieldNames ? '' : 'grade',
        subBuilder: GradeInsert.create)
    ..aOM<FeeInsert>(19, _omitFieldNames ? '' : 'fee',
        subBuilder: FeeInsert.create)
    ..aOM<InvoiceInsert>(20, _omitFieldNames ? '' : 'invoice',
        subBuilder: InvoiceInsert.create)
    ..aOM<PaymentInsert>(21, _omitFieldNames ? '' : 'payment',
        subBuilder: PaymentInsert.create)
    ..aOM<AnnouncementInsert>(22, _omitFieldNames ? '' : 'announcement',
        subBuilder: AnnouncementInsert.create)
    ..aOM<MasteryInsert>(23, _omitFieldNames ? '' : 'mastery',
        subBuilder: MasteryInsert.create)
    ..aOM<AiUsageInsert>(24, _omitFieldNames ? '' : 'aiUsage',
        subBuilder: AiUsageInsert.create)
    ..aOM<SettingsInsert>(25, _omitFieldNames ? '' : 'settings',
        subBuilder: SettingsInsert.create)
    ..aOM<RoleInsert>(26, _omitFieldNames ? '' : 'role',
        subBuilder: RoleInsert.create)
    ..aOM<ScopeInsert>(27, _omitFieldNames ? '' : 'scope',
        subBuilder: ScopeInsert.create)
    ..aOM<PlanInsert>(28, _omitFieldNames ? '' : 'plan',
        subBuilder: PlanInsert.create)
    ..aOM<SubscriptionInsert>(29, _omitFieldNames ? '' : 'subscription',
        subBuilder: SubscriptionInsert.create)
    ..aOM<DiscountInsert>(30, _omitFieldNames ? '' : 'discount',
        subBuilder: DiscountInsert.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InsertData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InsertData copyWith(void Function(InsertData) updates) =>
      super.copyWith((message) => updates(message as InsertData)) as InsertData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InsertData create() => InsertData._();
  @$core.override
  InsertData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InsertData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InsertData>(create);
  static InsertData? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  InsertData_Row whichRow() => _InsertData_RowByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  void clearRow() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  UserInsert get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(UserInsert value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  UserInsert ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  SchoolInsert get school => $_getN(1);
  @$pb.TagNumber(2)
  set school(SchoolInsert value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSchool() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchool() => $_clearField(2);
  @$pb.TagNumber(2)
  SchoolInsert ensureSchool() => $_ensure(1);

  @$pb.TagNumber(3)
  OwnerInsert get owner => $_getN(2);
  @$pb.TagNumber(3)
  set owner(OwnerInsert value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOwner() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwner() => $_clearField(3);
  @$pb.TagNumber(3)
  OwnerInsert ensureOwner() => $_ensure(2);

  @$pb.TagNumber(4)
  StudentInsert get student => $_getN(3);
  @$pb.TagNumber(4)
  set student(StudentInsert value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStudent() => $_has(3);
  @$pb.TagNumber(4)
  void clearStudent() => $_clearField(4);
  @$pb.TagNumber(4)
  StudentInsert ensureStudent() => $_ensure(3);

  @$pb.TagNumber(5)
  GuardianInsert get guardian => $_getN(4);
  @$pb.TagNumber(5)
  set guardian(GuardianInsert value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasGuardian() => $_has(4);
  @$pb.TagNumber(5)
  void clearGuardian() => $_clearField(5);
  @$pb.TagNumber(5)
  GuardianInsert ensureGuardian() => $_ensure(4);

  @$pb.TagNumber(6)
  DepartmentInsert get department => $_getN(5);
  @$pb.TagNumber(6)
  set department(DepartmentInsert value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDepartment() => $_has(5);
  @$pb.TagNumber(6)
  void clearDepartment() => $_clearField(6);
  @$pb.TagNumber(6)
  DepartmentInsert ensureDepartment() => $_ensure(5);

  @$pb.TagNumber(7)
  TeacherInsert get teacher => $_getN(6);
  @$pb.TagNumber(7)
  set teacher(TeacherInsert value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTeacher() => $_has(6);
  @$pb.TagNumber(7)
  void clearTeacher() => $_clearField(7);
  @$pb.TagNumber(7)
  TeacherInsert ensureTeacher() => $_ensure(6);

  @$pb.TagNumber(8)
  StaffInsert get staffMember => $_getN(7);
  @$pb.TagNumber(8)
  set staffMember(StaffInsert value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasStaffMember() => $_has(7);
  @$pb.TagNumber(8)
  void clearStaffMember() => $_clearField(8);
  @$pb.TagNumber(8)
  StaffInsert ensureStaffMember() => $_ensure(7);

  @$pb.TagNumber(9)
  TermInsert get term => $_getN(8);
  @$pb.TagNumber(9)
  set term(TermInsert value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasTerm() => $_has(8);
  @$pb.TagNumber(9)
  void clearTerm() => $_clearField(9);
  @$pb.TagNumber(9)
  TermInsert ensureTerm() => $_ensure(8);

  @$pb.TagNumber(10)
  ClassTeacherInsert get classTeacher => $_getN(9);
  @$pb.TagNumber(10)
  set classTeacher(ClassTeacherInsert value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasClassTeacher() => $_has(9);
  @$pb.TagNumber(10)
  void clearClassTeacher() => $_clearField(10);
  @$pb.TagNumber(10)
  ClassTeacherInsert ensureClassTeacher() => $_ensure(9);

  @$pb.TagNumber(11)
  EnrollmentInsert get enrollment => $_getN(10);
  @$pb.TagNumber(11)
  set enrollment(EnrollmentInsert value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasEnrollment() => $_has(10);
  @$pb.TagNumber(11)
  void clearEnrollment() => $_clearField(11);
  @$pb.TagNumber(11)
  EnrollmentInsert ensureEnrollment() => $_ensure(10);

  @$pb.TagNumber(12)
  SubjectInsert get subject => $_getN(11);
  @$pb.TagNumber(12)
  set subject(SubjectInsert value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSubject() => $_has(11);
  @$pb.TagNumber(12)
  void clearSubject() => $_clearField(12);
  @$pb.TagNumber(12)
  SubjectInsert ensureSubject() => $_ensure(11);

  @$pb.TagNumber(13)
  AttendanceInsert get attendance => $_getN(12);
  @$pb.TagNumber(13)
  set attendance(AttendanceInsert value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasAttendance() => $_has(12);
  @$pb.TagNumber(13)
  void clearAttendance() => $_clearField(13);
  @$pb.TagNumber(13)
  AttendanceInsert ensureAttendance() => $_ensure(12);

  @$pb.TagNumber(14)
  TimetableInsert get timetable => $_getN(13);
  @$pb.TagNumber(14)
  set timetable(TimetableInsert value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasTimetable() => $_has(13);
  @$pb.TagNumber(14)
  void clearTimetable() => $_clearField(14);
  @$pb.TagNumber(14)
  TimetableInsert ensureTimetable() => $_ensure(13);

  @$pb.TagNumber(15)
  LessonInsert get lesson => $_getN(14);
  @$pb.TagNumber(15)
  set lesson(LessonInsert value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasLesson() => $_has(14);
  @$pb.TagNumber(15)
  void clearLesson() => $_clearField(15);
  @$pb.TagNumber(15)
  LessonInsert ensureLesson() => $_ensure(14);

  @$pb.TagNumber(16)
  ExamInsert get exam => $_getN(15);
  @$pb.TagNumber(16)
  set exam(ExamInsert value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasExam() => $_has(15);
  @$pb.TagNumber(16)
  void clearExam() => $_clearField(16);
  @$pb.TagNumber(16)
  ExamInsert ensureExam() => $_ensure(15);

  @$pb.TagNumber(17)
  PaperInsert get paper => $_getN(16);
  @$pb.TagNumber(17)
  set paper(PaperInsert value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasPaper() => $_has(16);
  @$pb.TagNumber(17)
  void clearPaper() => $_clearField(17);
  @$pb.TagNumber(17)
  PaperInsert ensurePaper() => $_ensure(16);

  @$pb.TagNumber(18)
  GradeInsert get grade => $_getN(17);
  @$pb.TagNumber(18)
  set grade(GradeInsert value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasGrade() => $_has(17);
  @$pb.TagNumber(18)
  void clearGrade() => $_clearField(18);
  @$pb.TagNumber(18)
  GradeInsert ensureGrade() => $_ensure(17);

  @$pb.TagNumber(19)
  FeeInsert get fee => $_getN(18);
  @$pb.TagNumber(19)
  set fee(FeeInsert value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasFee() => $_has(18);
  @$pb.TagNumber(19)
  void clearFee() => $_clearField(19);
  @$pb.TagNumber(19)
  FeeInsert ensureFee() => $_ensure(18);

  @$pb.TagNumber(20)
  InvoiceInsert get invoice => $_getN(19);
  @$pb.TagNumber(20)
  set invoice(InvoiceInsert value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasInvoice() => $_has(19);
  @$pb.TagNumber(20)
  void clearInvoice() => $_clearField(20);
  @$pb.TagNumber(20)
  InvoiceInsert ensureInvoice() => $_ensure(19);

  @$pb.TagNumber(21)
  PaymentInsert get payment => $_getN(20);
  @$pb.TagNumber(21)
  set payment(PaymentInsert value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasPayment() => $_has(20);
  @$pb.TagNumber(21)
  void clearPayment() => $_clearField(21);
  @$pb.TagNumber(21)
  PaymentInsert ensurePayment() => $_ensure(20);

  @$pb.TagNumber(22)
  AnnouncementInsert get announcement => $_getN(21);
  @$pb.TagNumber(22)
  set announcement(AnnouncementInsert value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasAnnouncement() => $_has(21);
  @$pb.TagNumber(22)
  void clearAnnouncement() => $_clearField(22);
  @$pb.TagNumber(22)
  AnnouncementInsert ensureAnnouncement() => $_ensure(21);

  @$pb.TagNumber(23)
  MasteryInsert get mastery => $_getN(22);
  @$pb.TagNumber(23)
  set mastery(MasteryInsert value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasMastery() => $_has(22);
  @$pb.TagNumber(23)
  void clearMastery() => $_clearField(23);
  @$pb.TagNumber(23)
  MasteryInsert ensureMastery() => $_ensure(22);

  @$pb.TagNumber(24)
  AiUsageInsert get aiUsage => $_getN(23);
  @$pb.TagNumber(24)
  set aiUsage(AiUsageInsert value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasAiUsage() => $_has(23);
  @$pb.TagNumber(24)
  void clearAiUsage() => $_clearField(24);
  @$pb.TagNumber(24)
  AiUsageInsert ensureAiUsage() => $_ensure(23);

  @$pb.TagNumber(25)
  SettingsInsert get settings => $_getN(24);
  @$pb.TagNumber(25)
  set settings(SettingsInsert value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasSettings() => $_has(24);
  @$pb.TagNumber(25)
  void clearSettings() => $_clearField(25);
  @$pb.TagNumber(25)
  SettingsInsert ensureSettings() => $_ensure(24);

  @$pb.TagNumber(26)
  RoleInsert get role => $_getN(25);
  @$pb.TagNumber(26)
  set role(RoleInsert value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasRole() => $_has(25);
  @$pb.TagNumber(26)
  void clearRole() => $_clearField(26);
  @$pb.TagNumber(26)
  RoleInsert ensureRole() => $_ensure(25);

  @$pb.TagNumber(27)
  ScopeInsert get scope => $_getN(26);
  @$pb.TagNumber(27)
  set scope(ScopeInsert value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasScope() => $_has(26);
  @$pb.TagNumber(27)
  void clearScope() => $_clearField(27);
  @$pb.TagNumber(27)
  ScopeInsert ensureScope() => $_ensure(26);

  @$pb.TagNumber(28)
  PlanInsert get plan => $_getN(27);
  @$pb.TagNumber(28)
  set plan(PlanInsert value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasPlan() => $_has(27);
  @$pb.TagNumber(28)
  void clearPlan() => $_clearField(28);
  @$pb.TagNumber(28)
  PlanInsert ensurePlan() => $_ensure(27);

  @$pb.TagNumber(29)
  SubscriptionInsert get subscription => $_getN(28);
  @$pb.TagNumber(29)
  set subscription(SubscriptionInsert value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasSubscription() => $_has(28);
  @$pb.TagNumber(29)
  void clearSubscription() => $_clearField(29);
  @$pb.TagNumber(29)
  SubscriptionInsert ensureSubscription() => $_ensure(28);

  @$pb.TagNumber(30)
  DiscountInsert get discount => $_getN(29);
  @$pb.TagNumber(30)
  set discount(DiscountInsert value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasDiscount() => $_has(29);
  @$pb.TagNumber(30)
  void clearDiscount() => $_clearField(30);
  @$pb.TagNumber(30)
  DiscountInsert ensureDiscount() => $_ensure(29);
}

enum UpdateData_Row {
  user,
  school,
  student,
  guardian,
  department,
  teacher,
  staffMember,
  term,
  classTeacher,
  attendance,
  timetable,
  exam,
  paper,
  grade,
  fee,
  invoice,
  payment,
  announcement,
  mastery,
  aiUsage,
  settings,
  role,
  plan,
  subscription,
  discount,
  notSet
}

class UpdateData extends $pb.GeneratedMessage {
  factory UpdateData({
    UserUpdate? user,
    SchoolUpdate? school,
    StudentUpdate? student,
    GuardianUpdate? guardian,
    DepartmentUpdate? department,
    TeacherUpdate? teacher,
    StaffUpdate? staffMember,
    TermUpdate? term,
    ClassTeacherUpdate? classTeacher,
    AttendanceUpdate? attendance,
    TimetableUpdate? timetable,
    ExamUpdate? exam,
    PaperUpdate? paper,
    GradeUpdate? grade,
    FeeUpdate? fee,
    InvoiceUpdate? invoice,
    PaymentUpdate? payment,
    AnnouncementUpdate? announcement,
    MasteryUpdate? mastery,
    AiUsageUpdate? aiUsage,
    SettingsUpdate? settings,
    RoleUpdate? role,
    PlanUpdate? plan,
    SubscriptionUpdate? subscription,
    DiscountUpdate? discount,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (school != null) result.school = school;
    if (student != null) result.student = student;
    if (guardian != null) result.guardian = guardian;
    if (department != null) result.department = department;
    if (teacher != null) result.teacher = teacher;
    if (staffMember != null) result.staffMember = staffMember;
    if (term != null) result.term = term;
    if (classTeacher != null) result.classTeacher = classTeacher;
    if (attendance != null) result.attendance = attendance;
    if (timetable != null) result.timetable = timetable;
    if (exam != null) result.exam = exam;
    if (paper != null) result.paper = paper;
    if (grade != null) result.grade = grade;
    if (fee != null) result.fee = fee;
    if (invoice != null) result.invoice = invoice;
    if (payment != null) result.payment = payment;
    if (announcement != null) result.announcement = announcement;
    if (mastery != null) result.mastery = mastery;
    if (aiUsage != null) result.aiUsage = aiUsage;
    if (settings != null) result.settings = settings;
    if (role != null) result.role = role;
    if (plan != null) result.plan = plan;
    if (subscription != null) result.subscription = subscription;
    if (discount != null) result.discount = discount;
    return result;
  }

  UpdateData._();

  factory UpdateData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, UpdateData_Row> _UpdateData_RowByTag = {
    1: UpdateData_Row.user,
    2: UpdateData_Row.school,
    4: UpdateData_Row.student,
    5: UpdateData_Row.guardian,
    6: UpdateData_Row.department,
    7: UpdateData_Row.teacher,
    8: UpdateData_Row.staffMember,
    9: UpdateData_Row.term,
    10: UpdateData_Row.classTeacher,
    13: UpdateData_Row.attendance,
    14: UpdateData_Row.timetable,
    16: UpdateData_Row.exam,
    17: UpdateData_Row.paper,
    18: UpdateData_Row.grade,
    19: UpdateData_Row.fee,
    20: UpdateData_Row.invoice,
    21: UpdateData_Row.payment,
    22: UpdateData_Row.announcement,
    23: UpdateData_Row.mastery,
    24: UpdateData_Row.aiUsage,
    25: UpdateData_Row.settings,
    26: UpdateData_Row.role,
    28: UpdateData_Row.plan,
    29: UpdateData_Row.subscription,
    30: UpdateData_Row.discount,
    0: UpdateData_Row.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..oo(0, [
      1,
      2,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      13,
      14,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      28,
      29,
      30
    ])
    ..aOM<UserUpdate>(1, _omitFieldNames ? '' : 'user',
        subBuilder: UserUpdate.create)
    ..aOM<SchoolUpdate>(2, _omitFieldNames ? '' : 'school',
        subBuilder: SchoolUpdate.create)
    ..aOM<StudentUpdate>(4, _omitFieldNames ? '' : 'student',
        subBuilder: StudentUpdate.create)
    ..aOM<GuardianUpdate>(5, _omitFieldNames ? '' : 'guardian',
        subBuilder: GuardianUpdate.create)
    ..aOM<DepartmentUpdate>(6, _omitFieldNames ? '' : 'department',
        subBuilder: DepartmentUpdate.create)
    ..aOM<TeacherUpdate>(7, _omitFieldNames ? '' : 'teacher',
        subBuilder: TeacherUpdate.create)
    ..aOM<StaffUpdate>(8, _omitFieldNames ? '' : 'staffMember',
        subBuilder: StaffUpdate.create)
    ..aOM<TermUpdate>(9, _omitFieldNames ? '' : 'term',
        subBuilder: TermUpdate.create)
    ..aOM<ClassTeacherUpdate>(10, _omitFieldNames ? '' : 'classTeacher',
        subBuilder: ClassTeacherUpdate.create)
    ..aOM<AttendanceUpdate>(13, _omitFieldNames ? '' : 'attendance',
        subBuilder: AttendanceUpdate.create)
    ..aOM<TimetableUpdate>(14, _omitFieldNames ? '' : 'timetable',
        subBuilder: TimetableUpdate.create)
    ..aOM<ExamUpdate>(16, _omitFieldNames ? '' : 'exam',
        subBuilder: ExamUpdate.create)
    ..aOM<PaperUpdate>(17, _omitFieldNames ? '' : 'paper',
        subBuilder: PaperUpdate.create)
    ..aOM<GradeUpdate>(18, _omitFieldNames ? '' : 'grade',
        subBuilder: GradeUpdate.create)
    ..aOM<FeeUpdate>(19, _omitFieldNames ? '' : 'fee',
        subBuilder: FeeUpdate.create)
    ..aOM<InvoiceUpdate>(20, _omitFieldNames ? '' : 'invoice',
        subBuilder: InvoiceUpdate.create)
    ..aOM<PaymentUpdate>(21, _omitFieldNames ? '' : 'payment',
        subBuilder: PaymentUpdate.create)
    ..aOM<AnnouncementUpdate>(22, _omitFieldNames ? '' : 'announcement',
        subBuilder: AnnouncementUpdate.create)
    ..aOM<MasteryUpdate>(23, _omitFieldNames ? '' : 'mastery',
        subBuilder: MasteryUpdate.create)
    ..aOM<AiUsageUpdate>(24, _omitFieldNames ? '' : 'aiUsage',
        subBuilder: AiUsageUpdate.create)
    ..aOM<SettingsUpdate>(25, _omitFieldNames ? '' : 'settings',
        subBuilder: SettingsUpdate.create)
    ..aOM<RoleUpdate>(26, _omitFieldNames ? '' : 'role',
        subBuilder: RoleUpdate.create)
    ..aOM<PlanUpdate>(28, _omitFieldNames ? '' : 'plan',
        subBuilder: PlanUpdate.create)
    ..aOM<SubscriptionUpdate>(29, _omitFieldNames ? '' : 'subscription',
        subBuilder: SubscriptionUpdate.create)
    ..aOM<DiscountUpdate>(30, _omitFieldNames ? '' : 'discount',
        subBuilder: DiscountUpdate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateData copyWith(void Function(UpdateData) updates) =>
      super.copyWith((message) => updates(message as UpdateData)) as UpdateData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateData create() => UpdateData._();
  @$core.override
  UpdateData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateData>(create);
  static UpdateData? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  UpdateData_Row whichRow() => _UpdateData_RowByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  void clearRow() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  UserUpdate get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(UserUpdate value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  UserUpdate ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  SchoolUpdate get school => $_getN(1);
  @$pb.TagNumber(2)
  set school(SchoolUpdate value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSchool() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchool() => $_clearField(2);
  @$pb.TagNumber(2)
  SchoolUpdate ensureSchool() => $_ensure(1);

  @$pb.TagNumber(4)
  StudentUpdate get student => $_getN(2);
  @$pb.TagNumber(4)
  set student(StudentUpdate value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStudent() => $_has(2);
  @$pb.TagNumber(4)
  void clearStudent() => $_clearField(4);
  @$pb.TagNumber(4)
  StudentUpdate ensureStudent() => $_ensure(2);

  @$pb.TagNumber(5)
  GuardianUpdate get guardian => $_getN(3);
  @$pb.TagNumber(5)
  set guardian(GuardianUpdate value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasGuardian() => $_has(3);
  @$pb.TagNumber(5)
  void clearGuardian() => $_clearField(5);
  @$pb.TagNumber(5)
  GuardianUpdate ensureGuardian() => $_ensure(3);

  @$pb.TagNumber(6)
  DepartmentUpdate get department => $_getN(4);
  @$pb.TagNumber(6)
  set department(DepartmentUpdate value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDepartment() => $_has(4);
  @$pb.TagNumber(6)
  void clearDepartment() => $_clearField(6);
  @$pb.TagNumber(6)
  DepartmentUpdate ensureDepartment() => $_ensure(4);

  @$pb.TagNumber(7)
  TeacherUpdate get teacher => $_getN(5);
  @$pb.TagNumber(7)
  set teacher(TeacherUpdate value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTeacher() => $_has(5);
  @$pb.TagNumber(7)
  void clearTeacher() => $_clearField(7);
  @$pb.TagNumber(7)
  TeacherUpdate ensureTeacher() => $_ensure(5);

  @$pb.TagNumber(8)
  StaffUpdate get staffMember => $_getN(6);
  @$pb.TagNumber(8)
  set staffMember(StaffUpdate value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasStaffMember() => $_has(6);
  @$pb.TagNumber(8)
  void clearStaffMember() => $_clearField(8);
  @$pb.TagNumber(8)
  StaffUpdate ensureStaffMember() => $_ensure(6);

  @$pb.TagNumber(9)
  TermUpdate get term => $_getN(7);
  @$pb.TagNumber(9)
  set term(TermUpdate value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasTerm() => $_has(7);
  @$pb.TagNumber(9)
  void clearTerm() => $_clearField(9);
  @$pb.TagNumber(9)
  TermUpdate ensureTerm() => $_ensure(7);

  @$pb.TagNumber(10)
  ClassTeacherUpdate get classTeacher => $_getN(8);
  @$pb.TagNumber(10)
  set classTeacher(ClassTeacherUpdate value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasClassTeacher() => $_has(8);
  @$pb.TagNumber(10)
  void clearClassTeacher() => $_clearField(10);
  @$pb.TagNumber(10)
  ClassTeacherUpdate ensureClassTeacher() => $_ensure(8);

  @$pb.TagNumber(13)
  AttendanceUpdate get attendance => $_getN(9);
  @$pb.TagNumber(13)
  set attendance(AttendanceUpdate value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasAttendance() => $_has(9);
  @$pb.TagNumber(13)
  void clearAttendance() => $_clearField(13);
  @$pb.TagNumber(13)
  AttendanceUpdate ensureAttendance() => $_ensure(9);

  @$pb.TagNumber(14)
  TimetableUpdate get timetable => $_getN(10);
  @$pb.TagNumber(14)
  set timetable(TimetableUpdate value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasTimetable() => $_has(10);
  @$pb.TagNumber(14)
  void clearTimetable() => $_clearField(14);
  @$pb.TagNumber(14)
  TimetableUpdate ensureTimetable() => $_ensure(10);

  @$pb.TagNumber(16)
  ExamUpdate get exam => $_getN(11);
  @$pb.TagNumber(16)
  set exam(ExamUpdate value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasExam() => $_has(11);
  @$pb.TagNumber(16)
  void clearExam() => $_clearField(16);
  @$pb.TagNumber(16)
  ExamUpdate ensureExam() => $_ensure(11);

  @$pb.TagNumber(17)
  PaperUpdate get paper => $_getN(12);
  @$pb.TagNumber(17)
  set paper(PaperUpdate value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasPaper() => $_has(12);
  @$pb.TagNumber(17)
  void clearPaper() => $_clearField(17);
  @$pb.TagNumber(17)
  PaperUpdate ensurePaper() => $_ensure(12);

  @$pb.TagNumber(18)
  GradeUpdate get grade => $_getN(13);
  @$pb.TagNumber(18)
  set grade(GradeUpdate value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasGrade() => $_has(13);
  @$pb.TagNumber(18)
  void clearGrade() => $_clearField(18);
  @$pb.TagNumber(18)
  GradeUpdate ensureGrade() => $_ensure(13);

  @$pb.TagNumber(19)
  FeeUpdate get fee => $_getN(14);
  @$pb.TagNumber(19)
  set fee(FeeUpdate value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasFee() => $_has(14);
  @$pb.TagNumber(19)
  void clearFee() => $_clearField(19);
  @$pb.TagNumber(19)
  FeeUpdate ensureFee() => $_ensure(14);

  @$pb.TagNumber(20)
  InvoiceUpdate get invoice => $_getN(15);
  @$pb.TagNumber(20)
  set invoice(InvoiceUpdate value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasInvoice() => $_has(15);
  @$pb.TagNumber(20)
  void clearInvoice() => $_clearField(20);
  @$pb.TagNumber(20)
  InvoiceUpdate ensureInvoice() => $_ensure(15);

  @$pb.TagNumber(21)
  PaymentUpdate get payment => $_getN(16);
  @$pb.TagNumber(21)
  set payment(PaymentUpdate value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasPayment() => $_has(16);
  @$pb.TagNumber(21)
  void clearPayment() => $_clearField(21);
  @$pb.TagNumber(21)
  PaymentUpdate ensurePayment() => $_ensure(16);

  @$pb.TagNumber(22)
  AnnouncementUpdate get announcement => $_getN(17);
  @$pb.TagNumber(22)
  set announcement(AnnouncementUpdate value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasAnnouncement() => $_has(17);
  @$pb.TagNumber(22)
  void clearAnnouncement() => $_clearField(22);
  @$pb.TagNumber(22)
  AnnouncementUpdate ensureAnnouncement() => $_ensure(17);

  @$pb.TagNumber(23)
  MasteryUpdate get mastery => $_getN(18);
  @$pb.TagNumber(23)
  set mastery(MasteryUpdate value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasMastery() => $_has(18);
  @$pb.TagNumber(23)
  void clearMastery() => $_clearField(23);
  @$pb.TagNumber(23)
  MasteryUpdate ensureMastery() => $_ensure(18);

  @$pb.TagNumber(24)
  AiUsageUpdate get aiUsage => $_getN(19);
  @$pb.TagNumber(24)
  set aiUsage(AiUsageUpdate value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasAiUsage() => $_has(19);
  @$pb.TagNumber(24)
  void clearAiUsage() => $_clearField(24);
  @$pb.TagNumber(24)
  AiUsageUpdate ensureAiUsage() => $_ensure(19);

  @$pb.TagNumber(25)
  SettingsUpdate get settings => $_getN(20);
  @$pb.TagNumber(25)
  set settings(SettingsUpdate value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasSettings() => $_has(20);
  @$pb.TagNumber(25)
  void clearSettings() => $_clearField(25);
  @$pb.TagNumber(25)
  SettingsUpdate ensureSettings() => $_ensure(20);

  @$pb.TagNumber(26)
  RoleUpdate get role => $_getN(21);
  @$pb.TagNumber(26)
  set role(RoleUpdate value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasRole() => $_has(21);
  @$pb.TagNumber(26)
  void clearRole() => $_clearField(26);
  @$pb.TagNumber(26)
  RoleUpdate ensureRole() => $_ensure(21);

  @$pb.TagNumber(28)
  PlanUpdate get plan => $_getN(22);
  @$pb.TagNumber(28)
  set plan(PlanUpdate value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasPlan() => $_has(22);
  @$pb.TagNumber(28)
  void clearPlan() => $_clearField(28);
  @$pb.TagNumber(28)
  PlanUpdate ensurePlan() => $_ensure(22);

  @$pb.TagNumber(29)
  SubscriptionUpdate get subscription => $_getN(23);
  @$pb.TagNumber(29)
  set subscription(SubscriptionUpdate value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasSubscription() => $_has(23);
  @$pb.TagNumber(29)
  void clearSubscription() => $_clearField(29);
  @$pb.TagNumber(29)
  SubscriptionUpdate ensureSubscription() => $_ensure(23);

  @$pb.TagNumber(30)
  DiscountUpdate get discount => $_getN(24);
  @$pb.TagNumber(30)
  set discount(DiscountUpdate value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasDiscount() => $_has(24);
  @$pb.TagNumber(30)
  void clearDiscount() => $_clearField(30);
  @$pb.TagNumber(30)
  DiscountUpdate ensureDiscount() => $_ensure(24);
}

class UserInsert extends $pb.GeneratedMessage {
  factory UserInsert({
    $core.String? id,
    $core.String? phone,
    $core.String? email,
    $core.String? name,
    $core.int? level,
    $core.int? status,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (phone != null) result.phone = phone;
    if (email != null) result.email = email;
    if (name != null) result.name = name;
    if (level != null) result.level = level;
    if (status != null) result.status = status;
    return result;
  }

  UserInsert._();

  factory UserInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'phone')
    ..aOS(3, _omitFieldNames ? '' : 'email')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aI(5, _omitFieldNames ? '' : 'level')
    ..aI(6, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInsert copyWith(void Function(UserInsert) updates) =>
      super.copyWith((message) => updates(message as UserInsert)) as UserInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserInsert create() => UserInsert._();
  @$core.override
  UserInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserInsert>(create);
  static UserInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get phone => $_getSZ(1);
  @$pb.TagNumber(2)
  set phone($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPhone() => $_has(1);
  @$pb.TagNumber(2)
  void clearPhone() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get email => $_getSZ(2);
  @$pb.TagNumber(3)
  set email($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmail() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get level => $_getIZ(4);
  @$pb.TagNumber(5)
  set level($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLevel() => $_has(4);
  @$pb.TagNumber(5)
  void clearLevel() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get status => $_getIZ(5);
  @$pb.TagNumber(6)
  set status($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);
}

class SchoolInsert extends $pb.GeneratedMessage {
  factory SchoolInsert({
    $core.String? id,
    $core.String? name,
    $core.String? motto,
    $core.String? phone,
    $core.String? email,
    $core.int? county,
    $core.String? domain,
    $core.int? established,
    $core.int? status,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (motto != null) result.motto = motto;
    if (phone != null) result.phone = phone;
    if (email != null) result.email = email;
    if (county != null) result.county = county;
    if (domain != null) result.domain = domain;
    if (established != null) result.established = established;
    if (status != null) result.status = status;
    return result;
  }

  SchoolInsert._();

  factory SchoolInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchoolInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchoolInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'motto')
    ..aOS(4, _omitFieldNames ? '' : 'phone')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aI(6, _omitFieldNames ? '' : 'county')
    ..aOS(7, _omitFieldNames ? '' : 'domain')
    ..aI(8, _omitFieldNames ? '' : 'established')
    ..aI(9, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchoolInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchoolInsert copyWith(void Function(SchoolInsert) updates) =>
      super.copyWith((message) => updates(message as SchoolInsert))
          as SchoolInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchoolInsert create() => SchoolInsert._();
  @$core.override
  SchoolInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchoolInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchoolInsert>(create);
  static SchoolInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get motto => $_getSZ(2);
  @$pb.TagNumber(3)
  set motto($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMotto() => $_has(2);
  @$pb.TagNumber(3)
  void clearMotto() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get phone => $_getSZ(3);
  @$pb.TagNumber(4)
  set phone($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPhone() => $_has(3);
  @$pb.TagNumber(4)
  void clearPhone() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get county => $_getIZ(5);
  @$pb.TagNumber(6)
  set county($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCounty() => $_has(5);
  @$pb.TagNumber(6)
  void clearCounty() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get domain => $_getSZ(6);
  @$pb.TagNumber(7)
  set domain($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDomain() => $_has(6);
  @$pb.TagNumber(7)
  void clearDomain() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get established => $_getIZ(7);
  @$pb.TagNumber(8)
  set established($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEstablished() => $_has(7);
  @$pb.TagNumber(8)
  void clearEstablished() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);
}

class OwnerInsert extends $pb.GeneratedMessage {
  factory OwnerInsert({
    $core.String? school,
    $core.String? user,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    return result;
  }

  OwnerInsert._();

  factory OwnerInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OwnerInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OwnerInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OwnerInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OwnerInsert copyWith(void Function(OwnerInsert) updates) =>
      super.copyWith((message) => updates(message as OwnerInsert))
          as OwnerInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OwnerInsert create() => OwnerInsert._();
  @$core.override
  OwnerInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OwnerInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OwnerInsert>(create);
  static OwnerInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get user => $_getSZ(1);
  @$pb.TagNumber(2)
  set user($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
}

class StudentInsert extends $pb.GeneratedMessage {
  factory StudentInsert({
    $core.String? school,
    $core.int? adm,
    $core.String? user,
    $core.String? name,
    $core.int? dob,
    $core.int? gender,
    $core.String? documents,
    $core.int? admitted,
    $core.int? status,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (adm != null) result.adm = adm;
    if (user != null) result.user = user;
    if (name != null) result.name = name;
    if (dob != null) result.dob = dob;
    if (gender != null) result.gender = gender;
    if (documents != null) result.documents = documents;
    if (admitted != null) result.admitted = admitted;
    if (status != null) result.status = status;
    return result;
  }

  StudentInsert._();

  factory StudentInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudentInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudentInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'adm')
    ..aOS(3, _omitFieldNames ? '' : 'user')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aI(5, _omitFieldNames ? '' : 'dob')
    ..aI(6, _omitFieldNames ? '' : 'gender')
    ..aOS(7, _omitFieldNames ? '' : 'documents')
    ..aI(8, _omitFieldNames ? '' : 'admitted')
    ..aI(9, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentInsert copyWith(void Function(StudentInsert) updates) =>
      super.copyWith((message) => updates(message as StudentInsert))
          as StudentInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudentInsert create() => StudentInsert._();
  @$core.override
  StudentInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudentInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudentInsert>(create);
  static StudentInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get adm => $_getIZ(1);
  @$pb.TagNumber(2)
  set adm($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAdm() => $_has(1);
  @$pb.TagNumber(2)
  void clearAdm() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get user => $_getSZ(2);
  @$pb.TagNumber(3)
  set user($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearUser() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get dob => $_getIZ(4);
  @$pb.TagNumber(5)
  set dob($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDob() => $_has(4);
  @$pb.TagNumber(5)
  void clearDob() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get gender => $_getIZ(5);
  @$pb.TagNumber(6)
  set gender($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGender() => $_has(5);
  @$pb.TagNumber(6)
  void clearGender() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get documents => $_getSZ(6);
  @$pb.TagNumber(7)
  set documents($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDocuments() => $_has(6);
  @$pb.TagNumber(7)
  void clearDocuments() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get admitted => $_getIZ(7);
  @$pb.TagNumber(8)
  set admitted($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAdmitted() => $_has(7);
  @$pb.TagNumber(8)
  void clearAdmitted() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);
}

class GuardianInsert extends $pb.GeneratedMessage {
  factory GuardianInsert({
    $core.String? school,
    $core.String? user,
    $core.int? student,
    $core.int? relationship,
    $core.int? role,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    if (student != null) result.student = student;
    if (relationship != null) result.relationship = relationship;
    if (role != null) result.role = role;
    return result;
  }

  GuardianInsert._();

  factory GuardianInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GuardianInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GuardianInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aI(3, _omitFieldNames ? '' : 'student')
    ..aI(4, _omitFieldNames ? '' : 'relationship')
    ..aI(5, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuardianInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuardianInsert copyWith(void Function(GuardianInsert) updates) =>
      super.copyWith((message) => updates(message as GuardianInsert))
          as GuardianInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GuardianInsert create() => GuardianInsert._();
  @$core.override
  GuardianInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GuardianInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GuardianInsert>(create);
  static GuardianInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get user => $_getSZ(1);
  @$pb.TagNumber(2)
  set user($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get student => $_getIZ(2);
  @$pb.TagNumber(3)
  set student($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStudent() => $_has(2);
  @$pb.TagNumber(3)
  void clearStudent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get relationship => $_getIZ(3);
  @$pb.TagNumber(4)
  set relationship($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRelationship() => $_has(3);
  @$pb.TagNumber(4)
  void clearRelationship() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get role => $_getIZ(4);
  @$pb.TagNumber(5)
  set role($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRole() => $_has(4);
  @$pb.TagNumber(5)
  void clearRole() => $_clearField(5);
}

class DepartmentInsert extends $pb.GeneratedMessage {
  factory DepartmentInsert({
    $core.String? school,
    $core.String? name,
    $core.String? description,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    return result;
  }

  DepartmentInsert._();

  factory DepartmentInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DepartmentInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DepartmentInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DepartmentInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DepartmentInsert copyWith(void Function(DepartmentInsert) updates) =>
      super.copyWith((message) => updates(message as DepartmentInsert))
          as DepartmentInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DepartmentInsert create() => DepartmentInsert._();
  @$core.override
  DepartmentInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DepartmentInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DepartmentInsert>(create);
  static DepartmentInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);
}

class TeacherInsert extends $pb.GeneratedMessage {
  factory TeacherInsert({
    $core.String? school,
    $core.String? user,
    $core.int? hired,
    $core.String? role,
    $core.String? department,
    $core.int? status,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    if (hired != null) result.hired = hired;
    if (role != null) result.role = role;
    if (department != null) result.department = department;
    if (status != null) result.status = status;
    return result;
  }

  TeacherInsert._();

  factory TeacherInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TeacherInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TeacherInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aI(3, _omitFieldNames ? '' : 'hired')
    ..aOS(4, _omitFieldNames ? '' : 'role')
    ..aOS(5, _omitFieldNames ? '' : 'department')
    ..aI(6, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TeacherInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TeacherInsert copyWith(void Function(TeacherInsert) updates) =>
      super.copyWith((message) => updates(message as TeacherInsert))
          as TeacherInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TeacherInsert create() => TeacherInsert._();
  @$core.override
  TeacherInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TeacherInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TeacherInsert>(create);
  static TeacherInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get user => $_getSZ(1);
  @$pb.TagNumber(2)
  set user($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get hired => $_getIZ(2);
  @$pb.TagNumber(3)
  set hired($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHired() => $_has(2);
  @$pb.TagNumber(3)
  void clearHired() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get role => $_getSZ(3);
  @$pb.TagNumber(4)
  set role($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get department => $_getSZ(4);
  @$pb.TagNumber(5)
  set department($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDepartment() => $_has(4);
  @$pb.TagNumber(5)
  void clearDepartment() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get status => $_getIZ(5);
  @$pb.TagNumber(6)
  set status($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);
}

class StaffInsert extends $pb.GeneratedMessage {
  factory StaffInsert({
    $core.String? school,
    $core.String? user,
    $core.String? idnumber,
    $core.String? role,
    $core.String? department,
    $core.int? status,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    if (idnumber != null) result.idnumber = idnumber;
    if (role != null) result.role = role;
    if (department != null) result.department = department;
    if (status != null) result.status = status;
    return result;
  }

  StaffInsert._();

  factory StaffInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StaffInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StaffInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aOS(3, _omitFieldNames ? '' : 'idnumber')
    ..aOS(4, _omitFieldNames ? '' : 'role')
    ..aOS(5, _omitFieldNames ? '' : 'department')
    ..aI(6, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StaffInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StaffInsert copyWith(void Function(StaffInsert) updates) =>
      super.copyWith((message) => updates(message as StaffInsert))
          as StaffInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StaffInsert create() => StaffInsert._();
  @$core.override
  StaffInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StaffInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StaffInsert>(create);
  static StaffInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get user => $_getSZ(1);
  @$pb.TagNumber(2)
  set user($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get idnumber => $_getSZ(2);
  @$pb.TagNumber(3)
  set idnumber($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdnumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdnumber() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get role => $_getSZ(3);
  @$pb.TagNumber(4)
  set role($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get department => $_getSZ(4);
  @$pb.TagNumber(5)
  set department($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDepartment() => $_has(4);
  @$pb.TagNumber(5)
  void clearDepartment() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get status => $_getIZ(5);
  @$pb.TagNumber(6)
  set status($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);
}

class TermInsert extends $pb.GeneratedMessage {
  factory TermInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    return result;
  }

  TermInsert._();

  factory TermInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TermInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TermInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aInt64(4, _omitFieldNames ? '' : 'start')
    ..aInt64(5, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermInsert copyWith(void Function(TermInsert) updates) =>
      super.copyWith((message) => updates(message as TermInsert)) as TermInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TermInsert create() => TermInsert._();
  @$core.override
  TermInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TermInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TermInsert>(create);
  static TermInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get start => $_getI64(3);
  @$pb.TagNumber(4)
  set start($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get end => $_getI64(4);
  @$pb.TagNumber(5)
  set end($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnd() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnd() => $_clearField(5);
}

class ClassTeacherInsert extends $pb.GeneratedMessage {
  factory ClassTeacherInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.String? teacher,
    $core.int? start,
    $core.int? end,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (teacher != null) result.teacher = teacher;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    return result;
  }

  ClassTeacherInsert._();

  factory ClassTeacherInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClassTeacherInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClassTeacherInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aOS(6, _omitFieldNames ? '' : 'teacher')
    ..aI(7, _omitFieldNames ? '' : 'start')
    ..aI(8, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClassTeacherInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClassTeacherInsert copyWith(void Function(ClassTeacherInsert) updates) =>
      super.copyWith((message) => updates(message as ClassTeacherInsert))
          as ClassTeacherInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClassTeacherInsert create() => ClassTeacherInsert._();
  @$core.override
  ClassTeacherInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClassTeacherInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClassTeacherInsert>(create);
  static ClassTeacherInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

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
  $core.String get teacher => $_getSZ(5);
  @$pb.TagNumber(6)
  set teacher($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTeacher() => $_has(5);
  @$pb.TagNumber(6)
  void clearTeacher() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get start => $_getIZ(6);
  @$pb.TagNumber(7)
  set start($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStart() => $_has(6);
  @$pb.TagNumber(7)
  void clearStart() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get end => $_getIZ(7);
  @$pb.TagNumber(8)
  set end($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEnd() => $_has(7);
  @$pb.TagNumber(8)
  void clearEnd() => $_clearField(8);
}

class EnrollmentInsert extends $pb.GeneratedMessage {
  factory EnrollmentInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? student,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (student != null) result.student = student;
    return result;
  }

  EnrollmentInsert._();

  factory EnrollmentInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EnrollmentInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnrollmentInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'student')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnrollmentInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnrollmentInsert copyWith(void Function(EnrollmentInsert) updates) =>
      super.copyWith((message) => updates(message as EnrollmentInsert))
          as EnrollmentInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnrollmentInsert create() => EnrollmentInsert._();
  @$core.override
  EnrollmentInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EnrollmentInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnrollmentInsert>(create);
  static EnrollmentInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

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
  $core.int get student => $_getIZ(5);
  @$pb.TagNumber(6)
  set student($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStudent() => $_has(5);
  @$pb.TagNumber(6)
  void clearStudent() => $_clearField(6);
}

class SubjectInsert extends $pb.GeneratedMessage {
  factory SubjectInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? subject,
    $core.String? teacher,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (subject != null) result.subject = subject;
    if (teacher != null) result.teacher = teacher;
    return result;
  }

  SubjectInsert._();

  factory SubjectInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubjectInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubjectInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'subject')
    ..aOS(7, _omitFieldNames ? '' : 'teacher')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubjectInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubjectInsert copyWith(void Function(SubjectInsert) updates) =>
      super.copyWith((message) => updates(message as SubjectInsert))
          as SubjectInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubjectInsert create() => SubjectInsert._();
  @$core.override
  SubjectInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubjectInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubjectInsert>(create);
  static SubjectInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

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
  $core.int get subject => $_getIZ(5);
  @$pb.TagNumber(6)
  set subject($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSubject() => $_has(5);
  @$pb.TagNumber(6)
  void clearSubject() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get teacher => $_getSZ(6);
  @$pb.TagNumber(7)
  set teacher($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTeacher() => $_has(6);
  @$pb.TagNumber(7)
  void clearTeacher() => $_clearField(7);
}

class AttendanceInsert extends $pb.GeneratedMessage {
  factory AttendanceInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? student,
    $core.int? date,
    $core.int? status,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (student != null) result.student = student;
    if (date != null) result.date = date;
    if (status != null) result.status = status;
    return result;
  }

  AttendanceInsert._();

  factory AttendanceInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttendanceInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttendanceInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'student')
    ..aI(7, _omitFieldNames ? '' : 'date')
    ..aI(8, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttendanceInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttendanceInsert copyWith(void Function(AttendanceInsert) updates) =>
      super.copyWith((message) => updates(message as AttendanceInsert))
          as AttendanceInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttendanceInsert create() => AttendanceInsert._();
  @$core.override
  AttendanceInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttendanceInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttendanceInsert>(create);
  static AttendanceInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

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
  $core.int get student => $_getIZ(5);
  @$pb.TagNumber(6)
  set student($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStudent() => $_has(5);
  @$pb.TagNumber(6)
  void clearStudent() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get date => $_getIZ(6);
  @$pb.TagNumber(7)
  set date($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearDate() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get status => $_getIZ(7);
  @$pb.TagNumber(8)
  set status($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);
}

class TimetableInsert extends $pb.GeneratedMessage {
  factory TimetableInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? subject,
    $core.String? teacher,
    $core.int? day,
    $core.int? start,
    $core.int? end,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (subject != null) result.subject = subject;
    if (teacher != null) result.teacher = teacher;
    if (day != null) result.day = day;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    return result;
  }

  TimetableInsert._();

  factory TimetableInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TimetableInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimetableInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'subject')
    ..aOS(7, _omitFieldNames ? '' : 'teacher')
    ..aI(8, _omitFieldNames ? '' : 'day')
    ..aI(9, _omitFieldNames ? '' : 'start')
    ..aI(10, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimetableInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimetableInsert copyWith(void Function(TimetableInsert) updates) =>
      super.copyWith((message) => updates(message as TimetableInsert))
          as TimetableInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TimetableInsert create() => TimetableInsert._();
  @$core.override
  TimetableInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TimetableInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TimetableInsert>(create);
  static TimetableInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

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
  $core.int get subject => $_getIZ(5);
  @$pb.TagNumber(6)
  set subject($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSubject() => $_has(5);
  @$pb.TagNumber(6)
  void clearSubject() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get teacher => $_getSZ(6);
  @$pb.TagNumber(7)
  set teacher($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTeacher() => $_has(6);
  @$pb.TagNumber(7)
  void clearTeacher() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get day => $_getIZ(7);
  @$pb.TagNumber(8)
  set day($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDay() => $_has(7);
  @$pb.TagNumber(8)
  void clearDay() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get start => $_getIZ(8);
  @$pb.TagNumber(9)
  set start($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStart() => $_has(8);
  @$pb.TagNumber(9)
  void clearStart() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get end => $_getIZ(9);
  @$pb.TagNumber(10)
  set end($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEnd() => $_has(9);
  @$pb.TagNumber(10)
  void clearEnd() => $_clearField(10);
}

class LessonInsert extends $pb.GeneratedMessage {
  factory LessonInsert({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? date,
    $core.int? subject,
    $core.String? teacher,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (date != null) result.date = date;
    if (subject != null) result.subject = subject;
    if (teacher != null) result.teacher = teacher;
    return result;
  }

  LessonInsert._();

  factory LessonInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LessonInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LessonInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'date')
    ..aI(7, _omitFieldNames ? '' : 'subject')
    ..aOS(8, _omitFieldNames ? '' : 'teacher')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LessonInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LessonInsert copyWith(void Function(LessonInsert) updates) =>
      super.copyWith((message) => updates(message as LessonInsert))
          as LessonInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LessonInsert create() => LessonInsert._();
  @$core.override
  LessonInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LessonInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LessonInsert>(create);
  static LessonInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get term => $_getIZ(2);
  @$pb.TagNumber(3)
  set term($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerm() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerm() => $_clearField(3);

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
  $core.int get subject => $_getIZ(6);
  @$pb.TagNumber(7)
  set subject($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSubject() => $_has(6);
  @$pb.TagNumber(7)
  void clearSubject() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get teacher => $_getSZ(7);
  @$pb.TagNumber(8)
  set teacher($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTeacher() => $_has(7);
  @$pb.TagNumber(8)
  void clearTeacher() => $_clearField(8);
}

class ExamInsert extends $pb.GeneratedMessage {
  factory ExamInsert({
    $core.String? id,
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.bool? personalized,
    $core.int? type,
    $core.int? start,
    $core.int? end,
    $core.String? teacher,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (personalized != null) result.personalized = personalized;
    if (type != null) result.type = type;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (teacher != null) result.teacher = teacher;
    return result;
  }

  ExamInsert._();

  factory ExamInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExamInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExamInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aOB(7, _omitFieldNames ? '' : 'personalized')
    ..aI(8, _omitFieldNames ? '' : 'type')
    ..aI(9, _omitFieldNames ? '' : 'start')
    ..aI(10, _omitFieldNames ? '' : 'end')
    ..aOS(11, _omitFieldNames ? '' : 'teacher')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamInsert copyWith(void Function(ExamInsert) updates) =>
      super.copyWith((message) => updates(message as ExamInsert)) as ExamInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExamInsert create() => ExamInsert._();
  @$core.override
  ExamInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExamInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExamInsert>(create);
  static ExamInsert? _defaultInstance;

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
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

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
  $core.bool get personalized => $_getBF(6);
  @$pb.TagNumber(7)
  set personalized($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPersonalized() => $_has(6);
  @$pb.TagNumber(7)
  void clearPersonalized() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get type => $_getIZ(7);
  @$pb.TagNumber(8)
  set type($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasType() => $_has(7);
  @$pb.TagNumber(8)
  void clearType() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get start => $_getIZ(8);
  @$pb.TagNumber(9)
  set start($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStart() => $_has(8);
  @$pb.TagNumber(9)
  void clearStart() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get end => $_getIZ(9);
  @$pb.TagNumber(10)
  set end($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEnd() => $_has(9);
  @$pb.TagNumber(10)
  void clearEnd() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get teacher => $_getSZ(10);
  @$pb.TagNumber(11)
  set teacher($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTeacher() => $_has(10);
  @$pb.TagNumber(11)
  void clearTeacher() => $_clearField(11);
}

class PaperInsert extends $pb.GeneratedMessage {
  factory PaperInsert({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.String? invigilator,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
    $core.int? status,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (invigilator != null) result.invigilator = invigilator;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (status != null) result.status = status;
    return result;
  }

  PaperInsert._();

  factory PaperInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaperInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaperInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aOS(5, _omitFieldNames ? '' : 'invigilator')
    ..aInt64(6, _omitFieldNames ? '' : 'start')
    ..aInt64(7, _omitFieldNames ? '' : 'end')
    ..aI(8, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperInsert copyWith(void Function(PaperInsert) updates) =>
      super.copyWith((message) => updates(message as PaperInsert))
          as PaperInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaperInsert create() => PaperInsert._();
  @$core.override
  PaperInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaperInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaperInsert>(create);
  static PaperInsert? _defaultInstance;

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
  $core.String get invigilator => $_getSZ(4);
  @$pb.TagNumber(5)
  set invigilator($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInvigilator() => $_has(4);
  @$pb.TagNumber(5)
  void clearInvigilator() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get start => $_getI64(5);
  @$pb.TagNumber(6)
  set start($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStart() => $_has(5);
  @$pb.TagNumber(6)
  void clearStart() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get end => $_getI64(6);
  @$pb.TagNumber(7)
  set end($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEnd() => $_has(6);
  @$pb.TagNumber(7)
  void clearEnd() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get status => $_getIZ(7);
  @$pb.TagNumber(8)
  set status($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);
}

class GradeInsert extends $pb.GeneratedMessage {
  factory GradeInsert({
    $core.String? school,
    $core.String? exam,
    $core.int? student,
    $core.int? subject,
    $core.int? paper,
    $core.double? score,
    $core.int? total,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (student != null) result.student = student;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (score != null) result.score = score;
    if (total != null) result.total = total;
    return result;
  }

  GradeInsert._();

  factory GradeInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GradeInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GradeInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'student')
    ..aI(4, _omitFieldNames ? '' : 'subject')
    ..aI(5, _omitFieldNames ? '' : 'paper')
    ..aD(6, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..aI(7, _omitFieldNames ? '' : 'total')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeInsert copyWith(void Function(GradeInsert) updates) =>
      super.copyWith((message) => updates(message as GradeInsert))
          as GradeInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GradeInsert create() => GradeInsert._();
  @$core.override
  GradeInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GradeInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GradeInsert>(create);
  static GradeInsert? _defaultInstance;

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
  $core.double get score => $_getN(5);
  @$pb.TagNumber(6)
  set score($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScore() => $_has(5);
  @$pb.TagNumber(6)
  void clearScore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get total => $_getIZ(6);
  @$pb.TagNumber(7)
  set total($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotal() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotal() => $_clearField(7);
}

class FeeInsert extends $pb.GeneratedMessage {
  factory FeeInsert({
    $core.String? id,
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.String? title,
    $core.String? description,
    $core.double? amount,
    $core.bool? mandatory,
    $fixnum.Int64? due,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (title != null) result.title = title;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (mandatory != null) result.mandatory = mandatory;
    if (due != null) result.due = due;
    return result;
  }

  FeeInsert._();

  factory FeeInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FeeInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FeeInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aOS(6, _omitFieldNames ? '' : 'title')
    ..aOS(7, _omitFieldNames ? '' : 'description')
    ..aD(8, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aOB(9, _omitFieldNames ? '' : 'mandatory')
    ..aInt64(10, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeeInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeeInsert copyWith(void Function(FeeInsert) updates) =>
      super.copyWith((message) => updates(message as FeeInsert)) as FeeInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FeeInsert create() => FeeInsert._();
  @$core.override
  FeeInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FeeInsert getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FeeInsert>(create);
  static FeeInsert? _defaultInstance;

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
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get title => $_getSZ(5);
  @$pb.TagNumber(6)
  set title($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTitle() => $_has(5);
  @$pb.TagNumber(6)
  void clearTitle() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get description => $_getSZ(6);
  @$pb.TagNumber(7)
  set description($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDescription() => $_has(6);
  @$pb.TagNumber(7)
  void clearDescription() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get amount => $_getN(7);
  @$pb.TagNumber(8)
  set amount($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAmount() => $_has(7);
  @$pb.TagNumber(8)
  void clearAmount() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get mandatory => $_getBF(8);
  @$pb.TagNumber(9)
  set mandatory($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMandatory() => $_has(8);
  @$pb.TagNumber(9)
  void clearMandatory() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get due => $_getI64(9);
  @$pb.TagNumber(10)
  set due($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDue() => $_has(9);
  @$pb.TagNumber(10)
  void clearDue() => $_clearField(10);
}

class InvoiceInsert extends $pb.GeneratedMessage {
  factory InvoiceInsert({
    $core.String? id,
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.String? fee,
    $core.String? description,
    $core.int? student,
    $core.double? amount,
    $core.int? status,
    $fixnum.Int64? due,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (fee != null) result.fee = fee;
    if (description != null) result.description = description;
    if (student != null) result.student = student;
    if (amount != null) result.amount = amount;
    if (status != null) result.status = status;
    if (due != null) result.due = due;
    return result;
  }

  InvoiceInsert._();

  factory InvoiceInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InvoiceInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InvoiceInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aOS(5, _omitFieldNames ? '' : 'fee')
    ..aOS(6, _omitFieldNames ? '' : 'description')
    ..aI(7, _omitFieldNames ? '' : 'student')
    ..aD(8, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(9, _omitFieldNames ? '' : 'status')
    ..aInt64(10, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InvoiceInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InvoiceInsert copyWith(void Function(InvoiceInsert) updates) =>
      super.copyWith((message) => updates(message as InvoiceInsert))
          as InvoiceInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InvoiceInsert create() => InvoiceInsert._();
  @$core.override
  InvoiceInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InvoiceInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InvoiceInsert>(create);
  static InvoiceInsert? _defaultInstance;

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
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fee => $_getSZ(4);
  @$pb.TagNumber(5)
  set fee($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFee() => $_has(4);
  @$pb.TagNumber(5)
  void clearFee() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get student => $_getIZ(6);
  @$pb.TagNumber(7)
  set student($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStudent() => $_has(6);
  @$pb.TagNumber(7)
  void clearStudent() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get amount => $_getN(7);
  @$pb.TagNumber(8)
  set amount($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAmount() => $_has(7);
  @$pb.TagNumber(8)
  void clearAmount() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get due => $_getI64(9);
  @$pb.TagNumber(10)
  set due($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDue() => $_has(9);
  @$pb.TagNumber(10)
  void clearDue() => $_clearField(10);
}

class PaymentInsert extends $pb.GeneratedMessage {
  factory PaymentInsert({
    $core.String? id,
    $core.String? invoice,
    $core.String? school,
    $core.int? student,
    $core.double? amount,
    $core.int? method,
    $core.String? reference,
    $core.String? recorder,
    $core.int? date,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (invoice != null) result.invoice = invoice;
    if (school != null) result.school = school;
    if (student != null) result.student = student;
    if (amount != null) result.amount = amount;
    if (method != null) result.method = method;
    if (reference != null) result.reference = reference;
    if (recorder != null) result.recorder = recorder;
    if (date != null) result.date = date;
    return result;
  }

  PaymentInsert._();

  factory PaymentInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'invoice')
    ..aOS(3, _omitFieldNames ? '' : 'school')
    ..aI(4, _omitFieldNames ? '' : 'student')
    ..aD(5, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(6, _omitFieldNames ? '' : 'method')
    ..aOS(7, _omitFieldNames ? '' : 'reference')
    ..aOS(8, _omitFieldNames ? '' : 'recorder')
    ..aI(9, _omitFieldNames ? '' : 'date')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentInsert copyWith(void Function(PaymentInsert) updates) =>
      super.copyWith((message) => updates(message as PaymentInsert))
          as PaymentInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentInsert create() => PaymentInsert._();
  @$core.override
  PaymentInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaymentInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentInsert>(create);
  static PaymentInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get invoice => $_getSZ(1);
  @$pb.TagNumber(2)
  set invoice($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInvoice() => $_has(1);
  @$pb.TagNumber(2)
  void clearInvoice() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get school => $_getSZ(2);
  @$pb.TagNumber(3)
  set school($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchool() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchool() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get student => $_getIZ(3);
  @$pb.TagNumber(4)
  set student($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStudent() => $_has(3);
  @$pb.TagNumber(4)
  void clearStudent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get amount => $_getN(4);
  @$pb.TagNumber(5)
  set amount($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAmount() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get method => $_getIZ(5);
  @$pb.TagNumber(6)
  set method($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMethod() => $_has(5);
  @$pb.TagNumber(6)
  void clearMethod() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get reference => $_getSZ(6);
  @$pb.TagNumber(7)
  set reference($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReference() => $_has(6);
  @$pb.TagNumber(7)
  void clearReference() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get recorder => $_getSZ(7);
  @$pb.TagNumber(8)
  set recorder($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRecorder() => $_has(7);
  @$pb.TagNumber(8)
  void clearRecorder() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get date => $_getIZ(8);
  @$pb.TagNumber(9)
  set date($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDate() => $_has(8);
  @$pb.TagNumber(9)
  void clearDate() => $_clearField(9);
}

class AnnouncementInsert extends $pb.GeneratedMessage {
  factory AnnouncementInsert({
    $core.String? id,
    $core.String? school,
    $core.String? title,
    $core.String? content,
    $core.int? grade,
    $core.int? stream,
    $core.int? audience,
    $core.String? author,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (title != null) result.title = title;
    if (content != null) result.content = content;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (audience != null) result.audience = audience;
    if (author != null) result.author = author;
    return result;
  }

  AnnouncementInsert._();

  factory AnnouncementInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnnouncementInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnnouncementInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aI(6, _omitFieldNames ? '' : 'stream')
    ..aI(7, _omitFieldNames ? '' : 'audience')
    ..aOS(8, _omitFieldNames ? '' : 'author')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnnouncementInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnnouncementInsert copyWith(void Function(AnnouncementInsert) updates) =>
      super.copyWith((message) => updates(message as AnnouncementInsert))
          as AnnouncementInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnnouncementInsert create() => AnnouncementInsert._();
  @$core.override
  AnnouncementInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnnouncementInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnnouncementInsert>(create);
  static AnnouncementInsert? _defaultInstance;

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
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

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
  $core.int get audience => $_getIZ(6);
  @$pb.TagNumber(7)
  set audience($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAudience() => $_has(6);
  @$pb.TagNumber(7)
  void clearAudience() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get author => $_getSZ(7);
  @$pb.TagNumber(8)
  set author($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAuthor() => $_has(7);
  @$pb.TagNumber(8)
  void clearAuthor() => $_clearField(8);
}

class MasteryInsert extends $pb.GeneratedMessage {
  factory MasteryInsert({
    $core.String? school,
    $core.int? student,
    $core.int? grade,
    $core.int? subject,
    $core.int? topic,
    $core.double? score,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (student != null) result.student = student;
    if (grade != null) result.grade = grade;
    if (subject != null) result.subject = subject;
    if (topic != null) result.topic = topic;
    if (score != null) result.score = score;
    return result;
  }

  MasteryInsert._();

  factory MasteryInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MasteryInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MasteryInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'student')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aI(4, _omitFieldNames ? '' : 'subject')
    ..aI(5, _omitFieldNames ? '' : 'topic')
    ..aD(6, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MasteryInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MasteryInsert copyWith(void Function(MasteryInsert) updates) =>
      super.copyWith((message) => updates(message as MasteryInsert))
          as MasteryInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MasteryInsert create() => MasteryInsert._();
  @$core.override
  MasteryInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MasteryInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MasteryInsert>(create);
  static MasteryInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get student => $_getIZ(1);
  @$pb.TagNumber(2)
  set student($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStudent() => $_has(1);
  @$pb.TagNumber(2)
  void clearStudent() => $_clearField(2);

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

  @$pb.TagNumber(5)
  $core.int get topic => $_getIZ(4);
  @$pb.TagNumber(5)
  set topic($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTopic() => $_has(4);
  @$pb.TagNumber(5)
  void clearTopic() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get score => $_getN(5);
  @$pb.TagNumber(6)
  set score($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScore() => $_has(5);
  @$pb.TagNumber(6)
  void clearScore() => $_clearField(6);
}

class AiUsageInsert extends $pb.GeneratedMessage {
  factory AiUsageInsert({
    $core.String? school,
    $core.int? student,
    $core.int? year,
    $core.int? term,
    $core.int? allocated,
    $core.int? used,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (student != null) result.student = student;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (allocated != null) result.allocated = allocated;
    if (used != null) result.used = used;
    return result;
  }

  AiUsageInsert._();

  factory AiUsageInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AiUsageInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AiUsageInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'student')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'allocated')
    ..aI(6, _omitFieldNames ? '' : 'used')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AiUsageInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AiUsageInsert copyWith(void Function(AiUsageInsert) updates) =>
      super.copyWith((message) => updates(message as AiUsageInsert))
          as AiUsageInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AiUsageInsert create() => AiUsageInsert._();
  @$core.override
  AiUsageInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AiUsageInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AiUsageInsert>(create);
  static AiUsageInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get student => $_getIZ(1);
  @$pb.TagNumber(2)
  set student($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStudent() => $_has(1);
  @$pb.TagNumber(2)
  void clearStudent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get allocated => $_getIZ(4);
  @$pb.TagNumber(5)
  set allocated($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAllocated() => $_has(4);
  @$pb.TagNumber(5)
  void clearAllocated() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get used => $_getIZ(5);
  @$pb.TagNumber(6)
  set used($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUsed() => $_has(5);
  @$pb.TagNumber(6)
  void clearUsed() => $_clearField(6);
}

class SettingsInsert extends $pb.GeneratedMessage {
  factory SettingsInsert({
    $core.String? school,
    $core.String? data,
    $core.String? mpesa,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (data != null) result.data = data;
    if (mpesa != null) result.mpesa = mpesa;
    return result;
  }

  SettingsInsert._();

  factory SettingsInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettingsInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettingsInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'data')
    ..aOS(3, _omitFieldNames ? '' : 'mpesa')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsInsert copyWith(void Function(SettingsInsert) updates) =>
      super.copyWith((message) => updates(message as SettingsInsert))
          as SettingsInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettingsInsert create() => SettingsInsert._();
  @$core.override
  SettingsInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettingsInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettingsInsert>(create);
  static SettingsInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get data => $_getSZ(1);
  @$pb.TagNumber(2)
  set data($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get mpesa => $_getSZ(2);
  @$pb.TagNumber(3)
  set mpesa($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMpesa() => $_has(2);
  @$pb.TagNumber(3)
  void clearMpesa() => $_clearField(3);
}

class RoleInsert extends $pb.GeneratedMessage {
  factory RoleInsert({
    $core.String? id,
    $core.String? school,
    $core.String? name,
    $core.String? description,
    $core.List<$core.int>? permissions,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (permissions != null) result.permissions = permissions;
    return result;
  }

  RoleInsert._();

  factory RoleInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoleInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoleInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'permissions', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleInsert copyWith(void Function(RoleInsert) updates) =>
      super.copyWith((message) => updates(message as RoleInsert)) as RoleInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoleInsert create() => RoleInsert._();
  @$core.override
  RoleInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoleInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoleInsert>(create);
  static RoleInsert? _defaultInstance;

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
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get permissions => $_getN(4);
  @$pb.TagNumber(5)
  set permissions($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPermissions() => $_has(4);
  @$pb.TagNumber(5)
  void clearPermissions() => $_clearField(5);
}

class ScopeInsert extends $pb.GeneratedMessage {
  factory ScopeInsert({
    $core.String? school,
    $core.String? user,
    $core.String? role,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    if (role != null) result.role = role;
    return result;
  }

  ScopeInsert._();

  factory ScopeInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScopeInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScopeInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aOS(3, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScopeInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScopeInsert copyWith(void Function(ScopeInsert) updates) =>
      super.copyWith((message) => updates(message as ScopeInsert))
          as ScopeInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScopeInsert create() => ScopeInsert._();
  @$core.override
  ScopeInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScopeInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScopeInsert>(create);
  static ScopeInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get user => $_getSZ(1);
  @$pb.TagNumber(2)
  set user($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get role => $_getSZ(2);
  @$pb.TagNumber(3)
  set role($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);
}

class PlanInsert extends $pb.GeneratedMessage {
  factory PlanInsert({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.double? amount,
    $core.int? levels,
    $core.int? status,
    $core.String? features,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (levels != null) result.levels = levels;
    if (status != null) result.status = status;
    if (features != null) result.features = features;
    return result;
  }

  PlanInsert._();

  factory PlanInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlanInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aD(4, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'levels')
    ..aI(6, _omitFieldNames ? '' : 'status')
    ..aOS(7, _omitFieldNames ? '' : 'features')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanInsert copyWith(void Function(PlanInsert) updates) =>
      super.copyWith((message) => updates(message as PlanInsert)) as PlanInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlanInsert create() => PlanInsert._();
  @$core.override
  PlanInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlanInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanInsert>(create);
  static PlanInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get amount => $_getN(3);
  @$pb.TagNumber(4)
  set amount($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get levels => $_getIZ(4);
  @$pb.TagNumber(5)
  set levels($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLevels() => $_has(4);
  @$pb.TagNumber(5)
  void clearLevels() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get status => $_getIZ(5);
  @$pb.TagNumber(6)
  set status($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get features => $_getSZ(6);
  @$pb.TagNumber(7)
  set features($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFeatures() => $_has(6);
  @$pb.TagNumber(7)
  void clearFeatures() => $_clearField(7);
}

class SubscriptionInsert extends $pb.GeneratedMessage {
  factory SubscriptionInsert({
    $core.String? school,
    $core.String? plan,
    $core.int? year,
    $core.int? term,
    $core.int? student,
    $core.String? invoice,
    $core.double? discount,
    $core.int? status,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (plan != null) result.plan = plan;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (student != null) result.student = student;
    if (invoice != null) result.invoice = invoice;
    if (discount != null) result.discount = discount;
    if (status != null) result.status = status;
    return result;
  }

  SubscriptionInsert._();

  factory SubscriptionInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubscriptionInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscriptionInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'plan')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'student')
    ..aOS(6, _omitFieldNames ? '' : 'invoice')
    ..aD(7, _omitFieldNames ? '' : 'discount', fieldType: $pb.PbFieldType.OF)
    ..aI(8, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscriptionInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscriptionInsert copyWith(void Function(SubscriptionInsert) updates) =>
      super.copyWith((message) => updates(message as SubscriptionInsert))
          as SubscriptionInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscriptionInsert create() => SubscriptionInsert._();
  @$core.override
  SubscriptionInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubscriptionInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscriptionInsert>(create);
  static SubscriptionInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get plan => $_getSZ(1);
  @$pb.TagNumber(2)
  set plan($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlan() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlan() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get student => $_getIZ(4);
  @$pb.TagNumber(5)
  set student($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStudent() => $_has(4);
  @$pb.TagNumber(5)
  void clearStudent() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get invoice => $_getSZ(5);
  @$pb.TagNumber(6)
  set invoice($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInvoice() => $_has(5);
  @$pb.TagNumber(6)
  void clearInvoice() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get discount => $_getN(6);
  @$pb.TagNumber(7)
  set discount($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDiscount() => $_has(6);
  @$pb.TagNumber(7)
  void clearDiscount() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get status => $_getIZ(7);
  @$pb.TagNumber(8)
  set status($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);
}

class DiscountInsert extends $pb.GeneratedMessage {
  factory DiscountInsert({
    $core.String? school,
    $core.String? plan,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.double? amount,
    $core.int? unit,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (plan != null) result.plan = plan;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (amount != null) result.amount = amount;
    if (unit != null) result.unit = unit;
    return result;
  }

  DiscountInsert._();

  factory DiscountInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiscountInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscountInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'plan')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..aD(6, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(7, _omitFieldNames ? '' : 'unit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountInsert copyWith(void Function(DiscountInsert) updates) =>
      super.copyWith((message) => updates(message as DiscountInsert))
          as DiscountInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiscountInsert create() => DiscountInsert._();
  @$core.override
  DiscountInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiscountInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscountInsert>(create);
  static DiscountInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get plan => $_getSZ(1);
  @$pb.TagNumber(2)
  set plan($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlan() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlan() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get term => $_getIZ(3);
  @$pb.TagNumber(4)
  set term($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTerm() => $_has(3);
  @$pb.TagNumber(4)
  void clearTerm() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get grade => $_getIZ(4);
  @$pb.TagNumber(5)
  set grade($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearGrade() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get amount => $_getN(5);
  @$pb.TagNumber(6)
  set amount($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAmount() => $_has(5);
  @$pb.TagNumber(6)
  void clearAmount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get unit => $_getIZ(6);
  @$pb.TagNumber(7)
  set unit($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUnit() => $_has(6);
  @$pb.TagNumber(7)
  void clearUnit() => $_clearField(7);
}

class UserUpdate extends $pb.GeneratedMessage {
  factory UserUpdate({
    $core.String? phone,
    $core.String? email,
    $core.String? name,
    $core.int? level,
    $core.int? status,
  }) {
    final result = create();
    if (phone != null) result.phone = phone;
    if (email != null) result.email = email;
    if (name != null) result.name = name;
    if (level != null) result.level = level;
    if (status != null) result.status = status;
    return result;
  }

  UserUpdate._();

  factory UserUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'phone')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'level')
    ..aI(5, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserUpdate copyWith(void Function(UserUpdate) updates) =>
      super.copyWith((message) => updates(message as UserUpdate)) as UserUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserUpdate create() => UserUpdate._();
  @$core.override
  UserUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserUpdate>(create);
  static UserUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get phone => $_getSZ(0);
  @$pb.TagNumber(1)
  set phone($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPhone() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhone() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get level => $_getIZ(3);
  @$pb.TagNumber(4)
  set level($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLevel() => $_has(3);
  @$pb.TagNumber(4)
  void clearLevel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get status => $_getIZ(4);
  @$pb.TagNumber(5)
  set status($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);
}

class SchoolUpdate extends $pb.GeneratedMessage {
  factory SchoolUpdate({
    $core.String? name,
    $core.String? motto,
    $core.String? phone,
    $core.String? email,
    $core.int? county,
    $core.String? domain,
    $core.int? established,
    $core.int? status,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (motto != null) result.motto = motto;
    if (phone != null) result.phone = phone;
    if (email != null) result.email = email;
    if (county != null) result.county = county;
    if (domain != null) result.domain = domain;
    if (established != null) result.established = established;
    if (status != null) result.status = status;
    return result;
  }

  SchoolUpdate._();

  factory SchoolUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchoolUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchoolUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'motto')
    ..aOS(3, _omitFieldNames ? '' : 'phone')
    ..aOS(4, _omitFieldNames ? '' : 'email')
    ..aI(5, _omitFieldNames ? '' : 'county')
    ..aOS(6, _omitFieldNames ? '' : 'domain')
    ..aI(7, _omitFieldNames ? '' : 'established')
    ..aI(8, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchoolUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchoolUpdate copyWith(void Function(SchoolUpdate) updates) =>
      super.copyWith((message) => updates(message as SchoolUpdate))
          as SchoolUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchoolUpdate create() => SchoolUpdate._();
  @$core.override
  SchoolUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchoolUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchoolUpdate>(create);
  static SchoolUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get motto => $_getSZ(1);
  @$pb.TagNumber(2)
  set motto($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMotto() => $_has(1);
  @$pb.TagNumber(2)
  void clearMotto() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get phone => $_getSZ(2);
  @$pb.TagNumber(3)
  set phone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPhone() => $_has(2);
  @$pb.TagNumber(3)
  void clearPhone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get email => $_getSZ(3);
  @$pb.TagNumber(4)
  set email($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmail() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmail() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get county => $_getIZ(4);
  @$pb.TagNumber(5)
  set county($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCounty() => $_has(4);
  @$pb.TagNumber(5)
  void clearCounty() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get domain => $_getSZ(5);
  @$pb.TagNumber(6)
  set domain($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDomain() => $_has(5);
  @$pb.TagNumber(6)
  void clearDomain() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get established => $_getIZ(6);
  @$pb.TagNumber(7)
  set established($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEstablished() => $_has(6);
  @$pb.TagNumber(7)
  void clearEstablished() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get status => $_getIZ(7);
  @$pb.TagNumber(8)
  set status($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);
}

class StudentUpdate extends $pb.GeneratedMessage {
  factory StudentUpdate({
    $core.String? user,
    $core.String? name,
    $core.int? dob,
    $core.int? gender,
    $core.String? documents,
    $core.int? admitted,
    $core.int? status,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (name != null) result.name = name;
    if (dob != null) result.dob = dob;
    if (gender != null) result.gender = gender;
    if (documents != null) result.documents = documents;
    if (admitted != null) result.admitted = admitted;
    if (status != null) result.status = status;
    return result;
  }

  StudentUpdate._();

  factory StudentUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudentUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudentUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'user')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'dob')
    ..aI(4, _omitFieldNames ? '' : 'gender')
    ..aOS(5, _omitFieldNames ? '' : 'documents')
    ..aI(6, _omitFieldNames ? '' : 'admitted')
    ..aI(7, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudentUpdate copyWith(void Function(StudentUpdate) updates) =>
      super.copyWith((message) => updates(message as StudentUpdate))
          as StudentUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudentUpdate create() => StudentUpdate._();
  @$core.override
  StudentUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudentUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudentUpdate>(create);
  static StudentUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get user => $_getSZ(0);
  @$pb.TagNumber(1)
  set user($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get dob => $_getIZ(2);
  @$pb.TagNumber(3)
  set dob($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDob() => $_has(2);
  @$pb.TagNumber(3)
  void clearDob() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get gender => $_getIZ(3);
  @$pb.TagNumber(4)
  set gender($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGender() => $_has(3);
  @$pb.TagNumber(4)
  void clearGender() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get documents => $_getSZ(4);
  @$pb.TagNumber(5)
  set documents($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDocuments() => $_has(4);
  @$pb.TagNumber(5)
  void clearDocuments() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get admitted => $_getIZ(5);
  @$pb.TagNumber(6)
  set admitted($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAdmitted() => $_has(5);
  @$pb.TagNumber(6)
  void clearAdmitted() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get status => $_getIZ(6);
  @$pb.TagNumber(7)
  set status($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearStatus() => $_clearField(7);
}

class GuardianUpdate extends $pb.GeneratedMessage {
  factory GuardianUpdate({
    $core.int? relationship,
    $core.int? role,
  }) {
    final result = create();
    if (relationship != null) result.relationship = relationship;
    if (role != null) result.role = role;
    return result;
  }

  GuardianUpdate._();

  factory GuardianUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GuardianUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GuardianUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'relationship')
    ..aI(2, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuardianUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GuardianUpdate copyWith(void Function(GuardianUpdate) updates) =>
      super.copyWith((message) => updates(message as GuardianUpdate))
          as GuardianUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GuardianUpdate create() => GuardianUpdate._();
  @$core.override
  GuardianUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GuardianUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GuardianUpdate>(create);
  static GuardianUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get relationship => $_getIZ(0);
  @$pb.TagNumber(1)
  set relationship($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelationship() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelationship() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get role => $_getIZ(1);
  @$pb.TagNumber(2)
  set role($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);
}

class DepartmentUpdate extends $pb.GeneratedMessage {
  factory DepartmentUpdate({
    $core.String? description,
  }) {
    final result = create();
    if (description != null) result.description = description;
    return result;
  }

  DepartmentUpdate._();

  factory DepartmentUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DepartmentUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DepartmentUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DepartmentUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DepartmentUpdate copyWith(void Function(DepartmentUpdate) updates) =>
      super.copyWith((message) => updates(message as DepartmentUpdate))
          as DepartmentUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DepartmentUpdate create() => DepartmentUpdate._();
  @$core.override
  DepartmentUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DepartmentUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DepartmentUpdate>(create);
  static DepartmentUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get description => $_getSZ(0);
  @$pb.TagNumber(1)
  set description($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDescription() => $_has(0);
  @$pb.TagNumber(1)
  void clearDescription() => $_clearField(1);
}

class TeacherUpdate extends $pb.GeneratedMessage {
  factory TeacherUpdate({
    $core.int? hired,
    $core.String? role,
    $core.String? department,
    $core.int? status,
  }) {
    final result = create();
    if (hired != null) result.hired = hired;
    if (role != null) result.role = role;
    if (department != null) result.department = department;
    if (status != null) result.status = status;
    return result;
  }

  TeacherUpdate._();

  factory TeacherUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TeacherUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TeacherUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'hired')
    ..aOS(2, _omitFieldNames ? '' : 'role')
    ..aOS(3, _omitFieldNames ? '' : 'department')
    ..aI(4, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TeacherUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TeacherUpdate copyWith(void Function(TeacherUpdate) updates) =>
      super.copyWith((message) => updates(message as TeacherUpdate))
          as TeacherUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TeacherUpdate create() => TeacherUpdate._();
  @$core.override
  TeacherUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TeacherUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TeacherUpdate>(create);
  static TeacherUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get hired => $_getIZ(0);
  @$pb.TagNumber(1)
  set hired($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHired() => $_has(0);
  @$pb.TagNumber(1)
  void clearHired() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get role => $_getSZ(1);
  @$pb.TagNumber(2)
  set role($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get department => $_getSZ(2);
  @$pb.TagNumber(3)
  set department($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDepartment() => $_has(2);
  @$pb.TagNumber(3)
  void clearDepartment() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get status => $_getIZ(3);
  @$pb.TagNumber(4)
  set status($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);
}

class StaffUpdate extends $pb.GeneratedMessage {
  factory StaffUpdate({
    $core.String? idnumber,
    $core.String? role,
    $core.String? department,
    $core.int? status,
  }) {
    final result = create();
    if (idnumber != null) result.idnumber = idnumber;
    if (role != null) result.role = role;
    if (department != null) result.department = department;
    if (status != null) result.status = status;
    return result;
  }

  StaffUpdate._();

  factory StaffUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StaffUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StaffUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'idnumber')
    ..aOS(2, _omitFieldNames ? '' : 'role')
    ..aOS(3, _omitFieldNames ? '' : 'department')
    ..aI(4, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StaffUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StaffUpdate copyWith(void Function(StaffUpdate) updates) =>
      super.copyWith((message) => updates(message as StaffUpdate))
          as StaffUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StaffUpdate create() => StaffUpdate._();
  @$core.override
  StaffUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StaffUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StaffUpdate>(create);
  static StaffUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get idnumber => $_getSZ(0);
  @$pb.TagNumber(1)
  set idnumber($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIdnumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdnumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get role => $_getSZ(1);
  @$pb.TagNumber(2)
  set role($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get department => $_getSZ(2);
  @$pb.TagNumber(3)
  set department($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDepartment() => $_has(2);
  @$pb.TagNumber(3)
  void clearDepartment() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get status => $_getIZ(3);
  @$pb.TagNumber(4)
  set status($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);
}

class TermUpdate extends $pb.GeneratedMessage {
  factory TermUpdate({
    $fixnum.Int64? start,
    $fixnum.Int64? end,
  }) {
    final result = create();
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    return result;
  }

  TermUpdate._();

  factory TermUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TermUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TermUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'start')
    ..aInt64(2, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TermUpdate copyWith(void Function(TermUpdate) updates) =>
      super.copyWith((message) => updates(message as TermUpdate)) as TermUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TermUpdate create() => TermUpdate._();
  @$core.override
  TermUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TermUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TermUpdate>(create);
  static TermUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get start => $_getI64(0);
  @$pb.TagNumber(1)
  set start($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearStart() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get end => $_getI64(1);
  @$pb.TagNumber(2)
  set end($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnd() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnd() => $_clearField(2);
}

class ClassTeacherUpdate extends $pb.GeneratedMessage {
  factory ClassTeacherUpdate({
    $core.int? start,
    $core.int? end,
  }) {
    final result = create();
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    return result;
  }

  ClassTeacherUpdate._();

  factory ClassTeacherUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClassTeacherUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClassTeacherUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'start')
    ..aI(2, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClassTeacherUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClassTeacherUpdate copyWith(void Function(ClassTeacherUpdate) updates) =>
      super.copyWith((message) => updates(message as ClassTeacherUpdate))
          as ClassTeacherUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClassTeacherUpdate create() => ClassTeacherUpdate._();
  @$core.override
  ClassTeacherUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClassTeacherUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClassTeacherUpdate>(create);
  static ClassTeacherUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get start => $_getIZ(0);
  @$pb.TagNumber(1)
  set start($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearStart() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get end => $_getIZ(1);
  @$pb.TagNumber(2)
  set end($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnd() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnd() => $_clearField(2);
}

class AttendanceUpdate extends $pb.GeneratedMessage {
  factory AttendanceUpdate({
    $core.int? status,
  }) {
    final result = create();
    if (status != null) result.status = status;
    return result;
  }

  AttendanceUpdate._();

  factory AttendanceUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttendanceUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttendanceUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttendanceUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttendanceUpdate copyWith(void Function(AttendanceUpdate) updates) =>
      super.copyWith((message) => updates(message as AttendanceUpdate))
          as AttendanceUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttendanceUpdate create() => AttendanceUpdate._();
  @$core.override
  AttendanceUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttendanceUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttendanceUpdate>(create);
  static AttendanceUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get status => $_getIZ(0);
  @$pb.TagNumber(1)
  set status($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

class TimetableUpdate extends $pb.GeneratedMessage {
  factory TimetableUpdate({
    $core.String? teacher,
    $core.int? end,
  }) {
    final result = create();
    if (teacher != null) result.teacher = teacher;
    if (end != null) result.end = end;
    return result;
  }

  TimetableUpdate._();

  factory TimetableUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TimetableUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimetableUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'teacher')
    ..aI(2, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimetableUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimetableUpdate copyWith(void Function(TimetableUpdate) updates) =>
      super.copyWith((message) => updates(message as TimetableUpdate))
          as TimetableUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TimetableUpdate create() => TimetableUpdate._();
  @$core.override
  TimetableUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TimetableUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TimetableUpdate>(create);
  static TimetableUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get teacher => $_getSZ(0);
  @$pb.TagNumber(1)
  set teacher($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTeacher() => $_has(0);
  @$pb.TagNumber(1)
  void clearTeacher() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get end => $_getIZ(1);
  @$pb.TagNumber(2)
  set end($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnd() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnd() => $_clearField(2);
}

class ExamUpdate extends $pb.GeneratedMessage {
  factory ExamUpdate({
    $core.int? stream,
    $core.bool? personalized,
    $core.int? type,
    $core.int? start,
    $core.int? end,
    $core.String? teacher,
  }) {
    final result = create();
    if (stream != null) result.stream = stream;
    if (personalized != null) result.personalized = personalized;
    if (type != null) result.type = type;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (teacher != null) result.teacher = teacher;
    return result;
  }

  ExamUpdate._();

  factory ExamUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExamUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExamUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'stream')
    ..aOB(2, _omitFieldNames ? '' : 'personalized')
    ..aI(3, _omitFieldNames ? '' : 'type')
    ..aI(4, _omitFieldNames ? '' : 'start')
    ..aI(5, _omitFieldNames ? '' : 'end')
    ..aOS(6, _omitFieldNames ? '' : 'teacher')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamUpdate copyWith(void Function(ExamUpdate) updates) =>
      super.copyWith((message) => updates(message as ExamUpdate)) as ExamUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExamUpdate create() => ExamUpdate._();
  @$core.override
  ExamUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExamUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExamUpdate>(create);
  static ExamUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get stream => $_getIZ(0);
  @$pb.TagNumber(1)
  set stream($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStream() => $_has(0);
  @$pb.TagNumber(1)
  void clearStream() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get personalized => $_getBF(1);
  @$pb.TagNumber(2)
  set personalized($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPersonalized() => $_has(1);
  @$pb.TagNumber(2)
  void clearPersonalized() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get type => $_getIZ(2);
  @$pb.TagNumber(3)
  set type($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get start => $_getIZ(3);
  @$pb.TagNumber(4)
  set start($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get end => $_getIZ(4);
  @$pb.TagNumber(5)
  set end($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnd() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnd() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get teacher => $_getSZ(5);
  @$pb.TagNumber(6)
  set teacher($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTeacher() => $_has(5);
  @$pb.TagNumber(6)
  void clearTeacher() => $_clearField(6);
}

class PaperUpdate extends $pb.GeneratedMessage {
  factory PaperUpdate({
    $core.String? invigilator,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
    $core.int? status,
  }) {
    final result = create();
    if (invigilator != null) result.invigilator = invigilator;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (status != null) result.status = status;
    return result;
  }

  PaperUpdate._();

  factory PaperUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaperUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaperUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'invigilator')
    ..aInt64(2, _omitFieldNames ? '' : 'start')
    ..aInt64(3, _omitFieldNames ? '' : 'end')
    ..aI(4, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaperUpdate copyWith(void Function(PaperUpdate) updates) =>
      super.copyWith((message) => updates(message as PaperUpdate))
          as PaperUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaperUpdate create() => PaperUpdate._();
  @$core.override
  PaperUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaperUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaperUpdate>(create);
  static PaperUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get invigilator => $_getSZ(0);
  @$pb.TagNumber(1)
  set invigilator($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInvigilator() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvigilator() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get start => $_getI64(1);
  @$pb.TagNumber(2)
  set start($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearStart() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get end => $_getI64(2);
  @$pb.TagNumber(3)
  set end($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEnd() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnd() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get status => $_getIZ(3);
  @$pb.TagNumber(4)
  set status($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);
}

class GradeUpdate extends $pb.GeneratedMessage {
  factory GradeUpdate({
    $core.double? score,
    $core.int? total,
  }) {
    final result = create();
    if (score != null) result.score = score;
    if (total != null) result.total = total;
    return result;
  }

  GradeUpdate._();

  factory GradeUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GradeUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GradeUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..aI(2, _omitFieldNames ? '' : 'total')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeUpdate copyWith(void Function(GradeUpdate) updates) =>
      super.copyWith((message) => updates(message as GradeUpdate))
          as GradeUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GradeUpdate create() => GradeUpdate._();
  @$core.override
  GradeUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GradeUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GradeUpdate>(create);
  static GradeUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get score => $_getN(0);
  @$pb.TagNumber(1)
  set score($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScore() => $_has(0);
  @$pb.TagNumber(1)
  void clearScore() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get total => $_getIZ(1);
  @$pb.TagNumber(2)
  set total($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotal() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotal() => $_clearField(2);
}

class FeeUpdate extends $pb.GeneratedMessage {
  factory FeeUpdate({
    $core.String? title,
    $core.String? description,
    $core.double? amount,
    $core.bool? mandatory,
    $fixnum.Int64? due,
  }) {
    final result = create();
    if (title != null) result.title = title;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (mandatory != null) result.mandatory = mandatory;
    if (due != null) result.due = due;
    return result;
  }

  FeeUpdate._();

  factory FeeUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FeeUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FeeUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aD(3, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aOB(4, _omitFieldNames ? '' : 'mandatory')
    ..aInt64(5, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeeUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeeUpdate copyWith(void Function(FeeUpdate) updates) =>
      super.copyWith((message) => updates(message as FeeUpdate)) as FeeUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FeeUpdate create() => FeeUpdate._();
  @$core.override
  FeeUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FeeUpdate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FeeUpdate>(create);
  static FeeUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get mandatory => $_getBF(3);
  @$pb.TagNumber(4)
  set mandatory($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMandatory() => $_has(3);
  @$pb.TagNumber(4)
  void clearMandatory() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get due => $_getI64(4);
  @$pb.TagNumber(5)
  set due($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDue() => $_has(4);
  @$pb.TagNumber(5)
  void clearDue() => $_clearField(5);
}

class InvoiceUpdate extends $pb.GeneratedMessage {
  factory InvoiceUpdate({
    $core.String? fee,
    $core.String? description,
    $core.double? amount,
    $core.int? status,
    $fixnum.Int64? due,
  }) {
    final result = create();
    if (fee != null) result.fee = fee;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (status != null) result.status = status;
    if (due != null) result.due = due;
    return result;
  }

  InvoiceUpdate._();

  factory InvoiceUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InvoiceUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InvoiceUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fee')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aD(3, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'status')
    ..aInt64(5, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InvoiceUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InvoiceUpdate copyWith(void Function(InvoiceUpdate) updates) =>
      super.copyWith((message) => updates(message as InvoiceUpdate))
          as InvoiceUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InvoiceUpdate create() => InvoiceUpdate._();
  @$core.override
  InvoiceUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InvoiceUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InvoiceUpdate>(create);
  static InvoiceUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fee => $_getSZ(0);
  @$pb.TagNumber(1)
  set fee($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFee() => $_has(0);
  @$pb.TagNumber(1)
  void clearFee() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get status => $_getIZ(3);
  @$pb.TagNumber(4)
  set status($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get due => $_getI64(4);
  @$pb.TagNumber(5)
  set due($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDue() => $_has(4);
  @$pb.TagNumber(5)
  void clearDue() => $_clearField(5);
}

class PaymentUpdate extends $pb.GeneratedMessage {
  factory PaymentUpdate({
    $core.String? invoice,
    $core.double? amount,
    $core.int? method,
    $core.String? reference,
    $core.String? recorder,
    $core.int? date,
  }) {
    final result = create();
    if (invoice != null) result.invoice = invoice;
    if (amount != null) result.amount = amount;
    if (method != null) result.method = method;
    if (reference != null) result.reference = reference;
    if (recorder != null) result.recorder = recorder;
    if (date != null) result.date = date;
    return result;
  }

  PaymentUpdate._();

  factory PaymentUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'invoice')
    ..aD(2, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'method')
    ..aOS(4, _omitFieldNames ? '' : 'reference')
    ..aOS(5, _omitFieldNames ? '' : 'recorder')
    ..aI(6, _omitFieldNames ? '' : 'date')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentUpdate copyWith(void Function(PaymentUpdate) updates) =>
      super.copyWith((message) => updates(message as PaymentUpdate))
          as PaymentUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentUpdate create() => PaymentUpdate._();
  @$core.override
  PaymentUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PaymentUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentUpdate>(create);
  static PaymentUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get invoice => $_getSZ(0);
  @$pb.TagNumber(1)
  set invoice($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInvoice() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvoice() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get amount => $_getN(1);
  @$pb.TagNumber(2)
  set amount($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get method => $_getIZ(2);
  @$pb.TagNumber(3)
  set method($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMethod() => $_has(2);
  @$pb.TagNumber(3)
  void clearMethod() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get reference => $_getSZ(3);
  @$pb.TagNumber(4)
  set reference($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReference() => $_has(3);
  @$pb.TagNumber(4)
  void clearReference() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get recorder => $_getSZ(4);
  @$pb.TagNumber(5)
  set recorder($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRecorder() => $_has(4);
  @$pb.TagNumber(5)
  void clearRecorder() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get date => $_getIZ(5);
  @$pb.TagNumber(6)
  set date($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearDate() => $_clearField(6);
}

class AnnouncementUpdate extends $pb.GeneratedMessage {
  factory AnnouncementUpdate({
    $core.String? title,
    $core.String? content,
    $core.int? grade,
    $core.int? stream,
    $core.int? audience,
  }) {
    final result = create();
    if (title != null) result.title = title;
    if (content != null) result.content = content;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (audience != null) result.audience = audience;
    return result;
  }

  AnnouncementUpdate._();

  factory AnnouncementUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnnouncementUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnnouncementUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'content')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aI(4, _omitFieldNames ? '' : 'stream')
    ..aI(5, _omitFieldNames ? '' : 'audience')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnnouncementUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnnouncementUpdate copyWith(void Function(AnnouncementUpdate) updates) =>
      super.copyWith((message) => updates(message as AnnouncementUpdate))
          as AnnouncementUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnnouncementUpdate create() => AnnouncementUpdate._();
  @$core.override
  AnnouncementUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnnouncementUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnnouncementUpdate>(create);
  static AnnouncementUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get content => $_getSZ(1);
  @$pb.TagNumber(2)
  set content($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearContent() => $_clearField(2);

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
  $core.int get audience => $_getIZ(4);
  @$pb.TagNumber(5)
  set audience($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAudience() => $_has(4);
  @$pb.TagNumber(5)
  void clearAudience() => $_clearField(5);
}

class MasteryUpdate extends $pb.GeneratedMessage {
  factory MasteryUpdate({
    $core.double? score,
  }) {
    final result = create();
    if (score != null) result.score = score;
    return result;
  }

  MasteryUpdate._();

  factory MasteryUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MasteryUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MasteryUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MasteryUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MasteryUpdate copyWith(void Function(MasteryUpdate) updates) =>
      super.copyWith((message) => updates(message as MasteryUpdate))
          as MasteryUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MasteryUpdate create() => MasteryUpdate._();
  @$core.override
  MasteryUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MasteryUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MasteryUpdate>(create);
  static MasteryUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get score => $_getN(0);
  @$pb.TagNumber(1)
  set score($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScore() => $_has(0);
  @$pb.TagNumber(1)
  void clearScore() => $_clearField(1);
}

class AiUsageUpdate extends $pb.GeneratedMessage {
  factory AiUsageUpdate({
    $core.int? allocated,
    $core.int? used,
  }) {
    final result = create();
    if (allocated != null) result.allocated = allocated;
    if (used != null) result.used = used;
    return result;
  }

  AiUsageUpdate._();

  factory AiUsageUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AiUsageUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AiUsageUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'allocated')
    ..aI(2, _omitFieldNames ? '' : 'used')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AiUsageUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AiUsageUpdate copyWith(void Function(AiUsageUpdate) updates) =>
      super.copyWith((message) => updates(message as AiUsageUpdate))
          as AiUsageUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AiUsageUpdate create() => AiUsageUpdate._();
  @$core.override
  AiUsageUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AiUsageUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AiUsageUpdate>(create);
  static AiUsageUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get allocated => $_getIZ(0);
  @$pb.TagNumber(1)
  set allocated($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllocated() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllocated() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get used => $_getIZ(1);
  @$pb.TagNumber(2)
  set used($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsed() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsed() => $_clearField(2);
}

class SettingsUpdate extends $pb.GeneratedMessage {
  factory SettingsUpdate({
    $core.String? data,
    $core.String? mpesa,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (mpesa != null) result.mpesa = mpesa;
    return result;
  }

  SettingsUpdate._();

  factory SettingsUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettingsUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettingsUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'data')
    ..aOS(2, _omitFieldNames ? '' : 'mpesa')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsUpdate copyWith(void Function(SettingsUpdate) updates) =>
      super.copyWith((message) => updates(message as SettingsUpdate))
          as SettingsUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettingsUpdate create() => SettingsUpdate._();
  @$core.override
  SettingsUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettingsUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettingsUpdate>(create);
  static SettingsUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get data => $_getSZ(0);
  @$pb.TagNumber(1)
  set data($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mpesa => $_getSZ(1);
  @$pb.TagNumber(2)
  set mpesa($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMpesa() => $_has(1);
  @$pb.TagNumber(2)
  void clearMpesa() => $_clearField(2);
}

class RoleUpdate extends $pb.GeneratedMessage {
  factory RoleUpdate({
    $core.String? name,
    $core.String? description,
    $core.List<$core.int>? permissions,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (permissions != null) result.permissions = permissions;
    return result;
  }

  RoleUpdate._();

  factory RoleUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoleUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoleUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'permissions', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleUpdate copyWith(void Function(RoleUpdate) updates) =>
      super.copyWith((message) => updates(message as RoleUpdate)) as RoleUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoleUpdate create() => RoleUpdate._();
  @$core.override
  RoleUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoleUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoleUpdate>(create);
  static RoleUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get permissions => $_getN(2);
  @$pb.TagNumber(3)
  set permissions($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPermissions() => $_has(2);
  @$pb.TagNumber(3)
  void clearPermissions() => $_clearField(3);
}

class PlanUpdate extends $pb.GeneratedMessage {
  factory PlanUpdate({
    $core.String? name,
    $core.String? description,
    $core.double? amount,
    $core.int? levels,
    $core.int? status,
    $core.String? features,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (levels != null) result.levels = levels;
    if (status != null) result.status = status;
    if (features != null) result.features = features;
    return result;
  }

  PlanUpdate._();

  factory PlanUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlanUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aD(3, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'levels')
    ..aI(5, _omitFieldNames ? '' : 'status')
    ..aOS(6, _omitFieldNames ? '' : 'features')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanUpdate copyWith(void Function(PlanUpdate) updates) =>
      super.copyWith((message) => updates(message as PlanUpdate)) as PlanUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlanUpdate create() => PlanUpdate._();
  @$core.override
  PlanUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlanUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanUpdate>(create);
  static PlanUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get levels => $_getIZ(3);
  @$pb.TagNumber(4)
  set levels($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLevels() => $_has(3);
  @$pb.TagNumber(4)
  void clearLevels() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get status => $_getIZ(4);
  @$pb.TagNumber(5)
  set status($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get features => $_getSZ(5);
  @$pb.TagNumber(6)
  set features($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFeatures() => $_has(5);
  @$pb.TagNumber(6)
  void clearFeatures() => $_clearField(6);
}

class SubscriptionUpdate extends $pb.GeneratedMessage {
  factory SubscriptionUpdate({
    $core.String? invoice,
    $core.double? discount,
    $core.int? status,
  }) {
    final result = create();
    if (invoice != null) result.invoice = invoice;
    if (discount != null) result.discount = discount;
    if (status != null) result.status = status;
    return result;
  }

  SubscriptionUpdate._();

  factory SubscriptionUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubscriptionUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscriptionUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'invoice')
    ..aD(2, _omitFieldNames ? '' : 'discount', fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscriptionUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscriptionUpdate copyWith(void Function(SubscriptionUpdate) updates) =>
      super.copyWith((message) => updates(message as SubscriptionUpdate))
          as SubscriptionUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscriptionUpdate create() => SubscriptionUpdate._();
  @$core.override
  SubscriptionUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubscriptionUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscriptionUpdate>(create);
  static SubscriptionUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get invoice => $_getSZ(0);
  @$pb.TagNumber(1)
  set invoice($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInvoice() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvoice() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get discount => $_getN(1);
  @$pb.TagNumber(2)
  set discount($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDiscount() => $_has(1);
  @$pb.TagNumber(2)
  void clearDiscount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get status => $_getIZ(2);
  @$pb.TagNumber(3)
  set status($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);
}

class DiscountUpdate extends $pb.GeneratedMessage {
  factory DiscountUpdate({
    $core.double? amount,
    $core.int? unit,
  }) {
    final result = create();
    if (amount != null) result.amount = amount;
    if (unit != null) result.unit = unit;
    return result;
  }

  DiscountUpdate._();

  factory DiscountUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiscountUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscountUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(2, _omitFieldNames ? '' : 'unit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountUpdate copyWith(void Function(DiscountUpdate) updates) =>
      super.copyWith((message) => updates(message as DiscountUpdate))
          as DiscountUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiscountUpdate create() => DiscountUpdate._();
  @$core.override
  DiscountUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiscountUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscountUpdate>(create);
  static DiscountUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get amount => $_getN(0);
  @$pb.TagNumber(1)
  set amount($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAmount() => $_has(0);
  @$pb.TagNumber(1)
  void clearAmount() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get unit => $_getIZ(1);
  @$pb.TagNumber(2)
  set unit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnit() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnit() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
