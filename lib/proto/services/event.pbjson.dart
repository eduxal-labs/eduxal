// This is a generated file - do not edit.
//
// Generated from services/event.proto.

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

@$core.Deprecated('Use createEventRequestDescriptor instead')
const CreateEventRequest$json = {
  '1': 'CreateEventRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 3, '4': 1, '5': 5, '10': 'type'},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '10': 'term'},
    {'1': 'year', '3': 5, '4': 1, '5': 5, '10': 'year'},
    {'1': 'start_date', '3': 6, '4': 1, '5': 5, '10': 'startDate'},
    {'1': 'end_date', '3': 7, '4': 1, '5': 5, '10': 'endDate'},
  ],
};

/// Descriptor for `CreateEventRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createEventRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVFdmVudFJlcXVlc3QSFgoGc2Nob29sGAEgASgJUgZzY2hvb2wSEgoEbmFtZRgCIA'
    'EoCVIEbmFtZRISCgR0eXBlGAMgASgFUgR0eXBlEhIKBHRlcm0YBCABKAVSBHRlcm0SEgoEeWVh'
    'chgFIAEoBVIEeWVhchIdCgpzdGFydF9kYXRlGAYgASgFUglzdGFydERhdGUSGQoIZW5kX2RhdG'
    'UYByABKAVSB2VuZERhdGU=');

@$core.Deprecated('Use createEventResponseDescriptor instead')
const CreateEventResponse$json = {
  '1': 'CreateEventResponse',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 11, '6': '.event.Event', '10': 'event'},
  ],
};

/// Descriptor for `CreateEventResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createEventResponseDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVFdmVudFJlc3BvbnNlEiIKBWV2ZW50GAEgASgLMgwuZXZlbnQuRXZlbnRSBWV2ZW'
    '50');

@$core.Deprecated('Use getEventRequestDescriptor instead')
const GetEventRequest$json = {
  '1': 'GetEventRequest',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
  ],
};

/// Descriptor for `GetEventRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getEventRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRFdmVudFJlcXVlc3QSGQoIZXZlbnRfaWQYASABKAlSB2V2ZW50SWQ=');

@$core.Deprecated('Use getEventResponseDescriptor instead')
const GetEventResponse$json = {
  '1': 'GetEventResponse',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 11, '6': '.event.Event', '10': 'event'},
  ],
};

/// Descriptor for `GetEventResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getEventResponseDescriptor = $convert.base64Decode(
    'ChBHZXRFdmVudFJlc3BvbnNlEiIKBWV2ZW50GAEgASgLMgwuZXZlbnQuRXZlbnRSBWV2ZW50');

@$core.Deprecated('Use listEventsRequestDescriptor instead')
const ListEventsRequest$json = {
  '1': 'ListEventsRequest',
  '2': [
    {'1': 'school', '3': 1, '4': 1, '5': 9, '10': 'school'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'year', '17': true},
    {'1': 'term', '3': 3, '4': 1, '5': 5, '9': 1, '10': 'term', '17': true},
  ],
  '8': [
    {'1': '_year'},
    {'1': '_term'},
  ],
};

/// Descriptor for `ListEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listEventsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0RXZlbnRzUmVxdWVzdBIWCgZzY2hvb2wYASABKAlSBnNjaG9vbBIXCgR5ZWFyGAIgAS'
    'gFSABSBHllYXKIAQESFwoEdGVybRgDIAEoBUgBUgR0ZXJtiAEBQgcKBV95ZWFyQgcKBV90ZXJt');

@$core.Deprecated('Use listEventsResponseDescriptor instead')
const ListEventsResponse$json = {
  '1': 'ListEventsResponse',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.event.Event',
      '10': 'events'
    },
  ],
};

/// Descriptor for `ListEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listEventsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0RXZlbnRzUmVzcG9uc2USJAoGZXZlbnRzGAEgAygLMgwuZXZlbnQuRXZlbnRSBmV2ZW'
    '50cw==');

@$core.Deprecated('Use updateEventRequestDescriptor instead')
const UpdateEventRequest$json = {
  '1': 'UpdateEventRequest',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'type', '3': 3, '4': 1, '5': 5, '9': 1, '10': 'type', '17': true},
    {'1': 'term', '3': 4, '4': 1, '5': 5, '9': 2, '10': 'term', '17': true},
    {'1': 'year', '3': 5, '4': 1, '5': 5, '9': 3, '10': 'year', '17': true},
    {
      '1': 'start_date',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'startDate',
      '17': true
    },
    {
      '1': 'end_date',
      '3': 7,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'endDate',
      '17': true
    },
    {'1': 'status', '3': 8, '4': 1, '5': 5, '9': 6, '10': 'status', '17': true},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_type'},
    {'1': '_term'},
    {'1': '_year'},
    {'1': '_start_date'},
    {'1': '_end_date'},
    {'1': '_status'},
  ],
};

/// Descriptor for `UpdateEventRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateEventRequestDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVFdmVudFJlcXVlc3QSGQoIZXZlbnRfaWQYASABKAlSB2V2ZW50SWQSFwoEbmFtZR'
    'gCIAEoCUgAUgRuYW1liAEBEhcKBHR5cGUYAyABKAVIAVIEdHlwZYgBARIXCgR0ZXJtGAQgASgF'
    'SAJSBHRlcm2IAQESFwoEeWVhchgFIAEoBUgDUgR5ZWFyiAEBEiIKCnN0YXJ0X2RhdGUYBiABKA'
    'VIBFIJc3RhcnREYXRliAEBEh4KCGVuZF9kYXRlGAcgASgFSAVSB2VuZERhdGWIAQESGwoGc3Rh'
    'dHVzGAggASgFSAZSBnN0YXR1c4gBAUIHCgVfbmFtZUIHCgVfdHlwZUIHCgVfdGVybUIHCgVfeW'
    'VhckINCgtfc3RhcnRfZGF0ZUILCglfZW5kX2RhdGVCCQoHX3N0YXR1cw==');

@$core.Deprecated('Use updateEventResponseDescriptor instead')
const UpdateEventResponse$json = {
  '1': 'UpdateEventResponse',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 11, '6': '.event.Event', '10': 'event'},
  ],
};

/// Descriptor for `UpdateEventResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateEventResponseDescriptor = $convert.base64Decode(
    'ChNVcGRhdGVFdmVudFJlc3BvbnNlEiIKBWV2ZW50GAEgASgLMgwuZXZlbnQuRXZlbnRSBWV2ZW'
    '50');

@$core.Deprecated('Use deleteEventRequestDescriptor instead')
const DeleteEventRequest$json = {
  '1': 'DeleteEventRequest',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
  ],
};

/// Descriptor for `DeleteEventRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteEventRequestDescriptor =
    $convert.base64Decode(
        'ChJEZWxldGVFdmVudFJlcXVlc3QSGQoIZXZlbnRfaWQYASABKAlSB2V2ZW50SWQ=');

@$core.Deprecated('Use deleteEventResponseDescriptor instead')
const DeleteEventResponse$json = {
  '1': 'DeleteEventResponse',
};

/// Descriptor for `DeleteEventResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteEventResponseDescriptor =
    $convert.base64Decode('ChNEZWxldGVFdmVudFJlc3BvbnNl');
