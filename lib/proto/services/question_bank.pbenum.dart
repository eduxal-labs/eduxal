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

import 'package:protobuf/protobuf.dart' as $pb;

class MarkingPhase extends $pb.ProtobufEnum {
  static const MarkingPhase QUEUED =
      MarkingPhase._(0, _omitEnumNames ? '' : 'QUEUED');
  static const MarkingPhase DOWNLOADING =
      MarkingPhase._(1, _omitEnumNames ? '' : 'DOWNLOADING');
  static const MarkingPhase CACHING =
      MarkingPhase._(2, _omitEnumNames ? '' : 'CACHING');
  static const MarkingPhase MARKING =
      MarkingPhase._(3, _omitEnumNames ? '' : 'MARKING');
  static const MarkingPhase AGGREGATING =
      MarkingPhase._(4, _omitEnumNames ? '' : 'AGGREGATING');
  static const MarkingPhase COMPLETE =
      MarkingPhase._(5, _omitEnumNames ? '' : 'COMPLETE');
  static const MarkingPhase FAILED =
      MarkingPhase._(6, _omitEnumNames ? '' : 'FAILED');

  static const $core.List<MarkingPhase> values = <MarkingPhase>[
    QUEUED,
    DOWNLOADING,
    CACHING,
    MARKING,
    AGGREGATING,
    COMPLETE,
    FAILED,
  ];

  static final $core.List<MarkingPhase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static MarkingPhase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MarkingPhase._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
