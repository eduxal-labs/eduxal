import 'package:drift/drift.dart';
import 'schools.dart';
import 'users.dart';
import 'roles.dart';

class Scopes extends Table {
  @override
  String get tableName => 'scopes';

  // Nullable: null means this is a system-level scope (not school-specific).
  // school is part of the composite PK but is nullable, which SQLite allows.
  // Drift cannot include nullable columns in its primaryKey set, so the PK
  // is declared via tableConstraints instead (Drift uses rowid internally).
  TextColumn get school =>
      text().nullable().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get user =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role =>
      text().references(Roles, #id, onDelete: KeyAction.cascade)();
  Int64Column get created => int64()();

  // [school] is nullable so it cannot be included in Drift's primaryKey set.
  // The composite PK (school, user, role) is declared as a table constraint.
  // Drift uses the implicit rowid for data-class identity on this table.
  @override
  List<String> get customConstraints => ['PRIMARY KEY (school, user, role)'];
}
