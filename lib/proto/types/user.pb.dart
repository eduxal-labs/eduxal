// This is a generated file - do not edit.
//
// Generated from types/user.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'user.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'user.pbenum.dart';

class User extends $pb.GeneratedMessage {
  factory User({
    $core.String? id,
    $core.String? phone,
    $core.String? name,
    $core.String? email,
    Level? level,
    Status? status,
    $core.String? profile,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (phone != null) result.phone = phone;
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    if (level != null) result.level = level;
    if (status != null) result.status = status;
    if (profile != null) result.profile = profile;
    if (created != null) result.created = created;
    if (updated != null) result.updated = updated;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'user'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'phone')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'email')
    ..aE<Level>(5, _omitFieldNames ? '' : 'level', enumValues: Level.values)
    ..aE<Status>(6, _omitFieldNames ? '' : 'status', enumValues: Status.values)
    ..aOS(7, _omitFieldNames ? '' : 'profile')
    ..aInt64(8, _omitFieldNames ? '' : 'created')
    ..aInt64(9, _omitFieldNames ? '' : 'updated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) =>
      super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static User create() => User._();
  @$core.override
  User createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static User getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(create);
  static User? _defaultInstance;

  /// / This is the user's id.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// / This is the user's phone number.
  @$pb.TagNumber(2)
  $core.String get phone => $_getSZ(1);
  @$pb.TagNumber(2)
  set phone($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPhone() => $_has(1);
  @$pb.TagNumber(2)
  void clearPhone() => $_clearField(2);

  /// / The name of the user.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// / The email address of the user.
  @$pb.TagNumber(4)
  $core.String get email => $_getSZ(3);
  @$pb.TagNumber(4)
  set email($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmail() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmail() => $_clearField(4);

  /// / What kind of a user this is: normal, system, super.
  @$pb.TagNumber(5)
  Level get level => $_getN(4);
  @$pb.TagNumber(5)
  set level(Level value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLevel() => $_has(4);
  @$pb.TagNumber(5)
  void clearLevel() => $_clearField(5);

  /// / The current status of the user.
  @$pb.TagNumber(6)
  Status get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(Status value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  /// / A presigned GET only url to view the user's profile page if there is one.
  @$pb.TagNumber(7)
  $core.String get profile => $_getSZ(6);
  @$pb.TagNumber(7)
  set profile($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProfile() => $_has(6);
  @$pb.TagNumber(7)
  void clearProfile() => $_clearField(7);

  /// / The time on which this record was created.
  @$pb.TagNumber(8)
  $fixnum.Int64 get created => $_getI64(7);
  @$pb.TagNumber(8)
  set created($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreated() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreated() => $_clearField(8);

  /// / The time on which this record was last updated.
  @$pb.TagNumber(9)
  $fixnum.Int64 get updated => $_getI64(8);
  @$pb.TagNumber(9)
  set updated($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdated() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdated() => $_clearField(9);
}

class Update extends $pb.GeneratedMessage {
  factory Update({
    $core.String? id,
    $core.String? phone,
    $core.String? name,
    $core.String? email,
    Level? level,
    Status? status,
    $core.String? profile,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (phone != null) result.phone = phone;
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    if (level != null) result.level = level;
    if (status != null) result.status = status;
    if (profile != null) result.profile = profile;
    if (created != null) result.created = created;
    if (updated != null) result.updated = updated;
    return result;
  }

  Update._();

  factory Update.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Update.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Update',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'user'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'phone')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'email')
    ..aE<Level>(5, _omitFieldNames ? '' : 'level', enumValues: Level.values)
    ..aE<Status>(6, _omitFieldNames ? '' : 'status', enumValues: Status.values)
    ..aOS(7, _omitFieldNames ? '' : 'profile')
    ..aInt64(8, _omitFieldNames ? '' : 'created')
    ..aInt64(9, _omitFieldNames ? '' : 'updated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Update clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Update copyWith(void Function(Update) updates) =>
      super.copyWith((message) => updates(message as Update)) as Update;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Update create() => Update._();
  @$core.override
  Update createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Update getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Update>(create);
  static Update? _defaultInstance;

  /// / This is the user's id.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// / This is the user's phone number.
  @$pb.TagNumber(2)
  $core.String get phone => $_getSZ(1);
  @$pb.TagNumber(2)
  set phone($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPhone() => $_has(1);
  @$pb.TagNumber(2)
  void clearPhone() => $_clearField(2);

  /// / The name of the user.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// / The email address of the user.
  @$pb.TagNumber(4)
  $core.String get email => $_getSZ(3);
  @$pb.TagNumber(4)
  set email($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmail() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmail() => $_clearField(4);

  /// / What kind of a user this is: normal, system, super.
  @$pb.TagNumber(5)
  Level get level => $_getN(4);
  @$pb.TagNumber(5)
  set level(Level value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLevel() => $_has(4);
  @$pb.TagNumber(5)
  void clearLevel() => $_clearField(5);

  /// / The current status of the user.
  @$pb.TagNumber(6)
  Status get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(Status value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  /// / A presigned GET only url to view the user's profile page if there is one.
  @$pb.TagNumber(7)
  $core.String get profile => $_getSZ(6);
  @$pb.TagNumber(7)
  set profile($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProfile() => $_has(6);
  @$pb.TagNumber(7)
  void clearProfile() => $_clearField(7);

  /// / The time on which this record was created.
  @$pb.TagNumber(8)
  $fixnum.Int64 get created => $_getI64(7);
  @$pb.TagNumber(8)
  set created($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreated() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreated() => $_clearField(8);

  /// / The time on which this record was last updated.
  @$pb.TagNumber(9)
  $fixnum.Int64 get updated => $_getI64(8);
  @$pb.TagNumber(9)
  set updated($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdated() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdated() => $_clearField(9);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
