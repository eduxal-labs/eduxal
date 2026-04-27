// This is a generated file - do not edit.
//
// Generated from types/event.proto.

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

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 4, '4': 1, '5': 5, '10': 'type'},
    {'1': 'term', '3': 5, '4': 1, '5': 5, '10': 'term'},
    {'1': 'year', '3': 6, '4': 1, '5': 5, '10': 'year'},
    {'1': 'start_date', '3': 7, '4': 1, '5': 5, '10': 'startDate'},
    {'1': 'end_date', '3': 8, '4': 1, '5': 5, '10': 'endDate'},
    {'1': 'status', '3': 9, '4': 1, '5': 5, '10': 'status'},
    {'1': 'created', '3': 10, '4': 1, '5': 3, '10': 'created'},
    {'1': 'updated', '3': 11, '4': 1, '5': 3, '10': 'updated'},
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBIOCgJpZBgBIAEoCVICaWQSFgoGc2Nob29sGAIgASgJUgZzY2hvb2wSEgoEbmFtZR'
    'gDIAEoCVIEbmFtZRISCgR0eXBlGAQgASgFUgR0eXBlEhIKBHRlcm0YBSABKAVSBHRlcm0SEgoE'
    'eWVhchgGIAEoBVIEeWVhchIdCgpzdGFydF9kYXRlGAcgASgFUglzdGFydERhdGUSGQoIZW5kX2'
    'RhdGUYCCABKAVSB2VuZERhdGUSFgoGc3RhdHVzGAkgASgFUgZzdGF0dXMSGAoHY3JlYXRlZBgK'
    'IAEoA1IHY3JlYXRlZBIYCgd1cGRhdGVkGAsgASgDUgd1cGRhdGVk');
