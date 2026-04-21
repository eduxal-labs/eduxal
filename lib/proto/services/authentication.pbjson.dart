// This is a generated file - do not edit.
//
// Generated from services/authentication.proto.

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

@$core.Deprecated('Use loginDescriptor instead')
const Login$json = {
  '1': 'Login',
  '2': [
    {'1': 'phone', '3': 1, '4': 1, '5': 9, '10': 'phone'},
  ],
};

/// Descriptor for `Login`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginDescriptor =
    $convert.base64Decode('CgVMb2dpbhIUCgVwaG9uZRgBIAEoCVIFcGhvbmU=');

@$core.Deprecated('Use verifyDescriptor instead')
const Verify$json = {
  '1': 'Verify',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `Verify`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyDescriptor = $convert.base64Decode(
    'CgZWZXJpZnkSDgoCaWQYASABKAlSAmlkEhIKBGNvZGUYAiABKAlSBGNvZGU=');

@$core.Deprecated('Use registeredDescriptor instead')
const Registered$json = {
  '1': 'Registered',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `Registered`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registeredDescriptor =
    $convert.base64Decode('CgpSZWdpc3RlcmVkEhQKBXRva2VuGAEgASgJUgV0b2tlbg==');

@$core.Deprecated('Use authenticatedDescriptor instead')
const Authenticated$json = {
  '1': 'Authenticated',
  '2': [
    {'1': 'access_token', '3': 1, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 2, '4': 1, '5': 9, '10': 'refreshToken'},
    {'1': 'user', '3': 3, '4': 1, '5': 11, '6': '.user.User', '10': 'user'},
    {'1': 'profile', '3': 4, '4': 1, '5': 9, '10': 'profile'},
  ],
};

/// Descriptor for `Authenticated`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authenticatedDescriptor = $convert.base64Decode(
    'Cg1BdXRoZW50aWNhdGVkEiEKDGFjY2Vzc190b2tlbhgBIAEoCVILYWNjZXNzVG9rZW4SIwoNcm'
    'VmcmVzaF90b2tlbhgCIAEoCVIMcmVmcmVzaFRva2VuEh4KBHVzZXIYAyABKAsyCi51c2VyLlVz'
    'ZXJSBHVzZXISGAoHcHJvZmlsZRgEIAEoCVIHcHJvZmlsZQ==');

@$core.Deprecated('Use verifiedDescriptor instead')
const Verified$json = {
  '1': 'Verified',
  '2': [
    {
      '1': 'registered',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.authentication.Registered',
      '9': 0,
      '10': 'registered'
    },
    {
      '1': 'authenticated',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.authentication.Authenticated',
      '9': 0,
      '10': 'authenticated'
    },
  ],
  '8': [
    {'1': 'verified'},
  ],
};

/// Descriptor for `Verified`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifiedDescriptor = $convert.base64Decode(
    'CghWZXJpZmllZBI8CgpyZWdpc3RlcmVkGAEgASgLMhouYXV0aGVudGljYXRpb24uUmVnaXN0ZX'
    'JlZEgAUgpyZWdpc3RlcmVkEkUKDWF1dGhlbnRpY2F0ZWQYAiABKAsyHS5hdXRoZW50aWNhdGlv'
    'bi5BdXRoZW50aWNhdGVkSABSDWF1dGhlbnRpY2F0ZWRCCgoIdmVyaWZpZWQ=');

@$core.Deprecated('Use setupDescriptor instead')
const Setup$json = {
  '1': 'Setup',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `Setup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setupDescriptor = $convert.base64Decode(
    'CgVTZXR1cBIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SEgoEbmFtZRgCIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use refreshDescriptor instead')
const Refresh$json = {
  '1': 'Refresh',
  '2': [
    {'1': 'refresh_token', '3': 1, '4': 1, '5': 9, '10': 'refreshToken'},
  ],
};

/// Descriptor for `Refresh`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshDescriptor = $convert.base64Decode(
    'CgdSZWZyZXNoEiMKDXJlZnJlc2hfdG9rZW4YASABKAlSDHJlZnJlc2hUb2tlbg==');

@$core.Deprecated('Use changePhoneDescriptor instead')
const ChangePhone$json = {
  '1': 'ChangePhone',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'phone', '3': 2, '4': 1, '5': 9, '10': 'phone'},
  ],
};

/// Descriptor for `ChangePhone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List changePhoneDescriptor = $convert.base64Decode(
    'CgtDaGFuZ2VQaG9uZRIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SFAoFcGhvbmUYAiABKAlSBXBob2'
    '5l');

@$core.Deprecated('Use confirmChangePhoneDescriptor instead')
const ConfirmChangePhone$json = {
  '1': 'ConfirmChangePhone',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'code', '3': 3, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `ConfirmChangePhone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmChangePhoneDescriptor = $convert.base64Decode(
    'ChJDb25maXJtQ2hhbmdlUGhvbmUSFAoFdG9rZW4YASABKAlSBXRva2VuEg4KAmlkGAIgASgJUg'
    'JpZBISCgRjb2RlGAMgASgJUgRjb2Rl');
