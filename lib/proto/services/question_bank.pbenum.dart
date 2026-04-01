// This is a generated file - do not edit.
//
// Generated from services/question_bank.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ImageContext extends $pb.ProtobufEnum {
  static const ImageContext QUESTION =
      ImageContext._(0, _omitEnumNames ? '' : 'QUESTION');
  static const ImageContext RUBRIC =
      ImageContext._(1, _omitEnumNames ? '' : 'RUBRIC');
  static const ImageContext EXAMPLE_ANSWER =
      ImageContext._(2, _omitEnumNames ? '' : 'EXAMPLE_ANSWER');

  static const $core.List<ImageContext> values = <ImageContext>[
    QUESTION,
    RUBRIC,
    EXAMPLE_ANSWER,
  ];

  static final $core.List<ImageContext?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ImageContext? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ImageContext._(super.value, super.name);
}

class MarkingStatusEnum extends $pb.ProtobufEnum {
  static const MarkingStatusEnum QUEUED =
      MarkingStatusEnum._(0, _omitEnumNames ? '' : 'QUEUED');
  static const MarkingStatusEnum DOWNLOADING =
      MarkingStatusEnum._(1, _omitEnumNames ? '' : 'DOWNLOADING');
  static const MarkingStatusEnum MARKING =
      MarkingStatusEnum._(2, _omitEnumNames ? '' : 'MARKING');
  static const MarkingStatusEnum COMPUTING =
      MarkingStatusEnum._(3, _omitEnumNames ? '' : 'COMPUTING');
  static const MarkingStatusEnum COMPLETE =
      MarkingStatusEnum._(4, _omitEnumNames ? '' : 'COMPLETE');
  static const MarkingStatusEnum FAILED =
      MarkingStatusEnum._(5, _omitEnumNames ? '' : 'FAILED');

  static const $core.List<MarkingStatusEnum> values = <MarkingStatusEnum>[
    QUEUED,
    DOWNLOADING,
    MARKING,
    COMPUTING,
    COMPLETE,
    FAILED,
  ];

  static final $core.List<MarkingStatusEnum?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static MarkingStatusEnum? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MarkingStatusEnum._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
