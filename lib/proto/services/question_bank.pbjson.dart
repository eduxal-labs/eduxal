// This is a generated file - do not edit.
//
// Generated from services/question_bank.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use questionDescriptor instead')
const Question$json = {
  '1': 'Question',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'topic_id', '3': 2, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'body', '3': 3, '4': 1, '5': 9, '10': 'body'},
    {'1': 'body_format', '3': 4, '4': 1, '5': 5, '10': 'bodyFormat'},
    {
      '1': 'stimulus',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'stimulus',
      '17': true
    },
    {'1': 'type', '3': 6, '4': 1, '5': 5, '10': 'type'},
    {'1': 'difficulty', '3': 7, '4': 1, '5': 5, '10': 'difficulty'},
    {'1': 'cognitive_level', '3': 8, '4': 1, '5': 5, '10': 'cognitiveLevel'},
    {'1': 'marks', '3': 9, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'max_marks',
      '3': 10,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'maxMarks',
      '17': true
    },
    {
      '1': 'answer_space_type',
      '3': 11,
      '4': 1,
      '5': 5,
      '10': 'answerSpaceType'
    },
    {
      '1': 'answer_lines',
      '3': 12,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'answerLines',
      '17': true
    },
    {
      '1': 'answer_box_height_mm',
      '3': 13,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'answerBoxHeightMm',
      '17': true
    },
    {
      '1': 'example_answer',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterion',
      '10': 'rubric'
    },
    {
      '1': 'parts',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.question_bank.QuestionPart',
      '10': 'parts'
    },
    {'1': 'created', '3': 17, '4': 1, '5': 3, '10': 'created'},
    {'1': 'updated', '3': 18, '4': 1, '5': 3, '10': 'updated'},
  ],
  '8': [
    {'1': '_stimulus'},
    {'1': '_max_marks'},
    {'1': '_answer_lines'},
    {'1': '_answer_box_height_mm'},
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `Question`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionDescriptor = $convert.base64Decode(
    'CghRdWVzdGlvbhIOCgJpZBgBIAEoBVICaWQSGQoIdG9waWNfaWQYAiABKAVSB3RvcGljSWQSEg'
    'oEYm9keRgDIAEoCVIEYm9keRIfCgtib2R5X2Zvcm1hdBgEIAEoBVIKYm9keUZvcm1hdBIfCghz'
    'dGltdWx1cxgFIAEoCUgAUghzdGltdWx1c4gBARISCgR0eXBlGAYgASgFUgR0eXBlEh4KCmRpZm'
    'ZpY3VsdHkYByABKAVSCmRpZmZpY3VsdHkSJwoPY29nbml0aXZlX2xldmVsGAggASgFUg5jb2du'
    'aXRpdmVMZXZlbBIUCgVtYXJrcxgJIAEoBVIFbWFya3MSIAoJbWF4X21hcmtzGAogASgFSAFSCG'
    '1heE1hcmtziAEBEioKEWFuc3dlcl9zcGFjZV90eXBlGAsgASgFUg9hbnN3ZXJTcGFjZVR5cGUS'
    'JgoMYW5zd2VyX2xpbmVzGAwgASgFSAJSC2Fuc3dlckxpbmVziAEBEjQKFGFuc3dlcl9ib3hfaG'
    'VpZ2h0X21tGA0gASgFSANSEWFuc3dlckJveEhlaWdodE1tiAEBEioKDmV4YW1wbGVfYW5zd2Vy'
    'GA4gASgJSARSDWV4YW1wbGVBbnN3ZXKIAQESNgoGcnVicmljGA8gAygLMh4ucXVlc3Rpb25fYm'
    'Fuay5SdWJyaWNDcml0ZXJpb25SBnJ1YnJpYxIxCgVwYXJ0cxgQIAMoCzIbLnF1ZXN0aW9uX2Jh'
    'bmsuUXVlc3Rpb25QYXJ0UgVwYXJ0cxIYCgdjcmVhdGVkGBEgASgDUgdjcmVhdGVkEhgKB3VwZG'
    'F0ZWQYEiABKANSB3VwZGF0ZWRCCwoJX3N0aW11bHVzQgwKCl9tYXhfbWFya3NCDwoNX2Fuc3dl'
    'cl9saW5lc0IXChVfYW5zd2VyX2JveF9oZWlnaHRfbW1CEQoPX2V4YW1wbGVfYW5zd2Vy');

@$core.Deprecated('Use rubricCriterionDescriptor instead')
const RubricCriterion$json = {
  '1': 'RubricCriterion',
  '2': [
    {'1': 'position', '3': 1, '4': 1, '5': 5, '10': 'position'},
    {'1': 'criterion', '3': 2, '4': 1, '5': 9, '10': 'criterion'},
    {'1': 'marks', '3': 3, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'max_marks',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'maxMarks',
      '17': true
    },
    {'1': 'required', '3': 5, '4': 1, '5': 8, '10': 'required'},
  ],
  '8': [
    {'1': '_max_marks'},
  ],
};

/// Descriptor for `RubricCriterion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rubricCriterionDescriptor = $convert.base64Decode(
    'Cg9SdWJyaWNDcml0ZXJpb24SGgoIcG9zaXRpb24YASABKAVSCHBvc2l0aW9uEhwKCWNyaXRlcm'
    'lvbhgCIAEoCVIJY3JpdGVyaW9uEhQKBW1hcmtzGAMgASgFUgVtYXJrcxIgCgltYXhfbWFya3MY'
    'BCABKAVIAFIIbWF4TWFya3OIAQESGgoIcmVxdWlyZWQYBSABKAhSCHJlcXVpcmVkQgwKCl9tYX'
    'hfbWFya3M=');

@$core.Deprecated('Use questionPartDescriptor instead')
const QuestionPart$json = {
  '1': 'QuestionPart',
  '2': [
    {'1': 'position', '3': 1, '4': 1, '5': 5, '10': 'position'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'body', '3': 3, '4': 1, '5': 9, '10': 'body'},
    {'1': 'body_format', '3': 4, '4': 1, '5': 5, '10': 'bodyFormat'},
    {'1': 'marks', '3': 5, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'max_marks',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'maxMarks',
      '17': true
    },
    {'1': 'answer_space_type', '3': 7, '4': 1, '5': 5, '10': 'answerSpaceType'},
    {
      '1': 'answer_lines',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'answerLines',
      '17': true
    },
    {
      '1': 'answer_box_height_mm',
      '3': 9,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'answerBoxHeightMm',
      '17': true
    },
    {
      '1': 'example_answer',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'stimulus',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'stimulus',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterion',
      '10': 'rubric'
    },
  ],
  '8': [
    {'1': '_max_marks'},
    {'1': '_answer_lines'},
    {'1': '_answer_box_height_mm'},
    {'1': '_example_answer'},
    {'1': '_stimulus'},
  ],
};

/// Descriptor for `QuestionPart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionPartDescriptor = $convert.base64Decode(
    'CgxRdWVzdGlvblBhcnQSGgoIcG9zaXRpb24YASABKAVSCHBvc2l0aW9uEhQKBWxhYmVsGAIgAS'
    'gJUgVsYWJlbBISCgRib2R5GAMgASgJUgRib2R5Eh8KC2JvZHlfZm9ybWF0GAQgASgFUgpib2R5'
    'Rm9ybWF0EhQKBW1hcmtzGAUgASgFUgVtYXJrcxIgCgltYXhfbWFya3MYBiABKAVIAFIIbWF4TW'
    'Fya3OIAQESKgoRYW5zd2VyX3NwYWNlX3R5cGUYByABKAVSD2Fuc3dlclNwYWNlVHlwZRImCgxh'
    'bnN3ZXJfbGluZXMYCCABKAVIAVILYW5zd2VyTGluZXOIAQESNAoUYW5zd2VyX2JveF9oZWlnaH'
    'RfbW0YCSABKAVIAlIRYW5zd2VyQm94SGVpZ2h0TW2IAQESKgoOZXhhbXBsZV9hbnN3ZXIYCiAB'
    'KAlIA1INZXhhbXBsZUFuc3dlcogBARIfCghzdGltdWx1cxgLIAEoCUgEUghzdGltdWx1c4gBAR'
    'I2CgZydWJyaWMYDCADKAsyHi5xdWVzdGlvbl9iYW5rLlJ1YnJpY0NyaXRlcmlvblIGcnVicmlj'
    'QgwKCl9tYXhfbWFya3NCDwoNX2Fuc3dlcl9saW5lc0IXChVfYW5zd2VyX2JveF9oZWlnaHRfbW'
    '1CEQoPX2V4YW1wbGVfYW5zd2VyQgsKCV9zdGltdWx1cw==');

@$core.Deprecated('Use rubricCriterionInputDescriptor instead')
const RubricCriterionInput$json = {
  '1': 'RubricCriterionInput',
  '2': [
    {'1': 'criterion', '3': 1, '4': 1, '5': 9, '10': 'criterion'},
    {'1': 'marks', '3': 2, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'max_marks',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'maxMarks',
      '17': true
    },
    {'1': 'required', '3': 4, '4': 1, '5': 8, '10': 'required'},
  ],
  '8': [
    {'1': '_max_marks'},
  ],
};

/// Descriptor for `RubricCriterionInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rubricCriterionInputDescriptor = $convert.base64Decode(
    'ChRSdWJyaWNDcml0ZXJpb25JbnB1dBIcCgljcml0ZXJpb24YASABKAlSCWNyaXRlcmlvbhIUCg'
    'VtYXJrcxgCIAEoBVIFbWFya3MSIAoJbWF4X21hcmtzGAMgASgFSABSCG1heE1hcmtziAEBEhoK'
    'CHJlcXVpcmVkGAQgASgIUghyZXF1aXJlZEIMCgpfbWF4X21hcmtz');

@$core.Deprecated('Use questionPartInputDescriptor instead')
const QuestionPartInput$json = {
  '1': 'QuestionPartInput',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'body', '3': 2, '4': 1, '5': 9, '10': 'body'},
    {'1': 'body_format', '3': 3, '4': 1, '5': 5, '10': 'bodyFormat'},
    {'1': 'marks', '3': 4, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'max_marks',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'maxMarks',
      '17': true
    },
    {'1': 'answer_space_type', '3': 6, '4': 1, '5': 5, '10': 'answerSpaceType'},
    {
      '1': 'answer_lines',
      '3': 7,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'answerLines',
      '17': true
    },
    {
      '1': 'answer_box_height_mm',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'answerBoxHeightMm',
      '17': true
    },
    {
      '1': 'example_answer',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'stimulus',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'stimulus',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterionInput',
      '10': 'rubric'
    },
  ],
  '8': [
    {'1': '_max_marks'},
    {'1': '_answer_lines'},
    {'1': '_answer_box_height_mm'},
    {'1': '_example_answer'},
    {'1': '_stimulus'},
  ],
};

/// Descriptor for `QuestionPartInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionPartInputDescriptor = $convert.base64Decode(
    'ChFRdWVzdGlvblBhcnRJbnB1dBIUCgVsYWJlbBgBIAEoCVIFbGFiZWwSEgoEYm9keRgCIAEoCV'
    'IEYm9keRIfCgtib2R5X2Zvcm1hdBgDIAEoBVIKYm9keUZvcm1hdBIUCgVtYXJrcxgEIAEoBVIF'
    'bWFya3MSIAoJbWF4X21hcmtzGAUgASgFSABSCG1heE1hcmtziAEBEioKEWFuc3dlcl9zcGFjZV'
    '90eXBlGAYgASgFUg9hbnN3ZXJTcGFjZVR5cGUSJgoMYW5zd2VyX2xpbmVzGAcgASgFSAFSC2Fu'
    'c3dlckxpbmVziAEBEjQKFGFuc3dlcl9ib3hfaGVpZ2h0X21tGAggASgFSAJSEWFuc3dlckJveE'
    'hlaWdodE1tiAEBEioKDmV4YW1wbGVfYW5zd2VyGAkgASgJSANSDWV4YW1wbGVBbnN3ZXKIAQES'
    'HwoIc3RpbXVsdXMYCiABKAlIBFIIc3RpbXVsdXOIAQESOwoGcnVicmljGAsgAygLMiMucXVlc3'
    'Rpb25fYmFuay5SdWJyaWNDcml0ZXJpb25JbnB1dFIGcnVicmljQgwKCl9tYXhfbWFya3NCDwoN'
    'X2Fuc3dlcl9saW5lc0IXChVfYW5zd2VyX2JveF9oZWlnaHRfbW1CEQoPX2V4YW1wbGVfYW5zd2'
    'VyQgsKCV9zdGltdWx1cw==');

@$core.Deprecated('Use createQuestionRequestDescriptor instead')
const CreateQuestionRequest$json = {
  '1': 'CreateQuestionRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'body', '3': 2, '4': 1, '5': 9, '10': 'body'},
    {'1': 'body_format', '3': 3, '4': 1, '5': 5, '10': 'bodyFormat'},
    {
      '1': 'stimulus',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'stimulus',
      '17': true
    },
    {'1': 'type', '3': 5, '4': 1, '5': 5, '10': 'type'},
    {'1': 'difficulty', '3': 6, '4': 1, '5': 5, '10': 'difficulty'},
    {'1': 'cognitive_level', '3': 7, '4': 1, '5': 5, '10': 'cognitiveLevel'},
    {'1': 'marks', '3': 8, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'max_marks',
      '3': 9,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'maxMarks',
      '17': true
    },
    {
      '1': 'answer_space_type',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'answerSpaceType'
    },
    {
      '1': 'answer_lines',
      '3': 11,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'answerLines',
      '17': true
    },
    {
      '1': 'answer_box_height_mm',
      '3': 12,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'answerBoxHeightMm',
      '17': true
    },
    {
      '1': 'example_answer',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterionInput',
      '10': 'rubric'
    },
    {
      '1': 'parts',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.question_bank.QuestionPartInput',
      '10': 'parts'
    },
  ],
  '8': [
    {'1': '_stimulus'},
    {'1': '_max_marks'},
    {'1': '_answer_lines'},
    {'1': '_answer_box_height_mm'},
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `CreateQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createQuestionRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVRdWVzdGlvblJlcXVlc3QSGQoIdG9waWNfaWQYASABKAVSB3RvcGljSWQSEgoEYm'
    '9keRgCIAEoCVIEYm9keRIfCgtib2R5X2Zvcm1hdBgDIAEoBVIKYm9keUZvcm1hdBIfCghzdGlt'
    'dWx1cxgEIAEoCUgAUghzdGltdWx1c4gBARISCgR0eXBlGAUgASgFUgR0eXBlEh4KCmRpZmZpY3'
    'VsdHkYBiABKAVSCmRpZmZpY3VsdHkSJwoPY29nbml0aXZlX2xldmVsGAcgASgFUg5jb2duaXRp'
    'dmVMZXZlbBIUCgVtYXJrcxgIIAEoBVIFbWFya3MSIAoJbWF4X21hcmtzGAkgASgFSAFSCG1heE'
    '1hcmtziAEBEioKEWFuc3dlcl9zcGFjZV90eXBlGAogASgFUg9hbnN3ZXJTcGFjZVR5cGUSJgoM'
    'YW5zd2VyX2xpbmVzGAsgASgFSAJSC2Fuc3dlckxpbmVziAEBEjQKFGFuc3dlcl9ib3hfaGVpZ2'
    'h0X21tGAwgASgFSANSEWFuc3dlckJveEhlaWdodE1tiAEBEioKDmV4YW1wbGVfYW5zd2VyGA0g'
    'ASgJSARSDWV4YW1wbGVBbnN3ZXKIAQESOwoGcnVicmljGA4gAygLMiMucXVlc3Rpb25fYmFuay'
    '5SdWJyaWNDcml0ZXJpb25JbnB1dFIGcnVicmljEjYKBXBhcnRzGA8gAygLMiAucXVlc3Rpb25f'
    'YmFuay5RdWVzdGlvblBhcnRJbnB1dFIFcGFydHNCCwoJX3N0aW11bHVzQgwKCl9tYXhfbWFya3'
    'NCDwoNX2Fuc3dlcl9saW5lc0IXChVfYW5zd2VyX2JveF9oZWlnaHRfbW1CEQoPX2V4YW1wbGVf'
    'YW5zd2Vy');

@$core.Deprecated('Use createQuestionResponseDescriptor instead')
const CreateQuestionResponse$json = {
  '1': 'CreateQuestionResponse',
  '2': [
    {
      '1': 'question',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'question'
    },
  ],
};

/// Descriptor for `CreateQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createQuestionResponseDescriptor =
    $convert.base64Decode(
        'ChZDcmVhdGVRdWVzdGlvblJlc3BvbnNlEjMKCHF1ZXN0aW9uGAEgASgLMhcucXVlc3Rpb25fYm'
        'Fuay5RdWVzdGlvblIIcXVlc3Rpb24=');

@$core.Deprecated('Use getQuestionRequestDescriptor instead')
const GetQuestionRequest$json = {
  '1': 'GetQuestionRequest',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
  ],
};

/// Descriptor for `GetQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuestionRequestDescriptor = $convert.base64Decode(
    'ChJHZXRRdWVzdGlvblJlcXVlc3QSHwoLcXVlc3Rpb25faWQYASABKAVSCnF1ZXN0aW9uSWQ=');

@$core.Deprecated('Use getQuestionResponseDescriptor instead')
const GetQuestionResponse$json = {
  '1': 'GetQuestionResponse',
  '2': [
    {
      '1': 'question',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'question'
    },
  ],
};

/// Descriptor for `GetQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuestionResponseDescriptor = $convert.base64Decode(
    'ChNHZXRRdWVzdGlvblJlc3BvbnNlEjMKCHF1ZXN0aW9uGAEgASgLMhcucXVlc3Rpb25fYmFuay'
    '5RdWVzdGlvblIIcXVlc3Rpb24=');

@$core.Deprecated('Use listQuestionsRequestDescriptor instead')
const ListQuestionsRequest$json = {
  '1': 'ListQuestionsRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'page', '3': 2, '4': 1, '5': 5, '10': 'page'},
    {'1': 'page_size', '3': 3, '4': 1, '5': 5, '10': 'pageSize'},
  ],
};

/// Descriptor for `ListQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listQuestionsRequestDescriptor = $convert.base64Decode(
    'ChRMaXN0UXVlc3Rpb25zUmVxdWVzdBIZCgh0b3BpY19pZBgBIAEoBVIHdG9waWNJZBISCgRwYW'
    'dlGAIgASgFUgRwYWdlEhsKCXBhZ2Vfc2l6ZRgDIAEoBVIIcGFnZVNpemU=');

@$core.Deprecated('Use listQuestionsResponseDescriptor instead')
const ListQuestionsResponse$json = {
  '1': 'ListQuestionsResponse',
  '2': [
    {
      '1': 'questions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'questions'
    },
    {'1': 'total', '3': 2, '4': 1, '5': 5, '10': 'total'},
  ],
};

/// Descriptor for `ListQuestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listQuestionsResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0UXVlc3Rpb25zUmVzcG9uc2USNQoJcXVlc3Rpb25zGAEgAygLMhcucXVlc3Rpb25fYm'
    'Fuay5RdWVzdGlvblIJcXVlc3Rpb25zEhQKBXRvdGFsGAIgASgFUgV0b3RhbA==');

@$core.Deprecated('Use updateQuestionRequestDescriptor instead')
const UpdateQuestionRequest$json = {
  '1': 'UpdateQuestionRequest',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {
      '1': 'topic_id',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'topicId',
      '17': true
    },
    {'1': 'body', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'body', '17': true},
    {
      '1': 'body_format',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'bodyFormat',
      '17': true
    },
    {
      '1': 'stimulus',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'stimulus',
      '17': true
    },
    {'1': 'type', '3': 6, '4': 1, '5': 5, '9': 4, '10': 'type', '17': true},
    {
      '1': 'difficulty',
      '3': 7,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'difficulty',
      '17': true
    },
    {
      '1': 'cognitive_level',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 6,
      '10': 'cognitiveLevel',
      '17': true
    },
    {'1': 'marks', '3': 9, '4': 1, '5': 5, '9': 7, '10': 'marks', '17': true},
    {
      '1': 'max_marks',
      '3': 10,
      '4': 1,
      '5': 5,
      '9': 8,
      '10': 'maxMarks',
      '17': true
    },
    {
      '1': 'answer_space_type',
      '3': 11,
      '4': 1,
      '5': 5,
      '9': 9,
      '10': 'answerSpaceType',
      '17': true
    },
    {
      '1': 'answer_lines',
      '3': 12,
      '4': 1,
      '5': 5,
      '9': 10,
      '10': 'answerLines',
      '17': true
    },
    {
      '1': 'answer_box_height_mm',
      '3': 13,
      '4': 1,
      '5': 5,
      '9': 11,
      '10': 'answerBoxHeightMm',
      '17': true
    },
    {
      '1': 'example_answer',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 12,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterionInput',
      '10': 'rubric'
    },
    {
      '1': 'parts',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.question_bank.QuestionPartInput',
      '10': 'parts'
    },
  ],
  '8': [
    {'1': '_topic_id'},
    {'1': '_body'},
    {'1': '_body_format'},
    {'1': '_stimulus'},
    {'1': '_type'},
    {'1': '_difficulty'},
    {'1': '_cognitive_level'},
    {'1': '_marks'},
    {'1': '_max_marks'},
    {'1': '_answer_space_type'},
    {'1': '_answer_lines'},
    {'1': '_answer_box_height_mm'},
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `UpdateQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateQuestionRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVRdWVzdGlvblJlcXVlc3QSHwoLcXVlc3Rpb25faWQYASABKAVSCnF1ZXN0aW9uSW'
    'QSHgoIdG9waWNfaWQYAiABKAVIAFIHdG9waWNJZIgBARIXCgRib2R5GAMgASgJSAFSBGJvZHmI'
    'AQESJAoLYm9keV9mb3JtYXQYBCABKAVIAlIKYm9keUZvcm1hdIgBARIfCghzdGltdWx1cxgFIA'
    'EoCUgDUghzdGltdWx1c4gBARIXCgR0eXBlGAYgASgFSARSBHR5cGWIAQESIwoKZGlmZmljdWx0'
    'eRgHIAEoBUgFUgpkaWZmaWN1bHR5iAEBEiwKD2NvZ25pdGl2ZV9sZXZlbBgIIAEoBUgGUg5jb2'
    'duaXRpdmVMZXZlbIgBARIZCgVtYXJrcxgJIAEoBUgHUgVtYXJrc4gBARIgCgltYXhfbWFya3MY'
    'CiABKAVICFIIbWF4TWFya3OIAQESLwoRYW5zd2VyX3NwYWNlX3R5cGUYCyABKAVICVIPYW5zd2'
    'VyU3BhY2VUeXBliAEBEiYKDGFuc3dlcl9saW5lcxgMIAEoBUgKUgthbnN3ZXJMaW5lc4gBARI0'
    'ChRhbnN3ZXJfYm94X2hlaWdodF9tbRgNIAEoBUgLUhFhbnN3ZXJCb3hIZWlnaHRNbYgBARIqCg'
    '5leGFtcGxlX2Fuc3dlchgOIAEoCUgMUg1leGFtcGxlQW5zd2VyiAEBEjsKBnJ1YnJpYxgPIAMo'
    'CzIjLnF1ZXN0aW9uX2JhbmsuUnVicmljQ3JpdGVyaW9uSW5wdXRSBnJ1YnJpYxI2CgVwYXJ0cx'
    'gQIAMoCzIgLnF1ZXN0aW9uX2JhbmsuUXVlc3Rpb25QYXJ0SW5wdXRSBXBhcnRzQgsKCV90b3Bp'
    'Y19pZEIHCgVfYm9keUIOCgxfYm9keV9mb3JtYXRCCwoJX3N0aW11bHVzQgcKBV90eXBlQg0KC1'
    '9kaWZmaWN1bHR5QhIKEF9jb2duaXRpdmVfbGV2ZWxCCAoGX21hcmtzQgwKCl9tYXhfbWFya3NC'
    'FAoSX2Fuc3dlcl9zcGFjZV90eXBlQg8KDV9hbnN3ZXJfbGluZXNCFwoVX2Fuc3dlcl9ib3hfaG'
    'VpZ2h0X21tQhEKD19leGFtcGxlX2Fuc3dlcg==');

@$core.Deprecated('Use updateQuestionResponseDescriptor instead')
const UpdateQuestionResponse$json = {
  '1': 'UpdateQuestionResponse',
  '2': [
    {
      '1': 'question',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'question'
    },
  ],
};

/// Descriptor for `UpdateQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateQuestionResponseDescriptor =
    $convert.base64Decode(
        'ChZVcGRhdGVRdWVzdGlvblJlc3BvbnNlEjMKCHF1ZXN0aW9uGAEgASgLMhcucXVlc3Rpb25fYm'
        'Fuay5RdWVzdGlvblIIcXVlc3Rpb24=');

@$core.Deprecated('Use deleteQuestionRequestDescriptor instead')
const DeleteQuestionRequest$json = {
  '1': 'DeleteQuestionRequest',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
  ],
};

/// Descriptor for `DeleteQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteQuestionRequestDescriptor = $convert.base64Decode(
    'ChVEZWxldGVRdWVzdGlvblJlcXVlc3QSHwoLcXVlc3Rpb25faWQYASABKAVSCnF1ZXN0aW9uSW'
    'Q=');

@$core.Deprecated('Use deleteQuestionResponseDescriptor instead')
const DeleteQuestionResponse$json = {
  '1': 'DeleteQuestionResponse',
};

/// Descriptor for `DeleteQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteQuestionResponseDescriptor =
    $convert.base64Decode('ChZEZWxldGVRdWVzdGlvblJlc3BvbnNl');

@$core.Deprecated('Use bulkImportRequestDescriptor instead')
const BulkImportRequest$json = {
  '1': 'BulkImportRequest',
  '2': [
    {
      '1': 'questions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.CreateQuestionRequest',
      '10': 'questions'
    },
  ],
};

/// Descriptor for `BulkImportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bulkImportRequestDescriptor = $convert.base64Decode(
    'ChFCdWxrSW1wb3J0UmVxdWVzdBJCCglxdWVzdGlvbnMYASADKAsyJC5xdWVzdGlvbl9iYW5rLk'
    'NyZWF0ZVF1ZXN0aW9uUmVxdWVzdFIJcXVlc3Rpb25z');

@$core.Deprecated('Use bulkImportResponseDescriptor instead')
const BulkImportResponse$json = {
  '1': 'BulkImportResponse',
  '2': [
    {'1': 'created', '3': 1, '4': 1, '5': 5, '10': 'created'},
    {'1': 'skipped', '3': 2, '4': 1, '5': 5, '10': 'skipped'},
    {'1': 'errors', '3': 3, '4': 3, '5': 9, '10': 'errors'},
  ],
};

/// Descriptor for `BulkImportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bulkImportResponseDescriptor = $convert.base64Decode(
    'ChJCdWxrSW1wb3J0UmVzcG9uc2USGAoHY3JlYXRlZBgBIAEoBVIHY3JlYXRlZBIYCgdza2lwcG'
    'VkGAIgASgFUgdza2lwcGVkEhYKBmVycm9ycxgDIAMoCVIGZXJyb3Jz');

@$core.Deprecated('Use imageUploadUrlsRequestDescriptor instead')
const ImageUploadUrlsRequest$json = {
  '1': 'ImageUploadUrlsRequest',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'count', '3': 2, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `ImageUploadUrlsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageUploadUrlsRequestDescriptor =
    $convert.base64Decode(
        'ChZJbWFnZVVwbG9hZFVybHNSZXF1ZXN0Eh8KC3F1ZXN0aW9uX2lkGAEgASgFUgpxdWVzdGlvbk'
        'lkEhQKBWNvdW50GAIgASgFUgVjb3VudA==');

@$core.Deprecated('Use imageUploadUrlsResponseDescriptor instead')
const ImageUploadUrlsResponse$json = {
  '1': 'ImageUploadUrlsResponse',
  '2': [
    {'1': 'urls', '3': 1, '4': 3, '5': 9, '10': 'urls'},
  ],
};

/// Descriptor for `ImageUploadUrlsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageUploadUrlsResponseDescriptor =
    $convert.base64Decode(
        'ChdJbWFnZVVwbG9hZFVybHNSZXNwb25zZRISCgR1cmxzGAEgAygJUgR1cmxz');

@$core.Deprecated('Use topicAllocationDescriptor instead')
const TopicAllocation$json = {
  '1': 'TopicAllocation',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'total_marks', '3': 2, '4': 1, '5': 5, '10': 'totalMarks'},
  ],
};

/// Descriptor for `TopicAllocation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List topicAllocationDescriptor = $convert.base64Decode(
    'Cg9Ub3BpY0FsbG9jYXRpb24SGQoIdG9waWNfaWQYASABKAVSB3RvcGljSWQSHwoLdG90YWxfbW'
    'Fya3MYAiABKAVSCnRvdGFsTWFya3M=');

@$core.Deprecated('Use generatePaperRequestDescriptor instead')
const GeneratePaperRequest$json = {
  '1': 'GeneratePaperRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'total_marks', '3': 2, '4': 1, '5': 5, '10': 'totalMarks'},
    {
      '1': 'topic_allocations',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.question_bank.TopicAllocation',
      '10': 'topicAllocations'
    },
  ],
};

/// Descriptor for `GeneratePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generatePaperRequestDescriptor = $convert.base64Decode(
    'ChRHZW5lcmF0ZVBhcGVyUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZBIfCgt0b3'
    'RhbF9tYXJrcxgCIAEoBVIKdG90YWxNYXJrcxJLChF0b3BpY19hbGxvY2F0aW9ucxgDIAMoCzIe'
    'LnF1ZXN0aW9uX2JhbmsuVG9waWNBbGxvY2F0aW9uUhB0b3BpY0FsbG9jYXRpb25z');

@$core.Deprecated('Use generatePaperResponseDescriptor instead')
const GeneratePaperResponse$json = {
  '1': 'GeneratePaperResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `GeneratePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generatePaperResponseDescriptor = $convert.base64Decode(
    'ChVHZW5lcmF0ZVBhcGVyUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZX'
    'NzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use getPaperQuestionsRequestDescriptor instead')
const GetPaperQuestionsRequest$json = {
  '1': 'GetPaperQuestionsRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {
      '1': 'student',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'student',
      '17': true
    },
  ],
  '8': [
    {'1': '_student'},
  ],
};

/// Descriptor for `GetPaperQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperQuestionsRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRQYXBlclF1ZXN0aW9uc1JlcXVlc3QSGQoIcGFwZXJfaWQYASABKAlSB3BhcGVySWQSHQ'
        'oHc3R1ZGVudBgCIAEoBUgAUgdzdHVkZW50iAEBQgoKCF9zdHVkZW50');

@$core.Deprecated('Use getPaperQuestionsResponseDescriptor instead')
const GetPaperQuestionsResponse$json = {
  '1': 'GetPaperQuestionsResponse',
  '2': [
    {
      '1': 'questions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'questions'
    },
  ],
};

/// Descriptor for `GetPaperQuestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperQuestionsResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRQYXBlclF1ZXN0aW9uc1Jlc3BvbnNlEjUKCXF1ZXN0aW9ucxgBIAMoCzIXLnF1ZXN0aW'
        '9uX2JhbmsuUXVlc3Rpb25SCXF1ZXN0aW9ucw==');

@$core.Deprecated('Use regenerateQuestionRequestDescriptor instead')
const RegenerateQuestionRequest$json = {
  '1': 'RegenerateQuestionRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {
      '1': 'student',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'student',
      '17': true
    },
    {'1': 'position', '3': 3, '4': 1, '5': 5, '10': 'position'},
    {'1': 'topic_id', '3': 4, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'marks', '3': 5, '4': 1, '5': 5, '10': 'marks'},
    {'1': 'exclude_ids', '3': 6, '4': 3, '5': 5, '10': 'excludeIds'},
  ],
  '8': [
    {'1': '_student'},
  ],
};

/// Descriptor for `RegenerateQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regenerateQuestionRequestDescriptor = $convert.base64Decode(
    'ChlSZWdlbmVyYXRlUXVlc3Rpb25SZXF1ZXN0EhkKCHBhcGVyX2lkGAEgASgJUgdwYXBlcklkEh'
    '0KB3N0dWRlbnQYAiABKAVIAFIHc3R1ZGVudIgBARIaCghwb3NpdGlvbhgDIAEoBVIIcG9zaXRp'
    'b24SGQoIdG9waWNfaWQYBCABKAVSB3RvcGljSWQSFAoFbWFya3MYBSABKAVSBW1hcmtzEh8KC2'
    'V4Y2x1ZGVfaWRzGAYgAygFUgpleGNsdWRlSWRzQgoKCF9zdHVkZW50');

@$core.Deprecated('Use regenerateQuestionResponseDescriptor instead')
const RegenerateQuestionResponse$json = {
  '1': 'RegenerateQuestionResponse',
  '2': [
    {
      '1': 'question',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'question'
    },
  ],
};

/// Descriptor for `RegenerateQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regenerateQuestionResponseDescriptor =
    $convert.base64Decode(
        'ChpSZWdlbmVyYXRlUXVlc3Rpb25SZXNwb25zZRIzCghxdWVzdGlvbhgBIAEoCzIXLnF1ZXN0aW'
        '9uX2JhbmsuUXVlc3Rpb25SCHF1ZXN0aW9u');

@$core.Deprecated('Use clearPaperQuestionsRequestDescriptor instead')
const ClearPaperQuestionsRequest$json = {
  '1': 'ClearPaperQuestionsRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {
      '1': 'student',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'student',
      '17': true
    },
  ],
  '8': [
    {'1': '_student'},
  ],
};

/// Descriptor for `ClearPaperQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearPaperQuestionsRequestDescriptor =
    $convert.base64Decode(
        'ChpDbGVhclBhcGVyUXVlc3Rpb25zUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZB'
        'IdCgdzdHVkZW50GAIgASgFSABSB3N0dWRlbnSIAQFCCgoIX3N0dWRlbnQ=');

@$core.Deprecated('Use clearPaperQuestionsResponseDescriptor instead')
const ClearPaperQuestionsResponse$json = {
  '1': 'ClearPaperQuestionsResponse',
};

/// Descriptor for `ClearPaperQuestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearPaperQuestionsResponseDescriptor =
    $convert.base64Decode('ChtDbGVhclBhcGVyUXVlc3Rpb25zUmVzcG9uc2U=');

@$core.Deprecated('Use finalizePaperRequestDescriptor instead')
const FinalizePaperRequest$json = {
  '1': 'FinalizePaperRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `FinalizePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizePaperRequestDescriptor =
    $convert.base64Decode(
        'ChRGaW5hbGl6ZVBhcGVyUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZA==');

@$core.Deprecated('Use finalizePaperResponseDescriptor instead')
const FinalizePaperResponse$json = {
  '1': 'FinalizePaperResponse',
  '2': [
    {'1': 'pdf_key', '3': 1, '4': 1, '5': 9, '10': 'pdfKey'},
    {'1': 'ms_key', '3': 2, '4': 1, '5': 9, '10': 'msKey'},
  ],
};

/// Descriptor for `FinalizePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizePaperResponseDescriptor = $convert.base64Decode(
    'ChVGaW5hbGl6ZVBhcGVyUmVzcG9uc2USFwoHcGRmX2tleRgBIAEoCVIGcGRmS2V5EhUKBm1zX2'
    'tleRgCIAEoCVIFbXNLZXk=');

@$core.Deprecated('Use markingStatusRequestDescriptor instead')
const MarkingStatusRequest$json = {
  '1': 'MarkingStatusRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `MarkingStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markingStatusRequestDescriptor =
    $convert.base64Decode(
        'ChRNYXJraW5nU3RhdHVzUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZA==');

@$core.Deprecated('Use markingStatusResponseDescriptor instead')
const MarkingStatusResponse$json = {
  '1': 'MarkingStatusResponse',
  '2': [
    {'1': 'phase', '3': 1, '4': 1, '5': 5, '10': 'phase'},
    {'1': 'progress', '3': 2, '4': 1, '5': 9, '10': 'progress'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
    {'1': 'total_students', '3': 4, '4': 1, '5': 5, '10': 'totalStudents'},
    {'1': 'marked_students', '3': 5, '4': 1, '5': 5, '10': 'markedStudents'},
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `MarkingStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markingStatusResponseDescriptor = $convert.base64Decode(
    'ChVNYXJraW5nU3RhdHVzUmVzcG9uc2USFAoFcGhhc2UYASABKAVSBXBoYXNlEhoKCHByb2dyZX'
    'NzGAIgASgJUghwcm9ncmVzcxIZCgVlcnJvchgDIAEoCUgAUgVlcnJvcogBARIlCg50b3RhbF9z'
    'dHVkZW50cxgEIAEoBVINdG90YWxTdHVkZW50cxInCg9tYXJrZWRfc3R1ZGVudHMYBSABKAVSDm'
    '1hcmtlZFN0dWRlbnRzQggKBl9lcnJvcg==');

@$core.Deprecated('Use questionGradeDescriptor instead')
const QuestionGrade$json = {
  '1': 'QuestionGrade',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'score', '3': 2, '4': 1, '5': 2, '10': 'score'},
    {
      '1': 'feedback',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'feedback',
      '17': true
    },
  ],
  '8': [
    {'1': '_feedback'},
  ],
};

/// Descriptor for `QuestionGrade`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionGradeDescriptor = $convert.base64Decode(
    'Cg1RdWVzdGlvbkdyYWRlEh8KC3F1ZXN0aW9uX2lkGAEgASgFUgpxdWVzdGlvbklkEhQKBXNjb3'
    'JlGAIgASgCUgVzY29yZRIfCghmZWVkYmFjaxgDIAEoCUgAUghmZWVkYmFja4gBAUILCglfZmVl'
    'ZGJhY2s=');

@$core.Deprecated('Use getQuestionGradesRequestDescriptor instead')
const GetQuestionGradesRequest$json = {
  '1': 'GetQuestionGradesRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'student', '3': 2, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `GetQuestionGradesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuestionGradesRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRRdWVzdGlvbkdyYWRlc1JlcXVlc3QSGQoIcGFwZXJfaWQYASABKAlSB3BhcGVySWQSGA'
        'oHc3R1ZGVudBgCIAEoBVIHc3R1ZGVudA==');

@$core.Deprecated('Use getQuestionGradesResponseDescriptor instead')
const GetQuestionGradesResponse$json = {
  '1': 'GetQuestionGradesResponse',
  '2': [
    {
      '1': 'grades',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.QuestionGrade',
      '10': 'grades'
    },
  ],
};

/// Descriptor for `GetQuestionGradesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuestionGradesResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRRdWVzdGlvbkdyYWRlc1Jlc3BvbnNlEjQKBmdyYWRlcxgBIAMoCzIcLnF1ZXN0aW9uX2'
        'JhbmsuUXVlc3Rpb25HcmFkZVIGZ3JhZGVz');
