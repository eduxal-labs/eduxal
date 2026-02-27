import 'package:drift/drift.dart';
import 'enums.dart';

@DataClassName('UsersData')
class Users extends Table {
  @override
  String get tableName => 'users';

  TextColumn get id => text()();
  TextColumn get phone => text().customConstraint('NOT NULL UNIQUE')();
  TextColumn get email => text().nullable()();
  TextColumn get name => text()();
  IntColumn get level => integer()
      .map(const UserLevelConverter())
      .withDefault(const Constant(0))();
  IntColumn get status => integer()
      .map(const UserStatusConverter())
      .withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
