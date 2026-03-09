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

@$core.Deprecated('Use mutationBatchDescriptor instead')
const MutationBatch$json = {
  '1': 'MutationBatch',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {
      '1': 'mutations',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.sync.Mutation',
      '10': 'mutations'
    },
  ],
};

/// Descriptor for `MutationBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mutationBatchDescriptor = $convert.base64Decode(
    'Cg1NdXRhdGlvbkJhdGNoEhkKCGJhdGNoX2lkGAEgASgJUgdiYXRjaElkEiwKCW11dGF0aW9ucx'
    'gCIAMoCzIOLnN5bmMuTXV0YXRpb25SCW11dGF0aW9ucw==');

@$core.Deprecated('Use mutationDescriptor instead')
const Mutation$json = {
  '1': 'Mutation',
  '2': [
    {'1': 'table', '3': 1, '4': 1, '5': 5, '10': 'table'},
    {'1': 'operation', '3': 2, '4': 1, '5': 5, '10': 'operation'},
    {'1': 'row_key', '3': 3, '4': 1, '5': 9, '10': 'rowKey'},
    {
      '1': 'insert',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.sync.InsertData',
      '10': 'insert'
    },
    {
      '1': 'update',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.sync.UpdateData',
      '10': 'update'
    },
  ],
};

/// Descriptor for `Mutation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mutationDescriptor = $convert.base64Decode(
    'CghNdXRhdGlvbhIUCgV0YWJsZRgBIAEoBVIFdGFibGUSHAoJb3BlcmF0aW9uGAIgASgFUglvcG'
    'VyYXRpb24SFwoHcm93X2tleRgDIAEoCVIGcm93S2V5EigKBmluc2VydBgEIAEoCzIQLnN5bmMu'
    'SW5zZXJ0RGF0YVIGaW5zZXJ0EigKBnVwZGF0ZRgFIAEoCzIQLnN5bmMuVXBkYXRlRGF0YVIGdX'
    'BkYXRl');

@$core.Deprecated('Use pushAckDescriptor instead')
const PushAck$json = {
  '1': 'PushAck',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
    {'1': 'server_seq', '3': 4, '4': 1, '5': 3, '10': 'serverSeq'},
    {
      '1': 'results',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.sync.MutationResult',
      '10': 'results'
    },
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `PushAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushAckDescriptor = $convert.base64Decode(
    'CgdQdXNoQWNrEhkKCGJhdGNoX2lkGAEgASgJUgdiYXRjaElkEhgKB3N1Y2Nlc3MYAiABKAhSB3'
    'N1Y2Nlc3MSGQoFZXJyb3IYAyABKAlIAFIFZXJyb3KIAQESHQoKc2VydmVyX3NlcRgEIAEoA1IJ'
    'c2VydmVyU2VxEi4KB3Jlc3VsdHMYBSADKAsyFC5zeW5jLk11dGF0aW9uUmVzdWx0UgdyZXN1bH'
    'RzQggKBl9lcnJvcg==');

@$core.Deprecated('Use mutationResultDescriptor instead')
const MutationResult$json = {
  '1': 'MutationResult',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
    {'1': 'code', '3': 4, '4': 1, '5': 5, '10': 'code'},
    {
      '1': 'file_urls',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.sync.FileUrl',
      '10': 'fileUrls'
    },
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `MutationResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mutationResultDescriptor = $convert.base64Decode(
    'Cg5NdXRhdGlvblJlc3VsdBIUCgVpbmRleBgBIAEoBVIFaW5kZXgSGAoHc3VjY2VzcxgCIAEoCF'
    'IHc3VjY2VzcxIZCgVlcnJvchgDIAEoCUgAUgVlcnJvcogBARISCgRjb2RlGAQgASgFUgRjb2Rl'
    'EioKCWZpbGVfdXJscxgFIAMoCzINLnN5bmMuRmlsZVVybFIIZmlsZVVybHNCCAoGX2Vycm9y');

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
      '1': 'subject',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.sync.SubjectInsert',
      '9': 0,
      '10': 'subject'
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
      '1': 'settings',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.sync.SettingsInsert',
      '9': 0,
      '10': 'settings'
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
    'AFIKZW5yb2xsbWVudBIvCgdzdWJqZWN0GAwgASgLMhMuc3luYy5TdWJqZWN0SW5zZXJ0SABSB3'
    'N1YmplY3QSOAoKYXR0ZW5kYW5jZRgNIAEoCzIWLnN5bmMuQXR0ZW5kYW5jZUluc2VydEgAUgph'
    'dHRlbmRhbmNlEjUKCXRpbWV0YWJsZRgOIAEoCzIVLnN5bmMuVGltZXRhYmxlSW5zZXJ0SABSCX'
    'RpbWV0YWJsZRIsCgZsZXNzb24YDyABKAsyEi5zeW5jLkxlc3Nvbkluc2VydEgAUgZsZXNzb24S'
    'JgoEZXhhbRgQIAEoCzIQLnN5bmMuRXhhbUluc2VydEgAUgRleGFtEikKBXBhcGVyGBEgASgLMh'
    'Euc3luYy5QYXBlckluc2VydEgAUgVwYXBlchIpCgVncmFkZRgSIAEoCzIRLnN5bmMuR3JhZGVJ'
    'bnNlcnRIAFIFZ3JhZGUSIwoDZmVlGBMgASgLMg8uc3luYy5GZWVJbnNlcnRIAFIDZmVlEi8KB2'
    'ludm9pY2UYFCABKAsyEy5zeW5jLkludm9pY2VJbnNlcnRIAFIHaW52b2ljZRIvCgdwYXltZW50'
    'GBUgASgLMhMuc3luYy5QYXltZW50SW5zZXJ0SABSB3BheW1lbnQSPgoMYW5ub3VuY2VtZW50GB'
    'YgASgLMhguc3luYy5Bbm5vdW5jZW1lbnRJbnNlcnRIAFIMYW5ub3VuY2VtZW50Ei8KB21hc3Rl'
    'cnkYFyABKAsyEy5zeW5jLk1hc3RlcnlJbnNlcnRIAFIHbWFzdGVyeRIwCghhaV91c2FnZRgYIA'
    'EoCzITLnN5bmMuQWlVc2FnZUluc2VydEgAUgdhaVVzYWdlEjIKCHNldHRpbmdzGBkgASgLMhQu'
    'c3luYy5TZXR0aW5nc0luc2VydEgAUghzZXR0aW5ncxImCgRyb2xlGBogASgLMhAuc3luYy5Sb2'
    'xlSW5zZXJ0SABSBHJvbGUSKQoFc2NvcGUYGyABKAsyES5zeW5jLlNjb3BlSW5zZXJ0SABSBXNj'
    'b3BlEiYKBHBsYW4YHCABKAsyEC5zeW5jLlBsYW5JbnNlcnRIAFIEcGxhbhI+CgxzdWJzY3JpcH'
    'Rpb24YHSABKAsyGC5zeW5jLlN1YnNjcmlwdGlvbkluc2VydEgAUgxzdWJzY3JpcHRpb24SMgoI'
    'ZGlzY291bnQYHiABKAsyFC5zeW5jLkRpc2NvdW50SW5zZXJ0SABSCGRpc2NvdW50QgUKA3Jvdw'
    '==');

@$core.Deprecated('Use updateDataDescriptor instead')
const UpdateData$json = {
  '1': 'UpdateData',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.sync.UserUpdate',
      '9': 0,
      '10': 'user'
    },
    {
      '1': 'school',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.sync.SchoolUpdate',
      '9': 0,
      '10': 'school'
    },
    {
      '1': 'student',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.sync.StudentUpdate',
      '9': 0,
      '10': 'student'
    },
    {
      '1': 'guardian',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.sync.GuardianUpdate',
      '9': 0,
      '10': 'guardian'
    },
    {
      '1': 'department',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.sync.DepartmentUpdate',
      '9': 0,
      '10': 'department'
    },
    {
      '1': 'teacher',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.sync.TeacherUpdate',
      '9': 0,
      '10': 'teacher'
    },
    {
      '1': 'staff_member',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.sync.StaffUpdate',
      '9': 0,
      '10': 'staffMember'
    },
    {
      '1': 'term',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.sync.TermUpdate',
      '9': 0,
      '10': 'term'
    },
    {
      '1': 'class_teacher',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.sync.ClassTeacherUpdate',
      '9': 0,
      '10': 'classTeacher'
    },
    {
      '1': 'attendance',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.sync.AttendanceUpdate',
      '9': 0,
      '10': 'attendance'
    },
    {
      '1': 'timetable',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.sync.TimetableUpdate',
      '9': 0,
      '10': 'timetable'
    },
    {
      '1': 'exam',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.sync.ExamUpdate',
      '9': 0,
      '10': 'exam'
    },
    {
      '1': 'paper',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.sync.PaperUpdate',
      '9': 0,
      '10': 'paper'
    },
    {
      '1': 'grade',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.sync.GradeUpdate',
      '9': 0,
      '10': 'grade'
    },
    {
      '1': 'fee',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.sync.FeeUpdate',
      '9': 0,
      '10': 'fee'
    },
    {
      '1': 'invoice',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.sync.InvoiceUpdate',
      '9': 0,
      '10': 'invoice'
    },
    {
      '1': 'payment',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.sync.PaymentUpdate',
      '9': 0,
      '10': 'payment'
    },
    {
      '1': 'announcement',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.sync.AnnouncementUpdate',
      '9': 0,
      '10': 'announcement'
    },
    {
      '1': 'mastery',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.sync.MasteryUpdate',
      '9': 0,
      '10': 'mastery'
    },
    {
      '1': 'ai_usage',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.sync.AiUsageUpdate',
      '9': 0,
      '10': 'aiUsage'
    },
    {
      '1': 'settings',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.sync.SettingsUpdate',
      '9': 0,
      '10': 'settings'
    },
    {
      '1': 'role',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.sync.RoleUpdate',
      '9': 0,
      '10': 'role'
    },
    {
      '1': 'plan',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.sync.PlanUpdate',
      '9': 0,
      '10': 'plan'
    },
    {
      '1': 'subscription',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.sync.SubscriptionUpdate',
      '9': 0,
      '10': 'subscription'
    },
    {
      '1': 'discount',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.sync.DiscountUpdate',
      '9': 0,
      '10': 'discount'
    },
  ],
  '8': [
    {'1': 'row'},
  ],
};

/// Descriptor for `UpdateData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDataDescriptor = $convert.base64Decode(
    'CgpVcGRhdGVEYXRhEiYKBHVzZXIYASABKAsyEC5zeW5jLlVzZXJVcGRhdGVIAFIEdXNlchIsCg'
    'ZzY2hvb2wYAiABKAsyEi5zeW5jLlNjaG9vbFVwZGF0ZUgAUgZzY2hvb2wSLwoHc3R1ZGVudBgE'
    'IAEoCzITLnN5bmMuU3R1ZGVudFVwZGF0ZUgAUgdzdHVkZW50EjIKCGd1YXJkaWFuGAUgASgLMh'
    'Quc3luYy5HdWFyZGlhblVwZGF0ZUgAUghndWFyZGlhbhI4CgpkZXBhcnRtZW50GAYgASgLMhYu'
    'c3luYy5EZXBhcnRtZW50VXBkYXRlSABSCmRlcGFydG1lbnQSLwoHdGVhY2hlchgHIAEoCzITLn'
    'N5bmMuVGVhY2hlclVwZGF0ZUgAUgd0ZWFjaGVyEjYKDHN0YWZmX21lbWJlchgIIAEoCzIRLnN5'
    'bmMuU3RhZmZVcGRhdGVIAFILc3RhZmZNZW1iZXISJgoEdGVybRgJIAEoCzIQLnN5bmMuVGVybV'
    'VwZGF0ZUgAUgR0ZXJtEj8KDWNsYXNzX3RlYWNoZXIYCiABKAsyGC5zeW5jLkNsYXNzVGVhY2hl'
    'clVwZGF0ZUgAUgxjbGFzc1RlYWNoZXISOAoKYXR0ZW5kYW5jZRgNIAEoCzIWLnN5bmMuQXR0ZW'
    '5kYW5jZVVwZGF0ZUgAUgphdHRlbmRhbmNlEjUKCXRpbWV0YWJsZRgOIAEoCzIVLnN5bmMuVGlt'
    'ZXRhYmxlVXBkYXRlSABSCXRpbWV0YWJsZRImCgRleGFtGBAgASgLMhAuc3luYy5FeGFtVXBkYX'
    'RlSABSBGV4YW0SKQoFcGFwZXIYESABKAsyES5zeW5jLlBhcGVyVXBkYXRlSABSBXBhcGVyEikK'
    'BWdyYWRlGBIgASgLMhEuc3luYy5HcmFkZVVwZGF0ZUgAUgVncmFkZRIjCgNmZWUYEyABKAsyDy'
    '5zeW5jLkZlZVVwZGF0ZUgAUgNmZWUSLwoHaW52b2ljZRgUIAEoCzITLnN5bmMuSW52b2ljZVVw'
    'ZGF0ZUgAUgdpbnZvaWNlEi8KB3BheW1lbnQYFSABKAsyEy5zeW5jLlBheW1lbnRVcGRhdGVIAF'
    'IHcGF5bWVudBI+Cgxhbm5vdW5jZW1lbnQYFiABKAsyGC5zeW5jLkFubm91bmNlbWVudFVwZGF0'
    'ZUgAUgxhbm5vdW5jZW1lbnQSLwoHbWFzdGVyeRgXIAEoCzITLnN5bmMuTWFzdGVyeVVwZGF0ZU'
    'gAUgdtYXN0ZXJ5EjAKCGFpX3VzYWdlGBggASgLMhMuc3luYy5BaVVzYWdlVXBkYXRlSABSB2Fp'
    'VXNhZ2USMgoIc2V0dGluZ3MYGSABKAsyFC5zeW5jLlNldHRpbmdzVXBkYXRlSABSCHNldHRpbm'
    'dzEiYKBHJvbGUYGiABKAsyEC5zeW5jLlJvbGVVcGRhdGVIAFIEcm9sZRImCgRwbGFuGBwgASgL'
    'MhAuc3luYy5QbGFuVXBkYXRlSABSBHBsYW4SPgoMc3Vic2NyaXB0aW9uGB0gASgLMhguc3luYy'
    '5TdWJzY3JpcHRpb25VcGRhdGVIAFIMc3Vic2NyaXB0aW9uEjIKCGRpc2NvdW50GB4gASgLMhQu'
    'c3luYy5EaXNjb3VudFVwZGF0ZUgAUghkaXNjb3VudEIFCgNyb3c=');

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

@$core.Deprecated('Use subjectInsertDescriptor instead')
const SubjectInsert$json = {
  '1': 'SubjectInsert',
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

/// Descriptor for `SubjectInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subjectInsertDescriptor = $convert.base64Decode(
    'Cg1TdWJqZWN0SW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhIKBHllYXIYAiABKAVSBH'
    'llYXISEgoEdGVybRgDIAEoBVIEdGVybRIUCgVncmFkZRgEIAEoBVIFZ3JhZGUSFgoGc3RyZWFt'
    'GAUgASgFUgZzdHJlYW0SGAoHc3ViamVjdBgGIAEoBVIHc3ViamVjdBIYCgd0ZWFjaGVyGAcgAS'
    'gJUgd0ZWFjaGVy');

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
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'grade', '3': 5, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'stream', '3': 6, '4': 1, '5': 5, '9': 0, '10': 'stream', '17': true},
    {'1': 'personalized', '3': 7, '4': 1, '5': 8, '10': 'personalized'},
    {'1': 'type', '3': 8, '4': 1, '5': 5, '10': 'type'},
    {'1': 'start', '3': 9, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 10, '4': 1, '5': 5, '10': 'end'},
    {'1': 'teacher', '3': 11, '4': 1, '5': 9, '10': 'teacher'},
  ],
  '8': [
    {'1': '_stream'},
  ],
};

/// Descriptor for `ExamInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List examInsertDescriptor = $convert.base64Decode(
    'CgpFeGFtSW5zZXJ0Eg4KAmlkGAEgASgJUgJpZBIWCgZzY2hvb2wYAiABKAlSBnNjaG9vbBISCg'
    'R5ZWFyGAMgASgFUgR5ZWFyEhIKBHRlcm0YBCABKAVSBHRlcm0SFAoFZ3JhZGUYBSABKAVSBWdy'
    'YWRlEhsKBnN0cmVhbRgGIAEoBUgAUgZzdHJlYW2IAQESIgoMcGVyc29uYWxpemVkGAcgASgIUg'
    'xwZXJzb25hbGl6ZWQSEgoEdHlwZRgIIAEoBVIEdHlwZRIUCgVzdGFydBgJIAEoBVIFc3RhcnQS'
    'EAoDZW5kGAogASgFUgNlbmQSGAoHdGVhY2hlchgLIAEoCVIHdGVhY2hlckIJCgdfc3RyZWFt');

@$core.Deprecated('Use paperInsertDescriptor instead')
const PaperInsert$json = {
  '1': 'PaperInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'exam', '3': 2, '4': 1, '5': 9, '10': 'exam'},
    {'1': 'subject', '3': 3, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'paper', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'paper', '17': true},
    {'1': 'invigilator', '3': 5, '4': 1, '5': 9, '10': 'invigilator'},
    {'1': 'start', '3': 6, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 7, '4': 1, '5': 3, '10': 'end'},
    {'1': 'status', '3': 8, '4': 1, '5': 5, '10': 'status'},
  ],
  '8': [
    {'1': '_paper'},
  ],
};

/// Descriptor for `PaperInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperInsertDescriptor = $convert.base64Decode(
    'CgtQYXBlckluc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRleGFtGAIgASgJUgRleG'
    'FtEhgKB3N1YmplY3QYAyABKAVSB3N1YmplY3QSGQoFcGFwZXIYBCABKAVIAFIFcGFwZXKIAQES'
    'IAoLaW52aWdpbGF0b3IYBSABKAlSC2ludmlnaWxhdG9yEhQKBXN0YXJ0GAYgASgDUgVzdGFydB'
    'IQCgNlbmQYByABKANSA2VuZBIWCgZzdGF0dXMYCCABKAVSBnN0YXR1c0IICgZfcGFwZXI=');

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
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '10': 'grade'},
    {'1': 'subject', '3': 4, '4': 1, '5': 5, '10': 'subject'},
    {'1': 'topic', '3': 5, '4': 1, '5': 5, '10': 'topic'},
    {'1': 'score', '3': 6, '4': 1, '5': 2, '10': 'score'},
  ],
};

/// Descriptor for `MasteryInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List masteryInsertDescriptor = $convert.base64Decode(
    'Cg1NYXN0ZXJ5SW5zZXJ0EhYKBnNjaG9vbBgBIAEoCVIGc2Nob29sEhgKB3N0dWRlbnQYAiABKA'
    'VSB3N0dWRlbnQSFAoFZ3JhZGUYAyABKAVSBWdyYWRlEhgKB3N1YmplY3QYBCABKAVSB3N1Ympl'
    'Y3QSFAoFdG9waWMYBSABKAVSBXRvcGljEhQKBXNjb3JlGAYgASgCUgVzY29yZQ==');

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

@$core.Deprecated('Use settingsInsertDescriptor instead')
const SettingsInsert$json = {
  '1': 'SettingsInsert',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'data', '3': 2, '4': 1, '5': 9, '10': 'data'},
    {'1': 'mpesa', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'mpesa', '17': true},
  ],
  '8': [
    {'1': '_mpesa'},
  ],
};

/// Descriptor for `SettingsInsert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsInsertDescriptor = $convert.base64Decode(
    'Cg5TZXR0aW5nc0luc2VydBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBISCgRkYXRhGAIgASgJUg'
    'RkYXRhEhkKBW1wZXNhGAMgASgJSABSBW1wZXNhiAEBQggKBl9tcGVzYQ==');

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

@$core.Deprecated('Use userUpdateDescriptor instead')
const UserUpdate$json = {
  '1': 'UserUpdate',
  '2': [
    {'1': 'phone', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'phone', '17': true},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'email', '17': true},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '9': 2, '10': 'name', '17': true},
    {'1': 'level', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'level', '17': true},
    {'1': 'status', '3': 5, '4': 1, '5': 5, '9': 4, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_phone'},
    {'1': '_email'},
    {'1': '_name'},
    {'1': '_level'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UserUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userUpdateDescriptor = $convert.base64Decode(
    'CgpVc2VyVXBkYXRlEhkKBXBob25lGAEgASgJSABSBXBob25liAEBEhkKBWVtYWlsGAIgASgJSA'
    'FSBWVtYWlsiAEBEhcKBG5hbWUYAyABKAlIAlIEbmFtZYgBARIZCgVsZXZlbBgEIAEoBUgDUgVs'
    'ZXZlbIgBARIbCgZzdGF0dXMYBSABKAVIBFIGc3RhdHVziAEBQggKBl9waG9uZUIICgZfZW1haW'
    'xCBwoFX25hbWVCCAoGX2xldmVsQgkKB19zdGF0dXM=');

@$core.Deprecated('Use schoolUpdateDescriptor instead')
const SchoolUpdate$json = {
  '1': 'SchoolUpdate',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'motto', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'motto', '17': true},
    {'1': 'phone', '3': 3, '4': 1, '5': 9, '9': 2, '10': 'phone', '17': true},
    {'1': 'email', '3': 4, '4': 1, '5': 9, '9': 3, '10': 'email', '17': true},
    {'1': 'county', '3': 5, '4': 1, '5': 5, '9': 4, '10': 'county', '17': true},
    {'1': 'domain', '3': 6, '4': 1, '5': 9, '9': 5, '10': 'domain', '17': true},
    {
      '1': 'established',
      '3': 7,
      '4': 1,
      '5': 5,
      '9': 6,
      '10': 'established',
      '17': true
    },
    {'1': 'status', '3': 8, '4': 1, '5': 5, '9': 7, '10': 'status', '17': true},
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

/// Descriptor for `SchoolUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schoolUpdateDescriptor = $convert.base64Decode(
    'CgxTY2hvb2xVcGRhdGUSFwoEbmFtZRgBIAEoCUgAUgRuYW1liAEBEhkKBW1vdHRvGAIgASgJSA'
    'FSBW1vdHRviAEBEhkKBXBob25lGAMgASgJSAJSBXBob25liAEBEhkKBWVtYWlsGAQgASgJSANS'
    'BWVtYWlsiAEBEhsKBmNvdW50eRgFIAEoBUgEUgZjb3VudHmIAQESGwoGZG9tYWluGAYgASgJSA'
    'VSBmRvbWFpbogBARIlCgtlc3RhYmxpc2hlZBgHIAEoBUgGUgtlc3RhYmxpc2hlZIgBARIbCgZz'
    'dGF0dXMYCCABKAVIB1IGc3RhdHVziAEBQgcKBV9uYW1lQggKBl9tb3R0b0IICgZfcGhvbmVCCA'
    'oGX2VtYWlsQgkKB19jb3VudHlCCQoHX2RvbWFpbkIOCgxfZXN0YWJsaXNoZWRCCQoHX3N0YXR1'
    'cw==');

@$core.Deprecated('Use studentUpdateDescriptor instead')
const StudentUpdate$json = {
  '1': 'StudentUpdate',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'user', '17': true},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'name', '17': true},
    {'1': 'dob', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'dob', '17': true},
    {'1': 'gender', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'gender', '17': true},
    {
      '1': 'documents',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'documents',
      '17': true
    },
    {
      '1': 'admitted',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'admitted',
      '17': true
    },
    {'1': 'status', '3': 7, '4': 1, '5': 5, '9': 6, '10': 'status', '17': true},
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

/// Descriptor for `StudentUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List studentUpdateDescriptor = $convert.base64Decode(
    'Cg1TdHVkZW50VXBkYXRlEhcKBHVzZXIYASABKAlIAFIEdXNlcogBARIXCgRuYW1lGAIgASgJSA'
    'FSBG5hbWWIAQESFQoDZG9iGAMgASgFSAJSA2RvYogBARIbCgZnZW5kZXIYBCABKAVIA1IGZ2Vu'
    'ZGVyiAEBEiEKCWRvY3VtZW50cxgFIAEoCUgEUglkb2N1bWVudHOIAQESHwoIYWRtaXR0ZWQYBi'
    'ABKAVIBVIIYWRtaXR0ZWSIAQESGwoGc3RhdHVzGAcgASgFSAZSBnN0YXR1c4gBAUIHCgVfdXNl'
    'ckIHCgVfbmFtZUIGCgRfZG9iQgkKB19nZW5kZXJCDAoKX2RvY3VtZW50c0ILCglfYWRtaXR0ZW'
    'RCCQoHX3N0YXR1cw==');

@$core.Deprecated('Use guardianUpdateDescriptor instead')
const GuardianUpdate$json = {
  '1': 'GuardianUpdate',
  '2': [
    {
      '1': 'relationship',
      '3': 1,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'relationship',
      '17': true
    },
    {'1': 'role', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'role', '17': true},
  ],
  '8': [
    {'1': '_relationship'},
    {'1': '_role'},
  ],
};

/// Descriptor for `GuardianUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List guardianUpdateDescriptor = $convert.base64Decode(
    'Cg5HdWFyZGlhblVwZGF0ZRInCgxyZWxhdGlvbnNoaXAYASABKAVIAFIMcmVsYXRpb25zaGlwiA'
    'EBEhcKBHJvbGUYAiABKAVIAVIEcm9sZYgBAUIPCg1fcmVsYXRpb25zaGlwQgcKBV9yb2xl');

@$core.Deprecated('Use departmentUpdateDescriptor instead')
const DepartmentUpdate$json = {
  '1': 'DepartmentUpdate',
  '2': [
    {
      '1': 'description',
      '3': 1,
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

/// Descriptor for `DepartmentUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List departmentUpdateDescriptor = $convert.base64Decode(
    'ChBEZXBhcnRtZW50VXBkYXRlEiUKC2Rlc2NyaXB0aW9uGAEgASgJSABSC2Rlc2NyaXB0aW9uiA'
    'EBQg4KDF9kZXNjcmlwdGlvbg==');

@$core.Deprecated('Use teacherUpdateDescriptor instead')
const TeacherUpdate$json = {
  '1': 'TeacherUpdate',
  '2': [
    {'1': 'hired', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'hired', '17': true},
    {'1': 'role', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'department',
      '17': true
    },
    {'1': 'status', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_hired'},
    {'1': '_role'},
    {'1': '_department'},
    {'1': '_status'},
  ],
};

/// Descriptor for `TeacherUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List teacherUpdateDescriptor = $convert.base64Decode(
    'Cg1UZWFjaGVyVXBkYXRlEhkKBWhpcmVkGAEgASgFSABSBWhpcmVkiAEBEhcKBHJvbGUYAiABKA'
    'lIAVIEcm9sZYgBARIjCgpkZXBhcnRtZW50GAMgASgJSAJSCmRlcGFydG1lbnSIAQESGwoGc3Rh'
    'dHVzGAQgASgFSANSBnN0YXR1c4gBAUIICgZfaGlyZWRCBwoFX3JvbGVCDQoLX2RlcGFydG1lbn'
    'RCCQoHX3N0YXR1cw==');

@$core.Deprecated('Use staffUpdateDescriptor instead')
const StaffUpdate$json = {
  '1': 'StaffUpdate',
  '2': [
    {
      '1': 'idnumber',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'idnumber',
      '17': true
    },
    {'1': 'role', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'role', '17': true},
    {
      '1': 'department',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'department',
      '17': true
    },
    {'1': 'status', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_idnumber'},
    {'1': '_role'},
    {'1': '_department'},
    {'1': '_status'},
  ],
};

/// Descriptor for `StaffUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List staffUpdateDescriptor = $convert.base64Decode(
    'CgtTdGFmZlVwZGF0ZRIfCghpZG51bWJlchgBIAEoCUgAUghpZG51bWJlcogBARIXCgRyb2xlGA'
    'IgASgJSAFSBHJvbGWIAQESIwoKZGVwYXJ0bWVudBgDIAEoCUgCUgpkZXBhcnRtZW50iAEBEhsK'
    'BnN0YXR1cxgEIAEoBUgDUgZzdGF0dXOIAQFCCwoJX2lkbnVtYmVyQgcKBV9yb2xlQg0KC19kZX'
    'BhcnRtZW50QgkKB19zdGF0dXM=');

@$core.Deprecated('Use termUpdateDescriptor instead')
const TermUpdate$json = {
  '1': 'TermUpdate',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'start', '17': true},
    {'1': 'end', '3': 2, '4': 1, '5': 3, '9': 1, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_start'},
    {'1': '_end'},
  ],
};

/// Descriptor for `TermUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List termUpdateDescriptor = $convert.base64Decode(
    'CgpUZXJtVXBkYXRlEhkKBXN0YXJ0GAEgASgDSABSBXN0YXJ0iAEBEhUKA2VuZBgCIAEoA0gBUg'
    'NlbmSIAQFCCAoGX3N0YXJ0QgYKBF9lbmQ=');

@$core.Deprecated('Use classTeacherUpdateDescriptor instead')
const ClassTeacherUpdate$json = {
  '1': 'ClassTeacherUpdate',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'start', '17': true},
    {'1': 'end', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_start'},
    {'1': '_end'},
  ],
};

/// Descriptor for `ClassTeacherUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List classTeacherUpdateDescriptor = $convert.base64Decode(
    'ChJDbGFzc1RlYWNoZXJVcGRhdGUSGQoFc3RhcnQYASABKAVIAFIFc3RhcnSIAQESFQoDZW5kGA'
    'IgASgFSAFSA2VuZIgBAUIICgZfc3RhcnRCBgoEX2VuZA==');

@$core.Deprecated('Use attendanceUpdateDescriptor instead')
const AttendanceUpdate$json = {
  '1': 'AttendanceUpdate',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_status'},
  ],
};

/// Descriptor for `AttendanceUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attendanceUpdateDescriptor = $convert.base64Decode(
    'ChBBdHRlbmRhbmNlVXBkYXRlEhsKBnN0YXR1cxgBIAEoBUgAUgZzdGF0dXOIAQFCCQoHX3N0YX'
    'R1cw==');

@$core.Deprecated('Use timetableUpdateDescriptor instead')
const TimetableUpdate$json = {
  '1': 'TimetableUpdate',
  '2': [
    {
      '1': 'teacher',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'teacher',
      '17': true
    },
    {'1': 'end', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'end', '17': true},
  ],
  '8': [
    {'1': '_teacher'},
    {'1': '_end'},
  ],
};

/// Descriptor for `TimetableUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timetableUpdateDescriptor = $convert.base64Decode(
    'Cg9UaW1ldGFibGVVcGRhdGUSHQoHdGVhY2hlchgBIAEoCUgAUgd0ZWFjaGVyiAEBEhUKA2VuZB'
    'gCIAEoBUgBUgNlbmSIAQFCCgoIX3RlYWNoZXJCBgoEX2VuZA==');

@$core.Deprecated('Use examUpdateDescriptor instead')
const ExamUpdate$json = {
  '1': 'ExamUpdate',
  '2': [
    {'1': 'stream', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'stream', '17': true},
    {
      '1': 'personalized',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'personalized',
      '17': true
    },
    {'1': 'type', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'type', '17': true},
    {'1': 'start', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'start', '17': true},
    {'1': 'end', '3': 5, '4': 1, '5': 5, '9': 4, '10': 'end', '17': true},
    {
      '1': 'teacher',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'teacher',
      '17': true
    },
  ],
  '8': [
    {'1': '_stream'},
    {'1': '_personalized'},
    {'1': '_type'},
    {'1': '_start'},
    {'1': '_end'},
    {'1': '_teacher'},
  ],
};

/// Descriptor for `ExamUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List examUpdateDescriptor = $convert.base64Decode(
    'CgpFeGFtVXBkYXRlEhsKBnN0cmVhbRgBIAEoBUgAUgZzdHJlYW2IAQESJwoMcGVyc29uYWxpem'
    'VkGAIgASgISAFSDHBlcnNvbmFsaXplZIgBARIXCgR0eXBlGAMgASgFSAJSBHR5cGWIAQESGQoF'
    'c3RhcnQYBCABKAVIA1IFc3RhcnSIAQESFQoDZW5kGAUgASgFSARSA2VuZIgBARIdCgd0ZWFjaG'
    'VyGAYgASgJSAVSB3RlYWNoZXKIAQFCCQoHX3N0cmVhbUIPCg1fcGVyc29uYWxpemVkQgcKBV90'
    'eXBlQggKBl9zdGFydEIGCgRfZW5kQgoKCF90ZWFjaGVy');

@$core.Deprecated('Use paperUpdateDescriptor instead')
const PaperUpdate$json = {
  '1': 'PaperUpdate',
  '2': [
    {
      '1': 'invigilator',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invigilator',
      '17': true
    },
    {'1': 'start', '3': 2, '4': 1, '5': 3, '9': 1, '10': 'start', '17': true},
    {'1': 'end', '3': 3, '4': 1, '5': 3, '9': 2, '10': 'end', '17': true},
    {'1': 'status', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_invigilator'},
    {'1': '_start'},
    {'1': '_end'},
    {'1': '_status'},
  ],
};

/// Descriptor for `PaperUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paperUpdateDescriptor = $convert.base64Decode(
    'CgtQYXBlclVwZGF0ZRIlCgtpbnZpZ2lsYXRvchgBIAEoCUgAUgtpbnZpZ2lsYXRvcogBARIZCg'
    'VzdGFydBgCIAEoA0gBUgVzdGFydIgBARIVCgNlbmQYAyABKANIAlIDZW5kiAEBEhsKBnN0YXR1'
    'cxgEIAEoBUgDUgZzdGF0dXOIAQFCDgoMX2ludmlnaWxhdG9yQggKBl9zdGFydEIGCgRfZW5kQg'
    'kKB19zdGF0dXM=');

@$core.Deprecated('Use gradeUpdateDescriptor instead')
const GradeUpdate$json = {
  '1': 'GradeUpdate',
  '2': [
    {'1': 'score', '3': 1, '4': 1, '5': 2, '9': 0, '10': 'score', '17': true},
    {'1': 'total', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'total', '17': true},
  ],
  '8': [
    {'1': '_score'},
    {'1': '_total'},
  ],
};

/// Descriptor for `GradeUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gradeUpdateDescriptor = $convert.base64Decode(
    'CgtHcmFkZVVwZGF0ZRIZCgVzY29yZRgBIAEoAkgAUgVzY29yZYgBARIZCgV0b3RhbBgCIAEoBU'
    'gBUgV0b3RhbIgBAUIICgZfc2NvcmVCCAoGX3RvdGFs');

@$core.Deprecated('Use feeUpdateDescriptor instead')
const FeeUpdate$json = {
  '1': 'FeeUpdate',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'title', '17': true},
    {
      '1': 'description',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 3, '4': 1, '5': 2, '9': 2, '10': 'amount', '17': true},
    {
      '1': 'mandatory',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'mandatory',
      '17': true
    },
    {'1': 'due', '3': 5, '4': 1, '5': 3, '9': 4, '10': 'due', '17': true},
  ],
  '8': [
    {'1': '_title'},
    {'1': '_description'},
    {'1': '_amount'},
    {'1': '_mandatory'},
    {'1': '_due'},
  ],
};

/// Descriptor for `FeeUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feeUpdateDescriptor = $convert.base64Decode(
    'CglGZWVVcGRhdGUSGQoFdGl0bGUYASABKAlIAFIFdGl0bGWIAQESJQoLZGVzY3JpcHRpb24YAi'
    'ABKAlIAVILZGVzY3JpcHRpb26IAQESGwoGYW1vdW50GAMgASgCSAJSBmFtb3VudIgBARIhCglt'
    'YW5kYXRvcnkYBCABKAhIA1IJbWFuZGF0b3J5iAEBEhUKA2R1ZRgFIAEoA0gEUgNkdWWIAQFCCA'
    'oGX3RpdGxlQg4KDF9kZXNjcmlwdGlvbkIJCgdfYW1vdW50QgwKCl9tYW5kYXRvcnlCBgoEX2R1'
    'ZQ==');

@$core.Deprecated('Use invoiceUpdateDescriptor instead')
const InvoiceUpdate$json = {
  '1': 'InvoiceUpdate',
  '2': [
    {'1': 'fee', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'fee', '17': true},
    {
      '1': 'description',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 3, '4': 1, '5': 2, '9': 2, '10': 'amount', '17': true},
    {'1': 'status', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'status', '17': true},
    {'1': 'due', '3': 5, '4': 1, '5': 3, '9': 4, '10': 'due', '17': true},
  ],
  '8': [
    {'1': '_fee'},
    {'1': '_description'},
    {'1': '_amount'},
    {'1': '_status'},
    {'1': '_due'},
  ],
};

/// Descriptor for `InvoiceUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List invoiceUpdateDescriptor = $convert.base64Decode(
    'Cg1JbnZvaWNlVXBkYXRlEhUKA2ZlZRgBIAEoCUgAUgNmZWWIAQESJQoLZGVzY3JpcHRpb24YAi'
    'ABKAlIAVILZGVzY3JpcHRpb26IAQESGwoGYW1vdW50GAMgASgCSAJSBmFtb3VudIgBARIbCgZz'
    'dGF0dXMYBCABKAVIA1IGc3RhdHVziAEBEhUKA2R1ZRgFIAEoA0gEUgNkdWWIAQFCBgoEX2ZlZU'
    'IOCgxfZGVzY3JpcHRpb25CCQoHX2Ftb3VudEIJCgdfc3RhdHVzQgYKBF9kdWU=');

@$core.Deprecated('Use paymentUpdateDescriptor instead')
const PaymentUpdate$json = {
  '1': 'PaymentUpdate',
  '2': [
    {
      '1': 'invoice',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {'1': 'amount', '3': 2, '4': 1, '5': 2, '9': 1, '10': 'amount', '17': true},
    {'1': 'method', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'method', '17': true},
    {
      '1': 'reference',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'reference',
      '17': true
    },
    {
      '1': 'recorder',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'recorder',
      '17': true
    },
    {'1': 'date', '3': 6, '4': 1, '5': 5, '9': 5, '10': 'date', '17': true},
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

/// Descriptor for `PaymentUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentUpdateDescriptor = $convert.base64Decode(
    'Cg1QYXltZW50VXBkYXRlEh0KB2ludm9pY2UYASABKAlIAFIHaW52b2ljZYgBARIbCgZhbW91bn'
    'QYAiABKAJIAVIGYW1vdW50iAEBEhsKBm1ldGhvZBgDIAEoBUgCUgZtZXRob2SIAQESIQoJcmVm'
    'ZXJlbmNlGAQgASgJSANSCXJlZmVyZW5jZYgBARIfCghyZWNvcmRlchgFIAEoCUgEUghyZWNvcm'
    'RlcogBARIXCgRkYXRlGAYgASgFSAVSBGRhdGWIAQFCCgoIX2ludm9pY2VCCQoHX2Ftb3VudEIJ'
    'CgdfbWV0aG9kQgwKCl9yZWZlcmVuY2VCCwoJX3JlY29yZGVyQgcKBV9kYXRl');

@$core.Deprecated('Use announcementUpdateDescriptor instead')
const AnnouncementUpdate$json = {
  '1': 'AnnouncementUpdate',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'title', '17': true},
    {
      '1': 'content',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'content',
      '17': true
    },
    {'1': 'grade', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'grade', '17': true},
    {'1': 'stream', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'stream', '17': true},
    {
      '1': 'audience',
      '3': 5,
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

/// Descriptor for `AnnouncementUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List announcementUpdateDescriptor = $convert.base64Decode(
    'ChJBbm5vdW5jZW1lbnRVcGRhdGUSGQoFdGl0bGUYASABKAlIAFIFdGl0bGWIAQESHQoHY29udG'
    'VudBgCIAEoCUgBUgdjb250ZW50iAEBEhkKBWdyYWRlGAMgASgFSAJSBWdyYWRliAEBEhsKBnN0'
    'cmVhbRgEIAEoBUgDUgZzdHJlYW2IAQESHwoIYXVkaWVuY2UYBSABKAVIBFIIYXVkaWVuY2WIAQ'
    'FCCAoGX3RpdGxlQgoKCF9jb250ZW50QggKBl9ncmFkZUIJCgdfc3RyZWFtQgsKCV9hdWRpZW5j'
    'ZQ==');

@$core.Deprecated('Use masteryUpdateDescriptor instead')
const MasteryUpdate$json = {
  '1': 'MasteryUpdate',
  '2': [
    {'1': 'score', '3': 1, '4': 1, '5': 2, '9': 0, '10': 'score', '17': true},
  ],
  '8': [
    {'1': '_score'},
  ],
};

/// Descriptor for `MasteryUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List masteryUpdateDescriptor = $convert.base64Decode(
    'Cg1NYXN0ZXJ5VXBkYXRlEhkKBXNjb3JlGAEgASgCSABSBXNjb3JliAEBQggKBl9zY29yZQ==');

@$core.Deprecated('Use aiUsageUpdateDescriptor instead')
const AiUsageUpdate$json = {
  '1': 'AiUsageUpdate',
  '2': [
    {
      '1': 'allocated',
      '3': 1,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'allocated',
      '17': true
    },
    {'1': 'used', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'used', '17': true},
  ],
  '8': [
    {'1': '_allocated'},
    {'1': '_used'},
  ],
};

/// Descriptor for `AiUsageUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List aiUsageUpdateDescriptor = $convert.base64Decode(
    'Cg1BaVVzYWdlVXBkYXRlEiEKCWFsbG9jYXRlZBgBIAEoBUgAUglhbGxvY2F0ZWSIAQESFwoEdX'
    'NlZBgCIAEoBUgBUgR1c2VkiAEBQgwKCl9hbGxvY2F0ZWRCBwoFX3VzZWQ=');

@$core.Deprecated('Use settingsUpdateDescriptor instead')
const SettingsUpdate$json = {
  '1': 'SettingsUpdate',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'data', '17': true},
    {'1': 'mpesa', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'mpesa', '17': true},
  ],
  '8': [
    {'1': '_data'},
    {'1': '_mpesa'},
  ],
};

/// Descriptor for `SettingsUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsUpdateDescriptor = $convert.base64Decode(
    'Cg5TZXR0aW5nc1VwZGF0ZRIXCgRkYXRhGAEgASgJSABSBGRhdGGIAQESGQoFbXBlc2EYAiABKA'
    'lIAVIFbXBlc2GIAQFCBwoFX2RhdGFCCAoGX21wZXNh');

@$core.Deprecated('Use roleUpdateDescriptor instead')
const RoleUpdate$json = {
  '1': 'RoleUpdate',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'description',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {
      '1': 'permissions',
      '3': 3,
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

/// Descriptor for `RoleUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roleUpdateDescriptor = $convert.base64Decode(
    'CgpSb2xlVXBkYXRlEhcKBG5hbWUYASABKAlIAFIEbmFtZYgBARIlCgtkZXNjcmlwdGlvbhgCIA'
    'EoCUgBUgtkZXNjcmlwdGlvbogBARIlCgtwZXJtaXNzaW9ucxgDIAEoDEgCUgtwZXJtaXNzaW9u'
    'c4gBAUIHCgVfbmFtZUIOCgxfZGVzY3JpcHRpb25CDgoMX3Blcm1pc3Npb25z');

@$core.Deprecated('Use planUpdateDescriptor instead')
const PlanUpdate$json = {
  '1': 'PlanUpdate',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'description',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'description',
      '17': true
    },
    {'1': 'amount', '3': 3, '4': 1, '5': 2, '9': 2, '10': 'amount', '17': true},
    {'1': 'levels', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'levels', '17': true},
    {'1': 'status', '3': 5, '4': 1, '5': 5, '9': 4, '10': 'status', '17': true},
    {
      '1': 'features',
      '3': 6,
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

/// Descriptor for `PlanUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planUpdateDescriptor = $convert.base64Decode(
    'CgpQbGFuVXBkYXRlEhcKBG5hbWUYASABKAlIAFIEbmFtZYgBARIlCgtkZXNjcmlwdGlvbhgCIA'
    'EoCUgBUgtkZXNjcmlwdGlvbogBARIbCgZhbW91bnQYAyABKAJIAlIGYW1vdW50iAEBEhsKBmxl'
    'dmVscxgEIAEoBUgDUgZsZXZlbHOIAQESGwoGc3RhdHVzGAUgASgFSARSBnN0YXR1c4gBARIfCg'
    'hmZWF0dXJlcxgGIAEoCUgFUghmZWF0dXJlc4gBAUIHCgVfbmFtZUIOCgxfZGVzY3JpcHRpb25C'
    'CQoHX2Ftb3VudEIJCgdfbGV2ZWxzQgkKB19zdGF0dXNCCwoJX2ZlYXR1cmVz');

@$core.Deprecated('Use subscriptionUpdateDescriptor instead')
const SubscriptionUpdate$json = {
  '1': 'SubscriptionUpdate',
  '2': [
    {
      '1': 'invoice',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoice',
      '17': true
    },
    {
      '1': 'discount',
      '3': 2,
      '4': 1,
      '5': 2,
      '9': 1,
      '10': 'discount',
      '17': true
    },
    {'1': 'status', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_invoice'},
    {'1': '_discount'},
    {'1': '_status'},
  ],
};

/// Descriptor for `SubscriptionUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionUpdateDescriptor = $convert.base64Decode(
    'ChJTdWJzY3JpcHRpb25VcGRhdGUSHQoHaW52b2ljZRgBIAEoCUgAUgdpbnZvaWNliAEBEh8KCG'
    'Rpc2NvdW50GAIgASgCSAFSCGRpc2NvdW50iAEBEhsKBnN0YXR1cxgDIAEoBUgCUgZzdGF0dXOI'
    'AQFCCgoIX2ludm9pY2VCCwoJX2Rpc2NvdW50QgkKB19zdGF0dXM=');

@$core.Deprecated('Use discountUpdateDescriptor instead')
const DiscountUpdate$json = {
  '1': 'DiscountUpdate',
  '2': [
    {'1': 'amount', '3': 1, '4': 1, '5': 2, '9': 0, '10': 'amount', '17': true},
    {'1': 'unit', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'unit', '17': true},
  ],
  '8': [
    {'1': '_amount'},
    {'1': '_unit'},
  ],
};

/// Descriptor for `DiscountUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discountUpdateDescriptor = $convert.base64Decode(
    'Cg5EaXNjb3VudFVwZGF0ZRIbCgZhbW91bnQYASABKAJIAFIGYW1vdW50iAEBEhcKBHVuaXQYAi'
    'ABKAVIAVIEdW5pdIgBAUIJCgdfYW1vdW50QgcKBV91bml0');
