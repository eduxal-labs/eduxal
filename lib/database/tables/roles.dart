import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'schools.dart';

class Roles extends Table {
  @override
  String get tableName => 'roles';

  TextColumn get id => text()();
  TextColumn get school =>
      text().nullable().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BlobColumn get permissions => blob()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
