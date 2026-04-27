// This is a generated file - do not edit.
//
// Generated from services/ai_marking.proto.

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

@$core.Deprecated('Use uploadUrlsRequestDescriptor instead')
const UploadUrlsRequest$json = {
  '1': 'UploadUrlsRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'scheme_count', '3': 2, '4': 1, '5': 5, '10': 'schemeCount'},
    {
      '1': 'students',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ai_marking.StudentSheetCount',
      '10': 'students'
    },
  ],
};

/// Descriptor for `UploadUrlsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadUrlsRequestDescriptor = $convert.base64Decode(
    'ChFVcGxvYWRVcmxzUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZXJJZBIhCgxzY2hlbW'
    'VfY291bnQYAiABKAVSC3NjaGVtZUNvdW50EjkKCHN0dWRlbnRzGAMgAygLMh0uYWlfbWFya2lu'
    'Zy5TdHVkZW50U2hlZXRDb3VudFIIc3R1ZGVudHM=');

@$core.Deprecated('Use studentSheetCountDescriptor instead')
const StudentSheetCount$json = {
  '1': 'StudentSheetCount',
  '2': [
    {'1': 'adm', '3': 1, '4': 1, '5': 5, '10': 'adm'},
    {'1': 'count', '3': 2, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `StudentSheetCount`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List studentSheetCountDescriptor = $convert.base64Decode(
    'ChFTdHVkZW50U2hlZXRDb3VudBIQCgNhZG0YASABKAVSA2FkbRIUCgVjb3VudBgCIAEoBVIFY2'
    '91bnQ=');

@$core.Deprecated('Use uploadUrlsResponseDescriptor instead')
const UploadUrlsResponse$json = {
  '1': 'UploadUrlsResponse',
  '2': [
    {
      '1': 'scheme_urls',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ai_marking.SignedUrl',
      '10': 'schemeUrls'
    },
    {
      '1': 'student_urls',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ai_marking.StudentSignedUrls',
      '10': 'studentUrls'
    },
  ],
};

/// Descriptor for `UploadUrlsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadUrlsResponseDescriptor = $convert.base64Decode(
    'ChJVcGxvYWRVcmxzUmVzcG9uc2USNgoLc2NoZW1lX3VybHMYASADKAsyFS5haV9tYXJraW5nLl'
    'NpZ25lZFVybFIKc2NoZW1lVXJscxJACgxzdHVkZW50X3VybHMYAiADKAsyHS5haV9tYXJraW5n'
    'LlN0dWRlbnRTaWduZWRVcmxzUgtzdHVkZW50VXJscw==');

@$core.Deprecated('Use signedUrlDescriptor instead')
const SignedUrl$json = {
  '1': 'SignedUrl',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `SignedUrl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signedUrlDescriptor = $convert.base64Decode(
    'CglTaWduZWRVcmwSEAoDa2V5GAEgASgJUgNrZXkSEAoDdXJsGAIgASgJUgN1cmw=');

@$core.Deprecated('Use studentSignedUrlsDescriptor instead')
const StudentSignedUrls$json = {
  '1': 'StudentSignedUrls',
  '2': [
    {'1': 'adm', '3': 1, '4': 1, '5': 5, '10': 'adm'},
    {
      '1': 'urls',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ai_marking.SignedUrl',
      '10': 'urls'
    },
  ],
};

/// Descriptor for `StudentSignedUrls`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List studentSignedUrlsDescriptor = $convert.base64Decode(
    'ChFTdHVkZW50U2lnbmVkVXJscxIQCgNhZG0YASABKAVSA2FkbRIpCgR1cmxzGAIgAygLMhUuYW'
    'lfbWFya2luZy5TaWduZWRVcmxSBHVybHM=');

@$core.Deprecated('Use markPaperRequestDescriptor instead')
const MarkPaperRequest$json = {
  '1': 'MarkPaperRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'total_marks', '3': 2, '4': 1, '5': 5, '10': 'totalMarks'},
    {'1': 'scheme_keys', '3': 3, '4': 3, '5': 9, '10': 'schemeKeys'},
    {
      '1': 'students',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ai_marking.StudentMarkTarget',
      '10': 'students'
    },
  ],
};

/// Descriptor for `MarkPaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markPaperRequestDescriptor = $convert.base64Decode(
    'ChBNYXJrUGFwZXJSZXF1ZXN0EhkKCHBhcGVyX2lkGAEgASgJUgdwYXBlcklkEh8KC3RvdGFsX2'
    '1hcmtzGAIgASgFUgp0b3RhbE1hcmtzEh8KC3NjaGVtZV9rZXlzGAMgAygJUgpzY2hlbWVLZXlz'
    'EjkKCHN0dWRlbnRzGAQgAygLMh0uYWlfbWFya2luZy5TdHVkZW50TWFya1RhcmdldFIIc3R1ZG'
    'VudHM=');

@$core.Deprecated('Use studentMarkTargetDescriptor instead')
const StudentMarkTarget$json = {
  '1': 'StudentMarkTarget',
  '2': [
    {'1': 'adm', '3': 1, '4': 1, '5': 5, '10': 'adm'},
    {'1': 'keys', '3': 2, '4': 3, '5': 9, '10': 'keys'},
  ],
};

/// Descriptor for `StudentMarkTarget`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List studentMarkTargetDescriptor = $convert.base64Decode(
    'ChFTdHVkZW50TWFya1RhcmdldBIQCgNhZG0YASABKAVSA2FkbRISCgRrZXlzGAIgAygJUgRrZX'
    'lz');

@$core.Deprecated('Use markPaperResponseDescriptor instead')
const MarkPaperResponse$json = {
  '1': 'MarkPaperResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `MarkPaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markPaperResponseDescriptor = $convert.base64Decode(
    'ChFNYXJrUGFwZXJSZXNwb25zZRIaCghhY2NlcHRlZBgBIAEoCFIIYWNjZXB0ZWQSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');
