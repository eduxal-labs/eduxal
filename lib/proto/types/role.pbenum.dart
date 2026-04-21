// This is a generated file - do not edit.
//
// Generated from types/role.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Resource extends $pb.ProtobufEnum {
  static const Resource USERS = Resource._(0, _omitEnumNames ? '' : 'USERS');
  static const Resource SCHOOLS =
      Resource._(1, _omitEnumNames ? '' : 'SCHOOLS');
  static const Resource OWNERS = Resource._(2, _omitEnumNames ? '' : 'OWNERS');
  static const Resource TEACHERS =
      Resource._(3, _omitEnumNames ? '' : 'TEACHERS');
  static const Resource STAFF = Resource._(4, _omitEnumNames ? '' : 'STAFF');
  static const Resource STUDENTS =
      Resource._(5, _omitEnumNames ? '' : 'STUDENTS');
  static const Resource DEPARTMENTS =
      Resource._(6, _omitEnumNames ? '' : 'DEPARTMENTS');
  static const Resource CLASSES =
      Resource._(7, _omitEnumNames ? '' : 'CLASSES');
  static const Resource ATTENDANCE =
      Resource._(8, _omitEnumNames ? '' : 'ATTENDANCE');
  static const Resource LESSONS =
      Resource._(9, _omitEnumNames ? '' : 'LESSONS');
  static const Resource EXAMS = Resource._(10, _omitEnumNames ? '' : 'EXAMS');
  static const Resource GRADES = Resource._(11, _omitEnumNames ? '' : 'GRADES');
  static const Resource FEES = Resource._(12, _omitEnumNames ? '' : 'FEES');
  static const Resource PAYMENTS =
      Resource._(13, _omitEnumNames ? '' : 'PAYMENTS');
  static const Resource ANNOUNCEMENTS =
      Resource._(14, _omitEnumNames ? '' : 'ANNOUNCEMENTS');
  static const Resource ROLES = Resource._(15, _omitEnumNames ? '' : 'ROLES');
  static const Resource PLANS = Resource._(16, _omitEnumNames ? '' : 'PLANS');
  static const Resource AI = Resource._(17, _omitEnumNames ? '' : 'AI');
  static const Resource SUBJECTS =
      Resource._(18, _omitEnumNames ? '' : 'SUBJECTS');

  static const $core.List<Resource> values = <Resource>[
    USERS,
    SCHOOLS,
    OWNERS,
    TEACHERS,
    STAFF,
    STUDENTS,
    DEPARTMENTS,
    CLASSES,
    ATTENDANCE,
    LESSONS,
    EXAMS,
    GRADES,
    FEES,
    PAYMENTS,
    ANNOUNCEMENTS,
    ROLES,
    PLANS,
    AI,
    SUBJECTS,
  ];

  static final $core.List<Resource?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 18);
  static Resource? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Resource._(super.value, super.name);
}

class Action extends $pb.ProtobufEnum {
  static const Action CREATE = Action._(0, _omitEnumNames ? '' : 'CREATE');
  static const Action READ = Action._(1, _omitEnumNames ? '' : 'READ');
  static const Action UPDATE = Action._(2, _omitEnumNames ? '' : 'UPDATE');
  static const Action DELETE = Action._(3, _omitEnumNames ? '' : 'DELETE');
  static const Action PURGE = Action._(4, _omitEnumNames ? '' : 'PURGE');
  static const Action ASSIGN = Action._(5, _omitEnumNames ? '' : 'ASSIGN');
  static const Action UNASSIGN = Action._(6, _omitEnumNames ? '' : 'UNASSIGN');
  static const Action MARK = Action._(7, _omitEnumNames ? '' : 'MARK');
  static const Action APPROVE = Action._(8, _omitEnumNames ? '' : 'APPROVE');

  static const $core.List<Action> values = <Action>[
    CREATE,
    READ,
    UPDATE,
    DELETE,
    PURGE,
    ASSIGN,
    UNASSIGN,
    MARK,
    APPROVE,
  ];

  static final $core.List<Action?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static Action? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Action._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
