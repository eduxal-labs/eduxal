// This is a generated file - do not edit.
//
// Generated from types/user.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use levelDescriptor instead')
const Level$json = {
  '1': 'Level',
  '2': [
    {'1': 'Normal', '2': 0},
    {'1': 'System', '2': 1},
    {'1': 'Super', '2': 2},
  ],
};

/// Descriptor for `Level`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List levelDescriptor = $convert
    .base64Decode('CgVMZXZlbBIKCgZOb3JtYWwQABIKCgZTeXN0ZW0QARIJCgVTdXBlchAC');

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'Invited', '2': 0},
    {'1': 'Active', '2': 1},
    {'1': 'Suspended', '2': 2},
    {'1': 'Deleted', '2': 3},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSCwoHSW52aXRlZBAAEgoKBkFjdGl2ZRABEg0KCVN1c3BlbmRlZBACEgsKB0RlbG'
    'V0ZWQQAw==');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'phone', '3': 2, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'email', '3': 4, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
    {'1': 'level', '3': 5, '4': 1, '5': 14, '6': '.user.Level', '10': 'level'},
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.user.Status',
      '10': 'status'
    },
    {'1': 'profile', '3': 7, '4': 1, '5': 9, '10': 'profile'},
    {'1': 'created', '3': 8, '4': 1, '5': 3, '10': 'created'},
    {'1': 'updated', '3': 9, '4': 1, '5': 3, '10': 'updated'},
  ],
  '8': [
    {'1': '_email'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBIUCgVwaG9uZRgCIAEoCVIFcGhvbmUSEgoEbmFtZRgDIA'
    'EoCVIEbmFtZRIZCgVlbWFpbBgEIAEoCUgAUgVlbWFpbIgBARIhCgVsZXZlbBgFIAEoDjILLnVz'
    'ZXIuTGV2ZWxSBWxldmVsEiQKBnN0YXR1cxgGIAEoDjIMLnVzZXIuU3RhdHVzUgZzdGF0dXMSGA'
    'oHcHJvZmlsZRgHIAEoCVIHcHJvZmlsZRIYCgdjcmVhdGVkGAggASgDUgdjcmVhdGVkEhgKB3Vw'
    'ZGF0ZWQYCSABKANSB3VwZGF0ZWRCCAoGX2VtYWls');

@$core.Deprecated('Use updateDescriptor instead')
const Update$json = {
  '1': 'Update',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'id', '17': true},
    {'1': 'phone', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'phone', '17': true},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '9': 2, '10': 'name', '17': true},
    {'1': 'email', '3': 4, '4': 1, '5': 9, '9': 3, '10': 'email', '17': true},
    {
      '1': 'level',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.user.Level',
      '9': 4,
      '10': 'level',
      '17': true
    },
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.user.Status',
      '9': 5,
      '10': 'status',
      '17': true
    },
    {
      '1': 'profile',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'profile',
      '17': true
    },
    {
      '1': 'created',
      '3': 8,
      '4': 1,
      '5': 3,
      '9': 7,
      '10': 'created',
      '17': true
    },
    {
      '1': 'updated',
      '3': 9,
      '4': 1,
      '5': 3,
      '9': 8,
      '10': 'updated',
      '17': true
    },
  ],
  '8': [
    {'1': '_id'},
    {'1': '_phone'},
    {'1': '_name'},
    {'1': '_email'},
    {'1': '_level'},
    {'1': '_status'},
    {'1': '_profile'},
    {'1': '_created'},
    {'1': '_updated'},
  ],
};

/// Descriptor for `Update`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDescriptor = $convert.base64Decode(
    'CgZVcGRhdGUSEwoCaWQYASABKAlIAFICaWSIAQESGQoFcGhvbmUYAiABKAlIAVIFcGhvbmWIAQ'
    'ESFwoEbmFtZRgDIAEoCUgCUgRuYW1liAEBEhkKBWVtYWlsGAQgASgJSANSBWVtYWlsiAEBEiYK'
    'BWxldmVsGAUgASgOMgsudXNlci5MZXZlbEgEUgVsZXZlbIgBARIpCgZzdGF0dXMYBiABKA4yDC'
    '51c2VyLlN0YXR1c0gFUgZzdGF0dXOIAQESHQoHcHJvZmlsZRgHIAEoCUgGUgdwcm9maWxliAEB'
    'Eh0KB2NyZWF0ZWQYCCABKANIB1IHY3JlYXRlZIgBARIdCgd1cGRhdGVkGAkgASgDSAhSB3VwZG'
    'F0ZWSIAQFCBQoDX2lkQggKBl9waG9uZUIHCgVfbmFtZUIICgZfZW1haWxCCAoGX2xldmVsQgkK'
    'B19zdGF0dXNCCgoIX3Byb2ZpbGVCCgoIX2NyZWF0ZWRCCgoIX3VwZGF0ZWQ=');
