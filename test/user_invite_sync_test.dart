import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduxal/client.dart' as app_client;
import 'package:eduxal/database/database.dart';
import 'package:eduxal/database/tables/enums.dart';
import 'package:eduxal/models/authenticated.dart';
import 'package:eduxal/proto/services/sync.pb.dart' as sync_pb;
import 'package:eduxal/services/authorization_service.dart';

BigInt _nowMs() => BigInt.from(DateTime.now().millisecondsSinceEpoch);
BigInt _nowSec() => BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

UsersCompanion _userCompanion({
  required String id,
  required String phone,
  required String name,
  required UserLevel level,
  required UserStatus status,
  String? email,
}) {
  final now = _nowSec();
  return UsersCompanion(
    id: Value(id),
    phone: Value(phone),
    email: Value(email),
    name: Value(name),
    level: Value(level),
    status: Value(status),
    created: Value(now),
    updated: Value(now),
  );
}

SchoolsCompanion _schoolCompanion({
  required String id,
  required String name,
  int county = 47,
  SchoolStatus status = SchoolStatus.active,
}) {
  final now = _nowSec();
  return SchoolsCompanion(
    id: Value(id),
    name: Value(name),
    county: Value(county),
    status: Value(status),
    created: Value(now),
    updated: Value(now),
  );
}

Future<void> _seedAccount(
  AppDatabase database, {
  required String id,
  required String phone,
  required String name,
  required UserLevel level,
}) async {
  final now = _nowMs();
  final user = _userCompanion(
    id: id,
    phone: phone,
    name: name,
    level: level,
    status: UserStatus.active,
  );

  await database.into(database.users).insert(user);
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion(
          id: Value(id),
          accessToken: const Value('access-token'),
          refreshToken: const Value('refresh-token'),
          tokenExpiry: Value(now + BigInt.from(60000)),
          refreshTokenExpiry: Value(now + BigInt.from(120000)),
          isActive: const Value(true),
          theme: const Value(AppThemeMode.system),
          created: Value(now),
          updated: Value(now),
          lastSeq: Value(BigInt.zero),
        ),
      );
}

Future<void> _setCurrentAuthenticatedUser(
  AppDatabase database,
  String userId,
) async {
  final account = await (database.select(
    database.accounts,
  )..where((t) => t.id.equals(userId))).getSingle();
  final user = await (database.select(
    database.users,
  )..where((t) => t.id.equals(userId))).getSingle();
  app_client.cache.currentUser = Authenticated.fromRows(account, user);
}

Future<void> _seedAuthenticatedSuperUser(AppDatabase database) async {
  await _seedAccount(
    database,
    id: 'actor-super',
    phone: '0700000000',
    name: 'Super Actor',
    level: UserLevel.super_,
  );
  await _setCurrentAuthenticatedUser(database, 'actor-super');
}

Future<UsersData> _stageUser(
  AppDatabase database, {
  required String id,
  required String phone,
  required String name,
  required UserLevel level,
  required UserStatus status,
  String? email,
}) async {
  await database.usersDao.upsertUser(
    _userCompanion(
      id: id,
      phone: phone,
      name: name,
      level: level,
      status: status,
      email: email,
    ),
  );
  return (await database.usersDao.getUser(id))!;
}

Future<LogsData> _insertLog(
  AppDatabase database, {
  required String accountId,
  required SyncAction action,
  required List<int> payload,
  LogStatus status = LogStatus.pending,
  int attempts = 0,
  String? error,
  String resource = 'resource',
}) async {
  final id = await database
      .into(database.logs)
      .insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(action),
          resource: Value(resource),
          payload: Value(Uint8List.fromList(payload)),
          status: Value(status),
          attempts: Value(attempts),
          error: Value(error),
          created: Value(_nowMs()),
        ),
      );

  return (database.select(
    database.logs,
  )..where((t) => t.id.equals(id))).getSingle();
}

Future<File> _createTempDbFile() async {
  final dir = await Directory.systemTemp.createTemp('eduxal_invite_sync_test_');
  return File('${dir.path}/test.sqlite');
}

Future<AppDatabase> _reopenWithMigration(File file) async {
  final database = AppDatabase.forTesting(NativeDatabase(file));
  await database.customStatement('PRAGMA user_version = 11');
  await database.close();
  return AppDatabase.forTesting(NativeDatabase(file));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    app_client.client = await app_client.Client.create();
    app_client.authorization = const AuthorizationService();
  });

  tearDown(() async {
    await db.deleteAllData();
    app_client.cache.clear();
  });

  tearDownAll(() async {
    await db.close();
  });

  group('standalone invite queueing', () {
    test(
      'UsersDao.inviteUser writes inviteUser log and optimistic local user row',
      () async {
        await _seedAuthenticatedSuperUser(db);

        final invitedUser = _userCompanion(
          id: 'invite-1',
          phone: '0712345678',
          name: 'Queued Invite',
          level: UserLevel.system,
          status: UserStatus.invited,
          email: 'ignored@example.com',
        );

        await db.usersDao.inviteUser(invitedUser, accountId: 'actor-super');

        final queued = await db.usersDao.getUser('invite-1');
        final logs = await db.select(db.logs).get();

        expect(queued, isNotNull);
        expect(queued!.phone, '0712345678');
        expect(queued.name, 'Queued Invite');
        expect(queued.level, UserLevel.system);
        expect(queued.status, UserStatus.invited);

        expect(logs, hasLength(1));
        final log = logs.single;
        expect(log.action, SyncAction.inviteUser);
        expect(log.status, LogStatus.pending);

        final payload = sync_pb.InviteUserPayload.fromBuffer(log.payload);
        expect(payload.id, 'invite-1');
        expect(payload.phone, '0712345678');
        expect(payload.name, 'Queued Invite');
        expect(payload.level, UserLevel.system.index);
      },
    );
  });

  group('legacy invite log migration', () {
    test(
      'rewrites pending legacy invite-shaped updateUser log to inviteUser',
      () async {
        final file = await _createTempDbFile();
        AppDatabase? database;
        AppDatabase? reopened;

        try {
          database = AppDatabase.forTesting(NativeDatabase(file));
          await _seedAccount(
            database,
            id: 'actor-pending',
            phone: '0700000001',
            name: 'Pending Actor',
            level: UserLevel.super_,
          );

          final legacy = sync_pb.UpdateUserPayload(
            id: 'legacy-pending',
            phone: '0722000000',
            name: 'Legacy Pending Invite',
            level: UserLevel.system.index,
            status: UserStatus.invited.index,
          )..email = 'legacy@example.com';

          await _insertLog(
            database,
            accountId: 'actor-pending',
            action: SyncAction.updateUser,
            payload: legacy.writeToBuffer(),
            resource: '0722000000',
          );

          reopened = await _reopenWithMigration(file);
          final migrated = await reopened.select(reopened.logs).getSingle();

          expect(migrated.action, SyncAction.inviteUser);
          expect(migrated.status, LogStatus.pending);

          final payload = sync_pb.InviteUserPayload.fromBuffer(
            migrated.payload,
          );
          expect(payload.id, 'legacy-pending');
          expect(payload.phone, '0722000000');
          expect(payload.name, 'Legacy Pending Invite');
          expect(payload.level, UserLevel.system.index);
        } finally {
          await reopened?.close();
          await database?.close();
          final dir = file.parent;
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
        }
      },
    );

    test(
      'rewrites failed legacy invite log and resets it to pending',
      () async {
        final file = await _createTempDbFile();
        AppDatabase? database;
        AppDatabase? reopened;

        try {
          database = AppDatabase.forTesting(NativeDatabase(file));
          await _seedAccount(
            database,
            id: 'actor-failed',
            phone: '0700000002',
            name: 'Failed Actor',
            level: UserLevel.super_,
          );

          final legacy = sync_pb.UpdateUserPayload(
            id: 'legacy-failed',
            phone: '0722000001',
            name: 'Legacy Failed Invite',
            level: UserLevel.system.index,
            status: UserStatus.invited.index,
          );

          await _insertLog(
            database,
            accountId: 'actor-failed',
            action: SyncAction.updateUser,
            payload: legacy.writeToBuffer(),
            status: LogStatus.failed,
            attempts: 3,
            error: 'Permission denied',
            resource: '0722000001',
          );

          reopened = await _reopenWithMigration(file);
          final migrated = await reopened.select(reopened.logs).getSingle();

          expect(migrated.action, SyncAction.inviteUser);
          expect(migrated.status, LogStatus.pending);
          expect(migrated.attempts, 0);
          expect(migrated.error, isNull);

          final payload = sync_pb.InviteUserPayload.fromBuffer(
            migrated.payload,
          );
          expect(payload.id, 'legacy-failed');
          expect(payload.phone, '0722000001');
          expect(payload.name, 'Legacy Failed Invite');
          expect(payload.level, UserLevel.system.index);
        } finally {
          await reopened?.close();
          await database?.close();
          final dir = file.parent;
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
        }
      },
    );

    test('does not rewrite genuine updateUser logs', () async {
      final file = await _createTempDbFile();
      AppDatabase? database;
      AppDatabase? reopened;

      try {
        database = AppDatabase.forTesting(NativeDatabase(file));
        await _seedAccount(
          database,
          id: 'actor-update',
          phone: '0700000003',
          name: 'Update Actor',
          level: UserLevel.super_,
        );

        final genuine = sync_pb.UpdateUserPayload(
          id: 'real-user',
          name: 'Updated Name',
        );
        final originalBytes = genuine.writeToBuffer();

        await _insertLog(
          database,
          accountId: 'actor-update',
          action: SyncAction.updateUser,
          payload: originalBytes,
          resource: 'real-user',
        );

        reopened = await _reopenWithMigration(file);
        final preserved = await reopened.select(reopened.logs).getSingle();

        expect(preserved.action, SyncAction.updateUser);
        expect(preserved.payload, orderedEquals(originalBytes));
        expect(preserved.status, LogStatus.pending);

        final payload = sync_pb.UpdateUserPayload.fromBuffer(preserved.payload);
        expect(payload.id, 'real-user');
        expect(payload.name, 'Updated Name');
        expect(payload.hasPhone(), isFalse);
      } finally {
        await reopened?.close();
        await database?.close();
        final dir = file.parent;
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('invite revert behavior', () {
    test(
      'discarding a failed standalone invite log removes the optimistic invited user row',
      () async {
        await _seedAuthenticatedSuperUser(db);

        await db.usersDao.inviteUser(
          _userCompanion(
            id: 'invite-revert',
            phone: '0733000000',
            name: 'Revert Me',
            level: UserLevel.system,
            status: UserStatus.invited,
          ),
          accountId: 'actor-super',
        );

        final log = await db.select(db.logs).getSingle();
        await (db.update(db.logs)..where((t) => t.id.equals(log.id))).write(
          const LogsCompanion(
            status: Value(LogStatus.failed),
            attempts: Value(2),
            error: Value('server rejected invite'),
          ),
        );

        await db.logsDao.deleteLogAndRevert(log.id);

        final remainingLog = await db.select(db.logs).get();
        final remainingUser = await db.usersDao.getUser('invite-revert');

        expect(remainingLog, isEmpty);
        expect(remainingUser, isNull);
      },
    );
  });

  group('school-owner flow cleanup', () {
    test(
      'createSchool flow queues only createSchool even for a staged invited owner',
      () async {
        await _seedAuthenticatedSuperUser(db);
        final owner = await _stageUser(
          db,
          id: 'school-owner-user',
          phone: '0744000000',
          name: 'School Owner',
          level: UserLevel.normal,
          status: UserStatus.invited,
          email: 'owner@example.com',
        );

        await db.schoolsDao.createSchool(
          school: _schoolCompanion(id: 'school-1', name: 'Alpha School'),
          ownerUser: owner,
          accountId: 'actor-super',
        );

        final logs = await db.select(db.logs).get();
        expect(logs, hasLength(1));
        expect(logs.single.action, SyncAction.createSchool);
        expect(
          logs.where((log) => log.action == SyncAction.inviteUser),
          isEmpty,
        );

        final payload = sync_pb.CreateSchoolPayload.fromBuffer(
          logs.single.payload,
        );
        expect(payload.id, 'school-1');
        expect(payload.ownerId, 'school-owner-user');
        expect(payload.ownerPhone, '0744000000');
        expect(payload.ownerName, 'School Owner');
      },
    );

    test(
      'linkOwner flow queues only createOwner even for a staged invited owner',
      () async {
        await _seedAuthenticatedSuperUser(db);
        await db
            .into(db.schools)
            .insert(_schoolCompanion(id: 'school-2', name: 'Beta School'));
        final owner = await _stageUser(
          db,
          id: 'linked-owner-user',
          phone: '0755000000',
          name: 'Linked Owner',
          level: UserLevel.normal,
          status: UserStatus.invited,
          email: 'linked@example.com',
        );

        await db.schoolsDao.linkOwner(
          schoolId: 'school-2',
          ownerUser: owner,
          accountId: 'actor-super',
        );

        final logs = await db.select(db.logs).get();
        expect(logs, hasLength(1));
        expect(logs.single.action, SyncAction.createOwner);
        expect(
          logs.where((log) => log.action == SyncAction.inviteUser),
          isEmpty,
        );

        final payload = sync_pb.CreateOwnerPayload.fromBuffer(
          logs.single.payload,
        );
        expect(payload.school, 'school-2');
        expect(payload.userId, 'linked-owner-user');
        expect(payload.phone, '0755000000');
        expect(payload.name, 'Linked Owner');
      },
    );
  });
}
