import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/curriculum_subjects.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/mpesa.dart';
import '../tables/streams.dart';
import '../tables/subjects.dart';
import '../tables/topics.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

part 'catalog_dao.g.dart';

/// DAO for global catalog tables: [Subjects], [Topics], [Streams], [Mpesa].
///
/// - [Subjects] is the **global** subject catalog (id, name, curriculum). It
///   is populated by System/Super users only and is shared across all schools.
/// - [Topics] are grade-specific subdivisions of a subject, also global.
/// - [Streams] are per-school named stream definitions (e.g. "East", "West").
/// - [Mpesa] is per-school M-Pesa Daraja API integration configuration.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay it to the server when
/// connectivity is restored.
@DriftAccessor(tables: [Subjects, Topics, Streams, Mpesa, Logs])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Subjects (global catalog)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches all subjects in the global catalog, ordered by name.
  Stream<List<Subject>> watchSubjects() {
    return (select(
      subjects,
    )..orderBy([(s) => OrderingTerm.asc(s.name)])).watch();
  }

  /// Reactively watches subjects filtered by [curriculum], ordered by name.
  Stream<List<Subject>> watchSubjectsByCurriculum(CurriculumType curriculum) {
    return (select(subjects)
          ..where((s) => s.curriculum.equals(curriculum.index_))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  /// One-shot read of all subjects.
  Future<List<Subject>> getSubjects() => select(subjects).get();

  /// One-shot read of a single subject by [id], or null.
  Future<Subject?> getSubject(int id) =>
      (select(subjects)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Inserts a subject locally (optimistic) and writes a
  /// [SyncAction.createSubject] log. The local row uses an autoIncrement ID
  /// which may differ from the server's. When the server responds, the
  /// [DeltaWriter] deletes the stale local row by natural key and inserts
  /// the authoritative row with the server-assigned ID.
  Future<void> createSubject({
    required String name,
    required CurriculumType curriculum,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createSubject,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(subjects).insert(
        SubjectsCompanion(
          name: Value(name),
          curriculum: Value(curriculum),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
      );

      final payload = sync_pb.CreateSubjectPayload(
        name: name,
        curriculum: curriculum.index_,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createSubject),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Finds an existing subject by name and curriculum, or creates a new one.
  /// Returns the subject ID (local auto-increment or existing).
  /// Writes a `createSubject` log entry only when creating a new subject.
  Future<int> findOrCreateSubject({
    required String name,
    required CurriculumType curriculum,
    required String accountId,
  }) async {
    final existing =
        await (select(subjects)..where(
              (s) =>
                  s.name.equals(name) & s.curriculum.equals(curriculum.index_),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    await createSubject(
      name: name,
      curriculum: curriculum,
      accountId: accountId,
    );
    final created =
        await (select(subjects)
              ..where(
                (s) =>
                    s.name.equals(name) &
                    s.curriculum.equals(curriculum.index_),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.id)]))
            .getSingle();
    return created.id;
  }

  /// Updates a subject's [name] and/or [curriculum] and writes a
  /// [SyncAction.updateSubject] log.
  Future<void> updateSubject({
    required int id,
    String? name,
    CurriculumType? curriculum,
    required String accountId,
  }) async {
    if (name == null && curriculum == null) return;

    final _authResult = await authorization.check(
      action: SyncAction.updateSubject,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(subjects)..where((s) => s.id.equals(id))).write(
        SubjectsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          curriculum: curriculum != null
              ? Value(curriculum)
              : const Value.absent(),
          updated: Value(nowSeconds),
        ),
      );

      final payload = sync_pb.UpdateSubjectPayload(id: id);
      if (name != null) payload.name = name;
      if (curriculum != null) payload.curriculum = curriculum.index_;

      final current = await (select(
        subjects,
      )..where((s) => s.id.equals(id))).getSingleOrNull();

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateSubject),
          resource: Value(current?.name ?? 'Subject $id'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes a subject by [id] and writes a [SyncAction.deleteSubject] log.
  Future<void> deleteSubject({
    required int id,
    required String subjectName,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteSubject,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteSubjectPayload(id: id);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteSubject),
          resource: Value(subjectName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(subjects)..where((s) => s.id.equals(id))).go();
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Topics
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches all topics belonging to subjects of the given
  /// [curriculum], ordered by name.  Uses an inner join on [Subjects] so that
  /// only topics whose parent subject matches the curriculum are returned.
  Stream<List<Topic>> watchTopicsByCurriculum(CurriculumType curriculum) {
    final q = select(topics).join([
      innerJoin(subjects, subjects.id.equalsExp(topics.subject)),
    ])..where(subjects.curriculum.equals(curriculum.index_));
    return q.watch().map(
      (rows) => rows.map((row) => row.readTable(topics)).toList(),
    );
  }

  /// Reactively watches all topics for [subjectId] and [grade], ordered by
  /// name.
  Stream<List<Topic>> watchTopicsBySubjectAndGrade({
    required int subjectId,
    required int grade,
  }) {
    return (select(topics)
          ..where((t) => t.subject.equals(subjectId) & t.grade.equals(grade))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// One-shot read of all topics for [subjectId].
  Future<List<Topic>> getTopicsForSubject(int subjectId) =>
      (select(topics)..where((t) => t.subject.equals(subjectId))).get();

  /// Reactively watches the total topic count for [subjectId] across all
  /// grades. Used for the count badge on subject tiles.
  Stream<int> watchTopicCountForSubject(int subjectId) {
    return (select(topics)..where((t) => t.subject.equals(subjectId)))
        .watch()
        .map((list) => list.length);
  }

  /// Inserts a topic locally (optimistic) and writes a
  /// [SyncAction.createTopic] log. The local row uses an autoIncrement ID
  /// which may differ from the server's. When the server responds, the
  /// [DeltaWriter] deletes the stale local row by natural key and inserts
  /// the authoritative row with the server-assigned ID.
  Future<void> createTopic({
    required int subjectId,
    required int grade,
    required String name,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createTopic,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(topics).insert(
        TopicsCompanion(
          subject: Value(subjectId),
          grade: Value(grade),
          name: Value(name),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
      );

      final payload = sync_pb.CreateTopicPayload(
        subject: subjectId,
        grade: grade,
        name: name,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createTopic),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates a topic's [name] and writes a [SyncAction.updateTopic] log.
  Future<void> updateTopic({
    required int id,
    required String name,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateTopic,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(topics)..where((t) => t.id.equals(id))).write(
        TopicsCompanion(name: Value(name), updated: Value(nowSeconds)),
      );

      final payload = sync_pb.UpdateTopicPayload(id: id, name: name);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateTopic),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes a topic by [id] and writes a [SyncAction.deleteTopic] log.
  Future<void> deleteTopic({
    required int id,
    required String topicName,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteTopic,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteTopicPayload(id: id);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteTopic),
          resource: Value(topicName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(topics)..where((t) => t.id.equals(id))).go();
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Streams (per-school)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches all streams for [schoolId] and [grade], ordered by
  /// stream number.
  Stream<List<SchoolStream>> watchStreamsBySchoolAndGrade({
    required String schoolId,
    required int grade,
  }) {
    return (select(streams)
          ..where((s) => s.school.equals(schoolId) & s.grade.equals(grade))
          ..orderBy([(s) => OrderingTerm.asc(s.stream)]))
        .watch();
  }

  /// Reactively watches all streams for [schoolId], ordered by grade then
  /// stream number. Used by the Academics screen to build the full grade tree.
  Stream<List<SchoolStream>> watchAllStreamsForSchool(String schoolId) {
    return (select(streams)
          ..where((s) => s.school.equals(schoolId))
          ..orderBy([
            (s) => OrderingTerm.asc(s.grade),
            (s) => OrderingTerm.asc(s.stream),
          ]))
        .watch();
  }

  /// One-shot read of all streams for [schoolId].
  Future<List<SchoolStream>> getStreamsForSchool(String schoolId) =>
      (select(streams)..where((s) => s.school.equals(schoolId))).get();

  /// Creates a stream entry and writes a [SyncAction.createStream] log.
  Future<void> createSchoolStream({
    required String schoolId,
    required int grade,
    required int streamCode,
    required String name,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createStream,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(streams).insert(
        StreamsCompanion(
          school: Value(schoolId),
          grade: Value(grade),
          stream: Value(streamCode),
          name: Value(name),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
      );

      final payload = sync_pb.CreateStreamPayload(
        school: schoolId,
        grade: grade,
        stream: streamCode,
        name: name,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createStream),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates a stream's [name] and writes a [SyncAction.updateStream] log.
  Future<void> updateStream({
    required String schoolId,
    required int grade,
    required int streamCode,
    required String name,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateStream,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(streams)..where(
            (s) =>
                s.school.equals(schoolId) &
                s.grade.equals(grade) &
                s.stream.equals(streamCode),
          ))
          .write(
            StreamsCompanion(name: Value(name), updated: Value(nowSeconds)),
          );

      final payload = sync_pb.UpdateStreamPayload(
        school: schoolId,
        grade: grade,
        stream: streamCode,
        name: name,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateStream),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes a stream and writes a [SyncAction.deleteStream] log.
  Future<void> deleteStream({
    required String schoolId,
    required int grade,
    required int streamCode,
    required String streamName,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteStream,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteStreamPayload(
        school: schoolId,
        grade: grade,
        stream: streamCode,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteStream),
          resource: Value(streamName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(streams)..where(
            (s) =>
                s.school.equals(schoolId) &
                s.grade.equals(grade) &
                s.stream.equals(streamCode),
          ))
          .go();
    });
    sync.schedulePush();
  }

  /// Deletes **all** streams for a given school + grade, writing one
  /// [SyncAction.deleteStream] log entry per stream removed.
  ///
  /// Used when the user removes an entire grade from the Academics screen.
  Future<void> deleteAllStreamsForGrade({
    required String schoolId,
    required int grade,
    required String gradeLabel,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteStream,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Fetch all streams for this grade so we can log each deletion.
      final existing = await (select(
        streams,
      )..where((s) => s.school.equals(schoolId) & s.grade.equals(grade))).get();

      for (final s in existing) {
        final payload = sync_pb.DeleteStreamPayload(
          school: schoolId,
          grade: grade,
          stream: s.stream,
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.deleteStream),
            resource: Value(s.name),
            payload: Value(payload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );
      }

      // Bulk-delete all streams for this grade.
      await (delete(
        streams,
      )..where((s) => s.school.equals(schoolId) & s.grade.equals(grade))).go();
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mpesa (per-school)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches the M-Pesa config row for [schoolId], or null.
  Stream<MpesaData?> watchMpesa(String schoolId) {
    return (select(
      mpesa,
    )..where((m) => m.school.equals(schoolId))).watchSingleOrNull();
  }

  /// One-shot read of the M-Pesa config for [schoolId], or null.
  Future<MpesaData?> getMpesa(String schoolId) => (select(
    mpesa,
  )..where((m) => m.school.equals(schoolId))).getSingleOrNull();

  /// Upserts M-Pesa config and writes a [SyncAction.createMpesa] or
  /// [SyncAction.updateMpesa] log depending on whether a row already exists.
  Future<void> upsertMpesa({
    required String schoolId,
    required String consumerKey,
    required String consumerSecret,
    required String passkey,
    required String shortcode,
    required MpesaEnv env,
    required String accountId,
  }) async {
    // Pre-check whether a row exists to determine the correct SyncAction.
    final _existingMpesa = await getMpesa(schoolId);
    final _authResult = await authorization.check(
      action: _existingMpesa == null
          ? SyncAction.createMpesa
          : SyncAction.updateMpesa,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final existing = await getMpesa(schoolId);

      await into(mpesa).insertOnConflictUpdate(
        MpesaCompanion(
          school: Value(schoolId),
          consumerKey: Value(consumerKey),
          consumerSecret: Value(consumerSecret),
          passkey: Value(passkey),
          shortcode: Value(shortcode),
          env: Value(env),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
      );

      final Uint8List payloadBytes;
      final SyncAction action;

      if (existing == null) {
        payloadBytes = sync_pb.CreateMpesaPayload(
          school: schoolId,
          consumerKey: consumerKey,
          consumerSecret: consumerSecret,
          passkey: passkey,
          shortcode: shortcode,
          env: env.index,
        ).writeToBuffer();
        action = SyncAction.createMpesa;
      } else {
        payloadBytes = sync_pb.UpdateMpesaPayload(
          school: schoolId,
          consumerKey: consumerKey,
          consumerSecret: consumerSecret,
          passkey: passkey,
          shortcode: shortcode,
          env: env.index,
        ).writeToBuffer();
        action = SyncAction.updateMpesa;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(action),
          resource: Value(schoolId),
          payload: Value(payloadBytes),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes M-Pesa config and writes a [SyncAction.deleteMpesa] log.
  Future<void> deleteMpesa({
    required String schoolId,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteMpesa,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteMpesaPayload(school: schoolId);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteMpesa),
          resource: Value(schoolId),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(mpesa)..where((m) => m.school.equals(schoolId))).go();
    });
    sync.schedulePush();
  }
}
