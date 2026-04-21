// This is a generated file - do not edit.
//
// Generated from types/role.proto.

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

@$core.Deprecated('Use resourceDescriptor instead')
const Resource$json = {
  '1': 'Resource',
  '2': [
    {'1': 'USERS', '2': 0},
    {'1': 'SCHOOLS', '2': 1},
    {'1': 'OWNERS', '2': 2},
    {'1': 'TEACHERS', '2': 3},
    {'1': 'STAFF', '2': 4},
    {'1': 'STUDENTS', '2': 5},
    {'1': 'DEPARTMENTS', '2': 6},
    {'1': 'CLASSES', '2': 7},
    {'1': 'ATTENDANCE', '2': 8},
    {'1': 'LESSONS', '2': 9},
    {'1': 'EXAMS', '2': 10},
    {'1': 'GRADES', '2': 11},
    {'1': 'FEES', '2': 12},
    {'1': 'PAYMENTS', '2': 13},
    {'1': 'ANNOUNCEMENTS', '2': 14},
    {'1': 'ROLES', '2': 15},
    {'1': 'PLANS', '2': 16},
    {'1': 'AI', '2': 17},
    {'1': 'SUBJECTS', '2': 18},
  ],
};

/// Descriptor for `Resource`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List resourceDescriptor = $convert.base64Decode(
    'CghSZXNvdXJjZRIJCgVVU0VSUxAAEgsKB1NDSE9PTFMQARIKCgZPV05FUlMQAhIMCghURUFDSE'
    'VSUxADEgkKBVNUQUZGEAQSDAoIU1RVREVOVFMQBRIPCgtERVBBUlRNRU5UUxAGEgsKB0NMQVNT'
    'RVMQBxIOCgpBVFRFTkRBTkNFEAgSCwoHTEVTU09OUxAJEgkKBUVYQU1TEAoSCgoGR1JBREVTEA'
    'sSCAoERkVFUxAMEgwKCFBBWU1FTlRTEA0SEQoNQU5OT1VOQ0VNRU5UUxAOEgkKBVJPTEVTEA8S'
    'CQoFUExBTlMQEBIGCgJBSRAREgwKCFNVQkpFQ1RTEBI=');

@$core.Deprecated('Use actionDescriptor instead')
const Action$json = {
  '1': 'Action',
  '2': [
    {'1': 'CREATE', '2': 0},
    {'1': 'READ', '2': 1},
    {'1': 'UPDATE', '2': 2},
    {'1': 'DELETE', '2': 3},
    {'1': 'PURGE', '2': 4},
    {'1': 'ASSIGN', '2': 5},
    {'1': 'UNASSIGN', '2': 6},
    {'1': 'MARK', '2': 7},
    {'1': 'APPROVE', '2': 8},
  ],
};

/// Descriptor for `Action`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List actionDescriptor = $convert.base64Decode(
    'CgZBY3Rpb24SCgoGQ1JFQVRFEAASCAoEUkVBRBABEgoKBlVQREFURRACEgoKBkRFTEVURRADEg'
    'kKBVBVUkdFEAQSCgoGQVNTSUdOEAUSDAoIVU5BU1NJR04QBhIICgRNQVJLEAcSCwoHQVBQUk9W'
    'RRAI');

@$core.Deprecated('Use permissionDescriptor instead')
const Permission$json = {
  '1': 'Permission',
  '2': [
    {
      '1': 'resource',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.role.Resource',
      '10': 'resource'
    },
    {
      '1': 'actions',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.role.Action',
      '10': 'actions'
    },
  ],
};

/// Descriptor for `Permission`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List permissionDescriptor = $convert.base64Decode(
    'CgpQZXJtaXNzaW9uEioKCHJlc291cmNlGAEgASgOMg4ucm9sZS5SZXNvdXJjZVIIcmVzb3VyY2'
    'USJgoHYWN0aW9ucxgCIAMoDjIMLnJvbGUuQWN0aW9uUgdhY3Rpb25z');

@$core.Deprecated('Use roleDescriptor instead')
const Role$json = {
  '1': 'Role',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'permissions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.role.Permission',
      '10': 'permissions'
    },
    {'1': 'created', '3': 4, '4': 1, '5': 3, '10': 'created'},
  ],
};

/// Descriptor for `Role`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roleDescriptor = $convert.base64Decode(
    'CgRSb2xlEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEjIKC3Blcm1pc3Npb2'
    '5zGAMgAygLMhAucm9sZS5QZXJtaXNzaW9uUgtwZXJtaXNzaW9ucxIYCgdjcmVhdGVkGAQgASgD'
    'UgdjcmVhdGVk');

@$core.Deprecated('Use assignmentDescriptor instead')
const Assignment$json = {
  '1': 'Assignment',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'assigned', '3': 3, '4': 1, '5': 3, '10': 'assigned'},
    {
      '1': 'profile',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'profile',
      '17': true
    },
  ],
  '8': [
    {'1': '_profile'},
  ],
};

/// Descriptor for `Assignment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignmentDescriptor = $convert.base64Decode(
    'CgpBc3NpZ25tZW50Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEhoKCGFzc2'
    'lnbmVkGAMgASgDUghhc3NpZ25lZBIdCgdwcm9maWxlGAQgASgJSABSB3Byb2ZpbGWIAQFCCgoI'
    'X3Byb2ZpbGU=');
