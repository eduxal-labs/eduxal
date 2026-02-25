// This is a generated file - do not edit.
//
// Generated from types/verification.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use purposeDescriptor instead')
const Purpose$json = {
  '1': 'Purpose',
  '2': [
    {'1': 'Verify', '2': 0},
    {'1': 'ChangePhone', '2': 1},
    {'1': 'Delete', '2': 2},
  ],
};

/// Descriptor for `Purpose`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List purposeDescriptor = $convert.base64Decode(
    'CgdQdXJwb3NlEgoKBlZlcmlmeRAAEg8KC0NoYW5nZVBob25lEAESCgoGRGVsZXRlEAI=');

@$core.Deprecated('Use verificationDescriptor instead')
const Verification$json = {
  '1': 'Verification',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'user', '17': true},
    {'1': 'phone', '3': 3, '4': 1, '5': 9, '10': 'phone'},
    {
      '1': 'purpose',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.verification.Purpose',
      '10': 'purpose'
    },
  ],
  '8': [
    {'1': '_user'},
  ],
};

/// Descriptor for `Verification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verificationDescriptor = $convert.base64Decode(
    'CgxWZXJpZmljYXRpb24SDgoCaWQYASABKAlSAmlkEhcKBHVzZXIYAiABKAlIAFIEdXNlcogBAR'
    'IUCgVwaG9uZRgDIAEoCVIFcGhvbmUSLwoHcHVycG9zZRgEIAEoDjIVLnZlcmlmaWNhdGlvbi5Q'
    'dXJwb3NlUgdwdXJwb3NlQgcKBV91c2Vy');
