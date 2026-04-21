// This is a generated file - do not edit.
//
// Generated from types/member.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Role extends $pb.ProtobufEnum {
  static const Role OWNER = Role._(0, _omitEnumNames ? '' : 'OWNER');
  static const Role GUARDIAN = Role._(1, _omitEnumNames ? '' : 'GUARDIAN');
  static const Role STUDENT = Role._(2, _omitEnumNames ? '' : 'STUDENT');
  static const Role TEACHER = Role._(3, _omitEnumNames ? '' : 'TEACHER');
  static const Role STAFF = Role._(4, _omitEnumNames ? '' : 'STAFF');

  static const $core.List<Role> values = <Role>[
    OWNER,
    GUARDIAN,
    STUDENT,
    TEACHER,
    STAFF,
  ];

  static final $core.List<Role?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Role? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Role._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
