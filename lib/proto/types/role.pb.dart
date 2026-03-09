// This is a generated file - do not edit.
//
// Generated from types/role.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'role.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'role.pbenum.dart';

class Permission extends $pb.GeneratedMessage {
  factory Permission({
    Resource? resource,
    $core.Iterable<Action>? actions,
  }) {
    final result = create();
    if (resource != null) result.resource = resource;
    if (actions != null) result.actions.addAll(actions);
    return result;
  }

  Permission._();

  factory Permission.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Permission.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Permission',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'role'),
      createEmptyInstance: create)
    ..aE<Resource>(1, _omitFieldNames ? '' : 'resource',
        enumValues: Resource.values)
    ..pc<Action>(2, _omitFieldNames ? '' : 'actions', $pb.PbFieldType.KE,
        valueOf: Action.valueOf,
        enumValues: Action.values,
        defaultEnumValue: Action.CREATE)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Permission clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Permission copyWith(void Function(Permission) updates) =>
      super.copyWith((message) => updates(message as Permission)) as Permission;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Permission create() => Permission._();
  @$core.override
  Permission createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Permission getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Permission>(create);
  static Permission? _defaultInstance;

  @$pb.TagNumber(1)
  Resource get resource => $_getN(0);
  @$pb.TagNumber(1)
  set resource(Resource value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasResource() => $_has(0);
  @$pb.TagNumber(1)
  void clearResource() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Action> get actions => $_getList(1);
}

class Role extends $pb.GeneratedMessage {
  factory Role({
    $core.String? id,
    $core.String? name,
    $core.Iterable<Permission>? permissions,
    $fixnum.Int64? created,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (permissions != null) result.permissions.addAll(permissions);
    if (created != null) result.created = created;
    return result;
  }

  Role._();

  factory Role.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Role.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Role',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'role'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPM<Permission>(3, _omitFieldNames ? '' : 'permissions',
        subBuilder: Permission.create)
    ..aInt64(4, _omitFieldNames ? '' : 'created')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Role clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Role copyWith(void Function(Role) updates) =>
      super.copyWith((message) => updates(message as Role)) as Role;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Role create() => Role._();
  @$core.override
  Role createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Role getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Role>(create);
  static Role? _defaultInstance;

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
  $pb.PbList<Permission> get permissions => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get created => $_getI64(3);
  @$pb.TagNumber(4)
  set created($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreated() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreated() => $_clearField(4);
}

class Assignment extends $pb.GeneratedMessage {
  factory Assignment({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? assigned,
    $core.String? profile,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (assigned != null) result.assigned = assigned;
    if (profile != null) result.profile = profile;
    return result;
  }

  Assignment._();

  factory Assignment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Assignment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Assignment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'role'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'assigned')
    ..aOS(4, _omitFieldNames ? '' : 'profile')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Assignment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Assignment copyWith(void Function(Assignment) updates) =>
      super.copyWith((message) => updates(message as Assignment)) as Assignment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Assignment create() => Assignment._();
  @$core.override
  Assignment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Assignment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Assignment>(create);
  static Assignment? _defaultInstance;

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
  $fixnum.Int64 get assigned => $_getI64(2);
  @$pb.TagNumber(3)
  set assigned($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAssigned() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssigned() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get profile => $_getSZ(3);
  @$pb.TagNumber(4)
  set profile($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProfile() => $_has(3);
  @$pb.TagNumber(4)
  void clearProfile() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
