import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduxal/database/database.dart';

/// Opens an in-memory [AppDatabase] (no file on disk) for testing.
AppDatabase _openTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  group('AppDatabase smoke tests', () {
    late AppDatabase database;

    setUp(() {
      database = _openTestDb();
    });

    tearDown(() async {
      await database.close();
    });

    test('opens successfully and schema is created', () async {
      // A simple select on the users table confirms that:
      //   • The DB opened without error.
      //   • MigrationStrategy.onCreate ran (tables exist).
      //   • The generated query layer compiles and executes.
      final rows = await database.users.select().get();
      expect(rows, isEmpty); // fresh DB has no rows
    });

    test('accounts table is accessible', () async {
      final rows = await database.accounts.select().get();
      expect(rows, isEmpty);
    });

    test('logs table is accessible', () async {
      final rows = await database.logs.select().get();
      expect(rows, isEmpty);
    });

    test('schools table is accessible', () async {
      final rows = await database.schools.select().get();
      expect(rows, isEmpty);
    });
  });
}
