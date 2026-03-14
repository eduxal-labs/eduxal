// This is a generated file - do not edit.
//
// Generated from services/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use actionRequestDescriptor instead')
const ActionRequest$json = {
  '1': 'ActionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'action', '3': 2, '4': 1, '5': 5, '10': 'action'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `ActionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List actionRequestDescriptor = $convert.base64Decode(
    'Cg1BY3Rpb25SZXF1ZXN0Eg4KAmlkGAEgASgFUgJpZBIWCgZhY3Rpb24YAiABKAVSBmFjdGlvbh'
    'IYCgdwYXlsb2FkGAMgASgMUgdwYXlsb2Fk');

@$core.Deprecated('Use actionResponseDescriptor instead')
const ActionResponse$json = {
  '1': 'ActionResponse',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
    {'1': 'code', '3': 3, '4': 1, '5': 5, '10': 'code'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'rows',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.sync.ActionRow',
      '10': 'rows'
    },
    {
      '1': 'file_urls',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.sync.FileUrl',
      '10': 'fileUrls'
    },
  ],
};

/// Descriptor for `ActionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List actionResponseDescriptor = $convert.base64Decode(
    'Cg5BY3Rpb25SZXNwb25zZRIOCgJpZBgBIAEoBVICaWQSGAoHc3VjY2VzcxgCIAEoCFIHc3VjY2'
    'VzcxISCgRjb2RlGAMgASgFUgRjb2RlEhQKBWVycm9yGAQgASgJUgVlcnJvchIjCgRyb3dzGAUg'
    'AygLMg8uc3luYy5BY3Rpb25Sb3dSBHJvd3MSKgoJZmlsZV91cmxzGAYgAygLMg0uc3luYy5GaW'
    'xlVXJsUghmaWxlVXJscw==');

@$core.Deprecated('Use actionRowDescriptor instead')
const ActionRow$json = {
  '1': 'ActionRow',
  '2': [
    {'1': 'table', '3': 1, '4': 1, '5': 5, '10': 'table'},
    {'1': 'operation', '3': 2, '4': 1, '5': 5, '10': 'operation'},
    {'1': 'row_key', '3': 3, '4': 1, '5': 9, '10': 'rowKey'},
    {
      '1': 'data',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.sync.InsertData',
      '10': 'data'
    },
  ],
};

/// Descriptor for `ActionRow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List actionRowDescriptor = $convert.base64Decode(
    'CglBY3Rpb25Sb3cSFAoFdGFibGUYASABKAVSBXRhYmxlEhwKCW9wZXJhdGlvbhgCIAEoBVIJb3'
    'BlcmF0aW9uEhcKB3Jvd19rZXkYAyABKAlSBnJvd0tleRIkCgRkYXRhGAQgASgLMhAuc3luYy5J'
    'bnNlcnREYXRhUgRkYXRh');

@$core.Deprecated('Use watchRequestDescriptor instead')
const WatchRequest$json = {
  '1': 'WatchRequest',
  '2': [
    {'1': 'last_seq', '3': 1, '4': 1, '5': 3, '10': 'lastSeq'},
  ],
};

/// Descriptor for `WatchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchRequestDescriptor = $convert
    .base64Decode('CgxXYXRjaFJlcXVlc3QSGQoIbGFzdF9zZXEYASABKANSB2xhc3RTZXE=');

@$core.Deprecated('Use syncDeltaDescriptor instead')
const SyncDelta$json = {
  '1': 'SyncDelta',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'table', '3': 2, '4': 1, '5': 5, '10': 'table'},
    {'1': 'operation', '3': 3, '4': 1, '5': 5, '10': 'operation'},
    {'1': 'row_key', '3': 4, '4': 1, '5': 9, '10': 'rowKey'},
    {
      '1': 'data',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.sync.InsertData',
      '10': 'data'
    },
    {
      '1': 'file_urls',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.sync.FileUrl',
      '10': 'fileUrls'
    },
  ],
};

/// Descriptor for `SyncDelta`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncDeltaDescriptor = $convert.base64Decode(
    'CglTeW5jRGVsdGESEAoDc2VxGAEgASgDUgNzZXESFAoFdGFibGUYAiABKAVSBXRhYmxlEhwKCW'
    '9wZXJhdGlvbhgDIAEoBVIJb3BlcmF0aW9uEhcKB3Jvd19rZXkYBCABKAlSBnJvd0tleRIkCgRk'
    'YXRhGAUgASgLMhAuc3luYy5JbnNlcnREYXRhUgRkYXRhEioKCWZpbGVfdXJscxgGIAMoCzINLn'
    'N5bmMuRmlsZVVybFIIZmlsZVVybHM=');

@$core.Deprecated('Use fileUrlDescriptor instead')
const FileUrl$json = {
  '1': 'FileUrl',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {
      '1': 'put_url',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'putUrl',
      '17': true
    },
    {
      '1': 'get_url',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'getUrl',
      '17': true
    },
    {'1': 'expiry', '3': 4, '4': 1, '5': 3, '10': 'expiry'},
  ],
  '8': [
    {'1': '_put_url'},
    {'1': '_get_url'},
  ],
};

/// Descriptor for `FileUrl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileUrlDescriptor = $convert.base64Decode(
    'CgdGaWxlVXJsEhIKBHBhdGgYASABKAlSBHBhdGgSHAoHcHV0X3VybBgCIAEoCUgAUgZwdXRVcm'
    'yIAQESHAoHZ2V0X3VybBgDIAEoCUgBUgZnZXRVcmyIAQESFgoGZXhwaXJ5GAQgASgDUgZleHBp'
    'cnlCCgoIX3B1dF91cmxCCgoIX2dldF91cmw=');

@$core.Deprecated('Use createSchoolPayloadDescriptor instead')
const CreateSchoolPayload$json = {
  '1': 'CreateSchoolPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'motto', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'motto', '17': true},
    {'1': 'phone', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'phone', '17': true},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 2, '10': 'email', '17': true},
    {'1': 'county', '3': 6, '4': 1, '5': 5, '10': 'county'},
    {'1': 'domain', '3': 7, '4': 1, '5': 9, '9': 3, '10': 'domain', '17': true},
    {
      '1': 'established',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'established',
      '17': true
    },
    {'1': 'owner_id', '3': 10, '4': 1, '5': 9, '10': 'ownerId'},
    {'1': 'owner_phone', '3': 11, '4': 1, '5': 9, '10': 'ownerPhone'},
    {'1': 'owner_name', '3': 12, '4': 1, '5': 9, '10': 'ownerName'},
    {
      '1': 'owner_email',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'ownerEmail',
      '17': true
    },
  ],
  '8': [
    {'1': '_motto'},
    {'1': '_phone'},
    {'1': '_email'},
    {'1': '_domain'},
    {'1': '_established'},
    {'1': '_owner_email'},
  ],
};

/// Descriptor for `CreateSchoolPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSchoolPayloadDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVTY2hvb2xQYXlsb2FkEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW'
    '1lEhkKBW1vdHRvGAMgASgJSABSBW1vdHRviAEBEhkKBXBob25lGAQgASgJSAFSBXBob25liAEB'
    'EhkKBWVtYWlsGAUgASgJSAJSBWVtYWlsiAEBEhYKBmNvdW50eRgGIAEoBVIGY291bnR5EhsKBm'
    'RvbWFpbhgHIAEoCUgDUgZkb21haW6IAQESJQoLZXN0YWJsaXNoZWQYCCABKAVIBFILZXN0YWJs'
    'aXNoZWSIAQESGQoIb3duZXJfaWQYCiABKAlSB293bmVySWQSHwoLb3duZXJfcGhvbmUYCyABKA'
    'lSCm93bmVyUGhvbmUSHQoKb3duZXJfbmFtZRgMIAEoCVIJb3duZXJOYW1lEiQKC293bmVyX2Vt'
    'YWlsGA0gASgJSAVSCm93bmVyRW1haWyIAQFCCAoGX21vdHRvQggKBl9waG9uZUIICgZfZW1haW'
    'xCCQoHX2RvbWFpbkIOCgxfZXN0YWJsaXNoZWRCDgoMX293bmVyX2VtYWls');

@$core.Deprecated('Use updateSchoolPayloadDescriptor instead')
const UpdateSchoolPayload$json = {
  '1': 'UpdateSchoolPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'motto', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'motto', '17': true},
    {'1': 'phone', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'phone', '17': true},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 3, '10': 'email', '17': true},
    {'1': 'county', '3': 6, '4': 1, '5': 5, '9': 4, '10': 'county', '17': true},
    {'1': 'domain', '3': 7, '4': 1, '5': 9, '9': 5, '10': 'domain', '17': true},
    {
      '1': 'established',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 6,
      '10': 'established',
      '17': true
    },
    {'1': 'status', '3': 9, '4': 1, '5': 5, '9': 7, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_motto'},
    {'1': '_phone'},
    {'1': '_email'},
    {'1': '_county'},
    {'1': '_domain'},
    {'1': '_established'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateSchoolPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSchoolPayloadDescriptor = $convert.base64Decode(
    'ChNVcGRhdGVTY2hvb2xQYXlsb2FkEg4KAmlkGAEgASgJUgJpZBIXCgRuYW1lGAIgASgJSABSBG'
    '5hbWWIAQESGQoFbW90dG8YAyABKAlIAVIFbW90dG+IAQESGQoFcGhvbmUYBCABKAlIAlIFcGhv'
    'bmWIAQESGQoFZW1haWwYBSABKAlIA1IFZW1haWyIAQESGwoGY291bnR5GAYgASgFSARSBmNvdW'
    '50eYgBARIbCgZkb21haW4YByABKAlIBVIGZG9tYWluiAEBEiUKC2VzdGFibGlzaGVkGAggASgF'
    'SAZSC2VzdGFibGlzaGVkiAEBEhsKBnN0YXR1cxgJIAEoBUgHUgZzdGF0dXOIAQFCBwoFX25hbW'
    'VCCAoGX21vdHRvQggKBl9waG9uZUIICgZfZW1haWxCCQoHX2NvdW50eUIJCgdfZG9tYWluQg4K'
    'DF9lc3RhYmxpc2hlZEIJCgdfc3RhdHVz');

@$core.Deprecated('Use deleteSchoolPayloadDescriptor instead')
const DeleteSchoolPayload$json = {
  '1': 'DeleteSchoolPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteSchoolPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSchoolPayloadDescriptor = $convert
    .base64Decode('ChNEZWxldGVTY2hvb2xQYXlsb2FkEg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use createTeacherPayloadDescriptor instead')
const CreateTeacherPayload$json = {
  '1': 'CreateTeacherPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'phone', '3': 3, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
    {'1': 'hired', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'hired', '17': true},
    {'1': 'role', '3': 7, '4': 1, '5': 9, '9': 2, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'department',
      '17': true
    },
  ],
  '8': [
    {'1': '_email'},
    {'1': '_hired'},
    {'1': '_role'},
    {'1': '_department'},
  ],
};

/// Descriptor for `CreateTeacherPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTeacherPayloadDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVUZWFjaGVyUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIXCgd1c2VyX2'
    'lkGAIgASgJUgZ1c2VySWQSFAoFcGhvbmUYAyABKAlSBXBob25lEhIKBG5hbWUYBCABKAlSBG5h'
    'bWUSGQoFZW1haWwYBSABKAlIAFIFZW1haWyIAQESGQoFaGlyZWQYBiABKAVIAVIFaGlyZWSIAQ'
    'ESFwoEcm9sZRgHIAEoCUgCUgRyb2xliAEBEiMKCmRlcGFydG1lbnQYCCABKAlIA1IKZGVwYXJ0'
    'bWVudIgBAUIICgZfZW1haWxCCAoGX2hpcmVkQgcKBV9yb2xlQg0KC19kZXBhcnRtZW50');

@$core.Deprecated('Use updateTeacherPayloadDescriptor instead')
const UpdateTeacherPayload$json = {
  '1': 'UpdateTeacherPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'hired', '3': 3, '4': 1, '5': 5, '9': 0, '10': 'hired', '17': true},
    {'1': 'role', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'department',
      '17': true
    },
    {'1': 'status', '3': 6, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_hired'},
    {'1': '_role'},
    {'1': '_department'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateTeacherPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTeacherPayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVUZWFjaGVyUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR1c2VyGA'
    'IgASgJUgR1c2VyEhkKBWhpcmVkGAMgASgFSABSBWhpcmVkiAEBEhcKBHJvbGUYBCABKAlIAVIE'
    'cm9sZYgBARIjCgpkZXBhcnRtZW50GAUgASgJSAJSCmRlcGFydG1lbnSIAQESGwoGc3RhdHVzGA'
    'YgASgFSANSBnN0YXR1c4gBAUIICgZfaGlyZWRCBwoFX3JvbGVCDQoLX2RlcGFydG1lbnRCCQoH'
    'X3N0YXR1cw==');

@$core.Deprecated('Use deleteTeacherPayloadDescriptor instead')
const DeleteTeacherPayload$json = {
  '1': 'DeleteTeacherPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
  ],
};

/// Descriptor for `DeleteTeacherPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTeacherPayloadDescriptor = $convert.base64Decode(
    'ChREZWxldGVUZWFjaGVyUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR1c2VyGA'
    'IgASgJUgR1c2Vy');

@$core.Deprecated('Use createStaffPayloadDescriptor instead')
const CreateStaffPayload$json = {
  '1': 'CreateStaffPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'phone', '3': 3, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
    {
      '1': 'idnumber',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'idnumber',
      '17': true
    },
    {'1': 'role', '3': 7, '4': 1, '5': 9, '9': 2, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'department',
      '17': true
    },
  ],
  '8': [
    {'1': '_email'},
    {'1': '_idnumber'},
    {'1': '_role'},
    {'1': '_department'},
  ],
};

/// Descriptor for `CreateStaffPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createStaffPayloadDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVTdGFmZlBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSFwoHdXNlcl9pZB'
    'gCIAEoCVIGdXNlcklkEhQKBXBob25lGAMgASgJUgVwaG9uZRISCgRuYW1lGAQgASgJUgRuYW1l'
    'EhkKBWVtYWlsGAUgASgJSABSBWVtYWlsiAEBEh8KCGlkbnVtYmVyGAYgASgJSAFSCGlkbnVtYm'
    'VyiAEBEhcKBHJvbGUYByABKAlIAlIEcm9sZYgBARIjCgpkZXBhcnRtZW50GAggASgJSANSCmRl'
    'cGFydG1lbnSIAQFCCAoGX2VtYWlsQgsKCV9pZG51bWJlckIHCgVfcm9sZUINCgtfZGVwYXJ0bW'
    'VudA==');

@$core.Deprecated('Use updateStaffPayloadDescriptor instead')
const UpdateStaffPayload$json = {
  '1': 'UpdateStaffPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {
      '1': 'idnumber',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'idnumber',
      '17': true
    },
    {'1': 'role', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'department',
      '17': true
    },
    {'1': 'status', '3': 6, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_idnumber'},
    {'1': '_role'},
    {'1': '_department'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateStaffPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateStaffPayloadDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVTdGFmZlBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEdXNlchgCIA'
    'EoCVIEdXNlchIfCghpZG51bWJlchgDIAEoCUgAUghpZG51bWJlcogBARIXCgRyb2xlGAQgASgJ'
    'SAFSBHJvbGWIAQESIwoKZGVwYXJ0bWVudBgFIAEoCUgCUgpkZXBhcnRtZW50iAEBEhsKBnN0YX'
    'R1cxgGIAEoBUgDUgZzdGF0dXOIAQFCCwoJX2lkbnVtYmVyQgcKBV9yb2xlQg0KC19kZXBhcnRt'
    'ZW50QgkKB19zdGF0dXM=');

@$core.Deprecated('Use deleteStaffPayloadDescriptor instead')
const DeleteStaffPayload$json = {
  '1': 'DeleteStaffPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
  ],
};

/// Descriptor for `DeleteStaffPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteStaffPayloadDescriptor = $convert.base64Decode(
    'ChJEZWxldGVTdGFmZlBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEdXNlchgCIA'
    'EoCVIEdXNlcg==');

@$core.Deprecated('Use createOwnerPayloadDescriptor instead')
const CreateOwnerPayload$json = {
  '1': 'CreateOwnerPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'phone', '3': 3, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
  ],
  '8': [
    {'1': '_email'},
  ],
};

/// Descriptor for `CreateOwnerPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createOwnerPayloadDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVPd25lclBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSFwoHdXNlcl9pZB'
    'gCIAEoCVIGdXNlcklkEhQKBXBob25lGAMgASgJUgVwaG9uZRISCgRuYW1lGAQgASgJUgRuYW1l'
    'EhkKBWVtYWlsGAUgASgJSABSBWVtYWlsiAEBQggKBl9lbWFpbA==');

@$core.Deprecated('Use deleteOwnerPayloadDescriptor instead')
const DeleteOwnerPayload$json = {
  '1': 'DeleteOwnerPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
  ],
};

/// Descriptor for `DeleteOwnerPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteOwnerPayloadDescriptor = $convert.base64Decode(
    'ChJEZWxldGVPd25lclBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEdXNlchgCIA'
    'EoCVIEdXNlcg==');

@$core.Deprecated('Use createStudentPayloadDescriptor instead')
const CreateStudentPayload$json = {
  '1': 'CreateStudentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'adm', '3': 2, '4': 1, '5': 5, '10': 'adm'},
    {'1': 'user', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'user', '17': true},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'dob', '3': 5, '4': 1, '5': 5, '9': 1, '10': 'dob', '17': true},
    {'1': 'gender', '3': 6, '4': 1, '5': 5, '9': 2, '10': 'gender', '17': true},
    {
      '1': 'documents',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'documents',
      '17': true
    },
    {
      '1': 'admitted',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'admitted',
      '17': true
    },
  ],
  '8': [
    {'1': '_user'},
    {'1': '_dob'},
    {'1': '_gender'},
    {'1': '_documents'},
    {'1': '_admitted'},
  ],
};

/// Descriptor for `CreateStudentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createStudentPayloadDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVTdHVkZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIQCgNhZG0YAi'
    'ABKAVSA2FkbRIXCgR1c2VyGAMgASgJSABSBHVzZXKIAQESEgoEbmFtZRgEIAEoCVIEbmFtZRIV'
    'CgNkb2IYBSABKAVIAVIDZG9iiAEBEhsKBmdlbmRlchgGIAEoBUgCUgZnZW5kZXKIAQESIQoJZG'
    '9jdW1lbnRzGAcgASgJSANSCWRvY3VtZW50c4gBARIfCghhZG1pdHRlZBgIIAEoBUgEUghhZG1p'
    'dHRlZIgBAUIHCgVfdXNlckIGCgRfZG9iQgkKB19nZW5kZXJCDAoKX2RvY3VtZW50c0ILCglfYW'
    'RtaXR0ZWQ=');

@$core.Deprecated('Use updateStudentPayloadDescriptor instead')
const UpdateStudentPayload$json = {
  '1': 'UpdateStudentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'adm', '3': 2, '4': 1, '5': 5, '10': 'adm'},
    {'1': 'user', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'user', '17': true},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'name', '17': true},
    {'1': 'dob', '3': 5, '4': 1, '5': 5, '9': 2, '10': 'dob', '17': true},
    {'1': 'gender', '3': 6, '4': 1, '5': 5, '9': 3, '10': 'gender', '17': true},
    {
      '1': 'documents',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'documents',
      '17': true
    },
    {
      '1': 'admitted',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'admitted',
      '17': true
    },
    {'1': 'status', '3': 9, '4': 1, '5': 5, '9': 6, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_user'},
    {'1': '_name'},
    {'1': '_dob'},
    {'1': '_gender'},
    {'1': '_documents'},
    {'1': '_admitted'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateStudentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateStudentPayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVTdHVkZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIQCgNhZG0YAi'
    'ABKAVSA2FkbRIXCgR1c2VyGAMgASgJSABSBHVzZXKIAQESFwoEbmFtZRgEIAEoCUgBUgRuYW1l'
    'iAEBEhUKA2RvYhgFIAEoBUgCUgNkb2KIAQESGwoGZ2VuZGVyGAYgASgFSANSBmdlbmRlcogBAR'
    'IhCglkb2N1bWVudHMYByABKAlIBFIJZG9jdW1lbnRziAEBEh8KCGFkbWl0dGVkGAggASgFSAVS'
    'CGFkbWl0dGVkiAEBEhsKBnN0YXR1cxgJIAEoBUgGUgZzdGF0dXOIAQFCBwoFX3VzZXJCBwoFX2'
    '5hbWVCBgoEX2RvYkIJCgdfZ2VuZGVyQgwKCl9kb2N1bWVudHNCCwoJX2FkbWl0dGVkQgkKB19z'
    'dGF0dXM=');

@$core.Deprecated('Use deleteStudentPayloadDescriptor instead')
const DeleteStudentPayload$json = {
  '1': 'DeleteStudentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'adm', '3': 2, '4': 1, '5': 5, '10': 'adm'},
  ],
};

/// Descriptor for `DeleteStudentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteStudentPayloadDescriptor = $convert.base64Decode(
    'ChREZWxldGVTdHVkZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIQCgNhZG0YAi'
    'ABKAVSA2FkbQ==');

@$core.Deprecated('Use enrollStudentPayloadDescriptor instead')
const EnrollStudentPayload$json = {
  '1': 'EnrollStudentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'student', '3': 6, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `EnrollStudentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enrollStudentPayloadDescriptor = $convert.base64Decode(
    'ChRFbnJvbGxTdHVkZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZWFyGA'
    'IgASgFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0SFAoFZ3JhZGUYBCABKAVSBWdyYWRlEhYK'
    'BnN0cmVhbRgFIAEoBVIGc3RyZWFtEhgKB3N0dWRlbnQYBiABKAVSB3N0dWRlbnQ=');

@$core.Deprecated('Use unenrollStudentPayloadDescriptor instead')
const UnenrollStudentPayload$json = {
  '1': 'UnenrollStudentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'student', '3': 6, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `UnenrollStudentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unenrollStudentPayloadDescriptor = $convert.base64Decode(
    'ChZVbmVucm9sbFN0dWRlbnRQYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYX'
    'IYAiABKAVSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUS'
    'FgoGc3RyZWFtGAUgASgFUgZzdHJlYW0SGAoHc3R1ZGVudBgGIAEoBVIHc3R1ZGVudA==');

@$core.Deprecated('Use createGuardianPayloadDescriptor instead')
const CreateGuardianPayload$json = {
  '1': 'CreateGuardianPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'phone', '3': 3, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
    {'1': 'student', '3': 6, '4': 1, '5': 5, '10': 'student'},
    {'1': 'relationship', '3': 7, '4': 1, '5': 5, '10': 'relationship'},
    {'1': 'role', '3': 8, '4': 1, '5': 5, '10': 'role'},
  ],
  '8': [
    {'1': '_email'},
  ],
};

/// Descriptor for `CreateGuardianPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createGuardianPayloadDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVHdWFyZGlhblBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSFwoHdXNlcl'
    '9pZBgCIAEoCVIGdXNlcklkEhQKBXBob25lGAMgASgJUgVwaG9uZRISCgRuYW1lGAQgASgJUgRu'
    'YW1lEhkKBWVtYWlsGAUgASgJSABSBWVtYWlsiAEBEhgKB3N0dWRlbnQYBiABKAVSB3N0dWRlbn'
    'QSIgoMcmVsYXRpb25zaGlwGAcgASgFUgxyZWxhdGlvbnNoaXASEgoEcm9sZRgIIAEoBVIEcm9s'
    'ZUIICgZfZW1haWw=');

@$core.Deprecated('Use updateGuardianPayloadDescriptor instead')
const UpdateGuardianPayload$json = {
  '1': 'UpdateGuardianPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
    {
      '1': 'relationship',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'relationship',
      '17': true
    },
    {'1': 'role', '3': 5, '4': 1, '5': 5, '9': 1, '10': 'role', '17': true},
  ],
  '8': [
    {'1': '_relationship'},
    {'1': '_role'},
  ],
};

/// Descriptor for `UpdateGuardianPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateGuardianPayloadDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVHdWFyZGlhblBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEdXNlch'
    'gCIAEoCVIEdXNlchIYCgdzdHVkZW50GAMgASgFUgdzdHVkZW50EicKDHJlbGF0aW9uc2hpcBgE'
    'IAEoBUgAUgxyZWxhdGlvbnNoaXCIAQESFwoEcm9sZRgFIAEoBUgBUgRyb2xliAEBQg8KDV9yZW'
    'xhdGlvbnNoaXBCBwoFX3JvbGU=');

@$core.Deprecated('Use deleteGuardianPayloadDescriptor instead')
const DeleteGuardianPayload$json = {
  '1': 'DeleteGuardianPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `DeleteGuardianPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteGuardianPayloadDescriptor = $convert.base64Decode(
    'ChVEZWxldGVHdWFyZGlhblBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEdXNlch'
    'gCIAEoCVIEdXNlchIYCgdzdHVkZW50GAMgASgFUgdzdHVkZW50');

@$core.Deprecated('Use createDepartmentPayloadDescriptor instead')
const CreateDepartmentPayload$json = {
  '1': 'CreateDepartmentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'description',
      '17': true
    },
  ],
  '8': [
    {'1': '_description'},
  ],
};

/// Descriptor for `CreateDepartmentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createDepartmentPayloadDescriptor = $convert.base64Decode(
    'ChdDcmVhdGVEZXBhcnRtZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRuYW'
    '1lGAIgASgJUgRuYW1lEiUKC2Rlc2NyaXB0aW9uGAMgASgJSABSC2Rlc2NyaXB0aW9uiAEBQg4K'
    'DF9kZXNjcmlwdGlvbg==');

@$core.Deprecated('Use updateDepartmentPayloadDescriptor instead')
const UpdateDepartmentPayload$json = {
  '1': 'UpdateDepartmentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'description',
      '17': true
    },
  ],
  '8': [
    {'1': '_description'},
  ],
};

/// Descriptor for `UpdateDepartmentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDepartmentPayloadDescriptor = $convert.base64Decode(
    'ChdVcGRhdGVEZXBhcnRtZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRuYW'
    '1lGAIgASgJUgRuYW1lEiUKC2Rlc2NyaXB0aW9uGAMgASgJSABSC2Rlc2NyaXB0aW9uiAEBQg4K'
    'DF9kZXNjcmlwdGlvbg==');

@$core.Deprecated('Use deleteDepartmentPayloadDescriptor instead')
const DeleteDepartmentPayload$json = {
  '1': 'DeleteDepartmentPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `DeleteDepartmentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteDepartmentPayloadDescriptor =
    $convert.base64Decode(
        'ChdEZWxldGVEZXBhcnRtZW50UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRuYW'
        '1lGAIgASgJUgRuYW1l');

@$core.Deprecated('Use createTermPayloadDescriptor instead')
const CreateTermPayload$json = {
  '1': 'CreateTermPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 5, '4': 1, '5': 3, '10': 'end'},
  ],
};

/// Descriptor for `CreateTermPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTermPayloadDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVUZXJtUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZWFyGAIgAS'
    'gFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0SFAoFc3RhcnQYBCABKANSBXN0YXJ0EhAKA2Vu'
    'ZBgFIAEoA1IDZW5k');

@$core.Deprecated('Use updateTermPayloadDescriptor instead')
const UpdateTermPayload$json = {
  '1': 'UpdateTermPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '9': 0, '10': 'start', '17': true},
    {'1': 'end', '3': 5, '4': 1, '5': 3, '9': 1, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_start'},
    {'1': '_end'},
  ],
};

/// Descriptor for `UpdateTermPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTermPayloadDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVUZXJtUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZWFyGAIgAS'
    'gFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0SGQoFc3RhcnQYBCABKANIAFIFc3RhcnSIAQES'
    'FQoDZW5kGAUgASgDSAFSA2VuZIgBAUIICgZfc3RhcnRCBgoEX2VuZA==');

@$core.Deprecated('Use deleteTermPayloadDescriptor instead')
const DeleteTermPayload$json = {
  '1': 'DeleteTermPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
  ],
};

/// Descriptor for `DeleteTermPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTermPayloadDescriptor = $convert.base64Decode(
    'ChFEZWxldGVUZXJtUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZWFyGAIgAS'
    'gFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0=');

@$core.Deprecated('Use assignClassTeacherPayloadDescriptor instead')
const AssignClassTeacherPayload$json = {
  '1': 'AssignClassTeacherPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'teacher', '3': 6, '4': 1, '5': 9, '10': 'teacher'},
    {'1': 'start', '3': 7, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 8, '4': 1, '5': 5, '9': 0, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_end'},
  ],
};

/// Descriptor for `AssignClassTeacherPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignClassTeacherPayloadDescriptor = $convert.base64Decode(
    'ChlBc3NpZ25DbGFzc1RlYWNoZXJQYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBH'
    'llYXIYAiABKAVSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3Jh'
    'ZGUSFgoGc3RyZWFtGAUgASgFUgZzdHJlYW0SGAoHdGVhY2hlchgGIAEoCVIHdGVhY2hlchIUCg'
    'VzdGFydBgHIAEoBVIFc3RhcnQSFQoDZW5kGAggASgFSABSA2VuZIgBAUIGCgRfZW5k');

@$core.Deprecated('Use unassignClassTeacherPayloadDescriptor instead')
const UnassignClassTeacherPayload$json = {
  '1': 'UnassignClassTeacherPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'teacher', '3': 6, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `UnassignClassTeacherPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unassignClassTeacherPayloadDescriptor = $convert.base64Decode(
    'ChtVbmFzc2lnbkNsYXNzVGVhY2hlclBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEg'
    'oEeWVhchgCIAEoBVIEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVn'
    'cmFkZRIWCgZzdHJlYW0YBSABKAVSBnN0cmVhbRIYCgd0ZWFjaGVyGAYgASgJUgd0ZWFjaGVy');

@$core.Deprecated('Use assignSubjectPayloadDescriptor instead')
const AssignSubjectPayload$json = {
  '1': 'AssignSubjectPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 7, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `AssignSubjectPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignSubjectPayloadDescriptor = $convert.base64Decode(
    'ChRBc3NpZ25TdWJqZWN0UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZWFyGA'
    'IgASgFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0SFAoFZ3JhZGUYBCABKAVSBWdyYWRlEhYK'
    'BnN0cmVhbRgFIAEoBVIGc3RyZWFtEhgKB3N1YmplY3QYBiABKAVSB3N1YmplY3QSGAoHdGVhY2'
    'hlchgHIAEoCVIHdGVhY2hlcg==');

@$core.Deprecated('Use unassignSubjectPayloadDescriptor instead')
const UnassignSubjectPayload$json = {
  '1': 'UnassignSubjectPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
  ],
};

/// Descriptor for `UnassignSubjectPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unassignSubjectPayloadDescriptor = $convert.base64Decode(
    'ChZVbmFzc2lnblN1YmplY3RQYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYX'
    'IYAiABKAVSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUS'
    'FgoGc3RyZWFtGAUgASgFUgZzdHJlYW0SGAoHc3ViamVjdBgGIAEoBVIHc3ViamVjdA==');

@$core.Deprecated('Use createTimetableEntryPayloadDescriptor instead')
const CreateTimetableEntryPayload$json = {
  '1': 'CreateTimetableEntryPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 7, '4': 1, '5': 9, '10': 'teacher'},
    {'1': 'day', '3': 8, '4': 1, '5': 5, '10': 'day'},
    {'1': 'start', '3': 9, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 10, '4': 1, '5': 5, '10': 'end'},
  ],
};

/// Descriptor for `CreateTimetableEntryPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTimetableEntryPayloadDescriptor = $convert.base64Decode(
    'ChtDcmVhdGVUaW1ldGFibGVFbnRyeVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEg'
    'oEeWVhchgCIAEoBVIEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVn'
    'cmFkZRIWCgZzdHJlYW0YBSABKAVSBnN0cmVhbRIYCgdzdWJqZWN0GAYgASgFUgdzdWJqZWN0Eh'
    'gKB3RlYWNoZXIYByABKAlSB3RlYWNoZXISEAoDZGF5GAggASgFUgNkYXkSFAoFc3RhcnQYCSAB'
    'KAVSBXN0YXJ0EhAKA2VuZBgKIAEoBVIDZW5k');

@$core.Deprecated('Use updateTimetableEntryPayloadDescriptor instead')
const UpdateTimetableEntryPayload$json = {
  '1': 'UpdateTimetableEntryPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'day', '3': 7, '4': 1, '5': 5, '10': 'day'},
    {'1': 'start', '3': 8, '4': 1, '5': 5, '10': 'start'},
    {
      '1': 'teacher',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'teacher',
      '17': true
    },
    {'1': 'end', '3': 10, '4': 1, '5': 5, '9': 1, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_teacher'},
    {'1': '_end'},
  ],
};

/// Descriptor for `UpdateTimetableEntryPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTimetableEntryPayloadDescriptor = $convert.base64Decode(
    'ChtVcGRhdGVUaW1ldGFibGVFbnRyeVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEg'
    'oEeWVhchgCIAEoBVIEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVn'
    'cmFkZRIWCgZzdHJlYW0YBSABKAVSBnN0cmVhbRIYCgdzdWJqZWN0GAYgASgFUgdzdWJqZWN0Eh'
    'AKA2RheRgHIAEoBVIDZGF5EhQKBXN0YXJ0GAggASgFUgVzdGFydBIdCgd0ZWFjaGVyGAkgASgJ'
    'SABSB3RlYWNoZXKIAQESFQoDZW5kGAogASgFSAFSA2VuZIgBAUIKCghfdGVhY2hlckIGCgRfZW'
    '5k');

@$core.Deprecated('Use deleteTimetableEntryPayloadDescriptor instead')
const DeleteTimetableEntryPayload$json = {
  '1': 'DeleteTimetableEntryPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'day', '3': 7, '4': 1, '5': 5, '10': 'day'},
    {'1': 'start', '3': 8, '4': 1, '5': 5, '10': 'start'},
  ],
};

/// Descriptor for `DeleteTimetableEntryPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTimetableEntryPayloadDescriptor = $convert.base64Decode(
    'ChtEZWxldGVUaW1ldGFibGVFbnRyeVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEg'
    'oEeWVhchgCIAEoBVIEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVn'
    'cmFkZRIWCgZzdHJlYW0YBSABKAVSBnN0cmVhbRIYCgdzdWJqZWN0GAYgASgFUgdzdWJqZWN0Eh'
    'AKA2RheRgHIAEoBVIDZGF5EhQKBXN0YXJ0GAggASgFUgVzdGFydA==');

@$core.Deprecated('Use attendanceRecordDescriptor instead')
const AttendanceRecord$json = {
  '1': 'AttendanceRecord',
  '2': [
    {'1': 'student', '3': 1, '4': 1, '5': 5, '10': 'student'},
    {'1': 'status', '3': 2, '4': 1, '5': 5, '10': 'status'},
  ],
};

/// Descriptor for `AttendanceRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attendanceRecordDescriptor = $convert.base64Decode(
    'ChBBdHRlbmRhbmNlUmVjb3JkEhgKB3N0dWRlbnQYASABKAVSB3N0dWRlbnQSFgoGc3RhdHVzGA'
    'IgASgFUgZzdGF0dXM=');

@$core.Deprecated('Use markAttendancePayloadDescriptor instead')
const MarkAttendancePayload$json = {
  '1': 'MarkAttendancePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'date', '3': 6, '4': 1, '5': 5, '10': 'date'},
    {
      '1': 'records',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.sync.AttendanceRecord',
      '10': 'records'
    },
  ],
};

/// Descriptor for `MarkAttendancePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markAttendancePayloadDescriptor = $convert.base64Decode(
    'ChVNYXJrQXR0ZW5kYW5jZVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEeWVhch'
    'gCIAEoBVIEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVncmFkZRIW'
    'CgZzdHJlYW0YBSABKAVSBnN0cmVhbRISCgRkYXRlGAYgASgFUgRkYXRlEjAKB3JlY29yZHMYBy'
    'ADKAsyFi5zeW5jLkF0dGVuZGFuY2VSZWNvcmRSB3JlY29yZHM=');

@$core.Deprecated('Use deleteAttendancePayloadDescriptor instead')
const DeleteAttendancePayload$json = {
  '1': 'DeleteAttendancePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'student', '3': 6, '4': 1, '5': 5, '10': 'student'},
    {'1': 'date', '3': 7, '4': 1, '5': 5, '10': 'date'},
  ],
};

/// Descriptor for `DeleteAttendancePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAttendancePayloadDescriptor = $convert.base64Decode(
    'ChdEZWxldGVBdHRlbmRhbmNlUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZW'
    'FyGAIgASgFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0SFAoFZ3JhZGUYBCABKAVSBWdyYWRl'
    'EhYKBnN0cmVhbRgFIAEoBVIGc3RyZWFtEhgKB3N0dWRlbnQYBiABKAVSB3N0dWRlbnQSEgoEZG'
    'F0ZRgHIAEoBVIEZGF0ZQ==');

@$core.Deprecated('Use createLessonPayloadDescriptor instead')
const CreateLessonPayload$json = {
  '1': 'CreateLessonPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'date', '3': 6, '4': 1, '5': 5, '10': 'date'},
    {'1': 'subject', '3': 7, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 8, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `CreateLessonPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createLessonPayloadDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVMZXNzb25QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYXIYAi'
    'ABKAVSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUSFgoG'
    'c3RyZWFtGAUgASgFUgZzdHJlYW0SEgoEZGF0ZRgGIAEoBVIEZGF0ZRIYCgdzdWJqZWN0GAcgAS'
    'gFUgdzdWJqZWN0EhgKB3RlYWNoZXIYCCABKAlSB3RlYWNoZXI=');

@$core.Deprecated('Use deleteLessonPayloadDescriptor instead')
const DeleteLessonPayload$json = {
  '1': 'DeleteLessonPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'date', '3': 6, '4': 1, '5': 5, '10': 'date'},
    {'1': 'subject', '3': 7, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 8, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `DeleteLessonPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteLessonPayloadDescriptor = $convert.base64Decode(
    'ChNEZWxldGVMZXNzb25QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYXIYAi'
    'ABKAVSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUSFgoG'
    'c3RyZWFtGAUgASgFUgZzdHJlYW0SEgoEZGF0ZRgGIAEoBVIEZGF0ZRIYCgdzdWJqZWN0GAcgAS'
    'gFUgdzdWJqZWN0EhgKB3RlYWNoZXIYCCABKAlSB3RlYWNoZXI=');

@$core.Deprecated('Use examGradeEntryDescriptor instead')
const ExamGradeEntry$json = {
  '1': 'ExamGradeEntry',
  '2': [
    {'1': 'grade', '3': 1, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 2, '4': 1, '5': 5, '10': 'stream'},
  ],
};

/// Descriptor for `ExamGradeEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List examGradeEntryDescriptor = $convert.base64Decode(
    'Cg5FeGFtR3JhZGVFbnRyeRIUCgVncmFkZRgBIAEoBVIFZ3JhZGUSFgoGc3RyZWFtGAIgASgFUg'
    'ZzdHJlYW0=');

@$core.Deprecated('Use createExamPayloadDescriptor instead')
const CreateExamPayload$json = {
  '1': 'CreateExamPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'year', '3': 4, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 5, '4': 1, '5': 5, '10': 'term'},
    {'1': 'personalized', '3': 6, '4': 1, '5': 8, '10': 'personalized'},
    {'1': 'type', '3': 7, '4': 1, '5': 5, '10': 'type'},
    {'1': 'start', '3': 8, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 9, '4': 1, '5': 5, '10': 'end'},
    {'1': 'teacher', '3': 10, '4': 1, '5': 9, '10': 'teacher'},
    {
      '1': 'grades',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.sync.ExamGradeEntry',
      '10': 'grades'
    },
  ],
};

/// Descriptor for `CreateExamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExamPayloadDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVFeGFtUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSFgoGc2Nob29sGAIgASgJUgZzY2'
    'hvb2wSEgoEbmFtZRgDIAEoCVIEbmFtZRISCgR5ZWFyGAQgASgFUgR5ZWFyEhIKBHRlcm0YBSAB'
    'KAVSBHRlcm0SIgoMcGVyc29uYWxpemVkGAYgASgIUgxwZXJzb25hbGl6ZWQSEgoEdHlwZRgHIA'
    'EoBVIEdHlwZRIUCgVzdGFydBgIIAEoBVIFc3RhcnQSEAoDZW5kGAkgASgFUgNlbmQSGAoHdGVh'
    'Y2hlchgKIAEoCVIHdGVhY2hlchIsCgZncmFkZXMYCyADKAsyFC5zeW5jLkV4YW1HcmFkZUVudH'
    'J5UgZncmFkZXM=');

@$core.Deprecated('Use updateExamPayloadDescriptor instead')
const UpdateExamPayload$json = {
  '1': 'UpdateExamPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'personalized',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'personalized',
      '17': true
    },
    {'1': 'type', '3': 4, '4': 1, '5': 5, '9': 2, '10': 'type', '17': true},
    {'1': 'start', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'start', '17': true},
    {'1': 'end', '3': 6, '4': 1, '5': 5, '9': 4, '10': 'end', '17': true},
    {
      '1': 'teacher',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'teacher',
      '17': true
    },
  ],
  '8': [
    {'1': '_name'},
    {'1': '_personalized'},
    {'1': '_type'},
    {'1': '_start'},
    {'1': '_end'},
    {'1': '_teacher'},
  ],
};

/// Descriptor for `UpdateExamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateExamPayloadDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVFeGFtUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSFwoEbmFtZRgCIAEoCUgAUgRuYW'
    '1liAEBEicKDHBlcnNvbmFsaXplZBgDIAEoCEgBUgxwZXJzb25hbGl6ZWSIAQESFwoEdHlwZRgE'
    'IAEoBUgCUgR0eXBliAEBEhkKBXN0YXJ0GAUgASgFSANSBXN0YXJ0iAEBEhUKA2VuZBgGIAEoBU'
    'gEUgNlbmSIAQESHQoHdGVhY2hlchgHIAEoCUgFUgd0ZWFjaGVyiAEBQgcKBV9uYW1lQg8KDV9w'
    'ZXJzb25hbGl6ZWRCBwoFX3R5cGVCCAoGX3N0YXJ0QgYKBF9lbmRCCgoIX3RlYWNoZXI=');

@$core.Deprecated('Use deleteExamPayloadDescriptor instead')
const DeleteExamPayload$json = {
  '1': 'DeleteExamPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteExamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteExamPayloadDescriptor =
    $convert.base64Decode('ChFEZWxldGVFeGFtUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use createPaperPayloadDescriptor instead')
const CreatePaperPayload$json = {
  '1': 'CreatePaperPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'invigilator', '3': 5, '4': 1, '5': 9, '10': 'invigilator'},
    {'1': 'start', '3': 6, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 7, '4': 1, '5': 3, '10': 'end'},
    {'1': 'topic', '3': 8, '4': 1, '5': 5, '9': 1, '10': 'topic', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_topic'},
  ],
};

/// Descriptor for `CreatePaperPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPaperPayloadDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVQYXBlclBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZXhhbRgCIA'
    'EoCVIEZXhhbRIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhkKBXBhcGVyGAQgASgFSABSBXBh'
    'cGVyiAEBEiAKC2ludmlnaWxhdG9yGAUgASgJUgtpbnZpZ2lsYXRvchIUCgVzdGFydBgGIAEoA1'
    'IFc3RhcnQSEAoDZW5kGAcgASgDUgNlbmQSGQoFdG9waWMYCCABKAVIAVIFdG9waWOIAQFCCAoG'
    'X3BhcGVyQggKBl90b3BpYw==');

@$core.Deprecated('Use updatePaperPayloadDescriptor instead')
const UpdatePaperPayload$json = {
  '1': 'UpdatePaperPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {
      '1': 'invigilator',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'invigilator',
      '17': true
    },
    {'1': 'start', '3': 6, '4': 1, '5': 3, '9': 2, '10': 'start', '17': true},
    {'1': 'end', '3': 7, '4': 1, '5': 3, '9': 3, '10': 'end', '17': true},
    {'1': 'status', '3': 8, '4': 1, '5': 5, '9': 4, '10': 'status', '17': true},
    {'1': 'topic', '3': 9, '4': 1, '5': 5, '9': 5, '10': 'topic', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_invigilator'},
    {'1': '_start'},
    {'1': '_end'},
    {'1': '_status'},
    {'1': '_topic'},
  ],
};

/// Descriptor for `UpdatePaperPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePaperPayloadDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVQYXBlclBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZXhhbRgCIA'
    'EoCVIEZXhhbRIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhkKBXBhcGVyGAQgASgFSABSBXBh'
    'cGVyiAEBEiUKC2ludmlnaWxhdG9yGAUgASgJSAFSC2ludmlnaWxhdG9yiAEBEhkKBXN0YXJ0GA'
    'YgASgDSAJSBXN0YXJ0iAEBEhUKA2VuZBgHIAEoA0gDUgNlbmSIAQESGwoGc3RhdHVzGAggASgF'
    'SARSBnN0YXR1c4gBARIZCgV0b3BpYxgJIAEoBUgFUgV0b3BpY4gBAUIICgZfcGFwZXJCDgoMX2'
    'ludmlnaWxhdG9yQggKBl9zdGFydEIGCgRfZW5kQgkKB19zdGF0dXNCCAoGX3RvcGlj');

@$core.Deprecated('Use deletePaperPayloadDescriptor instead')
const DeletePaperPayload$json = {
  '1': 'DeletePaperPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
  ],
  '8': [
    {'1': '_paper'},
  ],
};

/// Descriptor for `DeletePaperPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePaperPayloadDescriptor = $convert.base64Decode(
    'ChJEZWxldGVQYXBlclBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZXhhbRgCIA'
    'EoCVIEZXhhbRIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhkKBXBhcGVyGAQgASgFSABSBXBh'
    'cGVyiAEBQggKBl9wYXBlcg==');

@$core.Deprecated('Use gradeRecordDescriptor instead')
const GradeRecord$json = {
  '1': 'GradeRecord',
  '2': [
    {'1': 'student', '3': 1, '4': 1, '5': 5, '10': 'student'},
    {'1': 'score', '3': 2, '4': 1, '5': 2, '10': 'score'},
    {'1': 'total', '3': 3, '4': 1, '5': 5, '10': 'total'},
  ],
};

/// Descriptor for `GradeRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gradeRecordDescriptor = $convert.base64Decode(
    'CgtHcmFkZVJlY29yZBIYCgdzdHVkZW50GAEgASgFUgdzdHVkZW50EhQKBXNjb3JlGAIgASgCUg'
    'VzY29yZRIUCgV0b3RhbBgDIAEoBVIFdG90YWw=');

@$core.Deprecated('Use markGradesPayloadDescriptor instead')
const MarkGradesPayload$json = {
  '1': 'MarkGradesPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {
      '1': 'records',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.sync.GradeRecord',
      '10': 'records'
    },
  ],
  '8': [
    {'1': '_paper'},
  ],
};

/// Descriptor for `MarkGradesPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markGradesPayloadDescriptor = $convert.base64Decode(
    'ChFNYXJrR3JhZGVzUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGAIgAS'
    'gJUgRleGFtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCABKAVIAFIFcGFw'
    'ZXKIAQESKwoHcmVjb3JkcxgFIAMoCzIRLnN5bmMuR3JhZGVSZWNvcmRSB3JlY29yZHNCCAoGX3'
    'BhcGVy');

@$core.Deprecated('Use updateGradePayloadDescriptor instead')
const UpdateGradePayload$json = {
  '1': 'UpdateGradePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
    {'1': 'subject', '3': 4, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'score', '3': 6, '4': 1, '5': 2, '9': 1, '10': 'score', '17': true},
    {'1': 'total', '3': 7, '4': 1, '5': 5, '9': 2, '10': 'total', '17': true},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_score'},
    {'1': '_total'},
  ],
};

/// Descriptor for `UpdateGradePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateGradePayloadDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVHcmFkZVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZXhhbRgCIA'
    'EoCVIEZXhhbRIYCgdzdHVkZW50GAMgASgFUgdzdHVkZW50EhgKB3N1YmplY3QYBCABKAVSB3N1'
    'YmplY3QSGQoFcGFwZXIYBSABKAVIAFIFcGFwZXKIAQESGQoFc2NvcmUYBiABKAJIAVIFc2Nvcm'
    'WIAQESGQoFdG90YWwYByABKAVIAlIFdG90YWyIAQFCCAoGX3BhcGVyQggKBl9zY29yZUIICgZf'
    'dG90YWw=');

@$core.Deprecated('Use deleteGradePayloadDescriptor instead')
const DeleteGradePayload$json = {
  '1': 'DeleteGradePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
    {'1': 'subject', '3': 4, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
  ],
  '8': [
    {'1': '_paper'},
  ],
};

/// Descriptor for `DeleteGradePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteGradePayloadDescriptor = $convert.base64Decode(
    'ChJEZWxldGVHcmFkZVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEZXhhbRgCIA'
    'EoCVIEZXhhbRIYCgdzdHVkZW50GAMgASgFUgdzdHVkZW50EhgKB3N1YmplY3QYBCABKAVSB3N1'
    'YmplY3QSGQoFcGFwZXIYBSABKAVIAFIFcGFwZXKIAQFCCAoGX3BhcGVy');

@$core.Deprecated('Use updateMasteryPayloadDescriptor instead')
const UpdateMasteryPayload$json = {
  '1': 'UpdateMasteryPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'student', '3': 2, '4': 1, '5': 5, '10': 'student'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'topic', '3': 4, '4': 1, '5': 5, '10': 'topic'},
    {'1': 'score', '3': 5, '4': 1, '5': 2, '10': 'score'},
  ],
};

/// Descriptor for `UpdateMasteryPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateMasteryPayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVNYXN0ZXJ5UGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIYCgdzdHVkZW'
    '50GAIgASgFUgdzdHVkZW50EhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSFAoFdG9waWMYBCAB'
    'KAVSBXRvcGljEhQKBXNjb3JlGAUgASgCUgVzY29yZQ==');

@$core.Deprecated('Use createFeePayloadDescriptor instead')
const CreateFeePayload$json = {
  '1': 'CreateFeePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'title', '3': 6, '4': 1, '5': 9, '10': 'title'},
    {'1': 'description', '3': 7, '4': 1, '5': 9, '10': 'description'},
    {'1': 'amount', '3': 8, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'mandatory', '3': 9, '4': 1, '5': 8, '10': 'mandatory'},
    {'1': 'due', '3': 10, '4': 1, '5': 3, '10': 'due'},
  ],
};

/// Descriptor for `CreateFeePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createFeePayloadDescriptor = $convert.base64Decode(
    'ChBDcmVhdGVGZWVQYXlsb2FkEg4KAmlkGAEgASgJUgJpZBIWCgZzY2hvb2wYAiABKAlSBnNjaG'
    '9vbBISCgR5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SFAoFZ3JhZGUYBSAB'
    'KAVSBWdyYWRlEhQKBXRpdGxlGAYgASgJUgV0aXRsZRIgCgtkZXNjcmlwdGlvbhgHIAEoCVILZG'
    'VzY3JpcHRpb24SFgoGYW1vdW50GAggASgCUgZhbW91bnQSHAoJbWFuZGF0b3J5GAkgASgIUglt'
    'YW5kYXRvcnkSEAoDZHVlGAogASgDUgNkdWU=');

@$core.Deprecated('Use updateFeePayloadDescriptor instead')
const UpdateFeePayload$json = {
  '1': 'UpdateFeePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'title', '17': true},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 4, '4': 1, '5': 2, '9': 2, '10': 'amount', '17': true},
    {
      '1': 'mandatory',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'mandatory',
      '17': true
    },
    {'1': 'due', '3': 6, '4': 1, '5': 3, '9': 4, '10': 'due', '17': true},
  ],
  '8': [
    {'1': '_title'},
    {'1': '_description'},
    {'1': '_amount'},
    {'1': '_mandatory'},
    {'1': '_due'},
  ],
};

/// Descriptor for `UpdateFeePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateFeePayloadDescriptor = $convert.base64Decode(
    'ChBVcGRhdGVGZWVQYXlsb2FkEg4KAmlkGAEgASgJUgJpZBIZCgV0aXRsZRgCIAEoCUgAUgV0aX'
    'RsZYgBARIlCgtkZXNjcmlwdGlvbhgDIAEoCUgBUgtkZXNjcmlwdGlvbogBARIbCgZhbW91bnQY'
    'BCABKAJIAlIGYW1vdW50iAEBEiEKCW1hbmRhdG9yeRgFIAEoCEgDUgltYW5kYXRvcnmIAQESFQ'
    'oDZHVlGAYgASgDSARSA2R1ZYgBAUIICgZfdGl0bGVCDgoMX2Rlc2NyaXB0aW9uQgkKB19hbW91'
    'bnRCDAoKX21hbmRhdG9yeUIGCgRfZHVl');

@$core.Deprecated('Use deleteFeePayloadDescriptor instead')
const DeleteFeePayload$json = {
  '1': 'DeleteFeePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteFeePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteFeePayloadDescriptor =
    $convert.base64Decode('ChBEZWxldGVGZWVQYXlsb2FkEg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use createInvoicePayloadDescriptor instead')
const CreateInvoicePayload$json = {
  '1': 'CreateInvoicePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'fee', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'fee', '17': true},
    {
      '1': 'description',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'student', '3': 7, '4': 1, '5': 5, '10': 'student'},
    {'1': 'amount', '3': 8, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'due', '3': 9, '4': 1, '5': 3, '9': 2, '10': 'due', '17': true},
  ],
  '8': [
    {'1': '_fee'},
    {'1': '_description'},
    {'1': '_due'},
  ],
};

/// Descriptor for `CreateInvoicePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createInvoicePayloadDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVJbnZvaWNlUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSFgoGc2Nob29sGAIgASgJUg'
    'ZzY2hvb2wSEgoEeWVhchgDIAEoBVIEeWVhchISCgR0ZXJtGAQgASgFUgR0ZXJtEhUKA2ZlZRgF'
    'IAEoCUgAUgNmZWWIAQESJQoLZGVzY3JpcHRpb24YBiABKAlIAVILZGVzY3JpcHRpb26IAQESGA'
    'oHc3R1ZGVudBgHIAEoBVIHc3R1ZGVudBIWCgZhbW91bnQYCCABKAJSBmFtb3VudBIVCgNkdWUY'
    'CSABKANIAlIDZHVliAEBQgYKBF9mZWVCDgoMX2Rlc2NyaXB0aW9uQgYKBF9kdWU=');

@$core.Deprecated('Use updateInvoicePayloadDescriptor instead')
const UpdateInvoicePayload$json = {
  '1': 'UpdateInvoicePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'fee', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'fee', '17': true},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 4, '4': 1, '5': 2, '9': 2, '10': 'amount', '17': true},
    {'1': 'status', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
    {'1': 'due', '3': 6, '4': 1, '5': 3, '9': 4, '10': 'due', '17': true},
  ],
  '8': [
    {'1': '_fee'},
    {'1': '_description'},
    {'1': '_amount'},
    {'1': '_status'},
    {'1': '_due'},
  ],
};

/// Descriptor for `UpdateInvoicePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateInvoicePayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVJbnZvaWNlUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSFQoDZmVlGAIgASgJSABSA2'
    'ZlZYgBARIlCgtkZXNjcmlwdGlvbhgDIAEoCUgBUgtkZXNjcmlwdGlvbogBARIbCgZhbW91bnQY'
    'BCABKAJIAlIGYW1vdW50iAEBEhsKBnN0YXR1cxgFIAEoBUgDUgZzdGF0dXOIAQESFQoDZHVlGA'
    'YgASgDSARSA2R1ZYgBAUIGCgRfZmVlQg4KDF9kZXNjcmlwdGlvbkIJCgdfYW1vdW50QgkKB19z'
    'dGF0dXNCBgoEX2R1ZQ==');

@$core.Deprecated('Use deleteInvoicePayloadDescriptor instead')
const DeleteInvoicePayload$json = {
  '1': 'DeleteInvoicePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteInvoicePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteInvoicePayloadDescriptor = $convert
    .base64Decode('ChREZWxldGVJbnZvaWNlUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use createPaymentPayloadDescriptor instead')
const CreatePaymentPayload$json = {
  '1': 'CreatePaymentPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'invoice',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {'1': 'school', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'school', '17': true},
    {
      '1': 'student',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'student',
      '17': true
    },
    {'1': 'amount', '3': 5, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'method', '3': 6, '4': 1, '5': 5, '10': 'method'},
    {
      '1': 'reference',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'reference',
      '17': true
    },
    {
      '1': 'recorder',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'recorder',
      '17': true
    },
    {'1': 'date', '3': 9, '4': 1, '5': 5, '9': 5, '10': 'date', '17': true},
  ],
  '8': [
    {'1': '_invoice'},
    {'1': '_school'},
    {'1': '_student'},
    {'1': '_reference'},
    {'1': '_recorder'},
    {'1': '_date'},
  ],
};

/// Descriptor for `CreatePaymentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPaymentPayloadDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVQYXltZW50UGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSHQoHaW52b2ljZRgCIAEoCU'
    'gAUgdpbnZvaWNliAEBEhsKBnNjaG9vbBgDIAEoCUgBUgZzY2hvb2yIAQESHQoHc3R1ZGVudBgE'
    'IAEoBUgCUgdzdHVkZW50iAEBEhYKBmFtb3VudBgFIAEoAlIGYW1vdW50EhYKBm1ldGhvZBgGIA'
    'EoBVIGbWV0aG9kEiEKCXJlZmVyZW5jZRgHIAEoCUgDUglyZWZlcmVuY2WIAQESHwoIcmVjb3Jk'
    'ZXIYCCABKAlIBFIIcmVjb3JkZXKIAQESFwoEZGF0ZRgJIAEoBUgFUgRkYXRliAEBQgoKCF9pbn'
    'ZvaWNlQgkKB19zY2hvb2xCCgoIX3N0dWRlbnRCDAoKX3JlZmVyZW5jZUILCglfcmVjb3JkZXJC'
    'BwoFX2RhdGU=');

@$core.Deprecated('Use updatePaymentPayloadDescriptor instead')
const UpdatePaymentPayload$json = {
  '1': 'UpdatePaymentPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'invoice',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {'1': 'amount', '3': 3, '4': 1, '5': 2, '9': 1, '10': 'amount', '17': true},
    {'1': 'method', '3': 4, '4': 1, '5': 5, '9': 2, '10': 'method', '17': true},
    {
      '1': 'reference',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'reference',
      '17': true
    },
    {
      '1': 'recorder',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'recorder',
      '17': true
    },
    {'1': 'date', '3': 7, '4': 1, '5': 5, '9': 5, '10': 'date', '17': true},
  ],
  '8': [
    {'1': '_invoice'},
    {'1': '_amount'},
    {'1': '_method'},
    {'1': '_reference'},
    {'1': '_recorder'},
    {'1': '_date'},
  ],
};

/// Descriptor for `UpdatePaymentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePaymentPayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVQYXltZW50UGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSHQoHaW52b2ljZRgCIAEoCU'
    'gAUgdpbnZvaWNliAEBEhsKBmFtb3VudBgDIAEoAkgBUgZhbW91bnSIAQESGwoGbWV0aG9kGAQg'
    'ASgFSAJSBm1ldGhvZIgBARIhCglyZWZlcmVuY2UYBSABKAlIA1IJcmVmZXJlbmNliAEBEh8KCH'
    'JlY29yZGVyGAYgASgJSARSCHJlY29yZGVyiAEBEhcKBGRhdGUYByABKAVIBVIEZGF0ZYgBAUIK'
    'CghfaW52b2ljZUIJCgdfYW1vdW50QgkKB19tZXRob2RCDAoKX3JlZmVyZW5jZUILCglfcmVjb3'
    'JkZXJCBwoFX2RhdGU=');

@$core.Deprecated('Use deletePaymentPayloadDescriptor instead')
const DeletePaymentPayload$json = {
  '1': 'DeletePaymentPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeletePaymentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePaymentPayloadDescriptor = $convert
    .base64Decode('ChREZWxldGVQYXltZW50UGF5bG9hZBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use approvePaymentPayloadDescriptor instead')
const ApprovePaymentPayload$json = {
  '1': 'ApprovePaymentPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `ApprovePaymentPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvePaymentPayloadDescriptor = $convert
    .base64Decode('ChVBcHByb3ZlUGF5bWVudFBheWxvYWQSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use createAnnouncementPayloadDescriptor instead')
const CreateAnnouncementPayload$json = {
  '1': 'CreateAnnouncementPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'grade', '17': true},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'audience', '3': 7, '4': 1, '5': 5, '10': 'audience'},
    {'1': 'author', '3': 8, '4': 1, '5': 9, '9': 2, '10': 'author', '17': true},
  ],
  '8': [
    {'1': '_grade'},
    {'1': '_stream'},
    {'1': '_author'},
  ],
};

/// Descriptor for `CreateAnnouncementPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAnnouncementPayloadDescriptor = $convert.base64Decode(
    'ChlDcmVhdGVBbm5vdW5jZW1lbnRQYXlsb2FkEg4KAmlkGAEgASgJUgJpZBIWCgZzY2hvb2wYAi'
    'ABKAlSBnNjaG9vbBIUCgV0aXRsZRgDIAEoCVIFdGl0bGUSGAoHY29udGVudBgEIAEoCVIHY29u'
    'dGVudBIZCgVncmFkZRgFIAEoBUgAUgVncmFkZYgBARIbCgZzdHJlYW0YBiABKAVIAVIGc3RyZW'
    'FtiAEBEhoKCGF1ZGllbmNlGAcgASgFUghhdWRpZW5jZRIbCgZhdXRob3IYCCABKAlIAlIGYXV0'
    'aG9yiAEBQggKBl9ncmFkZUIJCgdfc3RyZWFtQgkKB19hdXRob3I=');

@$core.Deprecated('Use updateAnnouncementPayloadDescriptor instead')
const UpdateAnnouncementPayload$json = {
  '1': 'UpdateAnnouncementPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'title', '17': true},
    {
      '1': 'content',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'content',
      '17': true
    },
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '9': 2, '10': 'grade', '17': true},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'stream', '17': true},
    {
      '1': 'audience',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'audience',
      '17': true
    },
  ],
  '8': [
    {'1': '_title'},
    {'1': '_content'},
    {'1': '_grade'},
    {'1': '_stream'},
    {'1': '_audience'},
  ],
};

/// Descriptor for `UpdateAnnouncementPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAnnouncementPayloadDescriptor = $convert.base64Decode(
    'ChlVcGRhdGVBbm5vdW5jZW1lbnRQYXlsb2FkEg4KAmlkGAEgASgJUgJpZBIZCgV0aXRsZRgCIA'
    'EoCUgAUgV0aXRsZYgBARIdCgdjb250ZW50GAMgASgJSAFSB2NvbnRlbnSIAQESGQoFZ3JhZGUY'
    'BCABKAVIAlIFZ3JhZGWIAQESGwoGc3RyZWFtGAUgASgFSANSBnN0cmVhbYgBARIfCghhdWRpZW'
    '5jZRgGIAEoBUgEUghhdWRpZW5jZYgBAUIICgZfdGl0bGVCCgoIX2NvbnRlbnRCCAoGX2dyYWRl'
    'QgkKB19zdHJlYW1CCwoJX2F1ZGllbmNl');

@$core.Deprecated('Use deleteAnnouncementPayloadDescriptor instead')
const DeleteAnnouncementPayload$json = {
  '1': 'DeleteAnnouncementPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteAnnouncementPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAnnouncementPayloadDescriptor =
    $convert.base64Decode(
        'ChlEZWxldGVBbm5vdW5jZW1lbnRQYXlsb2FkEg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use createRolePayloadDescriptor instead')
const CreateRolePayload$json = {
  '1': 'CreateRolePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'school', '17': true},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'permissions', '3': 5, '4': 1, '5': 12, '10': 'permissions'},
  ],
  '8': [
    {'1': '_school'},
    {'1': '_description'},
  ],
};

/// Descriptor for `CreateRolePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createRolePayloadDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVSb2xlUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSGwoGc2Nob29sGAIgASgJSABSBn'
    'NjaG9vbIgBARISCgRuYW1lGAMgASgJUgRuYW1lEiUKC2Rlc2NyaXB0aW9uGAQgASgJSAFSC2Rl'
    'c2NyaXB0aW9uiAEBEiAKC3Blcm1pc3Npb25zGAUgASgMUgtwZXJtaXNzaW9uc0IJCgdfc2Nob2'
    '9sQg4KDF9kZXNjcmlwdGlvbg==');

@$core.Deprecated('Use updateRolePayloadDescriptor instead')
const UpdateRolePayload$json = {
  '1': 'UpdateRolePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {
      '1': 'permissions',
      '3': 4,
      '4': 1,
      '5': 12,
      '9': 2,
      '10': 'permissions',
      '17': true
    },
  ],
  '8': [
    {'1': '_name'},
    {'1': '_description'},
    {'1': '_permissions'},
  ],
};

/// Descriptor for `UpdateRolePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateRolePayloadDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVSb2xlUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSFwoEbmFtZRgCIAEoCUgAUgRuYW'
    '1liAEBEiUKC2Rlc2NyaXB0aW9uGAMgASgJSAFSC2Rlc2NyaXB0aW9uiAEBEiUKC3Blcm1pc3Np'
    'b25zGAQgASgMSAJSC3Blcm1pc3Npb25ziAEBQgcKBV9uYW1lQg4KDF9kZXNjcmlwdGlvbkIOCg'
    'xfcGVybWlzc2lvbnM=');

@$core.Deprecated('Use deleteRolePayloadDescriptor instead')
const DeleteRolePayload$json = {
  '1': 'DeleteRolePayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteRolePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteRolePayloadDescriptor =
    $convert.base64Decode('ChFEZWxldGVSb2xlUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use assignRolePayloadDescriptor instead')
const AssignRolePayload$json = {
  '1': 'AssignRolePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'school', '17': true},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
  ],
  '8': [
    {'1': '_school'},
  ],
};

/// Descriptor for `AssignRolePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignRolePayloadDescriptor = $convert.base64Decode(
    'ChFBc3NpZ25Sb2xlUGF5bG9hZBIbCgZzY2hvb2wYASABKAlIAFIGc2Nob29siAEBEhIKBHVzZX'
    'IYAiABKAlSBHVzZXISEgoEcm9sZRgDIAEoCVIEcm9sZUIJCgdfc2Nob29s');

@$core.Deprecated('Use unassignRolePayloadDescriptor instead')
const UnassignRolePayload$json = {
  '1': 'UnassignRolePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'school', '17': true},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
  ],
  '8': [
    {'1': '_school'},
  ],
};

/// Descriptor for `UnassignRolePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unassignRolePayloadDescriptor = $convert.base64Decode(
    'ChNVbmFzc2lnblJvbGVQYXlsb2FkEhsKBnNjaG9vbBgBIAEoCUgAUgZzY2hvb2yIAQESEgoEdX'
    'NlchgCIAEoCVIEdXNlchISCgRyb2xlGAMgASgJUgRyb2xlQgkKB19zY2hvb2w=');

@$core.Deprecated('Use updateUserPayloadDescriptor instead')
const UpdateUserPayload$json = {
  '1': 'UpdateUserPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'phone', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'phone', '17': true},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'email', '17': true},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'name', '17': true},
    {'1': 'level', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'level', '17': true},
    {'1': 'status', '3': 6, '4': 1, '5': 5, '9': 4, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_phone'},
    {'1': '_email'},
    {'1': '_name'},
    {'1': '_level'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateUserPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateUserPayloadDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVVc2VyUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSGQoFcGhvbmUYAiABKAlIAFIFcG'
    'hvbmWIAQESGQoFZW1haWwYAyABKAlIAVIFZW1haWyIAQESFwoEbmFtZRgEIAEoCUgCUgRuYW1l'
    'iAEBEhkKBWxldmVsGAUgASgFSANSBWxldmVsiAEBEhsKBnN0YXR1cxgGIAEoBUgEUgZzdGF0dX'
    'OIAQFCCAoGX3Bob25lQggKBl9lbWFpbEIHCgVfbmFtZUIICgZfbGV2ZWxCCQoHX3N0YXR1cw==');

@$core.Deprecated('Use deleteUserPayloadDescriptor instead')
const DeleteUserPayload$json = {
  '1': 'DeleteUserPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteUserPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteUserPayloadDescriptor =
    $convert.base64Decode('ChFEZWxldGVVc2VyUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use createSubjectPayloadDescriptor instead')
const CreateSubjectPayload$json = {
  '1': 'CreateSubjectPayload',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'curriculum', '3': 2, '4': 1, '5': 5, '10': 'curriculum'},
  ],
};

/// Descriptor for `CreateSubjectPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSubjectPayloadDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVTdWJqZWN0UGF5bG9hZBISCgRuYW1lGAEgASgJUgRuYW1lEh4KCmN1cnJpY3VsdW'
    '0YAiABKAVSCmN1cnJpY3VsdW0=');

@$core.Deprecated('Use updateSubjectPayloadDescriptor instead')
const UpdateSubjectPayload$json = {
  '1': 'UpdateSubjectPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'curriculum',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'curriculum',
      '17': true
    },
  ],
  '8': [
    {'1': '_name'},
    {'1': '_curriculum'},
  ],
};

/// Descriptor for `UpdateSubjectPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSubjectPayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVTdWJqZWN0UGF5bG9hZBIOCgJpZBgBIAEoBVICaWQSFwoEbmFtZRgCIAEoCUgAUg'
    'RuYW1liAEBEiMKCmN1cnJpY3VsdW0YAyABKAVIAVIKY3VycmljdWx1bYgBAUIHCgVfbmFtZUIN'
    'CgtfY3VycmljdWx1bQ==');

@$core.Deprecated('Use deleteSubjectPayloadDescriptor instead')
const DeleteSubjectPayload$json = {
  '1': 'DeleteSubjectPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
  ],
};

/// Descriptor for `DeleteSubjectPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSubjectPayloadDescriptor = $convert
    .base64Decode('ChREZWxldGVTdWJqZWN0UGF5bG9hZBIOCgJpZBgBIAEoBVICaWQ=');

@$core.Deprecated('Use createTopicPayloadDescriptor instead')
const CreateTopicPayload$json = {
  '1': 'CreateTopicPayload',
  '2': [
    {'1': 'subject', '3': 1, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateTopicPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTopicPayloadDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVUb3BpY1BheWxvYWQSGAoHc3ViamVjdBgBIAEoBVIHc3ViamVjdBIUCgVncmFkZR'
    'gCIAEoBVIFZ3JhZGUSEgoEbmFtZRgDIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use updateTopicPayloadDescriptor instead')
const UpdateTopicPayload$json = {
  '1': 'UpdateTopicPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {
      '1': 'subject',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'subject',
      '17': true
    },
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '9': 1, '10': 'grade', '17': true},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'name', '17': true},
  ],
  '8': [
    {'1': '_subject'},
    {'1': '_grade'},
    {'1': '_name'},
  ],
};

/// Descriptor for `UpdateTopicPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTopicPayloadDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVUb3BpY1BheWxvYWQSDgoCaWQYASABKAVSAmlkEh0KB3N1YmplY3QYAiABKAVIAF'
    'IHc3ViamVjdIgBARIZCgVncmFkZRgDIAEoBUgBUgVncmFkZYgBARIXCgRuYW1lGAQgASgJSAJS'
    'BG5hbWWIAQFCCgoIX3N1YmplY3RCCAoGX2dyYWRlQgcKBV9uYW1l');

@$core.Deprecated('Use deleteTopicPayloadDescriptor instead')
const DeleteTopicPayload$json = {
  '1': 'DeleteTopicPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
  ],
};

/// Descriptor for `DeleteTopicPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTopicPayloadDescriptor =
    $convert.base64Decode('ChJEZWxldGVUb3BpY1BheWxvYWQSDgoCaWQYASABKAVSAmlk');

@$core.Deprecated('Use createStreamPayloadDescriptor instead')
const CreateStreamPayload$json = {
  '1': 'CreateStreamPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateStreamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createStreamPayloadDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVTdHJlYW1QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhQKBWdyYWRlGA'
    'IgASgFUgVncmFkZRIWCgZzdHJlYW0YAyABKAVSBnN0cmVhbRISCgRuYW1lGAQgASgJUgRuYW1l');

@$core.Deprecated('Use updateStreamPayloadDescriptor instead')
const UpdateStreamPayload$json = {
  '1': 'UpdateStreamPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
  ],
  '8': [
    {'1': '_name'},
  ],
};

/// Descriptor for `UpdateStreamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateStreamPayloadDescriptor = $convert.base64Decode(
    'ChNVcGRhdGVTdHJlYW1QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhQKBWdyYWRlGA'
    'IgASgFUgVncmFkZRIWCgZzdHJlYW0YAyABKAVSBnN0cmVhbRIXCgRuYW1lGAQgASgJSABSBG5h'
    'bWWIAQFCBwoFX25hbWU=');

@$core.Deprecated('Use deleteStreamPayloadDescriptor instead')
const DeleteStreamPayload$json = {
  '1': 'DeleteStreamPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
  ],
};

/// Descriptor for `DeleteStreamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteStreamPayloadDescriptor = $convert.base64Decode(
    'ChNEZWxldGVTdHJlYW1QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhQKBWdyYWRlGA'
    'IgASgFUgVncmFkZRIWCgZzdHJlYW0YAyABKAVSBnN0cmVhbQ==');

@$core.Deprecated('Use createMpesaPayloadDescriptor instead')
const CreateMpesaPayload$json = {
  '1': 'CreateMpesaPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'consumer_key', '3': 2, '4': 1, '5': 9, '10': 'consumerKey'},
    {'1': 'consumer_secret', '3': 3, '4': 1, '5': 9, '10': 'consumerSecret'},
    {'1': 'passkey', '3': 4, '4': 1, '5': 9, '10': 'passkey'},
    {'1': 'shortcode', '3': 5, '4': 1, '5': 9, '10': 'shortcode'},
    {'1': 'env', '3': 6, '4': 1, '5': 5, '10': 'env'},
  ],
};

/// Descriptor for `CreateMpesaPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createMpesaPayloadDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVNcGVzYVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSIQoMY29uc3VtZX'
    'Jfa2V5GAIgASgJUgtjb25zdW1lcktleRInCg9jb25zdW1lcl9zZWNyZXQYAyABKAlSDmNvbnN1'
    'bWVyU2VjcmV0EhgKB3Bhc3NrZXkYBCABKAlSB3Bhc3NrZXkSHAoJc2hvcnRjb2RlGAUgASgJUg'
    'lzaG9ydGNvZGUSEAoDZW52GAYgASgFUgNlbnY=');

@$core.Deprecated('Use updateMpesaPayloadDescriptor instead')
const UpdateMpesaPayload$json = {
  '1': 'UpdateMpesaPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {
      '1': 'consumer_key',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'consumerKey',
      '17': true
    },
    {
      '1': 'consumer_secret',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'consumerSecret',
      '17': true
    },
    {
      '1': 'passkey',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'passkey',
      '17': true
    },
    {
      '1': 'shortcode',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'shortcode',
      '17': true
    },
    {'1': 'env', '3': 6, '4': 1, '5': 5, '9': 4, '10': 'env', '17': true},
  ],
  '8': [
    {'1': '_consumer_key'},
    {'1': '_consumer_secret'},
    {'1': '_passkey'},
    {'1': '_shortcode'},
    {'1': '_env'},
  ],
};

/// Descriptor for `UpdateMpesaPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateMpesaPayloadDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVNcGVzYVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSJgoMY29uc3VtZX'
    'Jfa2V5GAIgASgJSABSC2NvbnN1bWVyS2V5iAEBEiwKD2NvbnN1bWVyX3NlY3JldBgDIAEoCUgB'
    'Ug5jb25zdW1lclNlY3JldIgBARIdCgdwYXNza2V5GAQgASgJSAJSB3Bhc3NrZXmIAQESIQoJc2'
    'hvcnRjb2RlGAUgASgJSANSCXNob3J0Y29kZYgBARIVCgNlbnYYBiABKAVIBFIDZW52iAEBQg8K'
    'DV9jb25zdW1lcl9rZXlCEgoQX2NvbnN1bWVyX3NlY3JldEIKCghfcGFzc2tleUIMCgpfc2hvcn'
    'Rjb2RlQgYKBF9lbnY=');

@$core.Deprecated('Use deleteMpesaPayloadDescriptor instead')
const DeleteMpesaPayload$json = {
  '1': 'DeleteMpesaPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
  ],
};

/// Descriptor for `DeleteMpesaPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteMpesaPayloadDescriptor =
    $convert.base64Decode(
        'ChJEZWxldGVNcGVzYVBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2w=');

@$core.Deprecated('Use addExamGradePayloadDescriptor instead')
const AddExamGradePayload$json = {
  '1': 'AddExamGradePayload',
  '2': [
    {'1': 'exam', '3': 1, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
  ],
};

/// Descriptor for `AddExamGradePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addExamGradePayloadDescriptor = $convert.base64Decode(
    'ChNBZGRFeGFtR3JhZGVQYXlsb2FkEhIKBGV4YW0YASABKAlSBGV4YW0SFAoFZ3JhZGUYAiABKA'
    'VSBWdyYWRlEhYKBnN0cmVhbRgDIAEoBVIGc3RyZWFt');

@$core.Deprecated('Use removeExamGradePayloadDescriptor instead')
const RemoveExamGradePayload$json = {
  '1': 'RemoveExamGradePayload',
  '2': [
    {'1': 'exam', '3': 1, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
  ],
};

/// Descriptor for `RemoveExamGradePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeExamGradePayloadDescriptor =
    $convert.base64Decode(
        'ChZSZW1vdmVFeGFtR3JhZGVQYXlsb2FkEhIKBGV4YW0YASABKAlSBGV4YW0SFAoFZ3JhZGUYAi'
        'ABKAVSBWdyYWRlEhYKBnN0cmVhbRgDIAEoBVIGc3RyZWFt');

@$core.Deprecated('Use createPlanPayloadDescriptor instead')
const CreatePlanPayload$json = {
  '1': 'CreatePlanPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 4, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'levels', '3': 5, '4': 1, '5': 5, '10': 'levels'},
    {
      '1': 'features',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'features',
      '17': true
    },
  ],
  '8': [
    {'1': '_description'},
    {'1': '_features'},
  ],
};

/// Descriptor for `CreatePlanPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPlanPayloadDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVQbGFuUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IlCgtkZXNjcmlwdGlvbhgDIAEoCUgAUgtkZXNjcmlwdGlvbogBARIWCgZhbW91bnQYBCABKAJS'
    'BmFtb3VudBIWCgZsZXZlbHMYBSABKAVSBmxldmVscxIfCghmZWF0dXJlcxgGIAEoCUgBUghmZW'
    'F0dXJlc4gBAUIOCgxfZGVzY3JpcHRpb25CCwoJX2ZlYXR1cmVz');

@$core.Deprecated('Use updatePlanPayloadDescriptor instead')
const UpdatePlanPayload$json = {
  '1': 'UpdatePlanPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 4, '4': 1, '5': 2, '9': 2, '10': 'amount', '17': true},
    {'1': 'levels', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'levels', '17': true},
    {'1': 'status', '3': 6, '4': 1, '5': 5, '9': 4, '10': 'status', '17': true},
    {
      '1': 'features',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'features',
      '17': true
    },
  ],
  '8': [
    {'1': '_name'},
    {'1': '_description'},
    {'1': '_amount'},
    {'1': '_levels'},
    {'1': '_status'},
    {'1': '_features'},
  ],
};

/// Descriptor for `UpdatePlanPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePlanPayloadDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVQbGFuUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQSFwoEbmFtZRgCIAEoCUgAUgRuYW'
    '1liAEBEiUKC2Rlc2NyaXB0aW9uGAMgASgJSAFSC2Rlc2NyaXB0aW9uiAEBEhsKBmFtb3VudBgE'
    'IAEoAkgCUgZhbW91bnSIAQESGwoGbGV2ZWxzGAUgASgFSANSBmxldmVsc4gBARIbCgZzdGF0dX'
    'MYBiABKAVIBFIGc3RhdHVziAEBEh8KCGZlYXR1cmVzGAcgASgJSAVSCGZlYXR1cmVziAEBQgcK'
    'BV9uYW1lQg4KDF9kZXNjcmlwdGlvbkIJCgdfYW1vdW50QgkKB19sZXZlbHNCCQoHX3N0YXR1c0'
    'ILCglfZmVhdHVyZXM=');

@$core.Deprecated('Use deletePlanPayloadDescriptor instead')
const DeletePlanPayload$json = {
  '1': 'DeletePlanPayload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeletePlanPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePlanPayloadDescriptor =
    $convert.base64Decode('ChFEZWxldGVQbGFuUGF5bG9hZBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use updateAiUsagePayloadDescriptor instead')
const UpdateAiUsagePayload$json = {
  '1': 'UpdateAiUsagePayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'student', '3': 2, '4': 1, '5': 5, '10': 'student'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {
      '1': 'allocated',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'allocated',
      '17': true
    },
    {'1': 'used', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'used', '17': true},
  ],
  '8': [
    {'1': '_allocated'},
    {'1': '_used'},
  ],
};

/// Descriptor for `UpdateAiUsagePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAiUsagePayloadDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVBaVVzYWdlUGF5bG9hZBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIYCgdzdHVkZW'
    '50GAIgASgFUgdzdHVkZW50EhIKBHllYXIYAyABKAVSBHllYXISEgoEdGVybRgEIAEoBVIEdGVy'
    'bRIhCglhbGxvY2F0ZWQYBSABKAVIAFIJYWxsb2NhdGVkiAEBEhcKBHVzZWQYBiABKAVIAVIEdX'
    'NlZIgBAUIMCgpfYWxsb2NhdGVkQgcKBV91c2Vk');

@$core.Deprecated('Use createSubscriptionPayloadDescriptor instead')
const CreateSubscriptionPayload$json = {
  '1': 'CreateSubscriptionPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'student', '3': 5, '4': 1, '5': 5, '10': 'student'},
    {
      '1': 'invoice',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {'1': 'discount', '3': 7, '4': 1, '5': 2, '10': 'discount'},
  ],
  '8': [
    {'1': '_invoice'},
  ],
};

/// Descriptor for `CreateSubscriptionPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSubscriptionPayloadDescriptor = $convert.base64Decode(
    'ChlDcmVhdGVTdWJzY3JpcHRpb25QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBH'
    'BsYW4YAiABKAlSBHBsYW4SEgoEeWVhchgDIAEoBVIEeWVhchISCgR0ZXJtGAQgASgFUgR0ZXJt'
    'EhgKB3N0dWRlbnQYBSABKAVSB3N0dWRlbnQSHQoHaW52b2ljZRgGIAEoCUgAUgdpbnZvaWNliA'
    'EBEhoKCGRpc2NvdW50GAcgASgCUghkaXNjb3VudEIKCghfaW52b2ljZQ==');

@$core.Deprecated('Use updateSubscriptionPayloadDescriptor instead')
const UpdateSubscriptionPayload$json = {
  '1': 'UpdateSubscriptionPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'student', '3': 5, '4': 1, '5': 5, '10': 'student'},
    {
      '1': 'invoice',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {
      '1': 'discount',
      '3': 7,
      '4': 1,
      '5': 2,
      '9': 1,
      '10': 'discount',
      '17': true
    },
    {'1': 'status', '3': 8, '4': 1, '5': 5, '9': 2, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_invoice'},
    {'1': '_discount'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateSubscriptionPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSubscriptionPayloadDescriptor = $convert.base64Decode(
    'ChlVcGRhdGVTdWJzY3JpcHRpb25QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBH'
    'BsYW4YAiABKAlSBHBsYW4SEgoEeWVhchgDIAEoBVIEeWVhchISCgR0ZXJtGAQgASgFUgR0ZXJt'
    'EhgKB3N0dWRlbnQYBSABKAVSB3N0dWRlbnQSHQoHaW52b2ljZRgGIAEoCUgAUgdpbnZvaWNliA'
    'EBEh8KCGRpc2NvdW50GAcgASgCSAFSCGRpc2NvdW50iAEBEhsKBnN0YXR1cxgIIAEoBUgCUgZz'
    'dGF0dXOIAQFCCgoIX2ludm9pY2VCCwoJX2Rpc2NvdW50QgkKB19zdGF0dXM=');

@$core.Deprecated('Use deleteSubscriptionPayloadDescriptor instead')
const DeleteSubscriptionPayload$json = {
  '1': 'DeleteSubscriptionPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'student', '3': 5, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `DeleteSubscriptionPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSubscriptionPayloadDescriptor = $convert.base64Decode(
    'ChlEZWxldGVTdWJzY3JpcHRpb25QYXlsb2FkEhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBH'
    'BsYW4YAiABKAlSBHBsYW4SEgoEeWVhchgDIAEoBVIEeWVhchISCgR0ZXJtGAQgASgFUgR0ZXJt'
    'EhgKB3N0dWRlbnQYBSABKAVSB3N0dWRlbnQ=');

@$core.Deprecated('Use createDiscountPayloadDescriptor instead')
const CreateDiscountPayload$json = {
  '1': 'CreateDiscountPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'amount', '3': 6, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'unit', '3': 7, '4': 1, '5': 5, '10': 'unit'},
  ],
};

/// Descriptor for `CreateDiscountPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createDiscountPayloadDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVEaXNjb3VudFBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEcGxhbh'
    'gCIAEoCVIEcGxhbhISCgR5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SFAoF'
    'Z3JhZGUYBSABKAVSBWdyYWRlEhYKBmFtb3VudBgGIAEoAlIGYW1vdW50EhIKBHVuaXQYByABKA'
    'VSBHVuaXQ=');

@$core.Deprecated('Use updateDiscountPayloadDescriptor instead')
const UpdateDiscountPayload$json = {
  '1': 'UpdateDiscountPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'amount', '3': 6, '4': 1, '5': 2, '9': 0, '10': 'amount', '17': true},
    {'1': 'unit', '3': 7, '4': 1, '5': 5, '9': 1, '10': 'unit', '17': true},
  ],
  '8': [
    {'1': '_amount'},
    {'1': '_unit'},
  ],
};

/// Descriptor for `UpdateDiscountPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDiscountPayloadDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVEaXNjb3VudFBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEcGxhbh'
    'gCIAEoCVIEcGxhbhISCgR5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SFAoF'
    'Z3JhZGUYBSABKAVSBWdyYWRlEhsKBmFtb3VudBgGIAEoAkgAUgZhbW91bnSIAQESFwoEdW5pdB'
    'gHIAEoBUgBUgR1bml0iAEBQgkKB19hbW91bnRCBwoFX3VuaXQ=');

@$core.Deprecated('Use deleteDiscountPayloadDescriptor instead')
const DeleteDiscountPayload$json = {
  '1': 'DeleteDiscountPayload',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
  ],
};

/// Descriptor for `DeleteDiscountPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteDiscountPayloadDescriptor = $convert.base64Decode(
    'ChVEZWxldGVEaXNjb3VudFBheWxvYWQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEcGxhbh'
    'gCIAEoCVIEcGxhbhISCgR5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SFAoF'
    'Z3JhZGUYBSABKAVSBWdyYWRl');

@$core.Deprecated('Use insertDataDescriptor instead')
const InsertData$json = {
  '1': 'InsertData',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.sync.UserInsert',
      '9': 0,
      '10': 'user'
    },
    {
      '1': 'school',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.sync.SchoolInsert',
      '9': 0,
      '10': 'school'
    },
    {
      '1': 'owner',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.sync.OwnerInsert',
      '9': 0,
      '10': 'owner'
    },
    {
      '1': 'student',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.sync.StudentInsert',
      '9': 0,
      '10': 'student'
    },
    {
      '1': 'guardian',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.sync.GuardianInsert',
      '9': 0,
      '10': 'guardian'
    },
    {
      '1': 'department',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.sync.DepartmentInsert',
      '9': 0,
      '10': 'department'
    },
    {
      '1': 'teacher',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.sync.TeacherInsert',
      '9': 0,
      '10': 'teacher'
    },
    {
      '1': 'staff_member',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.sync.StaffInsert',
      '9': 0,
      '10': 'staffMember'
    },
    {
      '1': 'term',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.sync.TermInsert',
      '9': 0,
      '10': 'term'
    },
    {
      '1': 'class_teacher',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.sync.ClassTeacherInsert',
      '9': 0,
      '10': 'classTeacher'
    },
    {
      '1': 'enrollment',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.sync.EnrollmentInsert',
      '9': 0,
      '10': 'enrollment'
    },
    {
      '1': 'subject_teacher',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.sync.SubjectTeacherInsert',
      '9': 0,
      '10': 'subjectTeacher'
    },
    {
      '1': 'attendance',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.sync.AttendanceInsert',
      '9': 0,
      '10': 'attendance'
    },
    {
      '1': 'timetable',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.sync.TimetableInsert',
      '9': 0,
      '10': 'timetable'
    },
    {
      '1': 'lesson',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.sync.LessonInsert',
      '9': 0,
      '10': 'lesson'
    },
    {
      '1': 'exam',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.sync.ExamInsert',
      '9': 0,
      '10': 'exam'
    },
    {
      '1': 'paper',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.sync.PaperInsert',
      '9': 0,
      '10': 'paper'
    },
    {
      '1': 'grade',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.sync.GradeInsert',
      '9': 0,
      '10': 'grade'
    },
    {
      '1': 'fee',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.sync.FeeInsert',
      '9': 0,
      '10': 'fee'
    },
    {
      '1': 'invoice',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.sync.InvoiceInsert',
      '9': 0,
      '10': 'invoice'
    },
    {
      '1': 'payment',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.sync.PaymentInsert',
      '9': 0,
      '10': 'payment'
    },
    {
      '1': 'announcement',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.sync.AnnouncementInsert',
      '9': 0,
      '10': 'announcement'
    },
    {
      '1': 'mastery',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.sync.MasteryInsert',
      '9': 0,
      '10': 'mastery'
    },
    {
      '1': 'ai_usage',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.sync.AiUsageInsert',
      '9': 0,
      '10': 'aiUsage'
    },
    {
      '1': 'role',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.sync.RoleInsert',
      '9': 0,
      '10': 'role'
    },
    {
      '1': 'scope',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.sync.ScopeInsert',
      '9': 0,
      '10': 'scope'
    },
    {
      '1': 'plan',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.sync.PlanInsert',
      '9': 0,
      '10': 'plan'
    },
    {
      '1': 'subscription',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.sync.SubscriptionInsert',
      '9': 0,
      '10': 'subscription'
    },
    {
      '1': 'discount',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.sync.DiscountInsert',
      '9': 0,
      '10': 'discount'
    },
    {
      '1': 'subject_catalog',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.sync.SubjectInsert',
      '9': 0,
      '10': 'subjectCatalog'
    },
    {
      '1': 'topic',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.sync.TopicInsert',
      '9': 0,
      '10': 'topic'
    },
    {
      '1': 'stream',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.sync.StreamInsert',
      '9': 0,
      '10': 'stream'
    },
    {
      '1': 'mpesa',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.sync.MpesaInsert',
      '9': 0,
      '10': 'mpesa'
    },
    {
      '1': 'exam_grade',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.sync.ExamGradeInsert',
      '9': 0,
      '10': 'examGrade'
    },
  ],
  '8': [
    {'1': 'row'},
  ],
};

/// Descriptor for `InsertData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List insertDataDescriptor = $convert.base64Decode(
    'CgpJbnNlcnREYXRhEiYKBHVzZXIYASABKAsyEC5zeW5jLlVzZXJJbnNlcnRIAFIEdXNlchIsCg'
    'ZzY2hvb2wYAiABKAsyEi5zeW5jLlNjaG9vbEluc2VydEgAUgZzY2hvb2wSKQoFb3duZXIYAyAB'
    'KAsyES5zeW5jLk93bmVySW5zZXJ0SABSBW93bmVyEi8KB3N0dWRlbnQYBCABKAsyEy5zeW5jLl'
    'N0dWRlbnRJbnNlcnRIAFIHc3R1ZGVudBIyCghndWFyZGlhbhgFIAEoCzIULnN5bmMuR3VhcmRp'
    'YW5JbnNlcnRIAFIIZ3VhcmRpYW4SOAoKZGVwYXJ0bWVudBgGIAEoCzIWLnN5bmMuRGVwYXJ0bW'
    'VudEluc2VydEgAUgpkZXBhcnRtZW50Ei8KB3RlYWNoZXIYByABKAsyEy5zeW5jLlRlYWNoZXJJ'
    'bnNlcnRIAFIHdGVhY2hlchI2CgxzdGFmZl9tZW1iZXIYCCABKAsyES5zeW5jLlN0YWZmSW5zZX'
    'J0SABSC3N0YWZmTWVtYmVyEiYKBHRlcm0YCSABKAsyEC5zeW5jLlRlcm1JbnNlcnRIAFIEdGVy'
    'bRI/Cg1jbGFzc190ZWFjaGVyGAogASgLMhguc3luYy5DbGFzc1RlYWNoZXJJbnNlcnRIAFIMY2'
    'xhc3NUZWFjaGVyEjgKCmVucm9sbG1lbnQYCyABKAsyFi5zeW5jLkVucm9sbG1lbnRJbnNlcnRI'
    'AFIKZW5yb2xsbWVudBJFCg9zdWJqZWN0X3RlYWNoZXIYDCABKAsyGi5zeW5jLlN1YmplY3RUZW'
    'FjaGVySW5zZXJ0SABSDnN1YmplY3RUZWFjaGVyEjgKCmF0dGVuZGFuY2UYDSABKAsyFi5zeW5j'
    'LkF0dGVuZGFuY2VJbnNlcnRIAFIKYXR0ZW5kYW5jZRI1Cgl0aW1ldGFibGUYDiABKAsyFS5zeW'
    '5jLlRpbWV0YWJsZUluc2VydEgAUgl0aW1ldGFibGUSLAoGbGVzc29uGA8gASgLMhIuc3luYy5M'
    'ZXNzb25JbnNlcnRIAFIGbGVzc29uEiYKBGV4YW0YECABKAsyEC5zeW5jLkV4YW1JbnNlcnRIAF'
    'IEZXhhbRIpCgVwYXBlchgRIAEoCzIRLnN5bmMuUGFwZXJJbnNlcnRIAFIFcGFwZXISKQoFZ3Jh'
    'ZGUYEiABKAsyES5zeW5jLkdyYWRlSW5zZXJ0SABSBWdyYWRlEiMKA2ZlZRgTIAEoCzIPLnN5bm'
    'MuRmVlSW5zZXJ0SABSA2ZlZRIvCgdpbnZvaWNlGBQgASgLMhMuc3luYy5JbnZvaWNlSW5zZXJ0'
    'SABSB2ludm9pY2USLwoHcGF5bWVudBgVIAEoCzITLnN5bmMuUGF5bWVudEluc2VydEgAUgdwYX'
    'ltZW50Ej4KDGFubm91bmNlbWVudBgWIAEoCzIYLnN5bmMuQW5ub3VuY2VtZW50SW5zZXJ0SABS'
    'DGFubm91bmNlbWVudBIvCgdtYXN0ZXJ5GBcgASgLMhMuc3luYy5NYXN0ZXJ5SW5zZXJ0SABSB2'
    '1hc3RlcnkSMAoIYWlfdXNhZ2UYGCABKAsyEy5zeW5jLkFpVXNhZ2VJbnNlcnRIAFIHYWlVc2Fn'
    'ZRImCgRyb2xlGBogASgLMhAuc3luYy5Sb2xlSW5zZXJ0SABSBHJvbGUSKQoFc2NvcGUYGyABKA'
    'syES5zeW5jLlNjb3BlSW5zZXJ0SABSBXNjb3BlEiYKBHBsYW4YHCABKAsyEC5zeW5jLlBsYW5J'
    'bnNlcnRIAFIEcGxhbhI+CgxzdWJzY3JpcHRpb24YHSABKAsyGC5zeW5jLlN1YnNjcmlwdGlvbk'
    'luc2VydEgAUgxzdWJzY3JpcHRpb24SMgoIZGlzY291bnQYHiABKAsyFC5zeW5jLkRpc2NvdW50'
    'SW5zZXJ0SABSCGRpc2NvdW50Ej4KD3N1YmplY3RfY2F0YWxvZxgfIAEoCzITLnN5bmMuU3Viam'
    'VjdEluc2VydEgAUg5zdWJqZWN0Q2F0YWxvZxIpCgV0b3BpYxggIAEoCzIRLnN5bmMuVG9waWNJ'
    'bnNlcnRIAFIFdG9waWMSLAoGc3RyZWFtGCEgASgLMhIuc3luYy5TdHJlYW1JbnNlcnRIAFIGc3'
    'RyZWFtEikKBW1wZXNhGCIgASgLMhEuc3luYy5NcGVzYUluc2VydEgAUgVtcGVzYRI2CgpleGFt'
    'X2dyYWRlGCMgASgLMhUuc3luYy5FeGFtR3JhZGVJbnNlcnRIAFIJZXhhbUdyYWRlQgUKA3Jvdw'
    '==');

@$core.Deprecated('Use userInsertDescriptor instead')
const UserInsert$json = {
  '1': 'UserInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'phone', '3': 2, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'level', '3': 5, '4': 1, '5': 5, '10': 'level'},
    {'1': 'status', '3': 6, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_email'},
  ],
};

/// Descriptor for `UserInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userInsertDescriptor = $convert.base64Decode(
    'CgpVc2VySW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBIUCgVwaG9uZRgCIAEoCVIFcGhvbmUSGQoFZW'
    '1haWwYAyABKAlIAFIFZW1haWyIAQESEgoEbmFtZRgEIAEoCVIEbmFtZRIUCgVsZXZlbBgFIAEo'
    'BVIFbGV2ZWwSFgoGc3RhdHVzGAYgASgFUgZzdGF0dXNCCAoGX2VtYWls');

@$core.Deprecated('Use schoolInsertDescriptor instead')
const SchoolInsert$json = {
  '1': 'SchoolInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'motto', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'motto', '17': true},
    {'1': 'phone', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'phone', '17': true},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '9': 2, '10': 'email', '17': true},
    {'1': 'county', '3': 6, '4': 1, '5': 5, '10': 'county'},
    {'1': 'domain', '3': 7, '4': 1, '5': 9, '9': 3, '10': 'domain', '17': true},
    {
      '1': 'established',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'established',
      '17': true
    },
    {'1': 'status', '3': 9, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_motto'},
    {'1': '_phone'},
    {'1': '_email'},
    {'1': '_domain'},
    {'1': '_established'},
  ],
};

/// Descriptor for `SchoolInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schoolInsertDescriptor = $convert.base64Decode(
    'CgxTY2hvb2xJbnNlcnQSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSGQoFbW'
    '90dG8YAyABKAlIAFIFbW90dG+IAQESGQoFcGhvbmUYBCABKAlIAVIFcGhvbmWIAQESGQoFZW1h'
    'aWwYBSABKAlIAlIFZW1haWyIAQESFgoGY291bnR5GAYgASgFUgZjb3VudHkSGwoGZG9tYWluGA'
    'cgASgJSANSBmRvbWFpbogBARIlCgtlc3RhYmxpc2hlZBgIIAEoBUgEUgtlc3RhYmxpc2hlZIgB'
    'ARIWCgZzdGF0dXMYCSABKAVSBnN0YXR1c0IICgZfbW90dG9CCAoGX3Bob25lQggKBl9lbWFpbE'
    'IJCgdfZG9tYWluQg4KDF9lc3RhYmxpc2hlZA==');

@$core.Deprecated('Use ownerInsertDescriptor instead')
const OwnerInsert$json = {
  '1': 'OwnerInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
  ],
};

/// Descriptor for `OwnerInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ownerInsertDescriptor = $convert.base64Decode(
    'CgtPd25lckluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR1c2VyGAIgASgJUgR1c2'
    'Vy');

@$core.Deprecated('Use studentInsertDescriptor instead')
const StudentInsert$json = {
  '1': 'StudentInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'adm', '3': 2, '4': 1, '5': 5, '10': 'adm'},
    {'1': 'user', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'user', '17': true},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'dob', '3': 5, '4': 1, '5': 5, '9': 1, '10': 'dob', '17': true},
    {'1': 'gender', '3': 6, '4': 1, '5': 5, '9': 2, '10': 'gender', '17': true},
    {
      '1': 'documents',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'documents',
      '17': true
    },
    {
      '1': 'admitted',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'admitted',
      '17': true
    },
    {'1': 'status', '3': 9, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_user'},
    {'1': '_dob'},
    {'1': '_gender'},
    {'1': '_documents'},
    {'1': '_admitted'},
  ],
};

/// Descriptor for `StudentInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List studentInsertDescriptor = $convert.base64Decode(
    'Cg1TdHVkZW50SW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhAKA2FkbRgCIAEoBVIDYW'
    'RtEhcKBHVzZXIYAyABKAlIAFIEdXNlcogBARISCgRuYW1lGAQgASgJUgRuYW1lEhUKA2RvYhgF'
    'IAEoBUgBUgNkb2KIAQESGwoGZ2VuZGVyGAYgASgFSAJSBmdlbmRlcogBARIhCglkb2N1bWVudH'
    'MYByABKAlIA1IJZG9jdW1lbnRziAEBEh8KCGFkbWl0dGVkGAggASgFSARSCGFkbWl0dGVkiAEB'
    'EhYKBnN0YXR1cxgJIAEoBVIGc3RhdHVzQgcKBV91c2VyQgYKBF9kb2JCCQoHX2dlbmRlckIMCg'
    'pfZG9jdW1lbnRzQgsKCV9hZG1pdHRlZA==');

@$core.Deprecated('Use guardianInsertDescriptor instead')
const GuardianInsert$json = {
  '1': 'GuardianInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
    {'1': 'relationship', '3': 4, '4': 1, '5': 5, '10': 'relationship'},
    {'1': 'role', '3': 5, '4': 1, '5': 5, '10': 'role'},
  ],
};

/// Descriptor for `GuardianInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List guardianInsertDescriptor = $convert.base64Decode(
    'Cg5HdWFyZGlhbkluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR1c2VyGAIgASgJUg'
    'R1c2VyEhgKB3N0dWRlbnQYAyABKAVSB3N0dWRlbnQSIgoMcmVsYXRpb25zaGlwGAQgASgFUgxy'
    'ZWxhdGlvbnNoaXASEgoEcm9sZRgFIAEoBVIEcm9sZQ==');

@$core.Deprecated('Use departmentInsertDescriptor instead')
const DepartmentInsert$json = {
  '1': 'DepartmentInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'description',
      '17': true
    },
  ],
  '8': [
    {'1': '_description'},
  ],
};

/// Descriptor for `DepartmentInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List departmentInsertDescriptor = $convert.base64Decode(
    'ChBEZXBhcnRtZW50SW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBG5hbWUYAiABKA'
    'lSBG5hbWUSJQoLZGVzY3JpcHRpb24YAyABKAlIAFILZGVzY3JpcHRpb26IAQFCDgoMX2Rlc2Ny'
    'aXB0aW9u');

@$core.Deprecated('Use teacherInsertDescriptor instead')
const TeacherInsert$json = {
  '1': 'TeacherInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'hired', '3': 3, '4': 1, '5': 5, '9': 0, '10': 'hired', '17': true},
    {'1': 'role', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'department',
      '17': true
    },
    {'1': 'status', '3': 6, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_hired'},
    {'1': '_role'},
    {'1': '_department'},
  ],
};

/// Descriptor for `TeacherInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List teacherInsertDescriptor = $convert.base64Decode(
    'Cg1UZWFjaGVySW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHVzZXIYAiABKAlSBH'
    'VzZXISGQoFaGlyZWQYAyABKAVIAFIFaGlyZWSIAQESFwoEcm9sZRgEIAEoCUgBUgRyb2xliAEB'
    'EiMKCmRlcGFydG1lbnQYBSABKAlIAlIKZGVwYXJ0bWVudIgBARIWCgZzdGF0dXMYBiABKAVSBn'
    'N0YXR1c0IICgZfaGlyZWRCBwoFX3JvbGVCDQoLX2RlcGFydG1lbnQ=');

@$core.Deprecated('Use staffInsertDescriptor instead')
const StaffInsert$json = {
  '1': 'StaffInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {
      '1': 'idnumber',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'idnumber',
      '17': true
    },
    {'1': 'role', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'department',
      '17': true
    },
    {'1': 'status', '3': 6, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_idnumber'},
    {'1': '_role'},
    {'1': '_department'},
  ],
};

/// Descriptor for `StaffInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List staffInsertDescriptor = $convert.base64Decode(
    'CgtTdGFmZkluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR1c2VyGAIgASgJUgR1c2'
    'VyEh8KCGlkbnVtYmVyGAMgASgJSABSCGlkbnVtYmVyiAEBEhcKBHJvbGUYBCABKAlIAVIEcm9s'
    'ZYgBARIjCgpkZXBhcnRtZW50GAUgASgJSAJSCmRlcGFydG1lbnSIAQESFgoGc3RhdHVzGAYgAS'
    'gFUgZzdGF0dXNCCwoJX2lkbnVtYmVyQgcKBV9yb2xlQg0KC19kZXBhcnRtZW50');

@$core.Deprecated('Use termInsertDescriptor instead')
const TermInsert$json = {
  '1': 'TermInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 5, '4': 1, '5': 3, '10': 'end'},
  ],
};

/// Descriptor for `TermInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List termInsertDescriptor = $convert.base64Decode(
    'CgpUZXJtSW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYXIYAiABKAVSBHllYX'
    'ISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVzdGFydBgEIAEoA1IFc3RhcnQSEAoDZW5kGAUgASgD'
    'UgNlbmQ=');

@$core.Deprecated('Use classTeacherInsertDescriptor instead')
const ClassTeacherInsert$json = {
  '1': 'ClassTeacherInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'teacher', '3': 6, '4': 1, '5': 9, '10': 'teacher'},
    {'1': 'start', '3': 7, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 8, '4': 1, '5': 5, '9': 0, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_end'},
  ],
};

/// Descriptor for `ClassTeacherInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List classTeacherInsertDescriptor = $convert.base64Decode(
    'ChJDbGFzc1RlYWNoZXJJbnNlcnQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEeWVhchgCIA'
    'EoBVIEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVncmFkZRIWCgZz'
    'dHJlYW0YBSABKAVSBnN0cmVhbRIYCgd0ZWFjaGVyGAYgASgJUgd0ZWFjaGVyEhQKBXN0YXJ0GA'
    'cgASgFUgVzdGFydBIVCgNlbmQYCCABKAVIAFIDZW5kiAEBQgYKBF9lbmQ=');

@$core.Deprecated('Use enrollmentInsertDescriptor instead')
const EnrollmentInsert$json = {
  '1': 'EnrollmentInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'student', '3': 6, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `EnrollmentInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enrollmentInsertDescriptor = $convert.base64Decode(
    'ChBFbnJvbGxtZW50SW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYXIYAiABKA'
    'VSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUSFgoGc3Ry'
    'ZWFtGAUgASgFUgZzdHJlYW0SGAoHc3R1ZGVudBgGIAEoBVIHc3R1ZGVudA==');

@$core.Deprecated('Use subjectTeacherInsertDescriptor instead')
const SubjectTeacherInsert$json = {
  '1': 'SubjectTeacherInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 7, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `SubjectTeacherInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subjectTeacherInsertDescriptor = $convert.base64Decode(
    'ChRTdWJqZWN0VGVhY2hlckluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgR5ZWFyGA'
    'IgASgFUgR5ZWFyEhIKBHRlcm0YAyABKAVSBHRlcm0SFAoFZ3JhZGUYBCABKAVSBWdyYWRlEhYK'
    'BnN0cmVhbRgFIAEoBVIGc3RyZWFtEhgKB3N1YmplY3QYBiABKAVSB3N1YmplY3QSGAoHdGVhY2'
    'hlchgHIAEoCVIHdGVhY2hlcg==');

@$core.Deprecated('Use attendanceInsertDescriptor instead')
const AttendanceInsert$json = {
  '1': 'AttendanceInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'student', '3': 6, '4': 1, '5': 5, '10': 'student'},
    {'1': 'date', '3': 7, '4': 1, '5': 5, '10': 'date'},
    {'1': 'status', '3': 8, '4': 1, '5': 5, '10': 'status'},
  ],
};

/// Descriptor for `AttendanceInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attendanceInsertDescriptor = $convert.base64Decode(
    'ChBBdHRlbmRhbmNlSW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYXIYAiABKA'
    'VSBHllYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUSFgoGc3Ry'
    'ZWFtGAUgASgFUgZzdHJlYW0SGAoHc3R1ZGVudBgGIAEoBVIHc3R1ZGVudBISCgRkYXRlGAcgAS'
    'gFUgRkYXRlEhYKBnN0YXR1cxgIIAEoBVIGc3RhdHVz');

@$core.Deprecated('Use timetableInsertDescriptor instead')
const TimetableInsert$json = {
  '1': 'TimetableInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'subject', '3': 6, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 7, '4': 1, '5': 9, '10': 'teacher'},
    {'1': 'day', '3': 8, '4': 1, '5': 5, '10': 'day'},
    {'1': 'start', '3': 9, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 10, '4': 1, '5': 5, '10': 'end'},
  ],
};

/// Descriptor for `TimetableInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timetableInsertDescriptor = $convert.base64Decode(
    'Cg9UaW1ldGFibGVJbnNlcnQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEeWVhchgCIAEoBV'
    'IEeWVhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVncmFkZRIWCgZzdHJl'
    'YW0YBSABKAVSBnN0cmVhbRIYCgdzdWJqZWN0GAYgASgFUgdzdWJqZWN0EhgKB3RlYWNoZXIYBy'
    'ABKAlSB3RlYWNoZXISEAoDZGF5GAggASgFUgNkYXkSFAoFc3RhcnQYCSABKAVSBXN0YXJ0EhAK'
    'A2VuZBgKIAEoBVIDZW5k');

@$core.Deprecated('Use lessonInsertDescriptor instead')
const LessonInsert$json = {
  '1': 'LessonInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'date', '3': 6, '4': 1, '5': 5, '10': 'date'},
    {'1': 'subject', '3': 7, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'teacher', '3': 8, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `LessonInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lessonInsertDescriptor = $convert.base64Decode(
    'CgxMZXNzb25JbnNlcnQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEeWVhchgCIAEoBVIEeW'
    'VhchISCgR0ZXJtGAMgASgFUgR0ZXJtEhQKBWdyYWRlGAQgASgFUgVncmFkZRIWCgZzdHJlYW0Y'
    'BSABKAVSBnN0cmVhbRISCgRkYXRlGAYgASgFUgRkYXRlEhgKB3N1YmplY3QYByABKAVSB3N1Ym'
    'plY3QSGAoHdGVhY2hlchgIIAEoCVIHdGVhY2hlcg==');

@$core.Deprecated('Use examInsertDescriptor instead')
const ExamInsert$json = {
  '1': 'ExamInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'year', '3': 4, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 5, '4': 1, '5': 5, '10': 'term'},
    {'1': 'personalized', '3': 6, '4': 1, '5': 8, '10': 'personalized'},
    {'1': 'type', '3': 7, '4': 1, '5': 5, '10': 'type'},
    {'1': 'start', '3': 8, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 9, '4': 1, '5': 5, '10': 'end'},
    {'1': 'teacher', '3': 10, '4': 1, '5': 9, '10': 'teacher'},
  ],
};

/// Descriptor for `ExamInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List examInsertDescriptor = $convert.base64Decode(
    'CgpFeGFtSW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBIWCgZzY2hvb2wYAiABKAlSBnNjaG9vbBISCg'
    'RuYW1lGAMgASgJUgRuYW1lEhIKBHllYXIYBCABKAVSBHllYXISEgoEdGVybRgFIAEoBVIEdGVy'
    'bRIiCgxwZXJzb25hbGl6ZWQYBiABKAhSDHBlcnNvbmFsaXplZBISCgR0eXBlGAcgASgFUgR0eX'
    'BlEhQKBXN0YXJ0GAggASgFUgVzdGFydBIQCgNlbmQYCSABKAVSA2VuZBIYCgd0ZWFjaGVyGAog'
    'ASgJUgd0ZWFjaGVy');

@$core.Deprecated('Use paperInsertDescriptor instead')
const PaperInsert$json = {
  '1': 'PaperInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'topic', '3': 5, '4': 1, '5': 5, '9': 1, '10': 'topic', '17': true},
    {'1': 'invigilator', '3': 6, '4': 1, '5': 9, '10': 'invigilator'},
    {'1': 'start', '3': 7, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 8, '4': 1, '5': 3, '10': 'end'},
    {'1': 'status', '3': 9, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_paper'},
    {'1': '_topic'},
  ],
};

/// Descriptor for `PaperInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperInsertDescriptor = $convert.base64Decode(
    'CgtQYXBlckluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGAIgASgJUgRleG'
    'FtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCABKAVIAFIFcGFwZXKIAQES'
    'GQoFdG9waWMYBSABKAVIAVIFdG9waWOIAQESIAoLaW52aWdpbGF0b3IYBiABKAlSC2ludmlnaW'
    'xhdG9yEhQKBXN0YXJ0GAcgASgDUgVzdGFydBIQCgNlbmQYCCABKANSA2VuZBIWCgZzdGF0dXMY'
    'CSABKAVSBnN0YXR1c0IICgZfcGFwZXJCCAoGX3RvcGlj');

@$core.Deprecated('Use gradeInsertDescriptor instead')
const GradeInsert$json = {
  '1': 'GradeInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'student', '3': 3, '4': 1, '5': 5, '10': 'student'},
    {'1': 'subject', '3': 4, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'score', '3': 6, '4': 1, '5': 2, '10': 'score'},
    {'1': 'total', '3': 7, '4': 1, '5': 5, '10': 'total'},
  ],
  '8': [
    {'1': '_paper'},
  ],
};

/// Descriptor for `GradeInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gradeInsertDescriptor = $convert.base64Decode(
    'CgtHcmFkZUluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGAIgASgJUgRleG'
    'FtEhgKB3N0dWRlbnQYAyABKAVSB3N0dWRlbnQSGAoHc3ViamVjdBgEIAEoBVIHc3ViamVjdBIZ'
    'CgVwYXBlchgFIAEoBUgAUgVwYXBlcogBARIUCgVzY29yZRgGIAEoAlIFc2NvcmUSFAoFdG90YW'
    'wYByABKAVSBXRvdGFsQggKBl9wYXBlcg==');

@$core.Deprecated('Use feeInsertDescriptor instead')
const FeeInsert$json = {
  '1': 'FeeInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'title', '3': 6, '4': 1, '5': 9, '10': 'title'},
    {'1': 'description', '3': 7, '4': 1, '5': 9, '10': 'description'},
    {'1': 'amount', '3': 8, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'mandatory', '3': 9, '4': 1, '5': 8, '10': 'mandatory'},
    {'1': 'due', '3': 10, '4': 1, '5': 3, '10': 'due'},
  ],
};

/// Descriptor for `FeeInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feeInsertDescriptor = $convert.base64Decode(
    'CglGZWVJbnNlcnQSDgoCaWQYASABKAlSAmlkEhYKBnNjaG9vbBgCIAEoCVIGc2Nob29sEhIKBH'
    'llYXIYAyABKAVSBHllYXISEgoEdGVybRgEIAEoBVIEdGVybRIUCgVncmFkZRgFIAEoBVIFZ3Jh'
    'ZGUSFAoFdGl0bGUYBiABKAlSBXRpdGxlEiAKC2Rlc2NyaXB0aW9uGAcgASgJUgtkZXNjcmlwdG'
    'lvbhIWCgZhbW91bnQYCCABKAJSBmFtb3VudBIcCgltYW5kYXRvcnkYCSABKAhSCW1hbmRhdG9y'
    'eRIQCgNkdWUYCiABKANSA2R1ZQ==');

@$core.Deprecated('Use invoiceInsertDescriptor instead')
const InvoiceInsert$json = {
  '1': 'InvoiceInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'fee', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'fee', '17': true},
    {
      '1': 'description',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'student', '3': 7, '4': 1, '5': 5, '10': 'student'},
    {'1': 'amount', '3': 8, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'status', '3': 9, '4': 1, '5': 5, '10': 'status'},
    {'1': 'due', '3': 10, '4': 1, '5': 3, '9': 2, '10': 'due', '17': true},
  ],
  '8': [
    {'1': '_fee'},
    {'1': '_description'},
    {'1': '_due'},
  ],
};

/// Descriptor for `InvoiceInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List invoiceInsertDescriptor = $convert.base64Decode(
    'Cg1JbnZvaWNlSW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBIWCgZzY2hvb2wYAiABKAlSBnNjaG9vbB'
    'ISCgR5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SFQoDZmVlGAUgASgJSABS'
    'A2ZlZYgBARIlCgtkZXNjcmlwdGlvbhgGIAEoCUgBUgtkZXNjcmlwdGlvbogBARIYCgdzdHVkZW'
    '50GAcgASgFUgdzdHVkZW50EhYKBmFtb3VudBgIIAEoAlIGYW1vdW50EhYKBnN0YXR1cxgJIAEo'
    'BVIGc3RhdHVzEhUKA2R1ZRgKIAEoA0gCUgNkdWWIAQFCBgoEX2ZlZUIOCgxfZGVzY3JpcHRpb2'
    '5CBgoEX2R1ZQ==');

@$core.Deprecated('Use paymentInsertDescriptor instead')
const PaymentInsert$json = {
  '1': 'PaymentInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'invoice',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {'1': 'school', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'school', '17': true},
    {
      '1': 'student',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'student',
      '17': true
    },
    {'1': 'amount', '3': 5, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'method', '3': 6, '4': 1, '5': 5, '10': 'method'},
    {
      '1': 'reference',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'reference',
      '17': true
    },
    {
      '1': 'recorder',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'recorder',
      '17': true
    },
    {'1': 'date', '3': 9, '4': 1, '5': 5, '9': 5, '10': 'date', '17': true},
  ],
  '8': [
    {'1': '_invoice'},
    {'1': '_school'},
    {'1': '_student'},
    {'1': '_reference'},
    {'1': '_recorder'},
    {'1': '_date'},
  ],
};

/// Descriptor for `PaymentInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentInsertDescriptor = $convert.base64Decode(
    'Cg1QYXltZW50SW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBIdCgdpbnZvaWNlGAIgASgJSABSB2ludm'
    '9pY2WIAQESGwoGc2Nob29sGAMgASgJSAFSBnNjaG9vbIgBARIdCgdzdHVkZW50GAQgASgFSAJS'
    'B3N0dWRlbnSIAQESFgoGYW1vdW50GAUgASgCUgZhbW91bnQSFgoGbWV0aG9kGAYgASgFUgZtZX'
    'Rob2QSIQoJcmVmZXJlbmNlGAcgASgJSANSCXJlZmVyZW5jZYgBARIfCghyZWNvcmRlchgIIAEo'
    'CUgEUghyZWNvcmRlcogBARIXCgRkYXRlGAkgASgFSAVSBGRhdGWIAQFCCgoIX2ludm9pY2VCCQ'
    'oHX3NjaG9vbEIKCghfc3R1ZGVudEIMCgpfcmVmZXJlbmNlQgsKCV9yZWNvcmRlckIHCgVfZGF0'
    'ZQ==');

@$core.Deprecated('Use announcementInsertDescriptor instead')
const AnnouncementInsert$json = {
  '1': 'AnnouncementInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'grade', '17': true},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'audience', '3': 7, '4': 1, '5': 5, '10': 'audience'},
    {'1': 'author', '3': 8, '4': 1, '5': 9, '9': 2, '10': 'author', '17': true},
  ],
  '8': [
    {'1': '_grade'},
    {'1': '_stream'},
    {'1': '_author'},
  ],
};

/// Descriptor for `AnnouncementInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List announcementInsertDescriptor = $convert.base64Decode(
    'ChJBbm5vdW5jZW1lbnRJbnNlcnQSDgoCaWQYASABKAlSAmlkEhYKBnNjaG9vbBgCIAEoCVIGc2'
    'Nob29sEhQKBXRpdGxlGAMgASgJUgV0aXRsZRIYCgdjb250ZW50GAQgASgJUgdjb250ZW50EhkK'
    'BWdyYWRlGAUgASgFSABSBWdyYWRliAEBEhsKBnN0cmVhbRgGIAEoBUgBUgZzdHJlYW2IAQESGg'
    'oIYXVkaWVuY2UYByABKAVSCGF1ZGllbmNlEhsKBmF1dGhvchgIIAEoCUgCUgZhdXRob3KIAQFC'
    'CAoGX2dyYWRlQgkKB19zdHJlYW1CCQoHX2F1dGhvcg==');

@$core.Deprecated('Use masteryInsertDescriptor instead')
const MasteryInsert$json = {
  '1': 'MasteryInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'student', '3': 2, '4': 1, '5': 5, '10': 'student'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'topic', '3': 4, '4': 1, '5': 5, '10': 'topic'},
    {'1': 'score', '3': 5, '4': 1, '5': 2, '10': 'score'},
  ],
};

/// Descriptor for `MasteryInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List masteryInsertDescriptor = $convert.base64Decode(
    'Cg1NYXN0ZXJ5SW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhgKB3N0dWRlbnQYAiABKA'
    'VSB3N0dWRlbnQSGAoHc3ViamVjdBgDIAEoBVIHc3ViamVjdBIUCgV0b3BpYxgEIAEoBVIFdG9w'
    'aWMSFAoFc2NvcmUYBSABKAJSBXNjb3Jl');

@$core.Deprecated('Use aiUsageInsertDescriptor instead')
const AiUsageInsert$json = {
  '1': 'AiUsageInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'student', '3': 2, '4': 1, '5': 5, '10': 'student'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'allocated', '3': 5, '4': 1, '5': 5, '10': 'allocated'},
    {'1': 'used', '3': 6, '4': 1, '5': 5, '10': 'used'},
  ],
};

/// Descriptor for `AiUsageInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List aiUsageInsertDescriptor = $convert.base64Decode(
    'Cg1BaVVzYWdlSW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhgKB3N0dWRlbnQYAiABKA'
    'VSB3N0dWRlbnQSEgoEeWVhchgDIAEoBVIEeWVhchISCgR0ZXJtGAQgASgFUgR0ZXJtEhwKCWFs'
    'bG9jYXRlZBgFIAEoBVIJYWxsb2NhdGVkEhIKBHVzZWQYBiABKAVSBHVzZWQ=');

@$core.Deprecated('Use subjectInsertDescriptor instead')
const SubjectInsert$json = {
  '1': 'SubjectInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'curriculum', '3': 3, '4': 1, '5': 5, '10': 'curriculum'},
  ],
};

/// Descriptor for `SubjectInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subjectInsertDescriptor = $convert.base64Decode(
    'Cg1TdWJqZWN0SW5zZXJ0Eg4KAmlkGAEgASgFUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh4KCm'
    'N1cnJpY3VsdW0YAyABKAVSCmN1cnJpY3VsdW0=');

@$core.Deprecated('Use topicInsertDescriptor instead')
const TopicInsert$json = {
  '1': 'TopicInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'subject', '3': 2, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `TopicInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List topicInsertDescriptor = $convert.base64Decode(
    'CgtUb3BpY0luc2VydBIOCgJpZBgBIAEoBVICaWQSGAoHc3ViamVjdBgCIAEoBVIHc3ViamVjdB'
    'IUCgVncmFkZRgDIAEoBVIFZ3JhZGUSEgoEbmFtZRgEIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use streamInsertDescriptor instead')
const StreamInsert$json = {
  '1': 'StreamInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `StreamInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamInsertDescriptor = $convert.base64Decode(
    'CgxTdHJlYW1JbnNlcnQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSFAoFZ3JhZGUYAiABKAVSBW'
    'dyYWRlEhYKBnN0cmVhbRgDIAEoBVIGc3RyZWFtEhIKBG5hbWUYBCABKAlSBG5hbWU=');

@$core.Deprecated('Use mpesaInsertDescriptor instead')
const MpesaInsert$json = {
  '1': 'MpesaInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'consumer_key', '3': 2, '4': 1, '5': 9, '10': 'consumerKey'},
    {'1': 'consumer_secret', '3': 3, '4': 1, '5': 9, '10': 'consumerSecret'},
    {'1': 'passkey', '3': 4, '4': 1, '5': 9, '10': 'passkey'},
    {'1': 'shortcode', '3': 5, '4': 1, '5': 9, '10': 'shortcode'},
    {'1': 'env', '3': 6, '4': 1, '5': 5, '10': 'env'},
  ],
};

/// Descriptor for `MpesaInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mpesaInsertDescriptor = $convert.base64Decode(
    'CgtNcGVzYUluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIhCgxjb25zdW1lcl9rZXkYAi'
    'ABKAlSC2NvbnN1bWVyS2V5EicKD2NvbnN1bWVyX3NlY3JldBgDIAEoCVIOY29uc3VtZXJTZWNy'
    'ZXQSGAoHcGFzc2tleRgEIAEoCVIHcGFzc2tleRIcCglzaG9ydGNvZGUYBSABKAlSCXNob3J0Y2'
    '9kZRIQCgNlbnYYBiABKAVSA2Vudg==');

@$core.Deprecated('Use examGradeInsertDescriptor instead')
const ExamGradeInsert$json = {
  '1': 'ExamGradeInsert',
  '2': [
    {'1': 'exam', '3': 1, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'grade', '3': 2, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 3, '4': 1, '5': 5, '10': 'stream'},
  ],
};

/// Descriptor for `ExamGradeInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List examGradeInsertDescriptor = $convert.base64Decode(
    'Cg9FeGFtR3JhZGVJbnNlcnQSEgoEZXhhbRgBIAEoCVIEZXhhbRIUCgVncmFkZRgCIAEoBVIFZ3'
    'JhZGUSFgoGc3RyZWFtGAMgASgFUgZzdHJlYW0=');

@$core.Deprecated('Use roleInsertDescriptor instead')
const RoleInsert$json = {
  '1': 'RoleInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'school', '17': true},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'permissions', '3': 5, '4': 1, '5': 12, '10': 'permissions'},
  ],
  '8': [
    {'1': '_school'},
    {'1': '_description'},
  ],
};

/// Descriptor for `RoleInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roleInsertDescriptor = $convert.base64Decode(
    'CgpSb2xlSW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBIbCgZzY2hvb2wYAiABKAlIAFIGc2Nob29siA'
    'EBEhIKBG5hbWUYAyABKAlSBG5hbWUSJQoLZGVzY3JpcHRpb24YBCABKAlIAVILZGVzY3JpcHRp'
    'b26IAQESIAoLcGVybWlzc2lvbnMYBSABKAxSC3Blcm1pc3Npb25zQgkKB19zY2hvb2xCDgoMX2'
    'Rlc2NyaXB0aW9u');

@$core.Deprecated('Use scopeInsertDescriptor instead')
const ScopeInsert$json = {
  '1': 'ScopeInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'school', '17': true},
    {'1': 'user', '3': 2, '4': 1, '5': 9, '10': 'user'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
  ],
  '8': [
    {'1': '_school'},
  ],
};

/// Descriptor for `ScopeInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scopeInsertDescriptor = $convert.base64Decode(
    'CgtTY29wZUluc2VydBIbCgZzY2hvb2wYASABKAlIAFIGc2Nob29siAEBEhIKBHVzZXIYAiABKA'
    'lSBHVzZXISEgoEcm9sZRgDIAEoCVIEcm9sZUIJCgdfc2Nob29s');

@$core.Deprecated('Use planInsertDescriptor instead')
const PlanInsert$json = {
  '1': 'PlanInsert',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'description',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 4, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'levels', '3': 5, '4': 1, '5': 5, '10': 'levels'},
    {'1': 'status', '3': 6, '4': 1, '5': 5, '10': 'status'},
    {
      '1': 'features',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'features',
      '17': true
    },
  ],
  '8': [
    {'1': '_description'},
    {'1': '_features'},
  ],
};

/// Descriptor for `PlanInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planInsertDescriptor = $convert.base64Decode(
    'CgpQbGFuSW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEiUKC2Rlc2'
    'NyaXB0aW9uGAMgASgJSABSC2Rlc2NyaXB0aW9uiAEBEhYKBmFtb3VudBgEIAEoAlIGYW1vdW50'
    'EhYKBmxldmVscxgFIAEoBVIGbGV2ZWxzEhYKBnN0YXR1cxgGIAEoBVIGc3RhdHVzEh8KCGZlYX'
    'R1cmVzGAcgASgJSAFSCGZlYXR1cmVziAEBQg4KDF9kZXNjcmlwdGlvbkILCglfZmVhdHVyZXM=');

@$core.Deprecated('Use subscriptionInsertDescriptor instead')
const SubscriptionInsert$json = {
  '1': 'SubscriptionInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'student', '3': 5, '4': 1, '5': 5, '10': 'student'},
    {
      '1': 'invoice',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {'1': 'discount', '3': 7, '4': 1, '5': 2, '10': 'discount'},
    {'1': 'status', '3': 8, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_invoice'},
  ],
};

/// Descriptor for `SubscriptionInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionInsertDescriptor = $convert.base64Decode(
    'ChJTdWJzY3JpcHRpb25JbnNlcnQSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEcGxhbhgCIA'
    'EoCVIEcGxhbhISCgR5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SGAoHc3R1'
    'ZGVudBgFIAEoBVIHc3R1ZGVudBIdCgdpbnZvaWNlGAYgASgJSABSB2ludm9pY2WIAQESGgoIZG'
    'lzY291bnQYByABKAJSCGRpc2NvdW50EhYKBnN0YXR1cxgIIAEoBVIGc3RhdHVzQgoKCF9pbnZv'
    'aWNl');

@$core.Deprecated('Use discountInsertDescriptor instead')
const DiscountInsert$json = {
  '1': 'DiscountInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'plan', '3': 2, '4': 1, '5': 9, '10': 'plan'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'amount', '3': 6, '4': 1, '5': 2, '10': 'amount'},
    {'1': 'unit', '3': 7, '4': 1, '5': 5, '10': 'unit'},
  ],
};

/// Descriptor for `DiscountInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discountInsertDescriptor = $convert.base64Decode(
    'Cg5EaXNjb3VudEluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRwbGFuGAIgASgJUg'
    'RwbGFuEhIKBHllYXIYAyABKAVSBHllYXISEgoEdGVybRgEIAEoBVIEdGVybRIUCgVncmFkZRgF'
    'IAEoBVIFZ3JhZGUSFgoGYW1vdW50GAYgASgCUgZhbW91bnQSEgoEdW5pdBgHIAEoBVIEdW5pdA'
    '==');
