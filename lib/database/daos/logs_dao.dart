import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../../models/app_notification.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;

part 'logs_dao.g.dart';

@DriftAccessor(tables: [Logs])
class LogsDao extends DatabaseAccessor<AppDatabase> with _$LogsDaoMixin {
  LogsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────
  // Writes — enqueueing actions
  // ─────────────────────────────────────────────────────────────────────

  /// Appends a new action log entry to the queue.
  ///
  /// The caller provides:
  /// - [LogsCompanion.action] — SyncAction enum value
  /// - [LogsCompanion.resource] — human-readable display key
  /// - [LogsCompanion.payload] — serialized proto payload bytes
  /// - [LogsCompanion.created] — milliseconds since epoch
  Future<void> insertLog(LogsCompanion log) {
    return into(logs).insert(log);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Reads — sync engine consumption
  // ─────────────────────────────────────────────────────────────────────

  /// Returns all pending entries for [accountId], oldest first.
  Future<List<LogsData>> getPendingLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.pending),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// Returns all failed entries for [accountId].
  Future<List<LogsData>> getFailedLogs(String accountId) {
    return (select(logs)..where(
          (t) =>
              t.account.equals(accountId) &
              t.status.equalsValue(LogStatus.failed),
        ))
        .get();
  }

  /// Emits all failed log entries as [AppNotification] objects,
  /// ordered by created descending, whenever the logs table changes.
  Stream<List<AppNotification>> watchFailedLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.failed),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => AppNotification(
                  logId: row.id,
                  action: row.action,
                  resource: row.resource,
                  errorMessage: row.error,
                  attempts: row.attempts,
                  occurred: DateTime.fromMillisecondsSinceEpoch(
                    row.created.toInt(),
                  ),
                ),
              )
              .toList(),
        );
  }

  /// Reactive count of failed entries for [accountId].
  Stream<int> watchFailedLogCount(String accountId) {
    final countExpr = logs.id.count();
    final query = selectOnly(logs)
      ..addColumns([countExpr])
      ..where(
        logs.account.equals(accountId) &
            logs.status.equalsValue(LogStatus.failed),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Deletes — after successful sync
  // ─────────────────────────────────────────────────────────────────────

  /// Deletes a single log entry by [id] after successful sync.
  Future<void> deleteLog(int id) {
    return (delete(logs)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes multiple log entries by their [ids].
  Future<void> deleteLogs(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(logs)..where((t) => t.id.isIn(ids))).go();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Error tracking
  // ─────────────────────────────────────────────────────────────────────

  /// Marks a log entry as failed and records the error message.
  Future<void> markFailed(int id, String error) {
    return customStatement(
      'UPDATE logs SET status = ?, error = ?, attempts = attempts + 1 WHERE id = ?',
      [LogStatus.failed.index, error, id],
    );
  }

  /// Resets a failed log entry back to [LogStatus.pending] so the sync engine
  /// picks it up on the next push cycle.
  ///
  /// The [attempts] counter and [error] field are cleared so the engine treats
  /// this as a fresh attempt.
  Future<void> retryLog(int id) {
    return customStatement(
      'UPDATE logs SET status = ?, error = NULL, attempts = 0 WHERE id = ?',
      [LogStatus.pending.index, id],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Delete + revert — remove log and undo the optimistic local write
  // ─────────────────────────────────────────────────────────────────────

  /// Deletes the log entry and, for **create** actions, also deletes the
  /// optimistically-inserted local row from the appropriate table.
  ///
  /// Both operations run inside a single Drift transaction for atomicity.
  ///
  /// **Create actions** — the payload is parsed to extract the PK of the
  /// locally-inserted row, which is then deleted. For invitation-pattern
  /// creates (teacher / staff / owner / guardian) the optimistic `users` row
  /// is also removed, but only when it was client-generated (status = Invited
  /// and a phone number is present in the payload — indicating the client
  /// invented the user ID rather than linking to an existing account).
  ///
  /// **All other action types** (update, delete, mark, assign, unassign,
  /// enroll, unenroll, approve) operated on rows that already existed on the
  /// server. Only the log entry is removed; the locally-modified data is left
  /// intact — the authoritative server version will arrive via watchChanges.
  Future<void> deleteLogAndRevert(int id) async {
    final row = await (select(
      logs,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await db.transaction(() async {
      await _revertCreate(row.action, row.payload);
      await (delete(logs)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Issues a raw DELETE against the locally-inserted row for the given
  /// `create*` [action]. For all other action types this is a no-op.
  Future<void> _revertCreate(SyncAction action, List<int> payload) async {
    switch (action) {
      // ── Schools ──────────────────────────────────────────────────────────
      case SyncAction.createSchool:
        final p = sync_pb.CreateSchoolPayload.fromBuffer(payload);
        await customStatement('DELETE FROM schools WHERE id = ?', [p.id]);

      // ── Teachers ─────────────────────────────────────────────────────────
      case SyncAction.createTeacher:
        final p = sync_pb.CreateTeacherPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM teachers WHERE school = ? AND user = ?',
          [p.school, p.userId],
        );
        // Remove the optimistic users row only when the client invented it
        // (phone present in payload = invitation flow, not an existing user).
        if (p.hasUserId() && p.hasPhone()) {
          await customStatement(
            'DELETE FROM users WHERE id = ? AND status = ?',
            [p.userId, 0], // 0 = Invited
          );
        }

      // ── Staff ─────────────────────────────────────────────────────────────
      case SyncAction.createStaff:
        final p = sync_pb.CreateStaffPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM staff WHERE school = ? AND user = ?',
          [p.school, p.userId],
        );
        if (p.hasUserId() && p.hasPhone()) {
          await customStatement(
            'DELETE FROM users WHERE id = ? AND status = ?',
            [p.userId, 0],
          );
        }

      // ── Owners ────────────────────────────────────────────────────────────
      case SyncAction.createOwner:
        final p = sync_pb.CreateOwnerPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM owners WHERE school = ? AND user = ?',
          [p.school, p.userId],
        );
        if (p.hasUserId() && p.hasPhone()) {
          await customStatement(
            'DELETE FROM users WHERE id = ? AND status = ?',
            [p.userId, 0],
          );
        }

      // ── Students ──────────────────────────────────────────────────────────
      case SyncAction.createStudent:
        final p = sync_pb.CreateStudentPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM students WHERE school = ? AND adm = ?',
          [p.school, p.adm],
        );

      // ── Guardians ─────────────────────────────────────────────────────────
      case SyncAction.createGuardian:
        final p = sync_pb.CreateGuardianPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM guardians WHERE school = ? AND user = ? AND student = ?',
          [p.school, p.userId, p.student],
        );
        if (p.hasUserId() && p.hasPhone()) {
          await customStatement(
            'DELETE FROM users WHERE id = ? AND status = ?',
            [p.userId, 0],
          );
        }

      // ── Departments ───────────────────────────────────────────────────────
      case SyncAction.createDepartment:
        final p = sync_pb.CreateDepartmentPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM departments WHERE school = ? AND name = ?',
          [p.school, p.name],
        );

      // ── Terms ─────────────────────────────────────────────────────────────
      case SyncAction.createTerm:
        final p = sync_pb.CreateTermPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM terms WHERE school = ? AND year = ? AND term = ?',
          [p.school, p.year, p.term],
        );

      // ── Timetable entries ─────────────────────────────────────────────────
      case SyncAction.createTimetableEntry:
        final p = sync_pb.CreateTimetableEntryPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM timetable '
          'WHERE school = ? AND year = ? AND term = ? AND grade = ? '
          'AND stream = ? AND day = ? AND subject = ? AND start = ?',
          [
            p.school,
            p.year,
            p.term,
            p.grade,
            p.stream,
            p.day,
            p.subject,
            p.start,
          ],
        );

      // ── Lessons ───────────────────────────────────────────────────────────
      case SyncAction.createLesson:
        final p = sync_pb.CreateLessonPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM lessons '
          'WHERE school = ? AND year = ? AND term = ? AND grade = ? '
          'AND stream = ? AND date = ? AND subject = ? AND teacher = ?',
          [
            p.school,
            p.year,
            p.term,
            p.grade,
            p.stream,
            p.date,
            p.subject,
            p.teacher,
          ],
        );

      // ── Exams ─────────────────────────────────────────────────────────────
      case SyncAction.createExam:
        final p = sync_pb.CreateExamPayload.fromBuffer(payload);
        await customStatement('DELETE FROM exams WHERE id = ?', [p.id]);

      // ── Papers ────────────────────────────────────────────────────────────
      // The `paper` column is nullable: null = subject-level paper,
      // non-null = numbered paper (e.g. Paper 1, 2, 3).
      case SyncAction.createPaper:
        final p = sync_pb.CreatePaperPayload.fromBuffer(payload);
        if (p.hasPaper()) {
          await customStatement(
            'DELETE FROM papers '
            'WHERE school = ? AND exam = ? AND subject = ? AND paper = ?',
            [p.school, p.exam, p.subject, p.paper],
          );
        } else {
          await customStatement(
            'DELETE FROM papers '
            'WHERE school = ? AND exam = ? AND subject = ? AND paper IS NULL',
            [p.school, p.exam, p.subject],
          );
        }

      // ── Fees ──────────────────────────────────────────────────────────────
      case SyncAction.createFee:
        final p = sync_pb.CreateFeePayload.fromBuffer(payload);
        await customStatement('DELETE FROM fees WHERE id = ?', [p.id]);

      // ── Invoices ──────────────────────────────────────────────────────────
      case SyncAction.createInvoice:
        final p = sync_pb.CreateInvoicePayload.fromBuffer(payload);
        await customStatement('DELETE FROM invoices WHERE id = ?', [p.id]);

      // ── Payments ──────────────────────────────────────────────────────────
      case SyncAction.createPayment:
        final p = sync_pb.CreatePaymentPayload.fromBuffer(payload);
        await customStatement('DELETE FROM payments WHERE id = ?', [p.id]);

      // ── Announcements ─────────────────────────────────────────────────────
      case SyncAction.createAnnouncement:
        final p = sync_pb.CreateAnnouncementPayload.fromBuffer(payload);
        await customStatement('DELETE FROM announcements WHERE id = ?', [p.id]);

      // ── Roles ─────────────────────────────────────────────────────────────
      case SyncAction.createRole:
        final p = sync_pb.CreateRolePayload.fromBuffer(payload);
        await customStatement('DELETE FROM roles WHERE id = ?', [p.id]);

      // ── Plans ─────────────────────────────────────────────────────────────
      case SyncAction.createPlan:
        final p = sync_pb.CreatePlanPayload.fromBuffer(payload);
        await customStatement('DELETE FROM plans WHERE id = ?', [p.id]);

      // ── Subscriptions ─────────────────────────────────────────────────────
      case SyncAction.createSubscription:
        final p = sync_pb.CreateSubscriptionPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM subscriptions '
          'WHERE school = ? AND plan = ? AND year = ? AND term = ? AND student = ?',
          [p.school, p.plan, p.year, p.term, p.student],
        );

      // ── Discounts ─────────────────────────────────────────────────────────
      case SyncAction.createDiscount:
        final p = sync_pb.CreateDiscountPayload.fromBuffer(payload);
        await customStatement(
          'DELETE FROM discounts '
          'WHERE school = ? AND plan = ? AND year = ? AND term = ? AND grade = ?',
          [p.school, p.plan, p.year, p.term, p.grade],
        );

      // ── Non-create actions — no local data to revert ──────────────────────
      // update / delete / mark / assign / unassign / enroll / unenroll /
      // approve all target rows that already existed on the server.
      // Dropping the log is sufficient; the server's authoritative version
      // will arrive (or has already arrived) via the watchChanges stream.
      default:
        break;
    }
  }
}
