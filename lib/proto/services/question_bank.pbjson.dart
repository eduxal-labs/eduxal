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

@$core.Deprecated('Use markingPhaseDescriptor instead')
const MarkingPhase$json = {
  '1': 'MarkingPhase',
  '2': [
    {'1': 'QUEUED', '2': 0},
    {'1': 'DOWNLOADING', '2': 1},
    {'1': 'CACHING', '2': 2},
    {'1': 'MARKING', '2': 3},
    {'1': 'AGGREGATING', '2': 4},
    {'1': 'COMPLETE', '2': 5},
    {'1': 'FAILED', '2': 6},
  ],
};

/// Descriptor for `MarkingPhase`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List markingPhaseDescriptor = $convert.base64Decode(
    'CgxNYXJraW5nUGhhc2USCgoGUVVFVUVEEAASDwoLRE9XTkxPQURJTkcQARILCgdDQUNISU5HEA'
    'ISCwoHTUFSS0lORxADEg8KC0FHR1JFR0FUSU5HEAQSDAoIQ09NUExFVEUQBRIKCgZGQUlMRUQQ'
    'Bg==');

@$core.Deprecated('Use questionDescriptor instead')
const Question$json = {
  '1': 'Question',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'topic_id', '3': 2, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'marks', '3': 4, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'example_answer',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterion',
      '10': 'rubric'
    },
    {
      '1': 'images',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.question_bank.QuestionImage',
      '10': 'images'
    },
    {'1': 'created', '3': 8, '4': 1, '5': 3, '10': 'created'},
    {'1': 'updated', '3': 9, '4': 1, '5': 3, '10': 'updated'},
  ],
  '8': [
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `Question`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionDescriptor = $convert.base64Decode(
    'CghRdWVzdGlvbhIOCgJpZBgBIAEoBVICaWQSGQoIdG9waWNfaWQYAiABKAVSB3RvcGljSWQSEg'
    'oEdGV4dBgDIAEoCVIEdGV4dBIUCgVtYXJrcxgEIAEoBVIFbWFya3MSKgoOZXhhbXBsZV9hbnN3'
    'ZXIYBSABKAlIAFINZXhhbXBsZUFuc3dlcogBARI2CgZydWJyaWMYBiADKAsyHi5xdWVzdGlvbl'
    '9iYW5rLlJ1YnJpY0NyaXRlcmlvblIGcnVicmljEjQKBmltYWdlcxgHIAMoCzIcLnF1ZXN0aW9u'
    'X2JhbmsuUXVlc3Rpb25JbWFnZVIGaW1hZ2VzEhgKB2NyZWF0ZWQYCCABKANSB2NyZWF0ZWQSGA'
    'oHdXBkYXRlZBgJIAEoA1IHdXBkYXRlZEIRCg9fZXhhbXBsZV9hbnN3ZXI=');

@$core.Deprecated('Use rubricCriterionDescriptor instead')
const RubricCriterion$json = {
  '1': 'RubricCriterion',
  '2': [
    {'1': 'position', '3': 1, '4': 1, '5': 5, '10': 'position'},
    {'1': 'criterion', '3': 2, '4': 1, '5': 9, '10': 'criterion'},
    {'1': 'marks', '3': 3, '4': 1, '5': 5, '10': 'marks'},
  ],
};

/// Descriptor for `RubricCriterion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rubricCriterionDescriptor = $convert.base64Decode(
    'Cg9SdWJyaWNDcml0ZXJpb24SGgoIcG9zaXRpb24YASABKAVSCHBvc2l0aW9uEhwKCWNyaXRlcm'
    'lvbhgCIAEoCVIJY3JpdGVyaW9uEhQKBW1hcmtzGAMgASgFUgVtYXJrcw==');

@$core.Deprecated('Use questionImageDescriptor instead')
const QuestionImage$json = {
  '1': 'QuestionImage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'position', '3': 2, '4': 1, '5': 5, '10': 'position'},
    {'1': 'context', '3': 3, '4': 1, '5': 5, '10': 'context'},
    {'1': 'key', '3': 4, '4': 1, '5': 9, '10': 'key'},
    {'1': 'url', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'url', '17': true},
    {
      '1': 'caption',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'caption',
      '17': true
    },
  ],
  '8': [
    {'1': '_url'},
    {'1': '_caption'},
  ],
};

/// Descriptor for `QuestionImage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionImageDescriptor = $convert.base64Decode(
    'Cg1RdWVzdGlvbkltYWdlEg4KAmlkGAEgASgFUgJpZBIaCghwb3NpdGlvbhgCIAEoBVIIcG9zaX'
    'Rpb24SGAoHY29udGV4dBgDIAEoBVIHY29udGV4dBIQCgNrZXkYBCABKAlSA2tleRIVCgN1cmwY'
    'BSABKAlIAFIDdXJsiAEBEh0KB2NhcHRpb24YBiABKAlIAVIHY2FwdGlvbogBAUIGCgRfdXJsQg'
    'oKCF9jYXB0aW9u');

@$core.Deprecated('Use createQuestionRequestDescriptor instead')
const CreateQuestionRequest$json = {
  '1': 'CreateQuestionRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'marks', '3': 3, '4': 1, '5': 5, '10': 'marks'},
    {
      '1': 'example_answer',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterionInput',
      '10': 'rubric'
    },
  ],
  '8': [
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `CreateQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createQuestionRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVRdWVzdGlvblJlcXVlc3QSGQoIdG9waWNfaWQYASABKAVSB3RvcGljSWQSEgoEdG'
    'V4dBgCIAEoCVIEdGV4dBIUCgVtYXJrcxgDIAEoBVIFbWFya3MSKgoOZXhhbXBsZV9hbnN3ZXIY'
    'BCABKAlIAFINZXhhbXBsZUFuc3dlcogBARI7CgZydWJyaWMYBSADKAsyIy5xdWVzdGlvbl9iYW'
    '5rLlJ1YnJpY0NyaXRlcmlvbklucHV0UgZydWJyaWNCEQoPX2V4YW1wbGVfYW5zd2Vy');

@$core.Deprecated('Use rubricCriterionInputDescriptor instead')
const RubricCriterionInput$json = {
  '1': 'RubricCriterionInput',
  '2': [
    {'1': 'criterion', '3': 1, '4': 1, '5': 9, '10': 'criterion'},
    {'1': 'marks', '3': 2, '4': 1, '5': 5, '10': 'marks'},
  ],
};

/// Descriptor for `RubricCriterionInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rubricCriterionInputDescriptor = $convert.base64Decode(
    'ChRSdWJyaWNDcml0ZXJpb25JbnB1dBIcCgljcml0ZXJpb24YASABKAlSCWNyaXRlcmlvbhIUCg'
    'VtYXJrcxgCIAEoBVIFbWFya3M=');

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

@$core.Deprecated('Use updateQuestionRequestDescriptor instead')
const UpdateQuestionRequest$json = {
  '1': 'UpdateQuestionRequest',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'text', '17': true},
    {'1': 'marks', '3': 3, '4': 1, '5': 5, '9': 1, '10': 'marks', '17': true},
    {
      '1': 'example_answer',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterionInput',
      '10': 'rubric'
    },
  ],
  '8': [
    {'1': '_text'},
    {'1': '_marks'},
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `UpdateQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateQuestionRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVRdWVzdGlvblJlcXVlc3QSHwoLcXVlc3Rpb25faWQYASABKAVSCnF1ZXN0aW9uSW'
    'QSFwoEdGV4dBgCIAEoCUgAUgR0ZXh0iAEBEhkKBW1hcmtzGAMgASgFSAFSBW1hcmtziAEBEioK'
    'DmV4YW1wbGVfYW5zd2VyGAQgASgJSAJSDWV4YW1wbGVBbnN3ZXKIAQESOwoGcnVicmljGAUgAy'
    'gLMiMucXVlc3Rpb25fYmFuay5SdWJyaWNDcml0ZXJpb25JbnB1dFIGcnVicmljQgcKBV90ZXh0'
    'QggKBl9tYXJrc0IRCg9fZXhhbXBsZV9hbnN3ZXI=');

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
    {'1': 'json_content', '3': 1, '4': 1, '5': 9, '10': 'jsonContent'},
  ],
};

/// Descriptor for `BulkImportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bulkImportRequestDescriptor = $convert.base64Decode(
    'ChFCdWxrSW1wb3J0UmVxdWVzdBIhCgxqc29uX2NvbnRlbnQYASABKAlSC2pzb25Db250ZW50');

@$core.Deprecated('Use bulkImportResponseDescriptor instead')
const BulkImportResponse$json = {
  '1': 'BulkImportResponse',
  '2': [
    {
      '1': 'questions_created',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'questionsCreated'
    },
    {
      '1': 'errors',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.question_bank.ImportError',
      '10': 'errors'
    },
    {'1': 'question_ids', '3': 3, '4': 3, '5': 5, '10': 'questionIds'},
    {
      '1': 'duplicates_skipped',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'duplicatesSkipped'
    },
  ],
};

/// Descriptor for `BulkImportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bulkImportResponseDescriptor = $convert.base64Decode(
    'ChJCdWxrSW1wb3J0UmVzcG9uc2USKwoRcXVlc3Rpb25zX2NyZWF0ZWQYASABKAVSEHF1ZXN0aW'
    '9uc0NyZWF0ZWQSMgoGZXJyb3JzGAIgAygLMhoucXVlc3Rpb25fYmFuay5JbXBvcnRFcnJvclIG'
    'ZXJyb3JzEiEKDHF1ZXN0aW9uX2lkcxgDIAMoBVILcXVlc3Rpb25JZHMSLQoSZHVwbGljYXRlc1'
    '9za2lwcGVkGAQgASgFUhFkdXBsaWNhdGVzU2tpcHBlZA==');

@$core.Deprecated('Use importErrorDescriptor instead')
const ImportError$json = {
  '1': 'ImportError',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ImportError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importErrorDescriptor = $convert.base64Decode(
    'CgtJbXBvcnRFcnJvchIUCgVpbmRleBgBIAEoBVIFaW5kZXgSGAoHbWVzc2FnZRgCIAEoCVIHbW'
    'Vzc2FnZQ==');

@$core.Deprecated('Use imageUploadUrlsRequestDescriptor instead')
const ImageUploadUrlsRequest$json = {
  '1': 'ImageUploadUrlsRequest',
  '2': [
    {
      '1': 'images',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.ImageUploadSpec',
      '10': 'images'
    },
  ],
};

/// Descriptor for `ImageUploadUrlsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageUploadUrlsRequestDescriptor =
    $convert.base64Decode(
        'ChZJbWFnZVVwbG9hZFVybHNSZXF1ZXN0EjYKBmltYWdlcxgBIAMoCzIeLnF1ZXN0aW9uX2Jhbm'
        'suSW1hZ2VVcGxvYWRTcGVjUgZpbWFnZXM=');

@$core.Deprecated('Use imageUploadSpecDescriptor instead')
const ImageUploadSpec$json = {
  '1': 'ImageUploadSpec',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'position', '3': 2, '4': 1, '5': 5, '10': 'position'},
    {'1': 'context', '3': 3, '4': 1, '5': 5, '10': 'context'},
    {
      '1': 'caption',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'caption',
      '17': true
    },
    {'1': 'filename', '3': 5, '4': 1, '5': 9, '10': 'filename'},
  ],
  '8': [
    {'1': '_caption'},
  ],
};

/// Descriptor for `ImageUploadSpec`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageUploadSpecDescriptor = $convert.base64Decode(
    'Cg9JbWFnZVVwbG9hZFNwZWMSHwoLcXVlc3Rpb25faWQYASABKAVSCnF1ZXN0aW9uSWQSGgoIcG'
    '9zaXRpb24YAiABKAVSCHBvc2l0aW9uEhgKB2NvbnRleHQYAyABKAVSB2NvbnRleHQSHQoHY2Fw'
    'dGlvbhgEIAEoCUgAUgdjYXB0aW9uiAEBEhoKCGZpbGVuYW1lGAUgASgJUghmaWxlbmFtZUIKCg'
    'hfY2FwdGlvbg==');

@$core.Deprecated('Use imageUploadUrlsResponseDescriptor instead')
const ImageUploadUrlsResponse$json = {
  '1': 'ImageUploadUrlsResponse',
  '2': [
    {
      '1': 'urls',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.ImageUploadUrl',
      '10': 'urls'
    },
  ],
};

/// Descriptor for `ImageUploadUrlsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageUploadUrlsResponseDescriptor =
    $convert.base64Decode(
        'ChdJbWFnZVVwbG9hZFVybHNSZXNwb25zZRIxCgR1cmxzGAEgAygLMh0ucXVlc3Rpb25fYmFuay'
        '5JbWFnZVVwbG9hZFVybFIEdXJscw==');

@$core.Deprecated('Use imageUploadUrlDescriptor instead')
const ImageUploadUrl$json = {
  '1': 'ImageUploadUrl',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'position', '3': 2, '4': 1, '5': 5, '10': 'position'},
    {'1': 'key', '3': 3, '4': 1, '5': 9, '10': 'key'},
    {'1': 'put_url', '3': 4, '4': 1, '5': 9, '10': 'putUrl'},
  ],
};

/// Descriptor for `ImageUploadUrl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageUploadUrlDescriptor = $convert.base64Decode(
    'Cg5JbWFnZVVwbG9hZFVybBIfCgtxdWVzdGlvbl9pZBgBIAEoBVIKcXVlc3Rpb25JZBIaCghwb3'
    'NpdGlvbhgCIAEoBVIIcG9zaXRpb24SEAoDa2V5GAMgASgJUgNrZXkSFwoHcHV0X3VybBgEIAEo'
    'CVIGcHV0VXJs');

@$core.Deprecated('Use generatePaperRequestDescriptor instead')
const GeneratePaperRequest$json = {
  '1': 'GeneratePaperRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'total_marks', '3': 7, '4': 1, '5': 5, '10': 'totalMarks'},
    {
      '1': 'topic_allocations',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.question_bank.TopicAllocation',
      '10': 'topicAllocations'
    },
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `GeneratePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generatePaperRequestDescriptor = $convert.base64Decode(
    'ChRHZW5lcmF0ZVBhcGVyUmVxdWVzdBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGA'
    'IgASgJUgRleGFtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCABKAVIAFIF'
    'cGFwZXKIAQESFAoFZ3JhZGUYBSABKAVSBWdyYWRlEhsKBnN0cmVhbRgGIAEoBUgBUgZzdHJlYW'
    '2IAQESHwoLdG90YWxfbWFya3MYByABKAVSCnRvdGFsTWFya3MSSwoRdG9waWNfYWxsb2NhdGlv'
    'bnMYCCADKAsyHi5xdWVzdGlvbl9iYW5rLlRvcGljQWxsb2NhdGlvblIQdG9waWNBbGxvY2F0aW'
    '9uc0IICgZfcGFwZXJCCQoHX3N0cmVhbQ==');

@$core.Deprecated('Use topicAllocationDescriptor instead')
const TopicAllocation$json = {
  '1': 'TopicAllocation',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'marks', '3': 2, '4': 1, '5': 5, '10': 'marks'},
  ],
};

/// Descriptor for `TopicAllocation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List topicAllocationDescriptor = $convert.base64Decode(
    'Cg9Ub3BpY0FsbG9jYXRpb24SGQoIdG9waWNfaWQYASABKAVSB3RvcGljSWQSFAoFbWFya3MYAi'
    'ABKAVSBW1hcmtz');

@$core.Deprecated('Use generatePaperResponseDescriptor instead')
const GeneratePaperResponse$json = {
  '1': 'GeneratePaperResponse',
  '2': [
    {
      '1': 'questions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.PaperQuestion',
      '10': 'questions'
    },
  ],
};

/// Descriptor for `GeneratePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generatePaperResponseDescriptor = $convert.base64Decode(
    'ChVHZW5lcmF0ZVBhcGVyUmVzcG9uc2USOgoJcXVlc3Rpb25zGAEgAygLMhwucXVlc3Rpb25fYm'
    'Fuay5QYXBlclF1ZXN0aW9uUglxdWVzdGlvbnM=');

@$core.Deprecated('Use paperQuestionDescriptor instead')
const PaperQuestion$json = {
  '1': 'PaperQuestion',
  '2': [
    {'1': 'position', '3': 1, '4': 1, '5': 5, '10': 'position'},
    {
      '1': 'question',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.question_bank.Question',
      '10': 'question'
    },
    {
      '1': 'section',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'section',
      '17': true
    },
  ],
  '8': [
    {'1': '_section'},
  ],
};

/// Descriptor for `PaperQuestion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperQuestionDescriptor = $convert.base64Decode(
    'Cg1QYXBlclF1ZXN0aW9uEhoKCHBvc2l0aW9uGAEgASgFUghwb3NpdGlvbhIzCghxdWVzdGlvbh'
    'gCIAEoCzIXLnF1ZXN0aW9uX2JhbmsuUXVlc3Rpb25SCHF1ZXN0aW9uEh0KB3NlY3Rpb24YAyAB'
    'KAlIAFIHc2VjdGlvbogBAUIKCghfc2VjdGlvbg==');

@$core.Deprecated('Use regenerateQuestionRequestDescriptor instead')
const RegenerateQuestionRequest$json = {
  '1': 'RegenerateQuestionRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'position', '3': 7, '4': 1, '5': 5, '10': 'position'},
    {'1': 'topic_id', '3': 8, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'marks', '3': 9, '4': 1, '5': 5, '10': 'marks'},
    {'1': 'exclude_ids', '3': 10, '4': 3, '5': 5, '10': 'excludeIds'},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `RegenerateQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regenerateQuestionRequestDescriptor = $convert.base64Decode(
    'ChlSZWdlbmVyYXRlUXVlc3Rpb25SZXF1ZXN0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBG'
    'V4YW0YAiABKAlSBGV4YW0SGAoHc3ViamVjdBgDIAEoBVIHc3ViamVjdBIZCgVwYXBlchgEIAEo'
    'BUgAUgVwYXBlcogBARIUCgVncmFkZRgFIAEoBVIFZ3JhZGUSGwoGc3RyZWFtGAYgASgFSAFSBn'
    'N0cmVhbYgBARIaCghwb3NpdGlvbhgHIAEoBVIIcG9zaXRpb24SGQoIdG9waWNfaWQYCCABKAVS'
    'B3RvcGljSWQSFAoFbWFya3MYCSABKAVSBW1hcmtzEh8KC2V4Y2x1ZGVfaWRzGAogAygFUgpleG'
    'NsdWRlSWRzQggKBl9wYXBlckIJCgdfc3RyZWFt');

@$core.Deprecated('Use regenerateQuestionResponseDescriptor instead')
const RegenerateQuestionResponse$json = {
  '1': 'RegenerateQuestionResponse',
  '2': [
    {
      '1': 'replacement',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.question_bank.PaperQuestion',
      '10': 'replacement'
    },
  ],
};

/// Descriptor for `RegenerateQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regenerateQuestionResponseDescriptor =
    $convert.base64Decode(
        'ChpSZWdlbmVyYXRlUXVlc3Rpb25SZXNwb25zZRI+CgtyZXBsYWNlbWVudBgBIAEoCzIcLnF1ZX'
        'N0aW9uX2JhbmsuUGFwZXJRdWVzdGlvblILcmVwbGFjZW1lbnQ=');

@$core.Deprecated('Use editPaperQuestionRequestDescriptor instead')
const EditPaperQuestionRequest$json = {
  '1': 'EditPaperQuestionRequest',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'text', '17': true},
    {'1': 'marks', '3': 3, '4': 1, '5': 5, '9': 1, '10': 'marks', '17': true},
    {
      '1': 'example_answer',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'exampleAnswer',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterionInput',
      '10': 'rubric'
    },
  ],
  '8': [
    {'1': '_text'},
    {'1': '_marks'},
    {'1': '_example_answer'},
  ],
};

/// Descriptor for `EditPaperQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editPaperQuestionRequestDescriptor = $convert.base64Decode(
    'ChhFZGl0UGFwZXJRdWVzdGlvblJlcXVlc3QSHwoLcXVlc3Rpb25faWQYASABKAVSCnF1ZXN0aW'
    '9uSWQSFwoEdGV4dBgCIAEoCUgAUgR0ZXh0iAEBEhkKBW1hcmtzGAMgASgFSAFSBW1hcmtziAEB'
    'EioKDmV4YW1wbGVfYW5zd2VyGAQgASgJSAJSDWV4YW1wbGVBbnN3ZXKIAQESOwoGcnVicmljGA'
    'UgAygLMiMucXVlc3Rpb25fYmFuay5SdWJyaWNDcml0ZXJpb25JbnB1dFIGcnVicmljQgcKBV90'
    'ZXh0QggKBl9tYXJrc0IRCg9fZXhhbXBsZV9hbnN3ZXI=');

@$core.Deprecated('Use editPaperQuestionResponseDescriptor instead')
const EditPaperQuestionResponse$json = {
  '1': 'EditPaperQuestionResponse',
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

/// Descriptor for `EditPaperQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editPaperQuestionResponseDescriptor =
    $convert.base64Decode(
        'ChlFZGl0UGFwZXJRdWVzdGlvblJlc3BvbnNlEjMKCHF1ZXN0aW9uGAEgASgLMhcucXVlc3Rpb2'
        '5fYmFuay5RdWVzdGlvblIIcXVlc3Rpb24=');

@$core.Deprecated('Use finalizePaperRequestDescriptor instead')
const FinalizePaperRequest$json = {
  '1': 'FinalizePaperRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `FinalizePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizePaperRequestDescriptor = $convert.base64Decode(
    'ChRGaW5hbGl6ZVBhcGVyUmVxdWVzdBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGA'
    'IgASgJUgRleGFtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCABKAVIAFIF'
    'cGFwZXKIAQESFAoFZ3JhZGUYBSABKAVSBWdyYWRlEhsKBnN0cmVhbRgGIAEoBUgBUgZzdHJlYW'
    '2IAQFCCAoGX3BhcGVyQgkKB19zdHJlYW0=');

@$core.Deprecated('Use finalizePaperResponseDescriptor instead')
const FinalizePaperResponse$json = {
  '1': 'FinalizePaperResponse',
  '2': [
    {'1': 'pdf_url', '3': 1, '4': 1, '5': 9, '10': 'pdfUrl'},
    {'1': 'pdf_expiry', '3': 2, '4': 1, '5': 3, '10': 'pdfExpiry'},
    {
      '1': 'marking_scheme_url',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'markingSchemeUrl'
    },
    {
      '1': 'marking_scheme_expiry',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'markingSchemeExpiry'
    },
  ],
};

/// Descriptor for `FinalizePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizePaperResponseDescriptor = $convert.base64Decode(
    'ChVGaW5hbGl6ZVBhcGVyUmVzcG9uc2USFwoHcGRmX3VybBgBIAEoCVIGcGRmVXJsEh0KCnBkZl'
    '9leHBpcnkYAiABKANSCXBkZkV4cGlyeRIsChJtYXJraW5nX3NjaGVtZV91cmwYAyABKAlSEG1h'
    'cmtpbmdTY2hlbWVVcmwSMgoVbWFya2luZ19zY2hlbWVfZXhwaXJ5GAQgASgDUhNtYXJraW5nU2'
    'NoZW1lRXhwaXJ5');

@$core.Deprecated('Use getPaperPdfRequestDescriptor instead')
const GetPaperPdfRequest$json = {
  '1': 'GetPaperPdfRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `GetPaperPdfRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperPdfRequestDescriptor = $convert.base64Decode(
    'ChJHZXRQYXBlclBkZlJlcXVlc3QSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZXhhbRgCIA'
    'EoCVIEZXhhbRIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhkKBXBhcGVyGAQgASgFSABSBXBh'
    'cGVyiAEBEhQKBWdyYWRlGAUgASgFUgVncmFkZRIbCgZzdHJlYW0YBiABKAVIAVIGc3RyZWFtiA'
    'EBQggKBl9wYXBlckIJCgdfc3RyZWFt');

@$core.Deprecated('Use getPaperPdfResponseDescriptor instead')
const GetPaperPdfResponse$json = {
  '1': 'GetPaperPdfResponse',
  '2': [
    {'1': 'pdf_url', '3': 1, '4': 1, '5': 9, '10': 'pdfUrl'},
    {'1': 'pdf_expiry', '3': 2, '4': 1, '5': 3, '10': 'pdfExpiry'},
  ],
};

/// Descriptor for `GetPaperPdfResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperPdfResponseDescriptor = $convert.base64Decode(
    'ChNHZXRQYXBlclBkZlJlc3BvbnNlEhcKB3BkZl91cmwYASABKAlSBnBkZlVybBIdCgpwZGZfZX'
    'hwaXJ5GAIgASgDUglwZGZFeHBpcnk=');

@$core.Deprecated('Use getPaperQuestionsRequestDescriptor instead')
const GetPaperQuestionsRequest$json = {
  '1': 'GetPaperQuestionsRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `GetPaperQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperQuestionsRequestDescriptor = $convert.base64Decode(
    'ChhHZXRQYXBlclF1ZXN0aW9uc1JlcXVlc3QSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZX'
    'hhbRgCIAEoCVIEZXhhbRIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhkKBXBhcGVyGAQgASgF'
    'SABSBXBhcGVyiAEBEhQKBWdyYWRlGAUgASgFUgVncmFkZRIbCgZzdHJlYW0YBiABKAVIAVIGc3'
    'RyZWFtiAEBQggKBl9wYXBlckIJCgdfc3RyZWFt');

@$core.Deprecated('Use getPaperQuestionsResponseDescriptor instead')
const GetPaperQuestionsResponse$json = {
  '1': 'GetPaperQuestionsResponse',
  '2': [
    {
      '1': 'questions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.PaperQuestion',
      '10': 'questions'
    },
  ],
};

/// Descriptor for `GetPaperQuestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperQuestionsResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRQYXBlclF1ZXN0aW9uc1Jlc3BvbnNlEjoKCXF1ZXN0aW9ucxgBIAMoCzIcLnF1ZXN0aW'
        '9uX2JhbmsuUGFwZXJRdWVzdGlvblIJcXVlc3Rpb25z');

@$core.Deprecated('Use setPaperQuestionSectionRequestDescriptor instead')
const SetPaperQuestionSectionRequest$json = {
  '1': 'SetPaperQuestionSectionRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'position', '3': 7, '4': 1, '5': 5, '10': 'position'},
    {
      '1': 'section',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'section',
      '17': true
    },
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
    {'1': '_section'},
  ],
};

/// Descriptor for `SetPaperQuestionSectionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPaperQuestionSectionRequestDescriptor = $convert.base64Decode(
    'Ch5TZXRQYXBlclF1ZXN0aW9uU2VjdGlvblJlcXVlc3QSFgoGc2Nob29sGAEgASgJUgZzY2hvb2'
    'wSEgoEZXhhbRgCIAEoCVIEZXhhbRIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhkKBXBhcGVy'
    'GAQgASgFSABSBXBhcGVyiAEBEhQKBWdyYWRlGAUgASgFUgVncmFkZRIbCgZzdHJlYW0YBiABKA'
    'VIAVIGc3RyZWFtiAEBEhoKCHBvc2l0aW9uGAcgASgFUghwb3NpdGlvbhIdCgdzZWN0aW9uGAgg'
    'ASgJSAJSB3NlY3Rpb26IAQFCCAoGX3BhcGVyQgkKB19zdHJlYW1CCgoIX3NlY3Rpb24=');

@$core.Deprecated('Use setPaperQuestionSectionResponseDescriptor instead')
const SetPaperQuestionSectionResponse$json = {
  '1': 'SetPaperQuestionSectionResponse',
};

/// Descriptor for `SetPaperQuestionSectionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPaperQuestionSectionResponseDescriptor =
    $convert.base64Decode('Ch9TZXRQYXBlclF1ZXN0aW9uU2VjdGlvblJlc3BvbnNl');

@$core.Deprecated('Use listQuestionsRequestDescriptor instead')
const ListQuestionsRequest$json = {
  '1': 'ListQuestionsRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {
      '1': 'min_marks',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'minMarks',
      '17': true
    },
    {
      '1': 'max_marks',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'maxMarks',
      '17': true
    },
    {'1': 'offset', '3': 4, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'limit', '3': 5, '4': 1, '5': 5, '10': 'limit'},
  ],
  '8': [
    {'1': '_min_marks'},
    {'1': '_max_marks'},
  ],
};

/// Descriptor for `ListQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listQuestionsRequestDescriptor = $convert.base64Decode(
    'ChRMaXN0UXVlc3Rpb25zUmVxdWVzdBIZCgh0b3BpY19pZBgBIAEoBVIHdG9waWNJZBIgCgltaW'
    '5fbWFya3MYAiABKAVIAFIIbWluTWFya3OIAQESIAoJbWF4X21hcmtzGAMgASgFSAFSCG1heE1h'
    'cmtziAEBEhYKBm9mZnNldBgEIAEoBVIGb2Zmc2V0EhQKBWxpbWl0GAUgASgFUgVsaW1pdEIMCg'
    'pfbWluX21hcmtzQgwKCl9tYXhfbWFya3M=');

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

@$core.Deprecated('Use getQuestionGradesRequestDescriptor instead')
const GetQuestionGradesRequest$json = {
  '1': 'GetQuestionGradesRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
    {'1': 'subject', '3': 4, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 6, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 7, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `GetQuestionGradesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuestionGradesRequestDescriptor = $convert.base64Decode(
    'ChhHZXRRdWVzdGlvbkdyYWRlc1JlcXVlc3QSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZX'
    'hhbRgCIAEoCVIEZXhhbRIYCgdzdHVkZW50GAMgASgFUgdzdHVkZW50EhgKB3N1YmplY3QYBCAB'
    'KAVSB3N1YmplY3QSGQoFcGFwZXIYBSABKAVIAFIFcGFwZXKIAQESFAoFZ3JhZGUYBiABKAVSBW'
    'dyYWRlEhsKBnN0cmVhbRgHIAEoBUgBUgZzdHJlYW2IAQFCCAoGX3BhcGVyQgkKB19zdHJlYW0=');

@$core.Deprecated('Use getQuestionGradesResponseDescriptor instead')
const GetQuestionGradesResponse$json = {
  '1': 'GetQuestionGradesResponse',
  '2': [
    {
      '1': 'grades',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.QuestionGradeDetail',
      '10': 'grades'
    },
  ],
};

/// Descriptor for `GetQuestionGradesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuestionGradesResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRRdWVzdGlvbkdyYWRlc1Jlc3BvbnNlEjoKBmdyYWRlcxgBIAMoCzIiLnF1ZXN0aW9uX2'
        'JhbmsuUXVlc3Rpb25HcmFkZURldGFpbFIGZ3JhZGVz');

@$core.Deprecated('Use questionGradeDetailDescriptor instead')
const QuestionGradeDetail$json = {
  '1': 'QuestionGradeDetail',
  '2': [
    {'1': 'question_id', '3': 1, '4': 1, '5': 5, '10': 'questionId'},
    {'1': 'question_text', '3': 2, '4': 1, '5': 9, '10': 'questionText'},
    {'1': 'question_marks', '3': 3, '4': 1, '5': 5, '10': 'questionMarks'},
    {'1': 'score', '3': 4, '4': 1, '5': 2, '10': 'score'},
    {
      '1': 'feedback',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'feedback',
      '17': true
    },
    {
      '1': 'rubric',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.question_bank.RubricCriterion',
      '10': 'rubric'
    },
  ],
  '8': [
    {'1': '_feedback'},
  ],
};

/// Descriptor for `QuestionGradeDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List questionGradeDetailDescriptor = $convert.base64Decode(
    'ChNRdWVzdGlvbkdyYWRlRGV0YWlsEh8KC3F1ZXN0aW9uX2lkGAEgASgFUgpxdWVzdGlvbklkEi'
    'MKDXF1ZXN0aW9uX3RleHQYAiABKAlSDHF1ZXN0aW9uVGV4dBIlCg5xdWVzdGlvbl9tYXJrcxgD'
    'IAEoBVINcXVlc3Rpb25NYXJrcxIUCgVzY29yZRgEIAEoAlIFc2NvcmUSHwoIZmVlZGJhY2sYBS'
    'ABKAlIAFIIZmVlZGJhY2uIAQESNgoGcnVicmljGAYgAygLMh4ucXVlc3Rpb25fYmFuay5SdWJy'
    'aWNDcml0ZXJpb25SBnJ1YnJpY0ILCglfZmVlZGJhY2s=');

@$core.Deprecated('Use markingStatusRequestDescriptor instead')
const MarkingStatusRequest$json = {
  '1': 'MarkingStatusRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `MarkingStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markingStatusRequestDescriptor = $convert.base64Decode(
    'ChRNYXJraW5nU3RhdHVzUmVxdWVzdBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGA'
    'IgASgJUgRleGFtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCABKAVIAFIF'
    'cGFwZXKIAQESFAoFZ3JhZGUYBSABKAVSBWdyYWRlEhsKBnN0cmVhbRgGIAEoBUgBUgZzdHJlYW'
    '2IAQFCCAoGX3BhcGVyQgkKB19zdHJlYW0=');

@$core.Deprecated('Use markingStatusResponseDescriptor instead')
const MarkingStatusResponse$json = {
  '1': 'MarkingStatusResponse',
  '2': [
    {
      '1': 'phase',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.question_bank.MarkingPhase',
      '10': 'phase'
    },
    {'1': 'progress', '3': 2, '4': 1, '5': 9, '10': 'progress'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
    {
      '1': 'estimated_completion',
      '3': 4,
      '4': 1,
      '5': 3,
      '9': 1,
      '10': 'estimatedCompletion',
      '17': true
    },
  ],
  '8': [
    {'1': '_error'},
    {'1': '_estimated_completion'},
  ],
};

/// Descriptor for `MarkingStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markingStatusResponseDescriptor = $convert.base64Decode(
    'ChVNYXJraW5nU3RhdHVzUmVzcG9uc2USMQoFcGhhc2UYASABKA4yGy5xdWVzdGlvbl9iYW5rLk'
    '1hcmtpbmdQaGFzZVIFcGhhc2USGgoIcHJvZ3Jlc3MYAiABKAlSCHByb2dyZXNzEhkKBWVycm9y'
    'GAMgASgJSABSBWVycm9yiAEBEjYKFGVzdGltYXRlZF9jb21wbGV0aW9uGAQgASgDSAFSE2VzdG'
    'ltYXRlZENvbXBsZXRpb26IAQFCCAoGX2Vycm9yQhcKFV9lc3RpbWF0ZWRfY29tcGxldGlvbg==');

@$core.Deprecated('Use clearPaperQuestionsRequestDescriptor instead')
const ClearPaperQuestionsRequest$json = {
  '1': 'ClearPaperQuestionsRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_stream'},
  ],
};

/// Descriptor for `ClearPaperQuestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearPaperQuestionsRequestDescriptor = $convert.base64Decode(
    'ChpDbGVhclBhcGVyUXVlc3Rpb25zUmVxdWVzdBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCg'
    'RleGFtGAIgASgJUgRleGFtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCAB'
    'KAVIAFIFcGFwZXKIAQESFAoFZ3JhZGUYBSABKAVSBWdyYWRlEhsKBnN0cmVhbRgGIAEoBUgBUg'
    'ZzdHJlYW2IAQFCCAoGX3BhcGVyQgkKB19zdHJlYW0=');

@$core.Deprecated('Use clearPaperQuestionsResponseDescriptor instead')
const ClearPaperQuestionsResponse$json = {
  '1': 'ClearPaperQuestionsResponse',
  '2': [
    {
      '1': 'questions_deleted',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'questionsDeleted'
    },
    {'1': 'pdf_deleted', '3': 2, '4': 1, '5': 8, '10': 'pdfDeleted'},
  ],
};

/// Descriptor for `ClearPaperQuestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearPaperQuestionsResponseDescriptor =
    $convert.base64Decode(
        'ChtDbGVhclBhcGVyUXVlc3Rpb25zUmVzcG9uc2USKwoRcXVlc3Rpb25zX2RlbGV0ZWQYASABKA'
        'VSEHF1ZXN0aW9uc0RlbGV0ZWQSHwoLcGRmX2RlbGV0ZWQYAiABKAhSCnBkZkRlbGV0ZWQ=');

@$core.Deprecated('Use copyPaperToStreamsRequestDescriptor instead')
const CopyPaperToStreamsRequest$json = {
  '1': 'CopyPaperToStreamsRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {
      '1': 'source_stream',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'sourceStream',
      '17': true
    },
    {'1': 'target_streams', '3': 7, '4': 3, '5': 5, '10': 'targetStreams'},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_source_stream'},
  ],
};

/// Descriptor for `CopyPaperToStreamsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List copyPaperToStreamsRequestDescriptor = $convert.base64Decode(
    'ChlDb3B5UGFwZXJUb1N0cmVhbXNSZXF1ZXN0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBG'
    'V4YW0YAiABKAlSBGV4YW0SGAoHc3ViamVjdBgDIAEoBVIHc3ViamVjdBIZCgVwYXBlchgEIAEo'
    'BUgAUgVwYXBlcogBARIUCgVncmFkZRgFIAEoBVIFZ3JhZGUSKAoNc291cmNlX3N0cmVhbRgGIA'
    'EoBUgBUgxzb3VyY2VTdHJlYW2IAQESJQoOdGFyZ2V0X3N0cmVhbXMYByADKAVSDXRhcmdldFN0'
    'cmVhbXNCCAoGX3BhcGVyQhAKDl9zb3VyY2Vfc3RyZWFt');

@$core.Deprecated('Use streamCopyResultDescriptor instead')
const StreamCopyResult$json = {
  '1': 'StreamCopyResult',
  '2': [
    {'1': 'stream', '3': 1, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
    {'1': 'pdf_url', '3': 3, '4': 1, '5': 9, '10': 'pdfUrl'},
    {'1': 'pdf_expiry', '3': 4, '4': 1, '5': 3, '10': 'pdfExpiry'},
    {
      '1': 'marking_scheme_url',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'markingSchemeUrl'
    },
    {
      '1': 'marking_scheme_expiry',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'markingSchemeExpiry'
    },
    {'1': 'error', '3': 7, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `StreamCopyResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamCopyResultDescriptor = $convert.base64Decode(
    'ChBTdHJlYW1Db3B5UmVzdWx0EhYKBnN0cmVhbRgBIAEoBVIGc3RyZWFtEhgKB3N1Y2Nlc3MYAi'
    'ABKAhSB3N1Y2Nlc3MSFwoHcGRmX3VybBgDIAEoCVIGcGRmVXJsEh0KCnBkZl9leHBpcnkYBCAB'
    'KANSCXBkZkV4cGlyeRIsChJtYXJraW5nX3NjaGVtZV91cmwYBSABKAlSEG1hcmtpbmdTY2hlbW'
    'VVcmwSMgoVbWFya2luZ19zY2hlbWVfZXhwaXJ5GAYgASgDUhNtYXJraW5nU2NoZW1lRXhwaXJ5'
    'EhQKBWVycm9yGAcgASgJUgVlcnJvcg==');

@$core.Deprecated('Use copyPaperToStreamsResponseDescriptor instead')
const CopyPaperToStreamsResponse$json = {
  '1': 'CopyPaperToStreamsResponse',
  '2': [
    {
      '1': 'results',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.question_bank.StreamCopyResult',
      '10': 'results'
    },
  ],
};

/// Descriptor for `CopyPaperToStreamsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List copyPaperToStreamsResponseDescriptor =
    $convert.base64Decode(
        'ChpDb3B5UGFwZXJUb1N0cmVhbXNSZXNwb25zZRI5CgdyZXN1bHRzGAEgAygLMh8ucXVlc3Rpb2'
        '5fYmFuay5TdHJlYW1Db3B5UmVzdWx0UgdyZXN1bHRz');
