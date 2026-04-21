// This is a generated file - do not edit.
//
// Generated from types/verification.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Purpose extends $pb.ProtobufEnum {
  static const Purpose Verify = Purpose._(0, _omitEnumNames ? '' : 'Verify');
  static const Purpose ChangePhone =
      Purpose._(1, _omitEnumNames ? '' : 'ChangePhone');
  static const Purpose Delete = Purpose._(2, _omitEnumNames ? '' : 'Delete');

  static const $core.List<Purpose> values = <Purpose>[
    Verify,
    ChangePhone,
    Delete,
  ];

  static final $core.List<Purpose?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Purpose? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Purpose._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
