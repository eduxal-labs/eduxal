// This is a generated file - do not edit.
//
// Generated from types/paper.proto.

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

@$core.Deprecated('Use paperDescriptor instead')
const Paper$json = {
  '1': 'Paper',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'school', '3': 2, '4': 1, '5': 9, '10': 'school'},
    {'1': 'event', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'event', '17': true},
    {'1': 'subject', '3': 4, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 1, '10': 'stream', '17': true},
    {'1': 'type', '3': 7, '4': 1, '5': 5, '10': 'type'},
    {'1': 'teacher', '3': 8, '4': 1, '5': 9, '10': 'teacher'},
    {'1': 'name', '3': 9, '4': 1, '5': 9, '10': 'name'},
    {'1': 'total_marks', '3': 10, '4': 1, '5': 5, '10': 'totalMarks'},
    {'1': 'duration_minutes', '3': 11, '4': 1, '5': 5, '10': 'durationMinutes'},
    {'1': 'date', '3': 12, '4': 1, '5': 5, '10': 'date'},
    {'1': 'status', '3': 13, '4': 1, '5': 5, '10': 'status'},
    {
      '1': 'pdf_key',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'pdfKey',
      '17': true
    },
    {'1': 'ms_key', '3': 15, '4': 1, '5': 9, '9': 3, '10': 'msKey', '17': true},
    {'1': 'generation_mode', '3': 16, '4': 1, '5': 5, '10': 'generationMode'},
    {
      '1': 'instructions',
      '3': 17,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'instructions',
      '17': true
    },
    {'1': 'created', '3': 18, '4': 1, '5': 3, '10': 'created'},
    {'1': 'updated', '3': 19, '4': 1, '5': 3, '10': 'updated'},
  ],
  '8': [
    {'1': '_event'},
    {'1': '_stream'},
    {'1': '_pdf_key'},
    {'1': '_ms_key'},
    {'1': '_instructions'},
  ],
};

/// Descriptor for `Paper`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperDescriptor = $convert.base64Decode(
    'CgVQYXBlchIOCgJpZBgBIAEoCVICaWQSFgoGc2Nob29sGAIgASgJUgZzY2hvb2wSGQoFZXZlbn'
    'QYAyABKAlIAFIFZXZlbnSIAQESGAoHc3ViamVjdBgEIAEoBVIHc3ViamVjdBIUCgVncmFkZRgF'
    'IAEoBVIFZ3JhZGUSGwoGc3RyZWFtGAYgASgFSAFSBnN0cmVhbYgBARISCgR0eXBlGAcgASgFUg'
    'R0eXBlEhgKB3RlYWNoZXIYCCABKAlSB3RlYWNoZXISEgoEbmFtZRgJIAEoCVIEbmFtZRIfCgt0'
    'b3RhbF9tYXJrcxgKIAEoBVIKdG90YWxNYXJrcxIpChBkdXJhdGlvbl9taW51dGVzGAsgASgFUg'
    '9kdXJhdGlvbk1pbnV0ZXMSEgoEZGF0ZRgMIAEoBVIEZGF0ZRIWCgZzdGF0dXMYDSABKAVSBnN0'
    'YXR1cxIcCgdwZGZfa2V5GA4gASgJSAJSBnBkZktleYgBARIaCgZtc19rZXkYDyABKAlIA1IFbX'
    'NLZXmIAQESJwoPZ2VuZXJhdGlvbl9tb2RlGBAgASgFUg5nZW5lcmF0aW9uTW9kZRInCgxpbnN0'
    'cnVjdGlvbnMYESABKAlIBFIMaW5zdHJ1Y3Rpb25ziAEBEhgKB2NyZWF0ZWQYEiABKANSB2NyZW'
    'F0ZWQSGAoHdXBkYXRlZBgTIAEoA1IHdXBkYXRlZEIICgZfZXZlbnRCCQoHX3N0cmVhbUIKCghf'
    'cGRmX2tleUIJCgdfbXNfa2V5Qg8KDV9pbnN0cnVjdGlvbnM=');
