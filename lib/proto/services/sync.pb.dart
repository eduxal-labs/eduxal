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

class ActionRequest extends $pb.GeneratedMessage {
  factory ActionRequest({
    $core.int? id,
    $core.int? action,
    $core.List<$core.int>? payload,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (action != null) result.action = action;
    if (payload != null) result.payload = payload;
    return result;
  }

  ActionRequest._();

  factory ActionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'action')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionRequest copyWith(void Function(ActionRequest) updates) =>
      super.copyWith((message) => updates(message as ActionRequest))
          as ActionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActionRequest create() => ActionRequest._();
  @$core.override
  ActionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActionRequest>(create);
  static ActionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get action => $_getIZ(1);
  @$pb.TagNumber(2)
  set action($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAction() => $_has(1);
  @$pb.TagNumber(2)
  void clearAction() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);
}

class ActionResponse extends $pb.GeneratedMessage {
  factory ActionResponse({
    $core.int? id,
    $core.bool? success,
    $core.int? code,
    $core.String? error,
    $core.Iterable<ActionRow>? rows,
    $core.Iterable<FileUrl>? fileUrls,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (success != null) result.success = success;
    if (code != null) result.code = code;
    if (error != null) result.error = error;
    if (rows != null) result.rows.addAll(rows);
    if (fileUrls != null) result.fileUrls.addAll(fileUrls);
    return result;
  }

  ActionResponse._();

  factory ActionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..aI(3, _omitFieldNames ? '' : 'code')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..pPM<ActionRow>(5, _omitFieldNames ? '' : 'rows',
        subBuilder: ActionRow.create)
    ..pPM<FileUrl>(6, _omitFieldNames ? '' : 'fileUrls',
        subBuilder: FileUrl.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionResponse copyWith(void Function(ActionResponse) updates) =>
      super.copyWith((message) => updates(message as ActionResponse))
          as ActionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActionResponse create() => ActionResponse._();
  @$core.override
  ActionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActionResponse>(create);
  static ActionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get code => $_getIZ(2);
  @$pb.TagNumber(3)
  set code($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<ActionRow> get rows => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<FileUrl> get fileUrls => $_getList(5);
}

/// A row returned by the server after an action executes
class ActionRow extends $pb.GeneratedMessage {
  factory ActionRow({
    $core.int? table,
    $core.int? operation,
    $core.String? rowKey,
    InsertData? data,
  }) {
    final result = create();
    if (table != null) result.table = table;
    if (operation != null) result.operation = operation;
    if (rowKey != null) result.rowKey = rowKey;
    if (data != null) result.data = data;
    return result;
  }

  ActionRow._();

  factory ActionRow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActionRow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActionRow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'table')
    ..aI(2, _omitFieldNames ? '' : 'operation')
    ..aOS(3, _omitFieldNames ? '' : 'rowKey')
    ..aOM<InsertData>(4, _omitFieldNames ? '' : 'data',
        subBuilder: InsertData.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionRow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionRow copyWith(void Function(ActionRow) updates) =>
      super.copyWith((message) => updates(message as ActionRow)) as ActionRow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActionRow create() => ActionRow._();
  @$core.override
  ActionRow createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActionRow getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ActionRow>(create);
  static ActionRow? _defaultInstance;

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
  InsertData get data => $_getN(3);
  @$pb.TagNumber(4)
  set data(InsertData value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasData() => $_has(3);
  @$pb.TagNumber(4)
  void clearData() => $_clearField(4);
  @$pb.TagNumber(4)
  InsertData ensureData() => $_ensure(3);
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

class CreateSchoolPayload extends $pb.GeneratedMessage {
  factory CreateSchoolPayload({
    $core.String? id,
    $core.String? name,
    $core.String? motto,
    $core.String? phone,
    $core.String? email,
    $core.int? county,
    $core.String? domain,
    $core.int? established,
    $core.String? ownerId,
    $core.String? ownerPhone,
    $core.String? ownerName,
    $core.String? ownerEmail,
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
    if (ownerId != null) result.ownerId = ownerId;
    if (ownerPhone != null) result.ownerPhone = ownerPhone;
    if (ownerName != null) result.ownerName = ownerName;
    if (ownerEmail != null) result.ownerEmail = ownerEmail;
    return result;
  }

  CreateSchoolPayload._();

  factory CreateSchoolPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateSchoolPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSchoolPayload',
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
    ..aOS(10, _omitFieldNames ? '' : 'ownerId')
    ..aOS(11, _omitFieldNames ? '' : 'ownerPhone')
    ..aOS(12, _omitFieldNames ? '' : 'ownerName')
    ..aOS(13, _omitFieldNames ? '' : 'ownerEmail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSchoolPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSchoolPayload copyWith(void Function(CreateSchoolPayload) updates) =>
      super.copyWith((message) => updates(message as CreateSchoolPayload))
          as CreateSchoolPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateSchoolPayload create() => CreateSchoolPayload._();
  @$core.override
  CreateSchoolPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateSchoolPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateSchoolPayload>(create);
  static CreateSchoolPayload? _defaultInstance;

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

  /// Owner info (invitation pattern)
  @$pb.TagNumber(10)
  $core.String get ownerId => $_getSZ(8);
  @$pb.TagNumber(10)
  set ownerId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(10)
  $core.bool hasOwnerId() => $_has(8);
  @$pb.TagNumber(10)
  void clearOwnerId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get ownerPhone => $_getSZ(9);
  @$pb.TagNumber(11)
  set ownerPhone($core.String value) => $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasOwnerPhone() => $_has(9);
  @$pb.TagNumber(11)
  void clearOwnerPhone() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get ownerName => $_getSZ(10);
  @$pb.TagNumber(12)
  set ownerName($core.String value) => $_setString(10, value);
  @$pb.TagNumber(12)
  $core.bool hasOwnerName() => $_has(10);
  @$pb.TagNumber(12)
  void clearOwnerName() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get ownerEmail => $_getSZ(11);
  @$pb.TagNumber(13)
  set ownerEmail($core.String value) => $_setString(11, value);
  @$pb.TagNumber(13)
  $core.bool hasOwnerEmail() => $_has(11);
  @$pb.TagNumber(13)
  void clearOwnerEmail() => $_clearField(13);
}

class UpdateSchoolPayload extends $pb.GeneratedMessage {
  factory UpdateSchoolPayload({
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

  UpdateSchoolPayload._();

  factory UpdateSchoolPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSchoolPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSchoolPayload',
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
  UpdateSchoolPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSchoolPayload copyWith(void Function(UpdateSchoolPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateSchoolPayload))
          as UpdateSchoolPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSchoolPayload create() => UpdateSchoolPayload._();
  @$core.override
  UpdateSchoolPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSchoolPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSchoolPayload>(create);
  static UpdateSchoolPayload? _defaultInstance;

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

class DeleteSchoolPayload extends $pb.GeneratedMessage {
  factory DeleteSchoolPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteSchoolPayload._();

  factory DeleteSchoolPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteSchoolPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSchoolPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSchoolPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSchoolPayload copyWith(void Function(DeleteSchoolPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteSchoolPayload))
          as DeleteSchoolPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteSchoolPayload create() => DeleteSchoolPayload._();
  @$core.override
  DeleteSchoolPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteSchoolPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSchoolPayload>(create);
  static DeleteSchoolPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateTeacherPayload extends $pb.GeneratedMessage {
  factory CreateTeacherPayload({
    $core.String? school,
    $core.String? userId,
    $core.String? phone,
    $core.String? name,
    $core.String? email,
    $core.int? hired,
    $core.String? role,
    $core.String? department,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (userId != null) result.userId = userId;
    if (phone != null) result.phone = phone;
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    if (hired != null) result.hired = hired;
    if (role != null) result.role = role;
    if (department != null) result.department = department;
    return result;
  }

  CreateTeacherPayload._();

  factory CreateTeacherPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTeacherPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTeacherPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'phone')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aI(6, _omitFieldNames ? '' : 'hired')
    ..aOS(7, _omitFieldNames ? '' : 'role')
    ..aOS(8, _omitFieldNames ? '' : 'department')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTeacherPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTeacherPayload copyWith(void Function(CreateTeacherPayload) updates) =>
      super.copyWith((message) => updates(message as CreateTeacherPayload))
          as CreateTeacherPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTeacherPayload create() => CreateTeacherPayload._();
  @$core.override
  CreateTeacherPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTeacherPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTeacherPayload>(create);
  static CreateTeacherPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get phone => $_getSZ(2);
  @$pb.TagNumber(3)
  set phone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPhone() => $_has(2);
  @$pb.TagNumber(3)
  void clearPhone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get hired => $_getIZ(5);
  @$pb.TagNumber(6)
  set hired($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHired() => $_has(5);
  @$pb.TagNumber(6)
  void clearHired() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get role => $_getSZ(6);
  @$pb.TagNumber(7)
  set role($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRole() => $_has(6);
  @$pb.TagNumber(7)
  void clearRole() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get department => $_getSZ(7);
  @$pb.TagNumber(8)
  set department($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDepartment() => $_has(7);
  @$pb.TagNumber(8)
  void clearDepartment() => $_clearField(8);
}

class UpdateTeacherPayload extends $pb.GeneratedMessage {
  factory UpdateTeacherPayload({
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

  UpdateTeacherPayload._();

  factory UpdateTeacherPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTeacherPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTeacherPayload',
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
  UpdateTeacherPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTeacherPayload copyWith(void Function(UpdateTeacherPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateTeacherPayload))
          as UpdateTeacherPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTeacherPayload create() => UpdateTeacherPayload._();
  @$core.override
  UpdateTeacherPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTeacherPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTeacherPayload>(create);
  static UpdateTeacherPayload? _defaultInstance;

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

class DeleteTeacherPayload extends $pb.GeneratedMessage {
  factory DeleteTeacherPayload({
    $core.String? school,
    $core.String? user,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    return result;
  }

  DeleteTeacherPayload._();

  factory DeleteTeacherPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTeacherPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTeacherPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTeacherPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTeacherPayload copyWith(void Function(DeleteTeacherPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteTeacherPayload))
          as DeleteTeacherPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTeacherPayload create() => DeleteTeacherPayload._();
  @$core.override
  DeleteTeacherPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTeacherPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTeacherPayload>(create);
  static DeleteTeacherPayload? _defaultInstance;

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

class CreateStaffPayload extends $pb.GeneratedMessage {
  factory CreateStaffPayload({
    $core.String? school,
    $core.String? userId,
    $core.String? phone,
    $core.String? name,
    $core.String? email,
    $core.String? idnumber,
    $core.String? role,
    $core.String? department,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (userId != null) result.userId = userId;
    if (phone != null) result.phone = phone;
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    if (idnumber != null) result.idnumber = idnumber;
    if (role != null) result.role = role;
    if (department != null) result.department = department;
    return result;
  }

  CreateStaffPayload._();

  factory CreateStaffPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateStaffPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateStaffPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'phone')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aOS(6, _omitFieldNames ? '' : 'idnumber')
    ..aOS(7, _omitFieldNames ? '' : 'role')
    ..aOS(8, _omitFieldNames ? '' : 'department')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateStaffPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateStaffPayload copyWith(void Function(CreateStaffPayload) updates) =>
      super.copyWith((message) => updates(message as CreateStaffPayload))
          as CreateStaffPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateStaffPayload create() => CreateStaffPayload._();
  @$core.override
  CreateStaffPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateStaffPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateStaffPayload>(create);
  static CreateStaffPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get phone => $_getSZ(2);
  @$pb.TagNumber(3)
  set phone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPhone() => $_has(2);
  @$pb.TagNumber(3)
  void clearPhone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get idnumber => $_getSZ(5);
  @$pb.TagNumber(6)
  set idnumber($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIdnumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdnumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get role => $_getSZ(6);
  @$pb.TagNumber(7)
  set role($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRole() => $_has(6);
  @$pb.TagNumber(7)
  void clearRole() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get department => $_getSZ(7);
  @$pb.TagNumber(8)
  set department($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDepartment() => $_has(7);
  @$pb.TagNumber(8)
  void clearDepartment() => $_clearField(8);
}

class UpdateStaffPayload extends $pb.GeneratedMessage {
  factory UpdateStaffPayload({
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

  UpdateStaffPayload._();

  factory UpdateStaffPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateStaffPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateStaffPayload',
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
  UpdateStaffPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStaffPayload copyWith(void Function(UpdateStaffPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateStaffPayload))
          as UpdateStaffPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateStaffPayload create() => UpdateStaffPayload._();
  @$core.override
  UpdateStaffPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateStaffPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateStaffPayload>(create);
  static UpdateStaffPayload? _defaultInstance;

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

class DeleteStaffPayload extends $pb.GeneratedMessage {
  factory DeleteStaffPayload({
    $core.String? school,
    $core.String? user,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    return result;
  }

  DeleteStaffPayload._();

  factory DeleteStaffPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteStaffPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteStaffPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteStaffPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteStaffPayload copyWith(void Function(DeleteStaffPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteStaffPayload))
          as DeleteStaffPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteStaffPayload create() => DeleteStaffPayload._();
  @$core.override
  DeleteStaffPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteStaffPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteStaffPayload>(create);
  static DeleteStaffPayload? _defaultInstance;

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

class CreateOwnerPayload extends $pb.GeneratedMessage {
  factory CreateOwnerPayload({
    $core.String? school,
    $core.String? userId,
    $core.String? phone,
    $core.String? name,
    $core.String? email,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (userId != null) result.userId = userId;
    if (phone != null) result.phone = phone;
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    return result;
  }

  CreateOwnerPayload._();

  factory CreateOwnerPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateOwnerPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateOwnerPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'phone')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateOwnerPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateOwnerPayload copyWith(void Function(CreateOwnerPayload) updates) =>
      super.copyWith((message) => updates(message as CreateOwnerPayload))
          as CreateOwnerPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateOwnerPayload create() => CreateOwnerPayload._();
  @$core.override
  CreateOwnerPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateOwnerPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateOwnerPayload>(create);
  static CreateOwnerPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get phone => $_getSZ(2);
  @$pb.TagNumber(3)
  set phone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPhone() => $_has(2);
  @$pb.TagNumber(3)
  void clearPhone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);
}

class DeleteOwnerPayload extends $pb.GeneratedMessage {
  factory DeleteOwnerPayload({
    $core.String? school,
    $core.String? user,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    return result;
  }

  DeleteOwnerPayload._();

  factory DeleteOwnerPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteOwnerPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteOwnerPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteOwnerPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteOwnerPayload copyWith(void Function(DeleteOwnerPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteOwnerPayload))
          as DeleteOwnerPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteOwnerPayload create() => DeleteOwnerPayload._();
  @$core.override
  DeleteOwnerPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteOwnerPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteOwnerPayload>(create);
  static DeleteOwnerPayload? _defaultInstance;

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

class CreateStudentPayload extends $pb.GeneratedMessage {
  factory CreateStudentPayload({
    $core.String? school,
    $core.int? adm,
    $core.String? user,
    $core.String? name,
    $core.int? dob,
    $core.int? gender,
    $core.String? documents,
    $core.int? admitted,
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
    return result;
  }

  CreateStudentPayload._();

  factory CreateStudentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateStudentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateStudentPayload',
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
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateStudentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateStudentPayload copyWith(void Function(CreateStudentPayload) updates) =>
      super.copyWith((message) => updates(message as CreateStudentPayload))
          as CreateStudentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateStudentPayload create() => CreateStudentPayload._();
  @$core.override
  CreateStudentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateStudentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateStudentPayload>(create);
  static CreateStudentPayload? _defaultInstance;

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
}

class UpdateStudentPayload extends $pb.GeneratedMessage {
  factory UpdateStudentPayload({
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

  UpdateStudentPayload._();

  factory UpdateStudentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateStudentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateStudentPayload',
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
  UpdateStudentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStudentPayload copyWith(void Function(UpdateStudentPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateStudentPayload))
          as UpdateStudentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateStudentPayload create() => UpdateStudentPayload._();
  @$core.override
  UpdateStudentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateStudentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateStudentPayload>(create);
  static UpdateStudentPayload? _defaultInstance;

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

class DeleteStudentPayload extends $pb.GeneratedMessage {
  factory DeleteStudentPayload({
    $core.String? school,
    $core.int? adm,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (adm != null) result.adm = adm;
    return result;
  }

  DeleteStudentPayload._();

  factory DeleteStudentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteStudentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteStudentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'adm')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteStudentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteStudentPayload copyWith(void Function(DeleteStudentPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteStudentPayload))
          as DeleteStudentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteStudentPayload create() => DeleteStudentPayload._();
  @$core.override
  DeleteStudentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteStudentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteStudentPayload>(create);
  static DeleteStudentPayload? _defaultInstance;

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
}

class EnrollStudentPayload extends $pb.GeneratedMessage {
  factory EnrollStudentPayload({
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

  EnrollStudentPayload._();

  factory EnrollStudentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EnrollStudentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnrollStudentPayload',
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
  EnrollStudentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnrollStudentPayload copyWith(void Function(EnrollStudentPayload) updates) =>
      super.copyWith((message) => updates(message as EnrollStudentPayload))
          as EnrollStudentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnrollStudentPayload create() => EnrollStudentPayload._();
  @$core.override
  EnrollStudentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EnrollStudentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnrollStudentPayload>(create);
  static EnrollStudentPayload? _defaultInstance;

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

class UnenrollStudentPayload extends $pb.GeneratedMessage {
  factory UnenrollStudentPayload({
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

  UnenrollStudentPayload._();

  factory UnenrollStudentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnenrollStudentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnenrollStudentPayload',
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
  UnenrollStudentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnenrollStudentPayload copyWith(
          void Function(UnenrollStudentPayload) updates) =>
      super.copyWith((message) => updates(message as UnenrollStudentPayload))
          as UnenrollStudentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnenrollStudentPayload create() => UnenrollStudentPayload._();
  @$core.override
  UnenrollStudentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnenrollStudentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnenrollStudentPayload>(create);
  static UnenrollStudentPayload? _defaultInstance;

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

class CreateGuardianPayload extends $pb.GeneratedMessage {
  factory CreateGuardianPayload({
    $core.String? school,
    $core.String? userId,
    $core.String? phone,
    $core.String? name,
    $core.String? email,
    $core.int? student,
    $core.int? relationship,
    $core.int? role,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (userId != null) result.userId = userId;
    if (phone != null) result.phone = phone;
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    if (student != null) result.student = student;
    if (relationship != null) result.relationship = relationship;
    if (role != null) result.role = role;
    return result;
  }

  CreateGuardianPayload._();

  factory CreateGuardianPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateGuardianPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateGuardianPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'phone')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aI(6, _omitFieldNames ? '' : 'student')
    ..aI(7, _omitFieldNames ? '' : 'relationship')
    ..aI(8, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGuardianPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGuardianPayload copyWith(
          void Function(CreateGuardianPayload) updates) =>
      super.copyWith((message) => updates(message as CreateGuardianPayload))
          as CreateGuardianPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateGuardianPayload create() => CreateGuardianPayload._();
  @$core.override
  CreateGuardianPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateGuardianPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateGuardianPayload>(create);
  static CreateGuardianPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get phone => $_getSZ(2);
  @$pb.TagNumber(3)
  set phone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPhone() => $_has(2);
  @$pb.TagNumber(3)
  void clearPhone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get student => $_getIZ(5);
  @$pb.TagNumber(6)
  set student($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStudent() => $_has(5);
  @$pb.TagNumber(6)
  void clearStudent() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get relationship => $_getIZ(6);
  @$pb.TagNumber(7)
  set relationship($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRelationship() => $_has(6);
  @$pb.TagNumber(7)
  void clearRelationship() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get role => $_getIZ(7);
  @$pb.TagNumber(8)
  set role($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRole() => $_has(7);
  @$pb.TagNumber(8)
  void clearRole() => $_clearField(8);
}

class UpdateGuardianPayload extends $pb.GeneratedMessage {
  factory UpdateGuardianPayload({
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

  UpdateGuardianPayload._();

  factory UpdateGuardianPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateGuardianPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateGuardianPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aI(3, _omitFieldNames ? '' : 'student')
    ..aI(4, _omitFieldNames ? '' : 'relationship')
    ..aI(5, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateGuardianPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateGuardianPayload copyWith(
          void Function(UpdateGuardianPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateGuardianPayload))
          as UpdateGuardianPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateGuardianPayload create() => UpdateGuardianPayload._();
  @$core.override
  UpdateGuardianPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateGuardianPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateGuardianPayload>(create);
  static UpdateGuardianPayload? _defaultInstance;

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

class DeleteGuardianPayload extends $pb.GeneratedMessage {
  factory DeleteGuardianPayload({
    $core.String? school,
    $core.String? user,
    $core.int? student,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (user != null) result.user = user;
    if (student != null) result.student = student;
    return result;
  }

  DeleteGuardianPayload._();

  factory DeleteGuardianPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteGuardianPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteGuardianPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aI(3, _omitFieldNames ? '' : 'student')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteGuardianPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteGuardianPayload copyWith(
          void Function(DeleteGuardianPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteGuardianPayload))
          as DeleteGuardianPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteGuardianPayload create() => DeleteGuardianPayload._();
  @$core.override
  DeleteGuardianPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteGuardianPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteGuardianPayload>(create);
  static DeleteGuardianPayload? _defaultInstance;

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
}

class CreateDepartmentPayload extends $pb.GeneratedMessage {
  factory CreateDepartmentPayload({
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

  CreateDepartmentPayload._();

  factory CreateDepartmentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateDepartmentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDepartmentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDepartmentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDepartmentPayload copyWith(
          void Function(CreateDepartmentPayload) updates) =>
      super.copyWith((message) => updates(message as CreateDepartmentPayload))
          as CreateDepartmentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateDepartmentPayload create() => CreateDepartmentPayload._();
  @$core.override
  CreateDepartmentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateDepartmentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDepartmentPayload>(create);
  static CreateDepartmentPayload? _defaultInstance;

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

class UpdateDepartmentPayload extends $pb.GeneratedMessage {
  factory UpdateDepartmentPayload({
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

  UpdateDepartmentPayload._();

  factory UpdateDepartmentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateDepartmentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateDepartmentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDepartmentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDepartmentPayload copyWith(
          void Function(UpdateDepartmentPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateDepartmentPayload))
          as UpdateDepartmentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateDepartmentPayload create() => UpdateDepartmentPayload._();
  @$core.override
  UpdateDepartmentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateDepartmentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateDepartmentPayload>(create);
  static UpdateDepartmentPayload? _defaultInstance;

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

class DeleteDepartmentPayload extends $pb.GeneratedMessage {
  factory DeleteDepartmentPayload({
    $core.String? school,
    $core.String? name,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    return result;
  }

  DeleteDepartmentPayload._();

  factory DeleteDepartmentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteDepartmentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteDepartmentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDepartmentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDepartmentPayload copyWith(
          void Function(DeleteDepartmentPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteDepartmentPayload))
          as DeleteDepartmentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteDepartmentPayload create() => DeleteDepartmentPayload._();
  @$core.override
  DeleteDepartmentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteDepartmentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteDepartmentPayload>(create);
  static DeleteDepartmentPayload? _defaultInstance;

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
}

class CreateTermPayload extends $pb.GeneratedMessage {
  factory CreateTermPayload({
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

  CreateTermPayload._();

  factory CreateTermPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTermPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTermPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aInt64(4, _omitFieldNames ? '' : 'start')
    ..aInt64(5, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTermPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTermPayload copyWith(void Function(CreateTermPayload) updates) =>
      super.copyWith((message) => updates(message as CreateTermPayload))
          as CreateTermPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTermPayload create() => CreateTermPayload._();
  @$core.override
  CreateTermPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTermPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTermPayload>(create);
  static CreateTermPayload? _defaultInstance;

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

class UpdateTermPayload extends $pb.GeneratedMessage {
  factory UpdateTermPayload({
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

  UpdateTermPayload._();

  factory UpdateTermPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTermPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTermPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aInt64(4, _omitFieldNames ? '' : 'start')
    ..aInt64(5, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTermPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTermPayload copyWith(void Function(UpdateTermPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateTermPayload))
          as UpdateTermPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTermPayload create() => UpdateTermPayload._();
  @$core.override
  UpdateTermPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTermPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTermPayload>(create);
  static UpdateTermPayload? _defaultInstance;

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

class DeleteTermPayload extends $pb.GeneratedMessage {
  factory DeleteTermPayload({
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

  DeleteTermPayload._();

  factory DeleteTermPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTermPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTermPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTermPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTermPayload copyWith(void Function(DeleteTermPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteTermPayload))
          as DeleteTermPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTermPayload create() => DeleteTermPayload._();
  @$core.override
  DeleteTermPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTermPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTermPayload>(create);
  static DeleteTermPayload? _defaultInstance;

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
}

class AssignClassTeacherPayload extends $pb.GeneratedMessage {
  factory AssignClassTeacherPayload({
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

  AssignClassTeacherPayload._();

  factory AssignClassTeacherPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssignClassTeacherPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssignClassTeacherPayload',
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
  AssignClassTeacherPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignClassTeacherPayload copyWith(
          void Function(AssignClassTeacherPayload) updates) =>
      super.copyWith((message) => updates(message as AssignClassTeacherPayload))
          as AssignClassTeacherPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssignClassTeacherPayload create() => AssignClassTeacherPayload._();
  @$core.override
  AssignClassTeacherPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssignClassTeacherPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssignClassTeacherPayload>(create);
  static AssignClassTeacherPayload? _defaultInstance;

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

class UnassignClassTeacherPayload extends $pb.GeneratedMessage {
  factory UnassignClassTeacherPayload({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.String? teacher,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (teacher != null) result.teacher = teacher;
    return result;
  }

  UnassignClassTeacherPayload._();

  factory UnassignClassTeacherPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnassignClassTeacherPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnassignClassTeacherPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aOS(6, _omitFieldNames ? '' : 'teacher')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignClassTeacherPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignClassTeacherPayload copyWith(
          void Function(UnassignClassTeacherPayload) updates) =>
      super.copyWith(
              (message) => updates(message as UnassignClassTeacherPayload))
          as UnassignClassTeacherPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnassignClassTeacherPayload create() =>
      UnassignClassTeacherPayload._();
  @$core.override
  UnassignClassTeacherPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnassignClassTeacherPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnassignClassTeacherPayload>(create);
  static UnassignClassTeacherPayload? _defaultInstance;

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
}

class AssignSubjectPayload extends $pb.GeneratedMessage {
  factory AssignSubjectPayload({
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

  AssignSubjectPayload._();

  factory AssignSubjectPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssignSubjectPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssignSubjectPayload',
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
  AssignSubjectPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignSubjectPayload copyWith(void Function(AssignSubjectPayload) updates) =>
      super.copyWith((message) => updates(message as AssignSubjectPayload))
          as AssignSubjectPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssignSubjectPayload create() => AssignSubjectPayload._();
  @$core.override
  AssignSubjectPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssignSubjectPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssignSubjectPayload>(create);
  static AssignSubjectPayload? _defaultInstance;

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

class UnassignSubjectPayload extends $pb.GeneratedMessage {
  factory UnassignSubjectPayload({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? subject,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (subject != null) result.subject = subject;
    return result;
  }

  UnassignSubjectPayload._();

  factory UnassignSubjectPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnassignSubjectPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnassignSubjectPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'subject')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignSubjectPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignSubjectPayload copyWith(
          void Function(UnassignSubjectPayload) updates) =>
      super.copyWith((message) => updates(message as UnassignSubjectPayload))
          as UnassignSubjectPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnassignSubjectPayload create() => UnassignSubjectPayload._();
  @$core.override
  UnassignSubjectPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnassignSubjectPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnassignSubjectPayload>(create);
  static UnassignSubjectPayload? _defaultInstance;

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
}

class CreateTimetableEntryPayload extends $pb.GeneratedMessage {
  factory CreateTimetableEntryPayload({
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

  CreateTimetableEntryPayload._();

  factory CreateTimetableEntryPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTimetableEntryPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTimetableEntryPayload',
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
  CreateTimetableEntryPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTimetableEntryPayload copyWith(
          void Function(CreateTimetableEntryPayload) updates) =>
      super.copyWith(
              (message) => updates(message as CreateTimetableEntryPayload))
          as CreateTimetableEntryPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTimetableEntryPayload create() =>
      CreateTimetableEntryPayload._();
  @$core.override
  CreateTimetableEntryPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTimetableEntryPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTimetableEntryPayload>(create);
  static CreateTimetableEntryPayload? _defaultInstance;

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

class UpdateTimetableEntryPayload extends $pb.GeneratedMessage {
  factory UpdateTimetableEntryPayload({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? subject,
    $core.int? day,
    $core.int? start,
    $core.String? teacher,
    $core.int? end,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (subject != null) result.subject = subject;
    if (day != null) result.day = day;
    if (start != null) result.start = start;
    if (teacher != null) result.teacher = teacher;
    if (end != null) result.end = end;
    return result;
  }

  UpdateTimetableEntryPayload._();

  factory UpdateTimetableEntryPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTimetableEntryPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTimetableEntryPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'subject')
    ..aI(7, _omitFieldNames ? '' : 'day')
    ..aI(8, _omitFieldNames ? '' : 'start')
    ..aOS(9, _omitFieldNames ? '' : 'teacher')
    ..aI(10, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTimetableEntryPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTimetableEntryPayload copyWith(
          void Function(UpdateTimetableEntryPayload) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateTimetableEntryPayload))
          as UpdateTimetableEntryPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTimetableEntryPayload create() =>
      UpdateTimetableEntryPayload._();
  @$core.override
  UpdateTimetableEntryPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTimetableEntryPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTimetableEntryPayload>(create);
  static UpdateTimetableEntryPayload? _defaultInstance;

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
  $core.int get day => $_getIZ(6);
  @$pb.TagNumber(7)
  set day($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDay() => $_has(6);
  @$pb.TagNumber(7)
  void clearDay() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get start => $_getIZ(7);
  @$pb.TagNumber(8)
  set start($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStart() => $_has(7);
  @$pb.TagNumber(8)
  void clearStart() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get teacher => $_getSZ(8);
  @$pb.TagNumber(9)
  set teacher($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTeacher() => $_has(8);
  @$pb.TagNumber(9)
  void clearTeacher() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get end => $_getIZ(9);
  @$pb.TagNumber(10)
  set end($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEnd() => $_has(9);
  @$pb.TagNumber(10)
  void clearEnd() => $_clearField(10);
}

class DeleteTimetableEntryPayload extends $pb.GeneratedMessage {
  factory DeleteTimetableEntryPayload({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? subject,
    $core.int? day,
    $core.int? start,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (subject != null) result.subject = subject;
    if (day != null) result.day = day;
    if (start != null) result.start = start;
    return result;
  }

  DeleteTimetableEntryPayload._();

  factory DeleteTimetableEntryPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTimetableEntryPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTimetableEntryPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'subject')
    ..aI(7, _omitFieldNames ? '' : 'day')
    ..aI(8, _omitFieldNames ? '' : 'start')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTimetableEntryPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTimetableEntryPayload copyWith(
          void Function(DeleteTimetableEntryPayload) updates) =>
      super.copyWith(
              (message) => updates(message as DeleteTimetableEntryPayload))
          as DeleteTimetableEntryPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTimetableEntryPayload create() =>
      DeleteTimetableEntryPayload._();
  @$core.override
  DeleteTimetableEntryPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTimetableEntryPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTimetableEntryPayload>(create);
  static DeleteTimetableEntryPayload? _defaultInstance;

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
  $core.int get day => $_getIZ(6);
  @$pb.TagNumber(7)
  set day($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDay() => $_has(6);
  @$pb.TagNumber(7)
  void clearDay() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get start => $_getIZ(7);
  @$pb.TagNumber(8)
  set start($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStart() => $_has(7);
  @$pb.TagNumber(8)
  void clearStart() => $_clearField(8);
}

class AttendanceRecord extends $pb.GeneratedMessage {
  factory AttendanceRecord({
    $core.int? student,
    $core.int? status,
  }) {
    final result = create();
    if (student != null) result.student = student;
    if (status != null) result.status = status;
    return result;
  }

  AttendanceRecord._();

  factory AttendanceRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttendanceRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttendanceRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'student')
    ..aI(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttendanceRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttendanceRecord copyWith(void Function(AttendanceRecord) updates) =>
      super.copyWith((message) => updates(message as AttendanceRecord))
          as AttendanceRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttendanceRecord create() => AttendanceRecord._();
  @$core.override
  AttendanceRecord createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttendanceRecord getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttendanceRecord>(create);
  static AttendanceRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get student => $_getIZ(0);
  @$pb.TagNumber(1)
  set student($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStudent() => $_has(0);
  @$pb.TagNumber(1)
  void clearStudent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get status => $_getIZ(1);
  @$pb.TagNumber(2)
  set status($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

class MarkAttendancePayload extends $pb.GeneratedMessage {
  factory MarkAttendancePayload({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? date,
    $core.Iterable<AttendanceRecord>? records,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (date != null) result.date = date;
    if (records != null) result.records.addAll(records);
    return result;
  }

  MarkAttendancePayload._();

  factory MarkAttendancePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkAttendancePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkAttendancePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'date')
    ..pPM<AttendanceRecord>(7, _omitFieldNames ? '' : 'records',
        subBuilder: AttendanceRecord.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkAttendancePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkAttendancePayload copyWith(
          void Function(MarkAttendancePayload) updates) =>
      super.copyWith((message) => updates(message as MarkAttendancePayload))
          as MarkAttendancePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkAttendancePayload create() => MarkAttendancePayload._();
  @$core.override
  MarkAttendancePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkAttendancePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkAttendancePayload>(create);
  static MarkAttendancePayload? _defaultInstance;

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
  $pb.PbList<AttendanceRecord> get records => $_getList(6);
}

class DeleteAttendancePayload extends $pb.GeneratedMessage {
  factory DeleteAttendancePayload({
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
    $core.int? stream,
    $core.int? student,
    $core.int? date,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (student != null) result.student = student;
    if (date != null) result.date = date;
    return result;
  }

  DeleteAttendancePayload._();

  factory DeleteAttendancePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAttendancePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAttendancePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aI(3, _omitFieldNames ? '' : 'term')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'student')
    ..aI(7, _omitFieldNames ? '' : 'date')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAttendancePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAttendancePayload copyWith(
          void Function(DeleteAttendancePayload) updates) =>
      super.copyWith((message) => updates(message as DeleteAttendancePayload))
          as DeleteAttendancePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAttendancePayload create() => DeleteAttendancePayload._();
  @$core.override
  DeleteAttendancePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAttendancePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAttendancePayload>(create);
  static DeleteAttendancePayload? _defaultInstance;

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
}

class CreateLessonPayload extends $pb.GeneratedMessage {
  factory CreateLessonPayload({
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

  CreateLessonPayload._();

  factory CreateLessonPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateLessonPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateLessonPayload',
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
  CreateLessonPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateLessonPayload copyWith(void Function(CreateLessonPayload) updates) =>
      super.copyWith((message) => updates(message as CreateLessonPayload))
          as CreateLessonPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateLessonPayload create() => CreateLessonPayload._();
  @$core.override
  CreateLessonPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateLessonPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateLessonPayload>(create);
  static CreateLessonPayload? _defaultInstance;

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

class DeleteLessonPayload extends $pb.GeneratedMessage {
  factory DeleteLessonPayload({
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

  DeleteLessonPayload._();

  factory DeleteLessonPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteLessonPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteLessonPayload',
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
  DeleteLessonPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteLessonPayload copyWith(void Function(DeleteLessonPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteLessonPayload))
          as DeleteLessonPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteLessonPayload create() => DeleteLessonPayload._();
  @$core.override
  DeleteLessonPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteLessonPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteLessonPayload>(create);
  static DeleteLessonPayload? _defaultInstance;

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

/// Helper for CreateExamPayload
class ExamGradeEntry extends $pb.GeneratedMessage {
  factory ExamGradeEntry({
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  ExamGradeEntry._();

  factory ExamGradeEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExamGradeEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExamGradeEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'grade')
    ..aI(2, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamGradeEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamGradeEntry copyWith(void Function(ExamGradeEntry) updates) =>
      super.copyWith((message) => updates(message as ExamGradeEntry))
          as ExamGradeEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExamGradeEntry create() => ExamGradeEntry._();
  @$core.override
  ExamGradeEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExamGradeEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExamGradeEntry>(create);
  static ExamGradeEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get grade => $_getIZ(0);
  @$pb.TagNumber(1)
  set grade($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGrade() => $_has(0);
  @$pb.TagNumber(1)
  void clearGrade() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get stream => $_getIZ(1);
  @$pb.TagNumber(2)
  set stream($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStream() => $_has(1);
  @$pb.TagNumber(2)
  void clearStream() => $_clearField(2);
}

class CreateExamPayload extends $pb.GeneratedMessage {
  factory CreateExamPayload({
    $core.String? id,
    $core.String? school,
    $core.String? name,
    $core.int? year,
    $core.int? term,
    $core.bool? personalized,
    $core.int? type,
    $core.int? start,
    $core.int? end,
    $core.String? teacher,
    $core.Iterable<ExamGradeEntry>? grades,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (personalized != null) result.personalized = personalized;
    if (type != null) result.type = type;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (teacher != null) result.teacher = teacher;
    if (grades != null) result.grades.addAll(grades);
    return result;
  }

  CreateExamPayload._();

  factory CreateExamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateExamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateExamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'year')
    ..aI(5, _omitFieldNames ? '' : 'term')
    ..aOB(6, _omitFieldNames ? '' : 'personalized')
    ..aI(7, _omitFieldNames ? '' : 'type')
    ..aI(8, _omitFieldNames ? '' : 'start')
    ..aI(9, _omitFieldNames ? '' : 'end')
    ..aOS(10, _omitFieldNames ? '' : 'teacher')
    ..pPM<ExamGradeEntry>(11, _omitFieldNames ? '' : 'grades',
        subBuilder: ExamGradeEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExamPayload copyWith(void Function(CreateExamPayload) updates) =>
      super.copyWith((message) => updates(message as CreateExamPayload))
          as CreateExamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateExamPayload create() => CreateExamPayload._();
  @$core.override
  CreateExamPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateExamPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateExamPayload>(create);
  static CreateExamPayload? _defaultInstance;

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
  $core.int get year => $_getIZ(3);
  @$pb.TagNumber(4)
  set year($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasYear() => $_has(3);
  @$pb.TagNumber(4)
  void clearYear() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get term => $_getIZ(4);
  @$pb.TagNumber(5)
  set term($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTerm() => $_has(4);
  @$pb.TagNumber(5)
  void clearTerm() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get personalized => $_getBF(5);
  @$pb.TagNumber(6)
  set personalized($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPersonalized() => $_has(5);
  @$pb.TagNumber(6)
  void clearPersonalized() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get type => $_getIZ(6);
  @$pb.TagNumber(7)
  set type($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasType() => $_has(6);
  @$pb.TagNumber(7)
  void clearType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get start => $_getIZ(7);
  @$pb.TagNumber(8)
  set start($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStart() => $_has(7);
  @$pb.TagNumber(8)
  void clearStart() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get end => $_getIZ(8);
  @$pb.TagNumber(9)
  set end($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEnd() => $_has(8);
  @$pb.TagNumber(9)
  void clearEnd() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get teacher => $_getSZ(9);
  @$pb.TagNumber(10)
  set teacher($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTeacher() => $_has(9);
  @$pb.TagNumber(10)
  void clearTeacher() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<ExamGradeEntry> get grades => $_getList(10);
}

class UpdateExamPayload extends $pb.GeneratedMessage {
  factory UpdateExamPayload({
    $core.String? id,
    $core.String? name,
    $core.bool? personalized,
    $core.int? type,
    $core.int? start,
    $core.int? end,
    $core.String? teacher,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (personalized != null) result.personalized = personalized;
    if (type != null) result.type = type;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (teacher != null) result.teacher = teacher;
    return result;
  }

  UpdateExamPayload._();

  factory UpdateExamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateExamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateExamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOB(3, _omitFieldNames ? '' : 'personalized')
    ..aI(4, _omitFieldNames ? '' : 'type')
    ..aI(5, _omitFieldNames ? '' : 'start')
    ..aI(6, _omitFieldNames ? '' : 'end')
    ..aOS(7, _omitFieldNames ? '' : 'teacher')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateExamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateExamPayload copyWith(void Function(UpdateExamPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateExamPayload))
          as UpdateExamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateExamPayload create() => UpdateExamPayload._();
  @$core.override
  UpdateExamPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateExamPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateExamPayload>(create);
  static UpdateExamPayload? _defaultInstance;

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
  $core.bool get personalized => $_getBF(2);
  @$pb.TagNumber(3)
  set personalized($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPersonalized() => $_has(2);
  @$pb.TagNumber(3)
  void clearPersonalized() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get type => $_getIZ(3);
  @$pb.TagNumber(4)
  set type($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get start => $_getIZ(4);
  @$pb.TagNumber(5)
  set start($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStart() => $_has(4);
  @$pb.TagNumber(5)
  void clearStart() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get end => $_getIZ(5);
  @$pb.TagNumber(6)
  set end($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnd() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnd() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get teacher => $_getSZ(6);
  @$pb.TagNumber(7)
  set teacher($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTeacher() => $_has(6);
  @$pb.TagNumber(7)
  void clearTeacher() => $_clearField(7);
}

class DeleteExamPayload extends $pb.GeneratedMessage {
  factory DeleteExamPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteExamPayload._();

  factory DeleteExamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteExamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteExamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteExamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteExamPayload copyWith(void Function(DeleteExamPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteExamPayload))
          as DeleteExamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteExamPayload create() => DeleteExamPayload._();
  @$core.override
  DeleteExamPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteExamPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteExamPayload>(create);
  static DeleteExamPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreatePaperPayload extends $pb.GeneratedMessage {
  factory CreatePaperPayload({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.String? invigilator,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
    $core.int? topic,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (invigilator != null) result.invigilator = invigilator;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (topic != null) result.topic = topic;
    return result;
  }

  CreatePaperPayload._();

  factory CreatePaperPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePaperPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePaperPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..aOS(5, _omitFieldNames ? '' : 'invigilator')
    ..aInt64(6, _omitFieldNames ? '' : 'start')
    ..aInt64(7, _omitFieldNames ? '' : 'end')
    ..aI(8, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaperPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaperPayload copyWith(void Function(CreatePaperPayload) updates) =>
      super.copyWith((message) => updates(message as CreatePaperPayload))
          as CreatePaperPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePaperPayload create() => CreatePaperPayload._();
  @$core.override
  CreatePaperPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePaperPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePaperPayload>(create);
  static CreatePaperPayload? _defaultInstance;

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
  $core.int get topic => $_getIZ(7);
  @$pb.TagNumber(8)
  set topic($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTopic() => $_has(7);
  @$pb.TagNumber(8)
  void clearTopic() => $_clearField(8);
}

class UpdatePaperPayload extends $pb.GeneratedMessage {
  factory UpdatePaperPayload({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.String? invigilator,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
    $core.int? status,
    $core.int? topic,
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
    if (topic != null) result.topic = topic;
    return result;
  }

  UpdatePaperPayload._();

  factory UpdatePaperPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePaperPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePaperPayload',
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
    ..aI(9, _omitFieldNames ? '' : 'topic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaperPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaperPayload copyWith(void Function(UpdatePaperPayload) updates) =>
      super.copyWith((message) => updates(message as UpdatePaperPayload))
          as UpdatePaperPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePaperPayload create() => UpdatePaperPayload._();
  @$core.override
  UpdatePaperPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePaperPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePaperPayload>(create);
  static UpdatePaperPayload? _defaultInstance;

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

  @$pb.TagNumber(9)
  $core.int get topic => $_getIZ(8);
  @$pb.TagNumber(9)
  set topic($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTopic() => $_has(8);
  @$pb.TagNumber(9)
  void clearTopic() => $_clearField(9);
}

class DeletePaperPayload extends $pb.GeneratedMessage {
  factory DeletePaperPayload({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    return result;
  }

  DeletePaperPayload._();

  factory DeletePaperPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePaperPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePaperPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaperPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaperPayload copyWith(void Function(DeletePaperPayload) updates) =>
      super.copyWith((message) => updates(message as DeletePaperPayload))
          as DeletePaperPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePaperPayload create() => DeletePaperPayload._();
  @$core.override
  DeletePaperPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePaperPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePaperPayload>(create);
  static DeletePaperPayload? _defaultInstance;

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
}

class GradeRecord extends $pb.GeneratedMessage {
  factory GradeRecord({
    $core.int? student,
    $core.double? score,
    $core.int? total,
  }) {
    final result = create();
    if (student != null) result.student = student;
    if (score != null) result.score = score;
    if (total != null) result.total = total;
    return result;
  }

  GradeRecord._();

  factory GradeRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GradeRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GradeRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'student')
    ..aD(2, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'total')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeRecord copyWith(void Function(GradeRecord) updates) =>
      super.copyWith((message) => updates(message as GradeRecord))
          as GradeRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GradeRecord create() => GradeRecord._();
  @$core.override
  GradeRecord createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GradeRecord getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GradeRecord>(create);
  static GradeRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get student => $_getIZ(0);
  @$pb.TagNumber(1)
  set student($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStudent() => $_has(0);
  @$pb.TagNumber(1)
  void clearStudent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get score => $_getN(1);
  @$pb.TagNumber(2)
  set score($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScore() => $_has(1);
  @$pb.TagNumber(2)
  void clearScore() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get total => $_getIZ(2);
  @$pb.TagNumber(3)
  set total($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotal() => $_clearField(3);
}

class MarkGradesPayload extends $pb.GeneratedMessage {
  factory MarkGradesPayload({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.Iterable<GradeRecord>? records,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (exam != null) result.exam = exam;
    if (subject != null) result.subject = subject;
    if (paper != null) result.paper = paper;
    if (records != null) result.records.addAll(records);
    return result;
  }

  MarkGradesPayload._();

  factory MarkGradesPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkGradesPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkGradesPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'paper')
    ..pPM<GradeRecord>(5, _omitFieldNames ? '' : 'records',
        subBuilder: GradeRecord.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkGradesPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkGradesPayload copyWith(void Function(MarkGradesPayload) updates) =>
      super.copyWith((message) => updates(message as MarkGradesPayload))
          as MarkGradesPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkGradesPayload create() => MarkGradesPayload._();
  @$core.override
  MarkGradesPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkGradesPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkGradesPayload>(create);
  static MarkGradesPayload? _defaultInstance;

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
  $pb.PbList<GradeRecord> get records => $_getList(4);
}

class UpdateGradePayload extends $pb.GeneratedMessage {
  factory UpdateGradePayload({
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

  UpdateGradePayload._();

  factory UpdateGradePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateGradePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateGradePayload',
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
  UpdateGradePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateGradePayload copyWith(void Function(UpdateGradePayload) updates) =>
      super.copyWith((message) => updates(message as UpdateGradePayload))
          as UpdateGradePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateGradePayload create() => UpdateGradePayload._();
  @$core.override
  UpdateGradePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateGradePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateGradePayload>(create);
  static UpdateGradePayload? _defaultInstance;

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

class DeleteGradePayload extends $pb.GeneratedMessage {
  factory DeleteGradePayload({
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

  DeleteGradePayload._();

  factory DeleteGradePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteGradePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteGradePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'exam')
    ..aI(3, _omitFieldNames ? '' : 'student')
    ..aI(4, _omitFieldNames ? '' : 'subject')
    ..aI(5, _omitFieldNames ? '' : 'paper')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteGradePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteGradePayload copyWith(void Function(DeleteGradePayload) updates) =>
      super.copyWith((message) => updates(message as DeleteGradePayload))
          as DeleteGradePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteGradePayload create() => DeleteGradePayload._();
  @$core.override
  DeleteGradePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteGradePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteGradePayload>(create);
  static DeleteGradePayload? _defaultInstance;

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

class UpdateMasteryPayload extends $pb.GeneratedMessage {
  factory UpdateMasteryPayload({
    $core.String? school,
    $core.int? student,
    $core.int? subject,
    $core.int? topic,
    $core.double? score,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (student != null) result.student = student;
    if (subject != null) result.subject = subject;
    if (topic != null) result.topic = topic;
    if (score != null) result.score = score;
    return result;
  }

  UpdateMasteryPayload._();

  factory UpdateMasteryPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateMasteryPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateMasteryPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'student')
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'topic')
    ..aD(5, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMasteryPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMasteryPayload copyWith(void Function(UpdateMasteryPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateMasteryPayload))
          as UpdateMasteryPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateMasteryPayload create() => UpdateMasteryPayload._();
  @$core.override
  UpdateMasteryPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateMasteryPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateMasteryPayload>(create);
  static UpdateMasteryPayload? _defaultInstance;

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
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get topic => $_getIZ(3);
  @$pb.TagNumber(4)
  set topic($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTopic() => $_has(3);
  @$pb.TagNumber(4)
  void clearTopic() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get score => $_getN(4);
  @$pb.TagNumber(5)
  set score($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScore() => $_has(4);
  @$pb.TagNumber(5)
  void clearScore() => $_clearField(5);
}

class CreateFeePayload extends $pb.GeneratedMessage {
  factory CreateFeePayload({
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

  CreateFeePayload._();

  factory CreateFeePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateFeePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateFeePayload',
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
  CreateFeePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateFeePayload copyWith(void Function(CreateFeePayload) updates) =>
      super.copyWith((message) => updates(message as CreateFeePayload))
          as CreateFeePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateFeePayload create() => CreateFeePayload._();
  @$core.override
  CreateFeePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateFeePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateFeePayload>(create);
  static CreateFeePayload? _defaultInstance;

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

class UpdateFeePayload extends $pb.GeneratedMessage {
  factory UpdateFeePayload({
    $core.String? id,
    $core.String? title,
    $core.String? description,
    $core.double? amount,
    $core.bool? mandatory,
    $fixnum.Int64? due,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (mandatory != null) result.mandatory = mandatory;
    if (due != null) result.due = due;
    return result;
  }

  UpdateFeePayload._();

  factory UpdateFeePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateFeePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateFeePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aD(4, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aOB(5, _omitFieldNames ? '' : 'mandatory')
    ..aInt64(6, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFeePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFeePayload copyWith(void Function(UpdateFeePayload) updates) =>
      super.copyWith((message) => updates(message as UpdateFeePayload))
          as UpdateFeePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateFeePayload create() => UpdateFeePayload._();
  @$core.override
  UpdateFeePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateFeePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateFeePayload>(create);
  static UpdateFeePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

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
  $core.bool get mandatory => $_getBF(4);
  @$pb.TagNumber(5)
  set mandatory($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMandatory() => $_has(4);
  @$pb.TagNumber(5)
  void clearMandatory() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get due => $_getI64(5);
  @$pb.TagNumber(6)
  set due($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDue() => $_has(5);
  @$pb.TagNumber(6)
  void clearDue() => $_clearField(6);
}

class DeleteFeePayload extends $pb.GeneratedMessage {
  factory DeleteFeePayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteFeePayload._();

  factory DeleteFeePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteFeePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteFeePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteFeePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteFeePayload copyWith(void Function(DeleteFeePayload) updates) =>
      super.copyWith((message) => updates(message as DeleteFeePayload))
          as DeleteFeePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteFeePayload create() => DeleteFeePayload._();
  @$core.override
  DeleteFeePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteFeePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteFeePayload>(create);
  static DeleteFeePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateInvoicePayload extends $pb.GeneratedMessage {
  factory CreateInvoicePayload({
    $core.String? id,
    $core.String? school,
    $core.int? year,
    $core.int? term,
    $core.String? fee,
    $core.String? description,
    $core.int? student,
    $core.double? amount,
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
    if (due != null) result.due = due;
    return result;
  }

  CreateInvoicePayload._();

  factory CreateInvoicePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateInvoicePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateInvoicePayload',
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
    ..aInt64(9, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateInvoicePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateInvoicePayload copyWith(void Function(CreateInvoicePayload) updates) =>
      super.copyWith((message) => updates(message as CreateInvoicePayload))
          as CreateInvoicePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateInvoicePayload create() => CreateInvoicePayload._();
  @$core.override
  CreateInvoicePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateInvoicePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateInvoicePayload>(create);
  static CreateInvoicePayload? _defaultInstance;

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
  $fixnum.Int64 get due => $_getI64(8);
  @$pb.TagNumber(9)
  set due($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDue() => $_has(8);
  @$pb.TagNumber(9)
  void clearDue() => $_clearField(9);
}

class UpdateInvoicePayload extends $pb.GeneratedMessage {
  factory UpdateInvoicePayload({
    $core.String? id,
    $core.String? fee,
    $core.String? description,
    $core.double? amount,
    $core.int? status,
    $fixnum.Int64? due,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (fee != null) result.fee = fee;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (status != null) result.status = status;
    if (due != null) result.due = due;
    return result;
  }

  UpdateInvoicePayload._();

  factory UpdateInvoicePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateInvoicePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateInvoicePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'fee')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aD(4, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'status')
    ..aInt64(6, _omitFieldNames ? '' : 'due')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateInvoicePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateInvoicePayload copyWith(void Function(UpdateInvoicePayload) updates) =>
      super.copyWith((message) => updates(message as UpdateInvoicePayload))
          as UpdateInvoicePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateInvoicePayload create() => UpdateInvoicePayload._();
  @$core.override
  UpdateInvoicePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateInvoicePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateInvoicePayload>(create);
  static UpdateInvoicePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fee => $_getSZ(1);
  @$pb.TagNumber(2)
  set fee($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFee() => $_has(1);
  @$pb.TagNumber(2)
  void clearFee() => $_clearField(2);

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
  $core.int get status => $_getIZ(4);
  @$pb.TagNumber(5)
  set status($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get due => $_getI64(5);
  @$pb.TagNumber(6)
  set due($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDue() => $_has(5);
  @$pb.TagNumber(6)
  void clearDue() => $_clearField(6);
}

class DeleteInvoicePayload extends $pb.GeneratedMessage {
  factory DeleteInvoicePayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteInvoicePayload._();

  factory DeleteInvoicePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteInvoicePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteInvoicePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteInvoicePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteInvoicePayload copyWith(void Function(DeleteInvoicePayload) updates) =>
      super.copyWith((message) => updates(message as DeleteInvoicePayload))
          as DeleteInvoicePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteInvoicePayload create() => DeleteInvoicePayload._();
  @$core.override
  DeleteInvoicePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteInvoicePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteInvoicePayload>(create);
  static DeleteInvoicePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreatePaymentPayload extends $pb.GeneratedMessage {
  factory CreatePaymentPayload({
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

  CreatePaymentPayload._();

  factory CreatePaymentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePaymentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePaymentPayload',
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
  CreatePaymentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePaymentPayload copyWith(void Function(CreatePaymentPayload) updates) =>
      super.copyWith((message) => updates(message as CreatePaymentPayload))
          as CreatePaymentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePaymentPayload create() => CreatePaymentPayload._();
  @$core.override
  CreatePaymentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePaymentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePaymentPayload>(create);
  static CreatePaymentPayload? _defaultInstance;

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

class UpdatePaymentPayload extends $pb.GeneratedMessage {
  factory UpdatePaymentPayload({
    $core.String? id,
    $core.String? invoice,
    $core.double? amount,
    $core.int? method,
    $core.String? reference,
    $core.String? recorder,
    $core.int? date,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (invoice != null) result.invoice = invoice;
    if (amount != null) result.amount = amount;
    if (method != null) result.method = method;
    if (reference != null) result.reference = reference;
    if (recorder != null) result.recorder = recorder;
    if (date != null) result.date = date;
    return result;
  }

  UpdatePaymentPayload._();

  factory UpdatePaymentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePaymentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePaymentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'invoice')
    ..aD(3, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'method')
    ..aOS(5, _omitFieldNames ? '' : 'reference')
    ..aOS(6, _omitFieldNames ? '' : 'recorder')
    ..aI(7, _omitFieldNames ? '' : 'date')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaymentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePaymentPayload copyWith(void Function(UpdatePaymentPayload) updates) =>
      super.copyWith((message) => updates(message as UpdatePaymentPayload))
          as UpdatePaymentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePaymentPayload create() => UpdatePaymentPayload._();
  @$core.override
  UpdatePaymentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePaymentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePaymentPayload>(create);
  static UpdatePaymentPayload? _defaultInstance;

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
  $core.double get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get method => $_getIZ(3);
  @$pb.TagNumber(4)
  set method($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMethod() => $_has(3);
  @$pb.TagNumber(4)
  void clearMethod() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reference => $_getSZ(4);
  @$pb.TagNumber(5)
  set reference($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReference() => $_has(4);
  @$pb.TagNumber(5)
  void clearReference() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get recorder => $_getSZ(5);
  @$pb.TagNumber(6)
  set recorder($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRecorder() => $_has(5);
  @$pb.TagNumber(6)
  void clearRecorder() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get date => $_getIZ(6);
  @$pb.TagNumber(7)
  set date($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearDate() => $_clearField(7);
}

class DeletePaymentPayload extends $pb.GeneratedMessage {
  factory DeletePaymentPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeletePaymentPayload._();

  factory DeletePaymentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePaymentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePaymentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaymentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePaymentPayload copyWith(void Function(DeletePaymentPayload) updates) =>
      super.copyWith((message) => updates(message as DeletePaymentPayload))
          as DeletePaymentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePaymentPayload create() => DeletePaymentPayload._();
  @$core.override
  DeletePaymentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePaymentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePaymentPayload>(create);
  static DeletePaymentPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ApprovePaymentPayload extends $pb.GeneratedMessage {
  factory ApprovePaymentPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  ApprovePaymentPayload._();

  factory ApprovePaymentPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApprovePaymentPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApprovePaymentPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovePaymentPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovePaymentPayload copyWith(
          void Function(ApprovePaymentPayload) updates) =>
      super.copyWith((message) => updates(message as ApprovePaymentPayload))
          as ApprovePaymentPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApprovePaymentPayload create() => ApprovePaymentPayload._();
  @$core.override
  ApprovePaymentPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApprovePaymentPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApprovePaymentPayload>(create);
  static ApprovePaymentPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateAnnouncementPayload extends $pb.GeneratedMessage {
  factory CreateAnnouncementPayload({
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

  CreateAnnouncementPayload._();

  factory CreateAnnouncementPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateAnnouncementPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateAnnouncementPayload',
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
  CreateAnnouncementPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAnnouncementPayload copyWith(
          void Function(CreateAnnouncementPayload) updates) =>
      super.copyWith((message) => updates(message as CreateAnnouncementPayload))
          as CreateAnnouncementPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAnnouncementPayload create() => CreateAnnouncementPayload._();
  @$core.override
  CreateAnnouncementPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateAnnouncementPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateAnnouncementPayload>(create);
  static CreateAnnouncementPayload? _defaultInstance;

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

class UpdateAnnouncementPayload extends $pb.GeneratedMessage {
  factory UpdateAnnouncementPayload({
    $core.String? id,
    $core.String? title,
    $core.String? content,
    $core.int? grade,
    $core.int? stream,
    $core.int? audience,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (content != null) result.content = content;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (audience != null) result.audience = audience;
    return result;
  }

  UpdateAnnouncementPayload._();

  factory UpdateAnnouncementPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateAnnouncementPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateAnnouncementPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'content')
    ..aI(4, _omitFieldNames ? '' : 'grade')
    ..aI(5, _omitFieldNames ? '' : 'stream')
    ..aI(6, _omitFieldNames ? '' : 'audience')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAnnouncementPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAnnouncementPayload copyWith(
          void Function(UpdateAnnouncementPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateAnnouncementPayload))
          as UpdateAnnouncementPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateAnnouncementPayload create() => UpdateAnnouncementPayload._();
  @$core.override
  UpdateAnnouncementPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateAnnouncementPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateAnnouncementPayload>(create);
  static UpdateAnnouncementPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);

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
  $core.int get audience => $_getIZ(5);
  @$pb.TagNumber(6)
  set audience($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAudience() => $_has(5);
  @$pb.TagNumber(6)
  void clearAudience() => $_clearField(6);
}

class DeleteAnnouncementPayload extends $pb.GeneratedMessage {
  factory DeleteAnnouncementPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteAnnouncementPayload._();

  factory DeleteAnnouncementPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAnnouncementPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAnnouncementPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAnnouncementPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAnnouncementPayload copyWith(
          void Function(DeleteAnnouncementPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteAnnouncementPayload))
          as DeleteAnnouncementPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAnnouncementPayload create() => DeleteAnnouncementPayload._();
  @$core.override
  DeleteAnnouncementPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAnnouncementPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAnnouncementPayload>(create);
  static DeleteAnnouncementPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateRolePayload extends $pb.GeneratedMessage {
  factory CreateRolePayload({
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

  CreateRolePayload._();

  factory CreateRolePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateRolePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateRolePayload',
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
  CreateRolePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateRolePayload copyWith(void Function(CreateRolePayload) updates) =>
      super.copyWith((message) => updates(message as CreateRolePayload))
          as CreateRolePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateRolePayload create() => CreateRolePayload._();
  @$core.override
  CreateRolePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateRolePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateRolePayload>(create);
  static CreateRolePayload? _defaultInstance;

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

class UpdateRolePayload extends $pb.GeneratedMessage {
  factory UpdateRolePayload({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.List<$core.int>? permissions,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (permissions != null) result.permissions = permissions;
    return result;
  }

  UpdateRolePayload._();

  factory UpdateRolePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateRolePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateRolePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'permissions', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateRolePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateRolePayload copyWith(void Function(UpdateRolePayload) updates) =>
      super.copyWith((message) => updates(message as UpdateRolePayload))
          as UpdateRolePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateRolePayload create() => UpdateRolePayload._();
  @$core.override
  UpdateRolePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateRolePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateRolePayload>(create);
  static UpdateRolePayload? _defaultInstance;

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
  $core.List<$core.int> get permissions => $_getN(3);
  @$pb.TagNumber(4)
  set permissions($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPermissions() => $_has(3);
  @$pb.TagNumber(4)
  void clearPermissions() => $_clearField(4);
}

class DeleteRolePayload extends $pb.GeneratedMessage {
  factory DeleteRolePayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteRolePayload._();

  factory DeleteRolePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteRolePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteRolePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteRolePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteRolePayload copyWith(void Function(DeleteRolePayload) updates) =>
      super.copyWith((message) => updates(message as DeleteRolePayload))
          as DeleteRolePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteRolePayload create() => DeleteRolePayload._();
  @$core.override
  DeleteRolePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteRolePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteRolePayload>(create);
  static DeleteRolePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class AssignRolePayload extends $pb.GeneratedMessage {
  factory AssignRolePayload({
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

  AssignRolePayload._();

  factory AssignRolePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssignRolePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssignRolePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aOS(3, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignRolePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignRolePayload copyWith(void Function(AssignRolePayload) updates) =>
      super.copyWith((message) => updates(message as AssignRolePayload))
          as AssignRolePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssignRolePayload create() => AssignRolePayload._();
  @$core.override
  AssignRolePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssignRolePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssignRolePayload>(create);
  static AssignRolePayload? _defaultInstance;

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

class UnassignRolePayload extends $pb.GeneratedMessage {
  factory UnassignRolePayload({
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

  UnassignRolePayload._();

  factory UnassignRolePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnassignRolePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnassignRolePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'user')
    ..aOS(3, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignRolePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignRolePayload copyWith(void Function(UnassignRolePayload) updates) =>
      super.copyWith((message) => updates(message as UnassignRolePayload))
          as UnassignRolePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnassignRolePayload create() => UnassignRolePayload._();
  @$core.override
  UnassignRolePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnassignRolePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnassignRolePayload>(create);
  static UnassignRolePayload? _defaultInstance;

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

class UpdateUserPayload extends $pb.GeneratedMessage {
  factory UpdateUserPayload({
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

  UpdateUserPayload._();

  factory UpdateUserPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateUserPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateUserPayload',
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
  UpdateUserPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateUserPayload copyWith(void Function(UpdateUserPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateUserPayload))
          as UpdateUserPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateUserPayload create() => UpdateUserPayload._();
  @$core.override
  UpdateUserPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateUserPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateUserPayload>(create);
  static UpdateUserPayload? _defaultInstance;

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

class DeleteUserPayload extends $pb.GeneratedMessage {
  factory DeleteUserPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteUserPayload._();

  factory DeleteUserPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteUserPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteUserPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteUserPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteUserPayload copyWith(void Function(DeleteUserPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteUserPayload))
          as DeleteUserPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteUserPayload create() => DeleteUserPayload._();
  @$core.override
  DeleteUserPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteUserPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteUserPayload>(create);
  static DeleteUserPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateSubjectPayload extends $pb.GeneratedMessage {
  factory CreateSubjectPayload({
    $core.String? name,
    $core.int? curriculum,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (curriculum != null) result.curriculum = curriculum;
    return result;
  }

  CreateSubjectPayload._();

  factory CreateSubjectPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateSubjectPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSubjectPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'curriculum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSubjectPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSubjectPayload copyWith(void Function(CreateSubjectPayload) updates) =>
      super.copyWith((message) => updates(message as CreateSubjectPayload))
          as CreateSubjectPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateSubjectPayload create() => CreateSubjectPayload._();
  @$core.override
  CreateSubjectPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateSubjectPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateSubjectPayload>(create);
  static CreateSubjectPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get curriculum => $_getIZ(1);
  @$pb.TagNumber(2)
  set curriculum($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCurriculum() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurriculum() => $_clearField(2);
}

class UpdateSubjectPayload extends $pb.GeneratedMessage {
  factory UpdateSubjectPayload({
    $core.int? id,
    $core.String? name,
    $core.int? curriculum,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (curriculum != null) result.curriculum = curriculum;
    return result;
  }

  UpdateSubjectPayload._();

  factory UpdateSubjectPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSubjectPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSubjectPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'curriculum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSubjectPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSubjectPayload copyWith(void Function(UpdateSubjectPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateSubjectPayload))
          as UpdateSubjectPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSubjectPayload create() => UpdateSubjectPayload._();
  @$core.override
  UpdateSubjectPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSubjectPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSubjectPayload>(create);
  static UpdateSubjectPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
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
  $core.int get curriculum => $_getIZ(2);
  @$pb.TagNumber(3)
  set curriculum($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurriculum() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurriculum() => $_clearField(3);
}

class DeleteSubjectPayload extends $pb.GeneratedMessage {
  factory DeleteSubjectPayload({
    $core.int? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteSubjectPayload._();

  factory DeleteSubjectPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteSubjectPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSubjectPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSubjectPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSubjectPayload copyWith(void Function(DeleteSubjectPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteSubjectPayload))
          as DeleteSubjectPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteSubjectPayload create() => DeleteSubjectPayload._();
  @$core.override
  DeleteSubjectPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteSubjectPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSubjectPayload>(create);
  static DeleteSubjectPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateTopicPayload extends $pb.GeneratedMessage {
  factory CreateTopicPayload({
    $core.int? subject,
    $core.int? grade,
    $core.String? name,
  }) {
    final result = create();
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (name != null) result.name = name;
    return result;
  }

  CreateTopicPayload._();

  factory CreateTopicPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTopicPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTopicPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'subject')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTopicPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTopicPayload copyWith(void Function(CreateTopicPayload) updates) =>
      super.copyWith((message) => updates(message as CreateTopicPayload))
          as CreateTopicPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTopicPayload create() => CreateTopicPayload._();
  @$core.override
  CreateTopicPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTopicPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTopicPayload>(create);
  static CreateTopicPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get subject => $_getIZ(0);
  @$pb.TagNumber(1)
  set subject($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubject() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubject() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);
}

class UpdateTopicPayload extends $pb.GeneratedMessage {
  factory UpdateTopicPayload({
    $core.int? id,
    $core.int? subject,
    $core.int? grade,
    $core.String? name,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (name != null) result.name = name;
    return result;
  }

  UpdateTopicPayload._();

  factory UpdateTopicPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTopicPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTopicPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'subject')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTopicPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTopicPayload copyWith(void Function(UpdateTopicPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateTopicPayload))
          as UpdateTopicPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTopicPayload create() => UpdateTopicPayload._();
  @$core.override
  UpdateTopicPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTopicPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTopicPayload>(create);
  static UpdateTopicPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

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
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);
}

class DeleteTopicPayload extends $pb.GeneratedMessage {
  factory DeleteTopicPayload({
    $core.int? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteTopicPayload._();

  factory DeleteTopicPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTopicPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTopicPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTopicPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTopicPayload copyWith(void Function(DeleteTopicPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteTopicPayload))
          as DeleteTopicPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTopicPayload create() => DeleteTopicPayload._();
  @$core.override
  DeleteTopicPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTopicPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTopicPayload>(create);
  static DeleteTopicPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateStreamPayload extends $pb.GeneratedMessage {
  factory CreateStreamPayload({
    $core.String? school,
    $core.int? grade,
    $core.int? stream,
    $core.String? name,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (name != null) result.name = name;
    return result;
  }

  CreateStreamPayload._();

  factory CreateStreamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateStreamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateStreamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateStreamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateStreamPayload copyWith(void Function(CreateStreamPayload) updates) =>
      super.copyWith((message) => updates(message as CreateStreamPayload))
          as CreateStreamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateStreamPayload create() => CreateStreamPayload._();
  @$core.override
  CreateStreamPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateStreamPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateStreamPayload>(create);
  static CreateStreamPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);
}

class UpdateStreamPayload extends $pb.GeneratedMessage {
  factory UpdateStreamPayload({
    $core.String? school,
    $core.int? grade,
    $core.int? stream,
    $core.String? name,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (name != null) result.name = name;
    return result;
  }

  UpdateStreamPayload._();

  factory UpdateStreamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateStreamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateStreamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStreamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStreamPayload copyWith(void Function(UpdateStreamPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateStreamPayload))
          as UpdateStreamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateStreamPayload create() => UpdateStreamPayload._();
  @$core.override
  UpdateStreamPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateStreamPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateStreamPayload>(create);
  static UpdateStreamPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);
}

class DeleteStreamPayload extends $pb.GeneratedMessage {
  factory DeleteStreamPayload({
    $core.String? school,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  DeleteStreamPayload._();

  factory DeleteStreamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteStreamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteStreamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteStreamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteStreamPayload copyWith(void Function(DeleteStreamPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteStreamPayload))
          as DeleteStreamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteStreamPayload create() => DeleteStreamPayload._();
  @$core.override
  DeleteStreamPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteStreamPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteStreamPayload>(create);
  static DeleteStreamPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);
}

class CreateMpesaPayload extends $pb.GeneratedMessage {
  factory CreateMpesaPayload({
    $core.String? school,
    $core.String? consumerKey,
    $core.String? consumerSecret,
    $core.String? passkey,
    $core.String? shortcode,
    $core.int? env,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (consumerKey != null) result.consumerKey = consumerKey;
    if (consumerSecret != null) result.consumerSecret = consumerSecret;
    if (passkey != null) result.passkey = passkey;
    if (shortcode != null) result.shortcode = shortcode;
    if (env != null) result.env = env;
    return result;
  }

  CreateMpesaPayload._();

  factory CreateMpesaPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateMpesaPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateMpesaPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'consumerKey')
    ..aOS(3, _omitFieldNames ? '' : 'consumerSecret')
    ..aOS(4, _omitFieldNames ? '' : 'passkey')
    ..aOS(5, _omitFieldNames ? '' : 'shortcode')
    ..aI(6, _omitFieldNames ? '' : 'env')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateMpesaPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateMpesaPayload copyWith(void Function(CreateMpesaPayload) updates) =>
      super.copyWith((message) => updates(message as CreateMpesaPayload))
          as CreateMpesaPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateMpesaPayload create() => CreateMpesaPayload._();
  @$core.override
  CreateMpesaPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateMpesaPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateMpesaPayload>(create);
  static CreateMpesaPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get consumerKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set consumerKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConsumerKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearConsumerKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get consumerSecret => $_getSZ(2);
  @$pb.TagNumber(3)
  set consumerSecret($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConsumerSecret() => $_has(2);
  @$pb.TagNumber(3)
  void clearConsumerSecret() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get passkey => $_getSZ(3);
  @$pb.TagNumber(4)
  set passkey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPasskey() => $_has(3);
  @$pb.TagNumber(4)
  void clearPasskey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get shortcode => $_getSZ(4);
  @$pb.TagNumber(5)
  set shortcode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShortcode() => $_has(4);
  @$pb.TagNumber(5)
  void clearShortcode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get env => $_getIZ(5);
  @$pb.TagNumber(6)
  set env($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnv() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnv() => $_clearField(6);
}

class UpdateMpesaPayload extends $pb.GeneratedMessage {
  factory UpdateMpesaPayload({
    $core.String? school,
    $core.String? consumerKey,
    $core.String? consumerSecret,
    $core.String? passkey,
    $core.String? shortcode,
    $core.int? env,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (consumerKey != null) result.consumerKey = consumerKey;
    if (consumerSecret != null) result.consumerSecret = consumerSecret;
    if (passkey != null) result.passkey = passkey;
    if (shortcode != null) result.shortcode = shortcode;
    if (env != null) result.env = env;
    return result;
  }

  UpdateMpesaPayload._();

  factory UpdateMpesaPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateMpesaPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateMpesaPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'consumerKey')
    ..aOS(3, _omitFieldNames ? '' : 'consumerSecret')
    ..aOS(4, _omitFieldNames ? '' : 'passkey')
    ..aOS(5, _omitFieldNames ? '' : 'shortcode')
    ..aI(6, _omitFieldNames ? '' : 'env')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMpesaPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMpesaPayload copyWith(void Function(UpdateMpesaPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateMpesaPayload))
          as UpdateMpesaPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateMpesaPayload create() => UpdateMpesaPayload._();
  @$core.override
  UpdateMpesaPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateMpesaPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateMpesaPayload>(create);
  static UpdateMpesaPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get consumerKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set consumerKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConsumerKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearConsumerKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get consumerSecret => $_getSZ(2);
  @$pb.TagNumber(3)
  set consumerSecret($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConsumerSecret() => $_has(2);
  @$pb.TagNumber(3)
  void clearConsumerSecret() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get passkey => $_getSZ(3);
  @$pb.TagNumber(4)
  set passkey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPasskey() => $_has(3);
  @$pb.TagNumber(4)
  void clearPasskey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get shortcode => $_getSZ(4);
  @$pb.TagNumber(5)
  set shortcode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShortcode() => $_has(4);
  @$pb.TagNumber(5)
  void clearShortcode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get env => $_getIZ(5);
  @$pb.TagNumber(6)
  set env($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnv() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnv() => $_clearField(6);
}

class DeleteMpesaPayload extends $pb.GeneratedMessage {
  factory DeleteMpesaPayload({
    $core.String? school,
  }) {
    final result = create();
    if (school != null) result.school = school;
    return result;
  }

  DeleteMpesaPayload._();

  factory DeleteMpesaPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteMpesaPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteMpesaPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteMpesaPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteMpesaPayload copyWith(void Function(DeleteMpesaPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteMpesaPayload))
          as DeleteMpesaPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteMpesaPayload create() => DeleteMpesaPayload._();
  @$core.override
  DeleteMpesaPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteMpesaPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteMpesaPayload>(create);
  static DeleteMpesaPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);
}

class AddExamGradePayload extends $pb.GeneratedMessage {
  factory AddExamGradePayload({
    $core.String? exam,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (exam != null) result.exam = exam;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  AddExamGradePayload._();

  factory AddExamGradePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddExamGradePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddExamGradePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'exam')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddExamGradePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddExamGradePayload copyWith(void Function(AddExamGradePayload) updates) =>
      super.copyWith((message) => updates(message as AddExamGradePayload))
          as AddExamGradePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddExamGradePayload create() => AddExamGradePayload._();
  @$core.override
  AddExamGradePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddExamGradePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddExamGradePayload>(create);
  static AddExamGradePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get exam => $_getSZ(0);
  @$pb.TagNumber(1)
  set exam($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExam() => $_has(0);
  @$pb.TagNumber(1)
  void clearExam() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);
}

class RemoveExamGradePayload extends $pb.GeneratedMessage {
  factory RemoveExamGradePayload({
    $core.String? exam,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (exam != null) result.exam = exam;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  RemoveExamGradePayload._();

  factory RemoveExamGradePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveExamGradePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveExamGradePayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'exam')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveExamGradePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveExamGradePayload copyWith(
          void Function(RemoveExamGradePayload) updates) =>
      super.copyWith((message) => updates(message as RemoveExamGradePayload))
          as RemoveExamGradePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveExamGradePayload create() => RemoveExamGradePayload._();
  @$core.override
  RemoveExamGradePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveExamGradePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveExamGradePayload>(create);
  static RemoveExamGradePayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get exam => $_getSZ(0);
  @$pb.TagNumber(1)
  set exam($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExam() => $_has(0);
  @$pb.TagNumber(1)
  void clearExam() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);
}

class CreatePlanPayload extends $pb.GeneratedMessage {
  factory CreatePlanPayload({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.double? amount,
    $core.int? levels,
    $core.String? features,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (amount != null) result.amount = amount;
    if (levels != null) result.levels = levels;
    if (features != null) result.features = features;
    return result;
  }

  CreatePlanPayload._();

  factory CreatePlanPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePlanPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePlanPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aD(4, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'levels')
    ..aOS(6, _omitFieldNames ? '' : 'features')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePlanPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePlanPayload copyWith(void Function(CreatePlanPayload) updates) =>
      super.copyWith((message) => updates(message as CreatePlanPayload))
          as CreatePlanPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePlanPayload create() => CreatePlanPayload._();
  @$core.override
  CreatePlanPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePlanPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePlanPayload>(create);
  static CreatePlanPayload? _defaultInstance;

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
  $core.String get features => $_getSZ(5);
  @$pb.TagNumber(6)
  set features($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFeatures() => $_has(5);
  @$pb.TagNumber(6)
  void clearFeatures() => $_clearField(6);
}

class UpdatePlanPayload extends $pb.GeneratedMessage {
  factory UpdatePlanPayload({
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

  UpdatePlanPayload._();

  factory UpdatePlanPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePlanPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePlanPayload',
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
  UpdatePlanPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePlanPayload copyWith(void Function(UpdatePlanPayload) updates) =>
      super.copyWith((message) => updates(message as UpdatePlanPayload))
          as UpdatePlanPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePlanPayload create() => UpdatePlanPayload._();
  @$core.override
  UpdatePlanPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePlanPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePlanPayload>(create);
  static UpdatePlanPayload? _defaultInstance;

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

class DeletePlanPayload extends $pb.GeneratedMessage {
  factory DeletePlanPayload({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeletePlanPayload._();

  factory DeletePlanPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePlanPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePlanPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePlanPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePlanPayload copyWith(void Function(DeletePlanPayload) updates) =>
      super.copyWith((message) => updates(message as DeletePlanPayload))
          as DeletePlanPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePlanPayload create() => DeletePlanPayload._();
  @$core.override
  DeletePlanPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePlanPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePlanPayload>(create);
  static DeletePlanPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class UpdateAiUsagePayload extends $pb.GeneratedMessage {
  factory UpdateAiUsagePayload({
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

  UpdateAiUsagePayload._();

  factory UpdateAiUsagePayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateAiUsagePayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateAiUsagePayload',
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
  UpdateAiUsagePayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAiUsagePayload copyWith(void Function(UpdateAiUsagePayload) updates) =>
      super.copyWith((message) => updates(message as UpdateAiUsagePayload))
          as UpdateAiUsagePayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateAiUsagePayload create() => UpdateAiUsagePayload._();
  @$core.override
  UpdateAiUsagePayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateAiUsagePayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateAiUsagePayload>(create);
  static UpdateAiUsagePayload? _defaultInstance;

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

class CreateSubscriptionPayload extends $pb.GeneratedMessage {
  factory CreateSubscriptionPayload({
    $core.String? school,
    $core.String? plan,
    $core.int? year,
    $core.int? term,
    $core.int? student,
    $core.String? invoice,
    $core.double? discount,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (plan != null) result.plan = plan;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (student != null) result.student = student;
    if (invoice != null) result.invoice = invoice;
    if (discount != null) result.discount = discount;
    return result;
  }

  CreateSubscriptionPayload._();

  factory CreateSubscriptionPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateSubscriptionPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSubscriptionPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'plan')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'student')
    ..aOS(6, _omitFieldNames ? '' : 'invoice')
    ..aD(7, _omitFieldNames ? '' : 'discount', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSubscriptionPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSubscriptionPayload copyWith(
          void Function(CreateSubscriptionPayload) updates) =>
      super.copyWith((message) => updates(message as CreateSubscriptionPayload))
          as CreateSubscriptionPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateSubscriptionPayload create() => CreateSubscriptionPayload._();
  @$core.override
  CreateSubscriptionPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateSubscriptionPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateSubscriptionPayload>(create);
  static CreateSubscriptionPayload? _defaultInstance;

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
}

class UpdateSubscriptionPayload extends $pb.GeneratedMessage {
  factory UpdateSubscriptionPayload({
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

  UpdateSubscriptionPayload._();

  factory UpdateSubscriptionPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSubscriptionPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSubscriptionPayload',
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
  UpdateSubscriptionPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSubscriptionPayload copyWith(
          void Function(UpdateSubscriptionPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateSubscriptionPayload))
          as UpdateSubscriptionPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSubscriptionPayload create() => UpdateSubscriptionPayload._();
  @$core.override
  UpdateSubscriptionPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSubscriptionPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSubscriptionPayload>(create);
  static UpdateSubscriptionPayload? _defaultInstance;

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

class DeleteSubscriptionPayload extends $pb.GeneratedMessage {
  factory DeleteSubscriptionPayload({
    $core.String? school,
    $core.String? plan,
    $core.int? year,
    $core.int? term,
    $core.int? student,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (plan != null) result.plan = plan;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (student != null) result.student = student;
    return result;
  }

  DeleteSubscriptionPayload._();

  factory DeleteSubscriptionPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteSubscriptionPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSubscriptionPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'plan')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'student')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSubscriptionPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSubscriptionPayload copyWith(
          void Function(DeleteSubscriptionPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteSubscriptionPayload))
          as DeleteSubscriptionPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteSubscriptionPayload create() => DeleteSubscriptionPayload._();
  @$core.override
  DeleteSubscriptionPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteSubscriptionPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSubscriptionPayload>(create);
  static DeleteSubscriptionPayload? _defaultInstance;

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
}

class CreateDiscountPayload extends $pb.GeneratedMessage {
  factory CreateDiscountPayload({
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

  CreateDiscountPayload._();

  factory CreateDiscountPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateDiscountPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDiscountPayload',
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
  CreateDiscountPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDiscountPayload copyWith(
          void Function(CreateDiscountPayload) updates) =>
      super.copyWith((message) => updates(message as CreateDiscountPayload))
          as CreateDiscountPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateDiscountPayload create() => CreateDiscountPayload._();
  @$core.override
  CreateDiscountPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateDiscountPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDiscountPayload>(create);
  static CreateDiscountPayload? _defaultInstance;

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

class UpdateDiscountPayload extends $pb.GeneratedMessage {
  factory UpdateDiscountPayload({
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

  UpdateDiscountPayload._();

  factory UpdateDiscountPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateDiscountPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateDiscountPayload',
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
  UpdateDiscountPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDiscountPayload copyWith(
          void Function(UpdateDiscountPayload) updates) =>
      super.copyWith((message) => updates(message as UpdateDiscountPayload))
          as UpdateDiscountPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateDiscountPayload create() => UpdateDiscountPayload._();
  @$core.override
  UpdateDiscountPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateDiscountPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateDiscountPayload>(create);
  static UpdateDiscountPayload? _defaultInstance;

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

class DeleteDiscountPayload extends $pb.GeneratedMessage {
  factory DeleteDiscountPayload({
    $core.String? school,
    $core.String? plan,
    $core.int? year,
    $core.int? term,
    $core.int? grade,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (plan != null) result.plan = plan;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
    if (grade != null) result.grade = grade;
    return result;
  }

  DeleteDiscountPayload._();

  factory DeleteDiscountPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteDiscountPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteDiscountPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'plan')
    ..aI(3, _omitFieldNames ? '' : 'year')
    ..aI(4, _omitFieldNames ? '' : 'term')
    ..aI(5, _omitFieldNames ? '' : 'grade')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDiscountPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDiscountPayload copyWith(
          void Function(DeleteDiscountPayload) updates) =>
      super.copyWith((message) => updates(message as DeleteDiscountPayload))
          as DeleteDiscountPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteDiscountPayload create() => DeleteDiscountPayload._();
  @$core.override
  DeleteDiscountPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteDiscountPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteDiscountPayload>(create);
  static DeleteDiscountPayload? _defaultInstance;

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
  subjectTeacher,
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
  role,
  scope,
  plan,
  subscription,
  discount,
  subjectCatalog,
  topic,
  stream,
  mpesa,
  examGrade,
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
    SubjectTeacherInsert? subjectTeacher,
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
    RoleInsert? role,
    ScopeInsert? scope,
    PlanInsert? plan,
    SubscriptionInsert? subscription,
    DiscountInsert? discount,
    SubjectInsert? subjectCatalog,
    TopicInsert? topic,
    StreamInsert? stream,
    MpesaInsert? mpesa,
    ExamGradeInsert? examGrade,
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
    if (subjectTeacher != null) result.subjectTeacher = subjectTeacher;
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
    if (role != null) result.role = role;
    if (scope != null) result.scope = scope;
    if (plan != null) result.plan = plan;
    if (subscription != null) result.subscription = subscription;
    if (discount != null) result.discount = discount;
    if (subjectCatalog != null) result.subjectCatalog = subjectCatalog;
    if (topic != null) result.topic = topic;
    if (stream != null) result.stream = stream;
    if (mpesa != null) result.mpesa = mpesa;
    if (examGrade != null) result.examGrade = examGrade;
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
    12: InsertData_Row.subjectTeacher,
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
    26: InsertData_Row.role,
    27: InsertData_Row.scope,
    28: InsertData_Row.plan,
    29: InsertData_Row.subscription,
    30: InsertData_Row.discount,
    31: InsertData_Row.subjectCatalog,
    32: InsertData_Row.topic,
    33: InsertData_Row.stream,
    34: InsertData_Row.mpesa,
    35: InsertData_Row.examGrade,
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
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35
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
    ..aOM<SubjectTeacherInsert>(12, _omitFieldNames ? '' : 'subjectTeacher',
        subBuilder: SubjectTeacherInsert.create)
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
    ..aOM<SubjectInsert>(31, _omitFieldNames ? '' : 'subjectCatalog',
        subBuilder: SubjectInsert.create)
    ..aOM<TopicInsert>(32, _omitFieldNames ? '' : 'topic',
        subBuilder: TopicInsert.create)
    ..aOM<StreamInsert>(33, _omitFieldNames ? '' : 'stream',
        subBuilder: StreamInsert.create)
    ..aOM<MpesaInsert>(34, _omitFieldNames ? '' : 'mpesa',
        subBuilder: MpesaInsert.create)
    ..aOM<ExamGradeInsert>(35, _omitFieldNames ? '' : 'examGrade',
        subBuilder: ExamGradeInsert.create)
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
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
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
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
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
  SubjectTeacherInsert get subjectTeacher => $_getN(11);
  @$pb.TagNumber(12)
  set subjectTeacher(SubjectTeacherInsert value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSubjectTeacher() => $_has(11);
  @$pb.TagNumber(12)
  void clearSubjectTeacher() => $_clearField(12);
  @$pb.TagNumber(12)
  SubjectTeacherInsert ensureSubjectTeacher() => $_ensure(11);

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

  @$pb.TagNumber(26)
  RoleInsert get role => $_getN(24);
  @$pb.TagNumber(26)
  set role(RoleInsert value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasRole() => $_has(24);
  @$pb.TagNumber(26)
  void clearRole() => $_clearField(26);
  @$pb.TagNumber(26)
  RoleInsert ensureRole() => $_ensure(24);

  @$pb.TagNumber(27)
  ScopeInsert get scope => $_getN(25);
  @$pb.TagNumber(27)
  set scope(ScopeInsert value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasScope() => $_has(25);
  @$pb.TagNumber(27)
  void clearScope() => $_clearField(27);
  @$pb.TagNumber(27)
  ScopeInsert ensureScope() => $_ensure(25);

  @$pb.TagNumber(28)
  PlanInsert get plan => $_getN(26);
  @$pb.TagNumber(28)
  set plan(PlanInsert value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasPlan() => $_has(26);
  @$pb.TagNumber(28)
  void clearPlan() => $_clearField(28);
  @$pb.TagNumber(28)
  PlanInsert ensurePlan() => $_ensure(26);

  @$pb.TagNumber(29)
  SubscriptionInsert get subscription => $_getN(27);
  @$pb.TagNumber(29)
  set subscription(SubscriptionInsert value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasSubscription() => $_has(27);
  @$pb.TagNumber(29)
  void clearSubscription() => $_clearField(29);
  @$pb.TagNumber(29)
  SubscriptionInsert ensureSubscription() => $_ensure(27);

  @$pb.TagNumber(30)
  DiscountInsert get discount => $_getN(28);
  @$pb.TagNumber(30)
  set discount(DiscountInsert value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasDiscount() => $_has(28);
  @$pb.TagNumber(30)
  void clearDiscount() => $_clearField(30);
  @$pb.TagNumber(30)
  DiscountInsert ensureDiscount() => $_ensure(28);

  @$pb.TagNumber(31)
  SubjectInsert get subjectCatalog => $_getN(29);
  @$pb.TagNumber(31)
  set subjectCatalog(SubjectInsert value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasSubjectCatalog() => $_has(29);
  @$pb.TagNumber(31)
  void clearSubjectCatalog() => $_clearField(31);
  @$pb.TagNumber(31)
  SubjectInsert ensureSubjectCatalog() => $_ensure(29);

  @$pb.TagNumber(32)
  TopicInsert get topic => $_getN(30);
  @$pb.TagNumber(32)
  set topic(TopicInsert value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasTopic() => $_has(30);
  @$pb.TagNumber(32)
  void clearTopic() => $_clearField(32);
  @$pb.TagNumber(32)
  TopicInsert ensureTopic() => $_ensure(30);

  @$pb.TagNumber(33)
  StreamInsert get stream => $_getN(31);
  @$pb.TagNumber(33)
  set stream(StreamInsert value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasStream() => $_has(31);
  @$pb.TagNumber(33)
  void clearStream() => $_clearField(33);
  @$pb.TagNumber(33)
  StreamInsert ensureStream() => $_ensure(31);

  @$pb.TagNumber(34)
  MpesaInsert get mpesa => $_getN(32);
  @$pb.TagNumber(34)
  set mpesa(MpesaInsert value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasMpesa() => $_has(32);
  @$pb.TagNumber(34)
  void clearMpesa() => $_clearField(34);
  @$pb.TagNumber(34)
  MpesaInsert ensureMpesa() => $_ensure(32);

  @$pb.TagNumber(35)
  ExamGradeInsert get examGrade => $_getN(33);
  @$pb.TagNumber(35)
  set examGrade(ExamGradeInsert value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasExamGrade() => $_has(33);
  @$pb.TagNumber(35)
  void clearExamGrade() => $_clearField(35);
  @$pb.TagNumber(35)
  ExamGradeInsert ensureExamGrade() => $_ensure(33);
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

class SubjectTeacherInsert extends $pb.GeneratedMessage {
  factory SubjectTeacherInsert({
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

  SubjectTeacherInsert._();

  factory SubjectTeacherInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubjectTeacherInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubjectTeacherInsert',
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
  SubjectTeacherInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubjectTeacherInsert copyWith(void Function(SubjectTeacherInsert) updates) =>
      super.copyWith((message) => updates(message as SubjectTeacherInsert))
          as SubjectTeacherInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubjectTeacherInsert create() => SubjectTeacherInsert._();
  @$core.override
  SubjectTeacherInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubjectTeacherInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubjectTeacherInsert>(create);
  static SubjectTeacherInsert? _defaultInstance;

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
    $core.String? name,
    $core.int? year,
    $core.int? term,
    $core.bool? personalized,
    $core.int? type,
    $core.int? start,
    $core.int? end,
    $core.String? teacher,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    if (year != null) result.year = year;
    if (term != null) result.term = term;
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
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'year')
    ..aI(5, _omitFieldNames ? '' : 'term')
    ..aOB(6, _omitFieldNames ? '' : 'personalized')
    ..aI(7, _omitFieldNames ? '' : 'type')
    ..aI(8, _omitFieldNames ? '' : 'start')
    ..aI(9, _omitFieldNames ? '' : 'end')
    ..aOS(10, _omitFieldNames ? '' : 'teacher')
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
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get year => $_getIZ(3);
  @$pb.TagNumber(4)
  set year($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasYear() => $_has(3);
  @$pb.TagNumber(4)
  void clearYear() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get term => $_getIZ(4);
  @$pb.TagNumber(5)
  set term($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTerm() => $_has(4);
  @$pb.TagNumber(5)
  void clearTerm() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get personalized => $_getBF(5);
  @$pb.TagNumber(6)
  set personalized($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPersonalized() => $_has(5);
  @$pb.TagNumber(6)
  void clearPersonalized() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get type => $_getIZ(6);
  @$pb.TagNumber(7)
  set type($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasType() => $_has(6);
  @$pb.TagNumber(7)
  void clearType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get start => $_getIZ(7);
  @$pb.TagNumber(8)
  set start($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStart() => $_has(7);
  @$pb.TagNumber(8)
  void clearStart() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get end => $_getIZ(8);
  @$pb.TagNumber(9)
  set end($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEnd() => $_has(8);
  @$pb.TagNumber(9)
  void clearEnd() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get teacher => $_getSZ(9);
  @$pb.TagNumber(10)
  set teacher($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTeacher() => $_has(9);
  @$pb.TagNumber(10)
  void clearTeacher() => $_clearField(10);
}

class PaperInsert extends $pb.GeneratedMessage {
  factory PaperInsert({
    $core.String? school,
    $core.String? exam,
    $core.int? subject,
    $core.int? paper,
    $core.int? topic,
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
    if (topic != null) result.topic = topic;
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
    ..aI(5, _omitFieldNames ? '' : 'topic')
    ..aOS(6, _omitFieldNames ? '' : 'invigilator')
    ..aInt64(7, _omitFieldNames ? '' : 'start')
    ..aInt64(8, _omitFieldNames ? '' : 'end')
    ..aI(9, _omitFieldNames ? '' : 'status')
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
  $core.int get topic => $_getIZ(4);
  @$pb.TagNumber(5)
  set topic($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTopic() => $_has(4);
  @$pb.TagNumber(5)
  void clearTopic() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get invigilator => $_getSZ(5);
  @$pb.TagNumber(6)
  set invigilator($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInvigilator() => $_has(5);
  @$pb.TagNumber(6)
  void clearInvigilator() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get start => $_getI64(6);
  @$pb.TagNumber(7)
  set start($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStart() => $_has(6);
  @$pb.TagNumber(7)
  void clearStart() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get end => $_getI64(7);
  @$pb.TagNumber(8)
  set end($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEnd() => $_has(7);
  @$pb.TagNumber(8)
  void clearEnd() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);
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
    $core.int? subject,
    $core.int? topic,
    $core.double? score,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (student != null) result.student = student;
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
    ..aI(3, _omitFieldNames ? '' : 'subject')
    ..aI(4, _omitFieldNames ? '' : 'topic')
    ..aD(5, _omitFieldNames ? '' : 'score', fieldType: $pb.PbFieldType.OF)
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
  $core.int get subject => $_getIZ(2);
  @$pb.TagNumber(3)
  set subject($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get topic => $_getIZ(3);
  @$pb.TagNumber(4)
  set topic($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTopic() => $_has(3);
  @$pb.TagNumber(4)
  void clearTopic() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get score => $_getN(4);
  @$pb.TagNumber(5)
  set score($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScore() => $_has(4);
  @$pb.TagNumber(5)
  void clearScore() => $_clearField(5);
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

class SubjectInsert extends $pb.GeneratedMessage {
  factory SubjectInsert({
    $core.int? id,
    $core.String? name,
    $core.int? curriculum,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (curriculum != null) result.curriculum = curriculum;
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
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'curriculum')
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
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
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
  $core.int get curriculum => $_getIZ(2);
  @$pb.TagNumber(3)
  set curriculum($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurriculum() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurriculum() => $_clearField(3);
}

class TopicInsert extends $pb.GeneratedMessage {
  factory TopicInsert({
    $core.int? id,
    $core.int? subject,
    $core.int? grade,
    $core.String? name,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (subject != null) result.subject = subject;
    if (grade != null) result.grade = grade;
    if (name != null) result.name = name;
    return result;
  }

  TopicInsert._();

  factory TopicInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TopicInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TopicInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'subject')
    ..aI(3, _omitFieldNames ? '' : 'grade')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicInsert copyWith(void Function(TopicInsert) updates) =>
      super.copyWith((message) => updates(message as TopicInsert))
          as TopicInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TopicInsert create() => TopicInsert._();
  @$core.override
  TopicInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TopicInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TopicInsert>(create);
  static TopicInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

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
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);
}

class StreamInsert extends $pb.GeneratedMessage {
  factory StreamInsert({
    $core.String? school,
    $core.int? grade,
    $core.int? stream,
    $core.String? name,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    if (name != null) result.name = name;
    return result;
  }

  StreamInsert._();

  factory StreamInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamInsert copyWith(void Function(StreamInsert) updates) =>
      super.copyWith((message) => updates(message as StreamInsert))
          as StreamInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamInsert create() => StreamInsert._();
  @$core.override
  StreamInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamInsert>(create);
  static StreamInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);
}

class MpesaInsert extends $pb.GeneratedMessage {
  factory MpesaInsert({
    $core.String? school,
    $core.String? consumerKey,
    $core.String? consumerSecret,
    $core.String? passkey,
    $core.String? shortcode,
    $core.int? env,
  }) {
    final result = create();
    if (school != null) result.school = school;
    if (consumerKey != null) result.consumerKey = consumerKey;
    if (consumerSecret != null) result.consumerSecret = consumerSecret;
    if (passkey != null) result.passkey = passkey;
    if (shortcode != null) result.shortcode = shortcode;
    if (env != null) result.env = env;
    return result;
  }

  MpesaInsert._();

  factory MpesaInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MpesaInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MpesaInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'school')
    ..aOS(2, _omitFieldNames ? '' : 'consumerKey')
    ..aOS(3, _omitFieldNames ? '' : 'consumerSecret')
    ..aOS(4, _omitFieldNames ? '' : 'passkey')
    ..aOS(5, _omitFieldNames ? '' : 'shortcode')
    ..aI(6, _omitFieldNames ? '' : 'env')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MpesaInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MpesaInsert copyWith(void Function(MpesaInsert) updates) =>
      super.copyWith((message) => updates(message as MpesaInsert))
          as MpesaInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MpesaInsert create() => MpesaInsert._();
  @$core.override
  MpesaInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MpesaInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MpesaInsert>(create);
  static MpesaInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get school => $_getSZ(0);
  @$pb.TagNumber(1)
  set school($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchool() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchool() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get consumerKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set consumerKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConsumerKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearConsumerKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get consumerSecret => $_getSZ(2);
  @$pb.TagNumber(3)
  set consumerSecret($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConsumerSecret() => $_has(2);
  @$pb.TagNumber(3)
  void clearConsumerSecret() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get passkey => $_getSZ(3);
  @$pb.TagNumber(4)
  set passkey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPasskey() => $_has(3);
  @$pb.TagNumber(4)
  void clearPasskey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get shortcode => $_getSZ(4);
  @$pb.TagNumber(5)
  set shortcode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShortcode() => $_has(4);
  @$pb.TagNumber(5)
  void clearShortcode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get env => $_getIZ(5);
  @$pb.TagNumber(6)
  set env($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnv() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnv() => $_clearField(6);
}

class ExamGradeInsert extends $pb.GeneratedMessage {
  factory ExamGradeInsert({
    $core.String? exam,
    $core.int? grade,
    $core.int? stream,
  }) {
    final result = create();
    if (exam != null) result.exam = exam;
    if (grade != null) result.grade = grade;
    if (stream != null) result.stream = stream;
    return result;
  }

  ExamGradeInsert._();

  factory ExamGradeInsert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExamGradeInsert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExamGradeInsert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'sync'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'exam')
    ..aI(2, _omitFieldNames ? '' : 'grade')
    ..aI(3, _omitFieldNames ? '' : 'stream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamGradeInsert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExamGradeInsert copyWith(void Function(ExamGradeInsert) updates) =>
      super.copyWith((message) => updates(message as ExamGradeInsert))
          as ExamGradeInsert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExamGradeInsert create() => ExamGradeInsert._();
  @$core.override
  ExamGradeInsert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExamGradeInsert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExamGradeInsert>(create);
  static ExamGradeInsert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get exam => $_getSZ(0);
  @$pb.TagNumber(1)
  set exam($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExam() => $_has(0);
  @$pb.TagNumber(1)
  void clearExam() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get grade => $_getIZ(1);
  @$pb.TagNumber(2)
  set grade($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearGrade() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stream => $_getIZ(2);
  @$pb.TagNumber(3)
  set stream($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStream() => $_clearField(3);
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
