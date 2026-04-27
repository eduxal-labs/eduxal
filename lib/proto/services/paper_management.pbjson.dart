// This is a generated file - do not edit.
//
// Generated from services/paper_management.proto.

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

@$core.Deprecated('Use schedulePaperRequestDescriptor instead')
const SchedulePaperRequest$json = {
  '1': 'SchedulePaperRequest',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'subject', '3': 2, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'stream', '17': true},
    {'1': 'date', '3': 5, '4': 1, '5': 5, '10': 'date'},
    {'1': 'start_time', '3': 6, '4': 1, '5': 5, '10': 'startTime'},
    {'1': 'end_time', '3': 7, '4': 1, '5': 5, '10': 'endTime'},
    {'1': 'duration_minutes', '3': 8, '4': 1, '5': 5, '10': 'durationMinutes'},
    {
      '1': 'invigilator',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'invigilator',
      '17': true
    },
    {'1': 'reveal_at', '3': 10, '4': 1, '5': 3, '10': 'revealAt'},
    {'1': 'generate_at', '3': 11, '4': 1, '5': 3, '10': 'generateAt'},
  ],
  '8': [
    {'1': '_stream'},
    {'1': '_invigilator'},
  ],
};

/// Descriptor for `SchedulePaperRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schedulePaperRequestDescriptor = $convert.base64Decode(
    'ChRTY2hlZHVsZVBhcGVyUmVxdWVzdBIZCghldmVudF9pZBgBIAEoCVIHZXZlbnRJZBIYCgdzdW'
    'JqZWN0GAIgASgFUgdzdWJqZWN0EhQKBWdyYWRlGAMgASgFUgVncmFkZRIbCgZzdHJlYW0YBCAB'
    'KAVIAFIGc3RyZWFtiAEBEhIKBGRhdGUYBSABKAVSBGRhdGUSHQoKc3RhcnRfdGltZRgGIAEoBV'
    'IJc3RhcnRUaW1lEhkKCGVuZF90aW1lGAcgASgFUgdlbmRUaW1lEikKEGR1cmF0aW9uX21pbnV0'
    'ZXMYCCABKAVSD2R1cmF0aW9uTWludXRlcxIlCgtpbnZpZ2lsYXRvchgJIAEoCUgBUgtpbnZpZ2'
    'lsYXRvcogBARIbCglyZXZlYWxfYXQYCiABKANSCHJldmVhbEF0Eh8KC2dlbmVyYXRlX2F0GAsg'
    'ASgDUgpnZW5lcmF0ZUF0QgkKB19zdHJlYW1CDgoMX2ludmlnaWxhdG9y');

@$core.Deprecated('Use schedulePaperResponseDescriptor instead')
const SchedulePaperResponse$json = {
  '1': 'SchedulePaperResponse',
  '2': [
    {'1': 'schedule_id', '3': 1, '4': 1, '5': 9, '10': 'scheduleId'},
  ],
};

/// Descriptor for `SchedulePaperResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schedulePaperResponseDescriptor = $convert.base64Decode(
    'ChVTY2hlZHVsZVBhcGVyUmVzcG9uc2USHwoLc2NoZWR1bGVfaWQYASABKAlSCnNjaGVkdWxlSW'
    'Q=');

@$core.Deprecated('Use assignInvigilatorRequestDescriptor instead')
const AssignInvigilatorRequest$json = {
  '1': 'AssignInvigilatorRequest',
  '2': [
    {'1': 'schedule_id', '3': 1, '4': 1, '5': 9, '10': 'scheduleId'},
    {
      '1': 'invigilator',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invigilator',
      '17': true
    },
  ],
  '8': [
    {'1': '_invigilator'},
  ],
};

/// Descriptor for `AssignInvigilatorRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignInvigilatorRequestDescriptor = $convert.base64Decode(
    'ChhBc3NpZ25JbnZpZ2lsYXRvclJlcXVlc3QSHwoLc2NoZWR1bGVfaWQYASABKAlSCnNjaGVkdW'
    'xlSWQSJQoLaW52aWdpbGF0b3IYAiABKAlIAFILaW52aWdpbGF0b3KIAQFCDgoMX2ludmlnaWxh'
    'dG9y');

@$core.Deprecated('Use assignInvigilatorResponseDescriptor instead')
const AssignInvigilatorResponse$json = {
  '1': 'AssignInvigilatorResponse',
};

/// Descriptor for `AssignInvigilatorResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignInvigilatorResponseDescriptor =
    $convert.base64Decode('ChlBc3NpZ25JbnZpZ2lsYXRvclJlc3BvbnNl');

@$core.Deprecated('Use paperScheduleProtoDescriptor instead')
const PaperScheduleProto$json = {
  '1': 'PaperScheduleProto',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'event', '3': 2, '4': 1, '5': 9, '10': 'event'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 4, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'stream', '17': true},
    {'1': 'date', '3': 6, '4': 1, '5': 5, '10': 'date'},
    {'1': 'start_time', '3': 7, '4': 1, '5': 5, '10': 'startTime'},
    {'1': 'end_time', '3': 8, '4': 1, '5': 5, '10': 'endTime'},
    {'1': 'duration_minutes', '3': 9, '4': 1, '5': 5, '10': 'durationMinutes'},
    {
      '1': 'invigilator',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'invigilator',
      '17': true
    },
    {'1': 'paper', '3': 11, '4': 1, '5': 9, '9': 2, '10': 'paper', '17': true},
    {
      '1': 'generation_status',
      '3': 12,
      '4': 1,
      '5': 5,
      '10': 'generationStatus'
    },
    {'1': 'reveal_at', '3': 13, '4': 1, '5': 3, '10': 'revealAt'},
    {'1': 'generate_at', '3': 14, '4': 1, '5': 3, '10': 'generateAt'},
    {'1': 'created', '3': 15, '4': 1, '5': 3, '10': 'created'},
  ],
  '8': [
    {'1': '_stream'},
    {'1': '_invigilator'},
    {'1': '_paper'},
  ],
};

/// Descriptor for `PaperScheduleProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperScheduleProtoDescriptor = $convert.base64Decode(
    'ChJQYXBlclNjaGVkdWxlUHJvdG8SDgoCaWQYASABKAlSAmlkEhQKBWV2ZW50GAIgASgJUgVldm'
    'VudBIYCgdzdWJqZWN0GAMgASgFUgdzdWJqZWN0EhQKBWdyYWRlGAQgASgFUgVncmFkZRIbCgZz'
    'dHJlYW0YBSABKAVIAFIGc3RyZWFtiAEBEhIKBGRhdGUYBiABKAVSBGRhdGUSHQoKc3RhcnRfdG'
    'ltZRgHIAEoBVIJc3RhcnRUaW1lEhkKCGVuZF90aW1lGAggASgFUgdlbmRUaW1lEikKEGR1cmF0'
    'aW9uX21pbnV0ZXMYCSABKAVSD2R1cmF0aW9uTWludXRlcxIlCgtpbnZpZ2lsYXRvchgKIAEoCU'
    'gBUgtpbnZpZ2lsYXRvcogBARIZCgVwYXBlchgLIAEoCUgCUgVwYXBlcogBARIrChFnZW5lcmF0'
    'aW9uX3N0YXR1cxgMIAEoBVIQZ2VuZXJhdGlvblN0YXR1cxIbCglyZXZlYWxfYXQYDSABKANSCH'
    'JldmVhbEF0Eh8KC2dlbmVyYXRlX2F0GA4gASgDUgpnZW5lcmF0ZUF0EhgKB2NyZWF0ZWQYDyAB'
    'KANSB2NyZWF0ZWRCCQoHX3N0cmVhbUIOCgxfaW52aWdpbGF0b3JCCAoGX3BhcGVy');

@$core.Deprecated('Use listSchedulesRequestDescriptor instead')
const ListSchedulesRequest$json = {
  '1': 'ListSchedulesRequest',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
  ],
};

/// Descriptor for `ListSchedulesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSchedulesRequestDescriptor =
    $convert.base64Decode(
        'ChRMaXN0U2NoZWR1bGVzUmVxdWVzdBIZCghldmVudF9pZBgBIAEoCVIHZXZlbnRJZA==');

@$core.Deprecated('Use listSchedulesResponseDescriptor instead')
const ListSchedulesResponse$json = {
  '1': 'ListSchedulesResponse',
  '2': [
    {
      '1': 'schedules',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.paper_management.PaperScheduleProto',
      '10': 'schedules'
    },
  ],
};

/// Descriptor for `ListSchedulesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSchedulesResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0U2NoZWR1bGVzUmVzcG9uc2USQgoJc2NoZWR1bGVzGAEgAygLMiQucGFwZXJfbWFuYW'
    'dlbWVudC5QYXBlclNjaGVkdWxlUHJvdG9SCXNjaGVkdWxlcw==');

@$core.Deprecated('Use updateScheduleRequestDescriptor instead')
const UpdateScheduleRequest$json = {
  '1': 'UpdateScheduleRequest',
  '2': [
    {'1': 'schedule_id', '3': 1, '4': 1, '5': 9, '10': 'scheduleId'},
    {'1': 'date', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'date', '17': true},
    {
      '1': 'start_time',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'startTime',
      '17': true
    },
    {
      '1': 'end_time',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'endTime',
      '17': true
    },
    {
      '1': 'duration_minutes',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'durationMinutes',
      '17': true
    },
    {
      '1': 'reveal_at',
      '3': 6,
      '4': 1,
      '5': 3,
      '9': 4,
      '10': 'revealAt',
      '17': true
    },
    {
      '1': 'generate_at',
      '3': 7,
      '4': 1,
      '5': 3,
      '9': 5,
      '10': 'generateAt',
      '17': true
    },
  ],
  '8': [
    {'1': '_date'},
    {'1': '_start_time'},
    {'1': '_end_time'},
    {'1': '_duration_minutes'},
    {'1': '_reveal_at'},
    {'1': '_generate_at'},
  ],
};

/// Descriptor for `UpdateScheduleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateScheduleRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVTY2hlZHVsZVJlcXVlc3QSHwoLc2NoZWR1bGVfaWQYASABKAlSCnNjaGVkdWxlSW'
    'QSFwoEZGF0ZRgCIAEoBUgAUgRkYXRliAEBEiIKCnN0YXJ0X3RpbWUYAyABKAVIAVIJc3RhcnRU'
    'aW1liAEBEh4KCGVuZF90aW1lGAQgASgFSAJSB2VuZFRpbWWIAQESLgoQZHVyYXRpb25fbWludX'
    'RlcxgFIAEoBUgDUg9kdXJhdGlvbk1pbnV0ZXOIAQESIAoJcmV2ZWFsX2F0GAYgASgDSARSCHJl'
    'dmVhbEF0iAEBEiQKC2dlbmVyYXRlX2F0GAcgASgDSAVSCmdlbmVyYXRlQXSIAQFCBwoFX2RhdG'
    'VCDQoLX3N0YXJ0X3RpbWVCCwoJX2VuZF90aW1lQhMKEV9kdXJhdGlvbl9taW51dGVzQgwKCl9y'
    'ZXZlYWxfYXRCDgoMX2dlbmVyYXRlX2F0');

@$core.Deprecated('Use updateScheduleResponseDescriptor instead')
const UpdateScheduleResponse$json = {
  '1': 'UpdateScheduleResponse',
  '2': [
    {
      '1': 'schedule',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.paper_management.PaperScheduleProto',
      '10': 'schedule'
    },
  ],
};

/// Descriptor for `UpdateScheduleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateScheduleResponseDescriptor =
    $convert.base64Decode(
        'ChZVcGRhdGVTY2hlZHVsZVJlc3BvbnNlEkAKCHNjaGVkdWxlGAEgASgLMiQucGFwZXJfbWFuYW'
        'dlbWVudC5QYXBlclNjaGVkdWxlUHJvdG9SCHNjaGVkdWxl');

@$core.Deprecated('Use taughtTopicProtoDescriptor instead')
const TaughtTopicProto$json = {
  '1': 'TaughtTopicProto',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 5, '10': 'topicId'},
    {'1': 'status', '3': 2, '4': 1, '5': 5, '10': 'status'},
    {
      '1': 'taught_date',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'taughtDate',
      '17': true
    },
  ],
  '8': [
    {'1': '_taught_date'},
  ],
};

/// Descriptor for `TaughtTopicProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taughtTopicProtoDescriptor = $convert.base64Decode(
    'ChBUYXVnaHRUb3BpY1Byb3RvEhkKCHRvcGljX2lkGAEgASgFUgd0b3BpY0lkEhYKBnN0YXR1cx'
    'gCIAEoBVIGc3RhdHVzEiQKC3RhdWdodF9kYXRlGAMgASgFSABSCnRhdWdodERhdGWIAQFCDgoM'
    'X3RhdWdodF9kYXRl');

@$core.Deprecated('Use setTaughtTopicsRequestDescriptor instead')
const SetTaughtTopicsRequest$json = {
  '1': 'SetTaughtTopicsRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'subject', '3': 2, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'stream', '17': true},
    {
      '1': 'topics',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.paper_management.TaughtTopicProto',
      '10': 'topics'
    },
  ],
  '8': [
    {'1': '_stream'},
  ],
};

/// Descriptor for `SetTaughtTopicsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTaughtTopicsRequestDescriptor = $convert.base64Decode(
    'ChZTZXRUYXVnaHRUb3BpY3NSZXF1ZXN0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhgKB3N1Ym'
    'plY3QYAiABKAVSB3N1YmplY3QSFAoFZ3JhZGUYAyABKAVSBWdyYWRlEhsKBnN0cmVhbRgEIAEo'
    'BUgAUgZzdHJlYW2IAQESOgoGdG9waWNzGAUgAygLMiIucGFwZXJfbWFuYWdlbWVudC5UYXVnaH'
    'RUb3BpY1Byb3RvUgZ0b3BpY3NCCQoHX3N0cmVhbQ==');

@$core.Deprecated('Use setTaughtTopicsResponseDescriptor instead')
const SetTaughtTopicsResponse$json = {
  '1': 'SetTaughtTopicsResponse',
};

/// Descriptor for `SetTaughtTopicsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTaughtTopicsResponseDescriptor =
    $convert.base64Decode('ChdTZXRUYXVnaHRUb3BpY3NSZXNwb25zZQ==');

@$core.Deprecated('Use getTaughtTopicsRequestDescriptor instead')
const GetTaughtTopicsRequest$json = {
  '1': 'GetTaughtTopicsRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'subject', '3': 2, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'stream', '17': true},
  ],
  '8': [
    {'1': '_stream'},
  ],
};

/// Descriptor for `GetTaughtTopicsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTaughtTopicsRequestDescriptor = $convert.base64Decode(
    'ChZHZXRUYXVnaHRUb3BpY3NSZXF1ZXN0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhgKB3N1Ym'
    'plY3QYAiABKAVSB3N1YmplY3QSFAoFZ3JhZGUYAyABKAVSBWdyYWRlEhsKBnN0cmVhbRgEIAEo'
    'BUgAUgZzdHJlYW2IAQFCCQoHX3N0cmVhbQ==');

@$core.Deprecated('Use getTaughtTopicsResponseDescriptor instead')
const GetTaughtTopicsResponse$json = {
  '1': 'GetTaughtTopicsResponse',
  '2': [
    {
      '1': 'topics',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.paper_management.TaughtTopicProto',
      '10': 'topics'
    },
  ],
};

/// Descriptor for `GetTaughtTopicsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTaughtTopicsResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRUYXVnaHRUb3BpY3NSZXNwb25zZRI6CgZ0b3BpY3MYASADKAsyIi5wYXBlcl9tYW5hZ2'
        'VtZW50LlRhdWdodFRvcGljUHJvdG9SBnRvcGljcw==');

@$core.Deprecated('Use confirmExamCoverageRequestDescriptor instead')
const ConfirmExamCoverageRequest$json = {
  '1': 'ConfirmExamCoverageRequest',
  '2': [
    {'1': 'schedule_id', '3': 1, '4': 1, '5': 9, '10': 'scheduleId'},
    {'1': 'topic_ids', '3': 2, '4': 3, '5': 5, '10': 'topicIds'},
  ],
};

/// Descriptor for `ConfirmExamCoverageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmExamCoverageRequestDescriptor =
    $convert.base64Decode(
        'ChpDb25maXJtRXhhbUNvdmVyYWdlUmVxdWVzdBIfCgtzY2hlZHVsZV9pZBgBIAEoCVIKc2NoZW'
        'R1bGVJZBIbCgl0b3BpY19pZHMYAiADKAVSCHRvcGljSWRz');

@$core.Deprecated('Use confirmExamCoverageResponseDescriptor instead')
const ConfirmExamCoverageResponse$json = {
  '1': 'ConfirmExamCoverageResponse',
  '2': [
    {'1': 'topics_confirmed', '3': 1, '4': 1, '5': 5, '10': 'topicsConfirmed'},
  ],
};

/// Descriptor for `ConfirmExamCoverageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmExamCoverageResponseDescriptor =
    $convert.base64Decode(
        'ChtDb25maXJtRXhhbUNvdmVyYWdlUmVzcG9uc2USKQoQdG9waWNzX2NvbmZpcm1lZBgBIAEoBV'
        'IPdG9waWNzQ29uZmlybWVk');

@$core.Deprecated('Use getExamCoverageRequestDescriptor instead')
const GetExamCoverageRequest$json = {
  '1': 'GetExamCoverageRequest',
  '2': [
    {'1': 'schedule_id', '3': 1, '4': 1, '5': 9, '10': 'scheduleId'},
  ],
};

/// Descriptor for `GetExamCoverageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getExamCoverageRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRFeGFtQ292ZXJhZ2VSZXF1ZXN0Eh8KC3NjaGVkdWxlX2lkGAEgASgJUgpzY2hlZHVsZU'
        'lk');

@$core.Deprecated('Use getExamCoverageResponseDescriptor instead')
const GetExamCoverageResponse$json = {
  '1': 'GetExamCoverageResponse',
  '2': [
    {'1': 'topic_ids', '3': 1, '4': 3, '5': 5, '10': 'topicIds'},
  ],
};

/// Descriptor for `GetExamCoverageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getExamCoverageResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRFeGFtQ292ZXJhZ2VSZXNwb25zZRIbCgl0b3BpY19pZHMYASADKAVSCHRvcGljSWRz');

@$core.Deprecated('Use generateAssessmentRequestDescriptor instead')
const GenerateAssessmentRequest$json = {
  '1': 'GenerateAssessmentRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `GenerateAssessmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateAssessmentRequestDescriptor =
    $convert.base64Decode(
        'ChlHZW5lcmF0ZUFzc2Vzc21lbnRSZXF1ZXN0EhkKCHBhcGVyX2lkGAEgASgJUgdwYXBlcklk');

@$core.Deprecated('Use generateAssessmentResponseDescriptor instead')
const GenerateAssessmentResponse$json = {
  '1': 'GenerateAssessmentResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `GenerateAssessmentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateAssessmentResponseDescriptor =
    $convert.base64Decode(
        'ChpHZW5lcmF0ZUFzc2Vzc21lbnRSZXNwb25zZRIaCghhY2NlcHRlZBgBIAEoCFIIYWNjZXB0ZW'
        'QSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use generateAssignmentRequestDescriptor instead')
const GenerateAssignmentRequest$json = {
  '1': 'GenerateAssignmentRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `GenerateAssignmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateAssignmentRequestDescriptor =
    $convert.base64Decode(
        'ChlHZW5lcmF0ZUFzc2lnbm1lbnRSZXF1ZXN0EhkKCHBhcGVyX2lkGAEgASgJUgdwYXBlcklk');

@$core.Deprecated('Use generateAssignmentResponseDescriptor instead')
const GenerateAssignmentResponse$json = {
  '1': 'GenerateAssignmentResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `GenerateAssignmentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateAssignmentResponseDescriptor =
    $convert.base64Decode(
        'ChpHZW5lcmF0ZUFzc2lnbm1lbnRSZXNwb25zZRIaCghhY2NlcHRlZBgBIAEoCFIIYWNjZXB0ZW'
        'QSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use finalizeStudentPapersRequestDescriptor instead')
const FinalizeStudentPapersRequest$json = {
  '1': 'FinalizeStudentPapersRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `FinalizeStudentPapersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizeStudentPapersRequestDescriptor =
    $convert.base64Decode(
        'ChxGaW5hbGl6ZVN0dWRlbnRQYXBlcnNSZXF1ZXN0EhkKCHBhcGVyX2lkGAEgASgJUgdwYXBlck'
        'lk');

@$core.Deprecated('Use finalizeStudentPapersResponseDescriptor instead')
const FinalizeStudentPapersResponse$json = {
  '1': 'FinalizeStudentPapersResponse',
  '2': [
    {'1': 'job_id', '3': 1, '4': 1, '5': 9, '10': 'jobId'},
  ],
};

/// Descriptor for `FinalizeStudentPapersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizeStudentPapersResponseDescriptor =
    $convert.base64Decode(
        'Ch1GaW5hbGl6ZVN0dWRlbnRQYXBlcnNSZXNwb25zZRIVCgZqb2JfaWQYASABKAlSBWpvYklk');

@$core.Deprecated('Use getStudentPapersStatusRequestDescriptor instead')
const GetStudentPapersStatusRequest$json = {
  '1': 'GetStudentPapersStatusRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
  ],
};

/// Descriptor for `GetStudentPapersStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStudentPapersStatusRequestDescriptor =
    $convert.base64Decode(
        'Ch1HZXRTdHVkZW50UGFwZXJzU3RhdHVzUmVxdWVzdBIZCghwYXBlcl9pZBgBIAEoCVIHcGFwZX'
        'JJZA==');

@$core.Deprecated('Use studentPdfStatusDescriptor instead')
const StudentPdfStatus$json = {
  '1': 'StudentPdfStatus',
  '2': [
    {'1': 'student', '3': 1, '4': 1, '5': 5, '10': 'student'},
    {'1': 'generated', '3': 2, '4': 1, '5': 8, '10': 'generated'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `StudentPdfStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List studentPdfStatusDescriptor = $convert.base64Decode(
    'ChBTdHVkZW50UGRmU3RhdHVzEhgKB3N0dWRlbnQYASABKAVSB3N0dWRlbnQSHAoJZ2VuZXJhdG'
    'VkGAIgASgIUglnZW5lcmF0ZWQSGQoFZXJyb3IYAyABKAlIAFIFZXJyb3KIAQFCCAoGX2Vycm9y');

@$core.Deprecated('Use getStudentPapersStatusResponseDescriptor instead')
const GetStudentPapersStatusResponse$json = {
  '1': 'GetStudentPapersStatusResponse',
  '2': [
    {'1': 'job_id', '3': 1, '4': 1, '5': 9, '10': 'jobId'},
    {'1': 'complete', '3': 2, '4': 1, '5': 8, '10': 'complete'},
    {'1': 'total', '3': 3, '4': 1, '5': 5, '10': 'total'},
    {'1': 'generated', '3': 4, '4': 1, '5': 5, '10': 'generated'},
    {
      '1': 'statuses',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.paper_management.StudentPdfStatus',
      '10': 'statuses'
    },
  ],
};

/// Descriptor for `GetStudentPapersStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStudentPapersStatusResponseDescriptor =
    $convert.base64Decode(
        'Ch5HZXRTdHVkZW50UGFwZXJzU3RhdHVzUmVzcG9uc2USFQoGam9iX2lkGAEgASgJUgVqb2JJZB'
        'IaCghjb21wbGV0ZRgCIAEoCFIIY29tcGxldGUSFAoFdG90YWwYAyABKAVSBXRvdGFsEhwKCWdl'
        'bmVyYXRlZBgEIAEoBVIJZ2VuZXJhdGVkEj4KCHN0YXR1c2VzGAUgAygLMiIucGFwZXJfbWFuYW'
        'dlbWVudC5TdHVkZW50UGRmU3RhdHVzUghzdGF0dXNlcw==');

@$core.Deprecated('Use getStudentPaperPdfRequestDescriptor instead')
const GetStudentPaperPdfRequest$json = {
  '1': 'GetStudentPaperPdfRequest',
  '2': [
    {'1': 'paper_id', '3': 1, '4': 1, '5': 9, '10': 'paperId'},
    {'1': 'student', '3': 2, '4': 1, '5': 5, '10': 'student'},
  ],
};

/// Descriptor for `GetStudentPaperPdfRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStudentPaperPdfRequestDescriptor =
    $convert.base64Decode(
        'ChlHZXRTdHVkZW50UGFwZXJQZGZSZXF1ZXN0EhkKCHBhcGVyX2lkGAEgASgJUgdwYXBlcklkEh'
        'gKB3N0dWRlbnQYAiABKAVSB3N0dWRlbnQ=');

@$core.Deprecated('Use getStudentPaperPdfResponseDescriptor instead')
const GetStudentPaperPdfResponse$json = {
  '1': 'GetStudentPaperPdfResponse',
  '2': [
    {'1': 'pdf_url', '3': 1, '4': 1, '5': 9, '10': 'pdfUrl'},
    {'1': 'expiry', '3': 2, '4': 1, '5': 3, '10': 'expiry'},
  ],
};

/// Descriptor for `GetStudentPaperPdfResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStudentPaperPdfResponseDescriptor =
    $convert.base64Decode(
        'ChpHZXRTdHVkZW50UGFwZXJQZGZSZXNwb25zZRIXCgdwZGZfdXJsGAEgASgJUgZwZGZVcmwSFg'
        'oGZXhwaXJ5GAIgASgDUgZleHBpcnk=');
