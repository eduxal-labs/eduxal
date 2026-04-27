// This is a generated file - do not edit.
//
// Generated from types/event.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Event extends $pb.GeneratedMessage {
  factory Event({
    $core.String? id,
    $core.String? school,
    $core.String? name,
    $core.int? type,
    $core.int? term,
    $core.int? year,
    $core.int? startDate,
    $core.int? endDate,
    $core.int? status,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (school != null) result.school = school;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (term != null) result.term = term;
    if (year != null) result.year = year;
    if (startDate != null) result.startDate = startDate;
    if (endDate != null) result.endDate = endDate;
    if (status != null) result.status = status;
    if (created != null) result.created = created;
    if (updated != null) result.updated = updated;
    return result;
  }

  Event._();

  factory Event.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Event.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'event'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'school')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'type')
    ..aI(5, _omitFieldNames ? '' : 'term')
    ..aI(6, _omitFieldNames ? '' : 'year')
    ..aI(7, _omitFieldNames ? '' : 'startDate')
    ..aI(8, _omitFieldNames ? '' : 'endDate')
    ..aI(9, _omitFieldNames ? '' : 'status')
    ..aInt64(10, _omitFieldNames ? '' : 'created')
    ..aInt64(11, _omitFieldNames ? '' : 'updated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event copyWith(void Function(Event) updates) =>
      super.copyWith((message) => updates(message as Event)) as Event;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Event create() => Event._();
  @$core.override
  Event createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Event getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Event>(create);
  static Event? _defaultInstance;

  /// / The unique identifier for this event.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// / The school this event belongs to.
  @$pb.TagNumber(2)
  $core.String get school => $_getSZ(1);
  @$pb.TagNumber(2)
  set school($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchool() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchool() => $_clearField(2);

  /// / The name/title of the event.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// / The type of event (enum discriminant).
  @$pb.TagNumber(4)
  $core.int get type => $_getIZ(3);
  @$pb.TagNumber(4)
  set type($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  /// / The school term this event falls in.
  @$pb.TagNumber(5)
  $core.int get term => $_getIZ(4);
  @$pb.TagNumber(5)
  set term($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTerm() => $_has(4);
  @$pb.TagNumber(5)
  void clearTerm() => $_clearField(5);

  /// / The academic year this event falls in.
  @$pb.TagNumber(6)
  $core.int get year => $_getIZ(5);
  @$pb.TagNumber(6)
  set year($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasYear() => $_has(5);
  @$pb.TagNumber(6)
  void clearYear() => $_clearField(6);

  /// / The start date of the event (days since Unix epoch).
  @$pb.TagNumber(7)
  $core.int get startDate => $_getIZ(6);
  @$pb.TagNumber(7)
  set startDate($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStartDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearStartDate() => $_clearField(7);

  /// / The end date of the event (days since Unix epoch).
  @$pb.TagNumber(8)
  $core.int get endDate => $_getIZ(7);
  @$pb.TagNumber(8)
  set endDate($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEndDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearEndDate() => $_clearField(8);

  /// / The current status of the event (enum discriminant).
  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);

  /// / The time on which this record was created (Unix seconds).
  @$pb.TagNumber(10)
  $fixnum.Int64 get created => $_getI64(9);
  @$pb.TagNumber(10)
  set created($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCreated() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreated() => $_clearField(10);

  /// / The time on which this record was last updated (Unix seconds).
  @$pb.TagNumber(11)
  $fixnum.Int64 get updated => $_getI64(10);
  @$pb.TagNumber(11)
  set updated($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasUpdated() => $_has(10);
  @$pb.TagNumber(11)
  void clearUpdated() => $_clearField(11);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
