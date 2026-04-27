// This is a generated file - do not edit.
//
// Generated from services/paper.proto.

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

@$core.Deprecated('Use paperTopicWeightDescriptor instead')
const PaperTopicWeight$json = {
  '1': 'PaperTopicWeight',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'weight', '3': 2, '4': 1, '5': 2, '10': 'weight'},
  ],
};

/// Descriptor for `PaperTopicWeight`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperTopicWeightDescriptor = $convert.base64Decode(
    'ChBQYXBlclRvcGljV2VpZ2h0EhkKCHRvcGljX2lkGAEgASgFUgd0b3BpY0lkEhYKBndlaWdodB'
    'gCIAEoAlIGd2VpZ2h0');

@$core.Deprecated('Use createPaperRequestDescriptor instead')
const CreatePaperRequest$json = {
  '1': 'CreatePaperRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'event', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'event', '17': true},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'type', '3': 6, '4': 1, '5': 5, '10': 'type'},
    {'1': 'name', '3': 7, '4': 1, '5': 9, '10': 'name'},
    {'1': 'total_marks', '3': 8, '4': 1, '5': 5, '10': 'totalMarks'},
    {'1': 'duration_minutes', '3': 9, '4': 1, '5': 5, '10': 'durationMinutes'},
    {'1': 'date', '3': 10, '4': 1, '5': 5, '10': 'date'},
    {'1': 'generation_mode', '3': 11, '4': 1, '5': 5, '10': 'generationMode'},
    {
      '1': 'instructions',
      '3': 12,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'instructions',
      '17': true
    },
    {
      '1': 'topic_weights',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.paper_service.PaperTopicWeight',
      '10': 'topicWeights'
    },
  ],
  '8': [
    {'1': '_event'},
    {'1': '_stream'},
    {'1': '_instructions'},
  ],
};

/// Descriptor for `CreatePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPaperRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVQYXBlclJlcXVlc3QSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSGQoFZXZlbnQYAi'
    'ABKAlIAFIFZXZlbnSIAQESGAoHc3ViamVjdBgDIAEoBVIHc3ViamVjdBIUCgVncmFkZRgEIAEo'
    'BVIFZ3JhZGUSGwoGc3RyZWFtGAUgASgFSAFSBnN0cmVhbYgBARISCgR0eXBlGAYgASgFUgR0eX'
    'BlEhIKBG5hbWUYByABKAlSBG5hbWUSHwoLdG90YWxfbWFya3MYCCABKAVSCnRvdGFsTWFya3MS'
    'KQoQZHVyYXRpb25fbWludXRlcxgJIAEoBVIPZHVyYXRpb25NaW51dGVzEhIKBGRhdGUYCiABKA'
    'VSBGRhdGUSJwoPZ2VuZXJhdGlvbl9tb2RlGAsgASgFUg5nZW5lcmF0aW9uTW9kZRInCgxpbnN0'
    'cnVjdGlvbnMYDCABKAlIAlIMaW5zdHJ1Y3Rpb25ziAEBEkQKDXRvcGljX3dlaWdodHMYDSADKA'
    'syHy5wYXBlcl9zZXJ2aWNlLlBhcGVyVG9waWNXZWlnaHRSDHRvcGljV2VpZ2h0c0IICgZfZXZl'
    'bnRCCQoHX3N0cmVhbUIPCg1faW5zdHJ1Y3Rpb25z');

@$core.Deprecated('Use createPaperResponseDescriptor instead')
const CreatePaperResponse$json = {
  '1': 'CreatePaperResponse',
  '2': [
    {'1': 'paper', '3': 1, '4': 1, '5': 11, '6': '.paper.Paper', '10': 'paper'},
  ],
};

/// Descriptor for `CreatePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPaperResponseDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVQYXBlclJlc3BvbnNlEiIKBXBhcGVyGAEgASgLMgwucGFwZXIuUGFwZXJSBXBhcG'
    'Vy');

@$core.Deprecated('Use getPaperRequestDescriptor instead')
const GetPaperRequest$json = {
  '1': 'GetPaperRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `GetPaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRQYXBlclJlcXVlc3QSGQoIcGFwZXJfaWQYASABKAlSB3BhcGVySWQ=');

@$core.Deprecated('Use getPaperResponseDescriptor instead')
const GetPaperResponse$json = {
  '1': 'GetPaperResponse',
  '2': [
    {'1': 'paper', '3': 1, '4': 1, '5': 11, '6': '.paper.Paper', '10': 'paper'},
  ],
};

/// Descriptor for `GetPaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperResponseDescriptor = $convert.base64Decode(
    'ChBHZXRQYXBlclJlc3BvbnNlEiIKBXBhcGVyGAEgASgLMgwucGFwZXIuUGFwZXJSBXBhcGVy');

@$core.Deprecated('Use listPapersRequestDescriptor instead')
const ListPapersRequest$json = {
  '1': 'ListPapersRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'event', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'event', '17': true},
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '9': 1, '10': 'grade', '17': true},
    {
      '1': 'subject',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'subject',
      '17': true
    },
  ],
  '8': [
    {'1': '_event'},
    {'1': '_grade'},
    {'1': '_subject'},
  ],
};

/// Descriptor for `ListPapersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPapersRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0UGFwZXJzUmVxdWVzdBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIZCgVldmVudBgCIA'
    'EoCUgAUgVldmVudIgBARIZCgVncmFkZRgDIAEoBUgBUgVncmFkZYgBARIdCgdzdWJqZWN0GAQg'
    'ASgFSAJSB3N1YmplY3SIAQFCCAoGX2V2ZW50QggKBl9ncmFkZUIKCghfc3ViamVjdA==');

@$core.Deprecated('Use listPapersResponseDescriptor instead')
const ListPapersResponse$json = {
  '1': 'ListPapersResponse',
  '2': [
    {
      '1': 'papers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.paper.Paper',
      '10': 'papers'
    },
  ],
};

/// Descriptor for `ListPapersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPapersResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0UGFwZXJzUmVzcG9uc2USJAoGcGFwZXJzGAEgAygLMgwucGFwZXIuUGFwZXJSBnBhcG'
    'Vycw==');

@$core.Deprecated('Use updatePaperRequestDescriptor instead')
const UpdatePaperRequest$json = {
  '1': 'UpdatePaperRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'total_marks',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'totalMarks',
      '17': true
    },
    {
      '1': 'duration_minutes',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'durationMinutes',
      '17': true
    },
    {'1': 'date', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'date', '17': true},
    {
      '1': 'instructions',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'instructions',
      '17': true
    },
    {
      '1': 'generation_mode',
      '3': 7,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'generationMode',
      '17': true
    },
  ],
  '8': [
    {'1': '_name'},
    {'1': '_total_marks'},
    {'1': '_duration_minutes'},
    {'1': '_date'},
    {'1': '_instructions'},
    {'1': '_generation_mode'},
  ],
};

/// Descriptor for `UpdatePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePaperRequestDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVQYXBlclJlcXVlc3QSGQoIcGFwZXJfaWQYASABKAlSB3BhcGVySWQSFwoEbmFtZR'
    'gCIAEoCUgAUgRuYW1liAEBEiQKC3RvdGFsX21hcmtzGAMgASgFSAFSCnRvdGFsTWFya3OIAQES'
    'LgoQZHVyYXRpb25fbWludXRlcxgEIAEoBUgCUg9kdXJhdGlvbk1pbnV0ZXOIAQESFwoEZGF0ZR'
    'gFIAEoBUgDUgRkYXRliAEBEicKDGluc3RydWN0aW9ucxgGIAEoCUgEUgxpbnN0cnVjdGlvbnOI'
    'AQESLAoPZ2VuZXJhdGlvbl9tb2RlGAcgASgFSAVSDmdlbmVyYXRpb25Nb2RliAEBQgcKBV9uYW'
    '1lQg4KDF90b3RhbF9tYXJrc0ITChFfZHVyYXRpb25fbWludXRlc0IHCgVfZGF0ZUIPCg1faW5z'
    'dHJ1Y3Rpb25zQhIKEF9nZW5lcmF0aW9uX21vZGU=');

@$core.Deprecated('Use updatePaperResponseDescriptor instead')
const UpdatePaperResponse$json = {
  '1': 'UpdatePaperResponse',
  '2': [
    {'1': 'paper', '3': 1, '4': 1, '5': 11, '6': '.paper.Paper', '10': 'paper'},
  ],
};

/// Descriptor for `UpdatePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePaperResponseDescriptor = $convert.base64Decode(
    'ChNVcGRhdGVQYXBlclJlc3BvbnNlEiIKBXBhcGVyGAEgASgLMgwucGFwZXIuUGFwZXJSBXBhcG'
    'Vy');

@$core.Deprecated('Use getPaperPdfUrlRequestDescriptor instead')
const GetPaperPdfUrlRequest$json = {
  '1': 'GetPaperPdfUrlRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `GetPaperPdfUrlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperPdfUrlRequestDescriptor =
    $convert.base64Decode(
        'ChVHZXRQYXBlclBkZlVybFJlcXVlc3QSGQoIcGFwZXJfaWQYASABKAlSB3BhcGVySWQ=');

@$core.Deprecated('Use getPaperPdfUrlResponseDescriptor instead')
const GetPaperPdfUrlResponse$json = {
  '1': 'GetPaperPdfUrlResponse',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'expiry', '3': 2, '4': 1, '5': 3, '10': 'expiry'},
  ],
};

/// Descriptor for `GetPaperPdfUrlResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPaperPdfUrlResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRQYXBlclBkZlVybFJlc3BvbnNlEhAKA3VybBgBIAEoCVIDdXJsEhYKBmV4cGlyeRgCIA'
        'EoA1IGZXhwaXJ5');

@$core.Deprecated('Use getMarkingSchemeUrlRequestDescriptor instead')
const GetMarkingSchemeUrlRequest$json = {
  '1': 'GetMarkingSchemeUrlRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `GetMarkingSchemeUrlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMarkingSchemeUrlRequestDescriptor =
    $convert.base64Decode(
        'ChpHZXRNYXJraW5nU2NoZW1lVXJsUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZA'
        '==');

@$core.Deprecated('Use getMarkingSchemeUrlResponseDescriptor instead')
const GetMarkingSchemeUrlResponse$json = {
  '1': 'GetMarkingSchemeUrlResponse',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'expiry', '3': 2, '4': 1, '5': 3, '10': 'expiry'},
  ],
};

/// Descriptor for `GetMarkingSchemeUrlResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMarkingSchemeUrlResponseDescriptor =
    $convert.base64Decode(
        'ChtHZXRNYXJraW5nU2NoZW1lVXJsUmVzcG9uc2USEAoDdXJsGAEgASgJUgN1cmwSFgoGZXhwaX'
        'J5GAIgASgDUgZleHBpcnk=');

@$core.Deprecated('Use forceSetPaperStatusRequestDescriptor instead')
const ForceSetPaperStatusRequest$json = {
  '1': 'ForceSetPaperStatusRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'status', '3': 2, '4': 1, '5': 5, '10': 'status'},
  ],
};

/// Descriptor for `ForceSetPaperStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forceSetPaperStatusRequestDescriptor =
    $convert.base64Decode(
        'ChpGb3JjZVNldFBhcGVyU3RhdHVzUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZB'
        'IWCgZzdGF0dXMYAiABKAVSBnN0YXR1cw==');

@$core.Deprecated('Use forceSetPaperStatusResponseDescriptor instead')
const ForceSetPaperStatusResponse$json = {
  '1': 'ForceSetPaperStatusResponse',
  '2': [
    {'1': 'paper', '3': 1, '4': 1, '5': 11, '6': '.paper.Paper', '10': 'paper'},
  ],
};

/// Descriptor for `ForceSetPaperStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forceSetPaperStatusResponseDescriptor =
    $convert.base64Decode(
        'ChtGb3JjZVNldFBhcGVyU3RhdHVzUmVzcG9uc2USIgoFcGFwZXIYASABKAsyDC5wYXBlci5QYX'
        'BlclIFcGFwZXI=');
