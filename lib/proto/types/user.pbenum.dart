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

import 'package:protobuf/protobuf.dart' as $pb;

class Level extends $pb.ProtobufEnum {
  /// / These are normal users of the software.
  static const Level Normal = Level._(0, _omitEnumNames ? '' : 'Normal');

  /// / These are staff/managers/workers/owners of the system.
  static const Level System = Level._(1, _omitEnumNames ? '' : 'System');

  /// / These are the Owners/Workers with full privilages.
  static const Level Super = Level._(2, _omitEnumNames ? '' : 'Super');

  static const $core.List<Level> values = <Level>[
    Normal,
    System,
    Super,
  ];

  static final $core.List<Level?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Level? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Level._(super.value, super.name);
}

class Status extends $pb.ProtobufEnum {
  /// / This indicates that this is an invite user and not yet signed up to the platform.
  static const Status Invited = Status._(0, _omitEnumNames ? '' : 'Invited');

  /// / This indicates that the user is active.
  static const Status Active = Status._(1, _omitEnumNames ? '' : 'Active');

  /// / This indicates that the user is suspended.
  static const Status Suspended =
      Status._(2, _omitEnumNames ? '' : 'Suspended');

  /// / This indicates that the user is deleted.
  static const Status Deleted = Status._(3, _omitEnumNames ? '' : 'Deleted');

  static const $core.List<Status> values = <Status>[
    Invited,
    Active,
    Suspended,
    Deleted,
  ];

  static final $core.List<Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
