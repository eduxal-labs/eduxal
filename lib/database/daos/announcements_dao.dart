import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/announcements.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

part 'announcements_dao.g.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Data models — joined rows used by the UI
// ═════════════════════════════════════════════════════════════════════════════

/// An announcement joined with its author's name from the `users` table.
///
/// When the author has been deleted (SET NULL on the FK), [authorName] is
/// `null` and the UI should display a placeholder like "Deleted user".
class AnnouncementWithAuthor {
  const AnnouncementWithAuthor({required this.announcement, this.authorName});

  final Announcement announcement;
  final String? authorName;

  /// Convenience — announcement id.
  String get id => announcement.id;

  /// Convenience — school id.
  String get school => announcement.school;

  /// Convenience — announcement title.
  String get title => announcement.title;

  /// Convenience — announcement content.
  String get content => announcement.content;

  /// Convenience — targeted grade (null = all grades).
  int? get grade => announcement.grade;

  /// Convenience — targeted stream (null = all streams within the grade).
  int? get stream => announcement.stream;

  /// Audience bitmask.
  ///
  /// Bit 0 = Students (1), Bit 1 = Parents/Guardians (2),
  /// Bit 2 = Teachers (4), Bit 3 = Staff (8).
  /// 0 = All (no filter — visible to everyone).
  int get audience => announcement.audience;

  /// Author user id, or `null` if the author was deleted.
  String? get authorId => announcement.author;

  /// Epoch seconds when the announcement was created.
  BigInt get created => announcement.created;

  /// Epoch seconds when the announcement was last updated.
  BigInt get updated => announcement.updated;

  /// Whether this announcement targets a specific audience bitmask or is
  /// visible to all roles.
  bool get isTargeted => audience != 0;

  /// Whether the announcement is visible to the given [audienceBit].
  ///
  /// An audience value of 0 means "all" — always visible.
  /// Otherwise check the specific bit.
  bool isVisibleTo(int audienceBit) {
    if (audience == 0) return true;
    return (audience & audienceBit) != 0;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Audience bit constants
// ═════════════════════════════════════════════════════════════════════════════

/// Audience bitmask constants matching the schema:
///   bit 0 = Students (1)
///   bit 1 = Parents/Guardians (2)
///   bit 2 = Teachers (4)
///   bit 3 = Staff (8)
///   0     = All (no filter)
abstract final class AudienceBits {
  static const int all = 0;
  static const int students = 1 << 0; // 1
  static const int guardians = 1 << 1; // 2
  static const int teachers = 1 << 2; // 4
  static const int staff = 1 << 3; // 8

  /// Returns the audience bit for a given [MembershipRole]-like string.
  /// Owner has no dedicated bit — owners always see everything.
  static int forRoleLabel(String label) => switch (label) {
    'student' => students,
    'guardian' => guardians,
    'teacher' => teachers,
    'staff' => staff,
    _ => 0, // owner or unknown — sees all
  };

  /// Human-readable labels for each audience flag (used in the creation UI).
  static const Map<int, String> labels = {
    students: 'Students',
    guardians: 'Guardians',
    teachers: 'Teachers',
    staff: 'Staff',
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// DAO
// ═════════════════════════════════════════════════════════════════════════════

/// DAO for the [Announcements] table.
///
/// Provides reactive streams and mutation methods for school-wide
/// communications. All local mutations write corresponding entries to the
/// [Logs] table inside the same transaction so the sync engine can replay
/// them to the server.
@DriftAccessor(tables: [Announcements, Users, Logs])
class AnnouncementsDao extends DatabaseAccessor<AppDatabase>
    with _$AnnouncementsDaoMixin {
  AnnouncementsDao(super.db);

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Builds the common join expression: announcements LEFT JOIN users ON
  /// author = users.id.
  JoinedSelectStatement<HasResultSet, dynamic> _baseJoin() {
    return select(
      announcements,
    ).join([leftOuterJoin(users, users.id.equalsExp(announcements.author))]);
  }

  /// Maps a [TypedResult] row from the joined query into an
  /// [AnnouncementWithAuthor].
  AnnouncementWithAuthor _mapRow(TypedResult row) {
    return AnnouncementWithAuthor(
      announcement: row.readTable(announcements),
      authorName: row.readTableOrNull(users)?.name,
    );
  }

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits all announcements for [schoolId], newest first, joined with the
  /// author's name. Fires whenever the announcements or users table changes.
  ///
  /// No audience filtering — used by owners who see everything.
  Stream<List<AnnouncementWithAuthor>> watchAllAnnouncements(String schoolId) {
    final q = _baseJoin()
      ..where(announcements.school.equals(schoolId))
      ..orderBy([OrderingTerm.desc(announcements.created)]);

    return q.watch().map((rows) => rows.map(_mapRow).toList());
  }

  /// Emits announcements for [schoolId] filtered by [audienceBit], newest
  /// first. An announcement is included if its `audience` is 0 (all) or if
  /// `audience & audienceBit != 0`.
  ///
  /// Optionally filters by [grade] and [stream] when non-null.
  ///
  /// Used by non-owner roles to see only relevant announcements.
  Stream<List<AnnouncementWithAuthor>> watchAnnouncementsForAudience(
    String schoolId, {
    required int audienceBit,
    int? grade,
    int? stream,
  }) {
    final q = _baseJoin();

    // School filter.
    Expression<bool> condition = announcements.school.equals(schoolId);

    // Audience filter: audience == 0 (all) OR (audience & bit != 0).
    // In SQLite: (audience = 0 OR (audience & ?1) != 0)
    condition =
        condition &
        (announcements.audience.equals(0) |
            announcements.audience
                .bitwiseAnd(Variable(audienceBit))
                .isBiggerThanValue(0));

    // Optional grade filter: null grade means school-wide, so include those
    // announcements too. We want:
    //   announcement.grade IS NULL  (school-wide)
    //   OR announcement.grade = :grade
    if (grade != null) {
      condition =
          condition &
          (announcements.grade.isNull() | announcements.grade.equals(grade));
    }

    // Optional stream filter (only meaningful when grade is also set).
    if (grade != null && stream != null) {
      condition =
          condition &
          (announcements.stream.isNull() | announcements.stream.equals(stream));
    }

    q
      ..where(condition)
      ..orderBy([OrderingTerm.desc(announcements.created)]);

    return q.watch().map((rows) => rows.map(_mapRow).toList());
  }

  /// Emits a single announcement by [id] with the author name, or `null` if
  /// not found. Fires whenever the row changes.
  Stream<AnnouncementWithAuthor?> watchAnnouncement(String id) {
    final q = _baseJoin()..where(announcements.id.equals(id));

    return q.watchSingleOrNull().map(
      (row) => row == null ? null : _mapRow(row),
    );
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns a single announcement by [id] with the author name, or `null`.
  Future<AnnouncementWithAuthor?> getAnnouncement(String id) async {
    final q = _baseJoin()..where(announcements.id.equals(id));
    final row = await q.getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  /// Returns the school ID for [announcementId], or null if not found locally.
  ///
  /// Used by [AuthorizationService] to resolve the organisation context for
  /// [SyncAction.updateAnnouncement] and [SyncAction.deleteAnnouncement].
  Future<String?> getSchoolForAnnouncement(String announcementId) async {
    final row = await (select(
      announcements,
    )..where((t) => t.id.equals(announcementId))).getSingleOrNull();
    return row?.school;
  }

  /// Returns the count of announcements for [schoolId].
  Future<int> countAnnouncements(String schoolId) async {
    final countExpr = announcements.id.count();
    final q = selectOnly(announcements)
      ..addColumns([countExpr])
      ..where(announcements.school.equals(schoolId));
    final row = await q.getSingle();
    return row.read(countExpr) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Sync-sourced writes (no log entry — from the server)
  // ---------------------------------------------------------------------------

  /// Upserts an announcement row from the sync engine. Does NOT write a log.
  Future<void> upsertAnnouncement(AnnouncementsCompanion row) {
    return into(announcements).insertOnConflictUpdate(row);
  }

  /// Deletes an announcement by [id]. Called by the sync engine when the
  /// server pushes a delete delta. Does NOT write a log.
  Future<void> deleteAnnouncementSync(String id) {
    return (delete(announcements)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Local mutation writes (with log entries)
  // ---------------------------------------------------------------------------

  /// Creates a new announcement and writes a corresponding INSERT log entry.
  ///
  /// [id] should be a UUID generated by the caller.
  /// [audience] is a bitmask (0 = all, or OR of [AudienceBits] values).
  /// [accountId] is the currently active account's user id.
  Future<void> createAnnouncement({
    required String id,
    required String schoolId,
    required String title,
    required String content,
    required int audience,
    int? grade,
    int? stream,
    required String authorId,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createAnnouncement,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);

    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(announcements).insert(
        AnnouncementsCompanion(
          id: Value(id),
          school: Value(schoolId),
          title: Value(title),
          content: Value(content),
          grade: Value(grade),
          stream: Value(stream),
          audience: Value(audience),
          author: Value(authorId),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
      );

      // Build the CreateAnnouncementPayload.
      final payload = sync_pb.CreateAnnouncementPayload(
        id: id,
        school: schoolId,
        title: title,
        content: content,
        audience: audience,
        author: authorId,
      );
      if (grade != null) payload.grade = grade;
      if (stream != null) payload.stream = stream;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createAnnouncement),
          resource: Value(title),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates an existing announcement and writes a corresponding UPDATE log
  /// entry with the changed-column bitmask.
  ///
  /// Only non-null parameters are written. At least one field must be provided.
  /// [accountId] is the currently active account's user id.
  Future<void> updateAnnouncement({
    required String id,
    required String accountId,
    String? title,
    String? content,
    int? audience,
    // Use Value<int?> to distinguish "not changing" from "setting to null".
    Value<int?>? grade,
    Value<int?>? stream,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.updateAnnouncement,
      schoolId: null,
      recordId: id,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);

    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      var companion = AnnouncementsCompanion(updated: Value(nowSeconds));

      if (title != null) {
        companion = AnnouncementsCompanion(
          updated: companion.updated,
          title: Value(title),
          content: companion.content,
          audience: companion.audience,
          grade: companion.grade,
          stream: companion.stream,
        );
      }

      if (content != null) {
        companion = AnnouncementsCompanion(
          updated: companion.updated,
          title: companion.title,
          content: Value(content),
          audience: companion.audience,
          grade: companion.grade,
          stream: companion.stream,
        );
      }

      if (audience != null) {
        companion = AnnouncementsCompanion(
          updated: companion.updated,
          title: companion.title,
          content: companion.content,
          audience: Value(audience),
          grade: companion.grade,
          stream: companion.stream,
        );
      }

      if (grade != null) {
        companion = AnnouncementsCompanion(
          updated: companion.updated,
          title: companion.title,
          content: companion.content,
          audience: companion.audience,
          grade: grade,
          stream: companion.stream,
        );
      }

      if (stream != null) {
        companion = AnnouncementsCompanion(
          updated: companion.updated,
          title: companion.title,
          content: companion.content,
          audience: companion.audience,
          grade: companion.grade,
          stream: stream,
        );
      }

      await (update(
        announcements,
      )..where((t) => t.id.equals(id))).write(companion);

      // Build the UpdateAnnouncementPayload with only changed fields.
      final payload = sync_pb.UpdateAnnouncementPayload(id: id);
      bool hasChanges = false;

      if (title != null) {
        payload.title = title;
        hasChanges = true;
      }
      if (content != null) {
        payload.content = content;
        hasChanges = true;
      }
      if (audience != null) {
        payload.audience = audience;
        hasChanges = true;
      }
      if (grade != null && grade.present) {
        if (grade.value != null) payload.grade = grade.value!;
        hasChanges = true;
      }
      if (stream != null && stream.present) {
        if (stream.value != null) payload.stream = stream.value!;
        hasChanges = true;
      }

      if (!hasChanges) return;

      // Use the title if changed, otherwise fetch existing for display.
      String resourceName = title ?? id;
      if (title == null) {
        final existing = await getAnnouncement(id);
        if (existing != null) resourceName = existing.title;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateAnnouncement),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes an announcement by [id] and writes a DELETE log entry.
  ///
  /// The DELETE log supersedes any pending INSERT/UPDATE logs for the same row
  /// (handled by the caller or sync engine via [LogsDao.supersedWithDelete]).
  Future<void> deleteAnnouncement({
    required String id,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.deleteAnnouncement,
      schoolId: null,
      recordId: id,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);

    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Get the title for display before deleting.
      final existing = await getAnnouncement(id);
      final resourceName = existing?.title ?? id;

      await (delete(announcements)..where((t) => t.id.equals(id))).go();

      final payload = sync_pb.DeleteAnnouncementPayload(id: id);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteAnnouncement),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }
}
