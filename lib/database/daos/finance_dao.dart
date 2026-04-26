import 'package:async/async.dart';
import 'package:drift/drift.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import '../database.dart';
import '../tables/enums.dart';
import '../tables/fees.dart';
import '../tables/invoices.dart';
import '../tables/payments.dart';
import '../tables/discounts.dart';
import '../tables/students.dart';
import '../tables/logs.dart';
import '../../client.dart';
import '../tables/terms.dart';
import '../tables/plans.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;

part 'finance_dao.g.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Data models — joined / aggregated rows used by the UI
// ═════════════════════════════════════════════════════════════════════════════

/// A fee definition with the count of invoices generated from it.
class FeeWithStats {
  const FeeWithStats({required this.fee, required this.invoiceCount});

  final Fee fee;
  final int invoiceCount;
}

/// An invoice joined with its linked fee (if any), the student name, and
/// the total amount paid against it.
class InvoiceWithDetails {
  const InvoiceWithDetails({
    required this.invoice,
    required this.studentName,
    required this.studentAdm,
    this.feeTitle,
    required this.totalPaid,
  });

  final Invoice invoice;
  final String studentName;
  final int studentAdm;
  final String? feeTitle;
  final double totalPaid;

  /// Outstanding balance = invoiced amount − payments received.
  double get balance => invoice.amount - totalPaid;

  /// Whether the invoice is fully settled.
  bool get isFullyPaid => balance <= 0.001; // tolerance for floating point
}

/// A payment joined with its invoice details (if linked) and student info.
class PaymentWithDetails {
  const PaymentWithDetails({
    required this.payment,
    this.invoiceId,
    this.invoiceDescription,
    required this.studentName,
    required this.studentAdm,
    this.recorderName,
  });

  final Payment payment;
  final String? invoiceId;
  final String? invoiceDescription;
  final String studentName;
  final int studentAdm;
  final String? recorderName;
}

/// A discount row joined with its plan name.
class DiscountWithPlan {
  const DiscountWithPlan({required this.discount, required this.planName});

  final Discount discount;
  final String planName;
}

/// Financial summary for a school in a specific term.
class TermFinanceSummary {
  const TermFinanceSummary({
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalPending,
    required this.totalOverdue,
    required this.invoiceCount,
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
  });

  final double totalInvoiced;
  final double totalPaid;
  final double totalPending;
  final double totalOverdue;
  final int invoiceCount;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;

  double get collectionRate =>
      totalInvoiced > 0 ? (totalPaid / totalInvoiced) : 0.0;
}

/// A student's financial summary — all invoices and payments rolled up.
class StudentFinanceSummary {
  const StudentFinanceSummary({
    required this.studentName,
    required this.studentAdm,
    required this.invoices,
    required this.payments,
  });

  final String studentName;
  final int studentAdm;
  final List<InvoiceWithDetails> invoices;
  final List<PaymentWithDetails> payments;

  double get totalInvoiced =>
      invoices.fold(0.0, (sum, inv) => sum + inv.invoice.amount);

  double get totalPaid => invoices.fold(0.0, (sum, inv) => sum + inv.totalPaid);

  double get totalBalance => totalInvoiced - totalPaid;
}

/// Lightweight balance summary for a single student across all terms.
///
/// Used by the [StudentBalanceLookup] widget to display a quick snapshot
/// of a student's financial standing without needing full invoice/payment
/// detail objects.
class StudentBalanceSummary {
  const StudentBalanceSummary({
    required this.studentName,
    required this.studentAdm,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.invoices,
  });

  final String studentName;
  final int studentAdm;
  final double totalInvoiced;
  final double totalPaid;
  final List<InvoiceBalanceItem> invoices;

  /// Outstanding balance = total invoiced − total paid.
  double get outstanding => totalInvoiced - totalPaid;

  /// Fraction of total invoiced that has been paid (0.0–1.0).
  double get collectionRate =>
      totalInvoiced > 0 ? totalPaid / totalInvoiced : 0;
}

/// Summary of a single payment method's contribution to daily collections.
class MethodSummary {
  const MethodSummary({required this.count, required this.amount});

  final int count;
  final double amount;
}

/// Aggregated collection totals for today (or any single-day window).
class DailyCollectionSummary {
  const DailyCollectionSummary({
    required this.totalAmount,
    required this.paymentCount,
    required this.byMethod,
  });

  final double totalAmount;
  final int paymentCount;

  /// Breakdown keyed by [PaymentMethod] enum index.
  final Map<int, MethodSummary> byMethod;
}

/// A single invoice's balance breakdown for the student balance card.
class InvoiceBalanceItem {
  const InvoiceBalanceItem({
    required this.invoiceId,
    required this.description,
    required this.amount,
    required this.paid,
  });

  final String invoiceId;
  final String description;
  final double amount;
  final double paid;

  /// Remaining balance on this invoice.
  double get balance => amount - paid;
}

// ═════════════════════════════════════════════════════════════════════════════
// DAO
// ═════════════════════════════════════════════════════════════════════════════

/// DAO for financial tables: [Fees], [Invoices], [Payments], [Discounts].
///
/// Provides reactive streams for the owner/staff financial dashboard and
/// the guardian read-only view, plus local mutation methods that write
/// corresponding [Logs] entries inside the same transaction for offline sync.
@DriftAccessor(
  tables: [Fees, Invoices, Payments, Discounts, Students, Logs, Terms, Plans],
)
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // FEES — reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits all fee definitions for a school/term/grade, ordered by due date.
  Stream<List<Fee>> watchFees({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
  }) {
    return (select(fees)
          ..where(
            (f) =>
                f.school.equals(schoolId) &
                f.year.equals(year) &
                f.term.equals(term) &
                f.grade.equals(grade),
          )
          ..orderBy([(f) => OrderingTerm.asc(f.due)]))
        .watch();
  }

  /// Emits all fee definitions for a school/term (all grades), ordered by
  /// grade then due date.
  Stream<List<Fee>> watchAllFeesForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(fees)
          ..where(
            (f) =>
                f.school.equals(schoolId) &
                f.year.equals(year) &
                f.term.equals(term),
          )
          ..orderBy([
            (f) => OrderingTerm.asc(f.grade),
            (f) => OrderingTerm.asc(f.due),
          ]))
        .watch();
  }

  /// Emits fees with their invoice counts for the overview cards.
  Stream<List<FeeWithStats>> watchFeesWithStats({
    required String schoolId,
    required int year,
    required int term,
  }) {
    final feeTable = alias(fees, 'f');
    final invTable = alias(invoices, 'i');

    final countExpr = invTable.id.count();

    final query = selectOnly(feeTable)
      ..addColumns([
        feeTable.id,
        feeTable.school,
        feeTable.year,
        feeTable.term,
        feeTable.grade,
        feeTable.title,
        feeTable.description,
        feeTable.amount,
        feeTable.mandatory,
        feeTable.due,
        feeTable.created,
        feeTable.updated,
        countExpr,
      ])
      ..join([leftOuterJoin(invTable, invTable.fee.equalsExp(feeTable.id))])
      ..where(
        feeTable.school.equals(schoolId) &
            feeTable.year.equals(year) &
            feeTable.term.equals(term),
      )
      ..groupBy([feeTable.id])
      ..orderBy([
        OrderingTerm.asc(feeTable.grade),
        OrderingTerm.asc(feeTable.due),
      ]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final feeRow = Fee(
          id: row.read(feeTable.id)!,
          school: row.read(feeTable.school)!,
          year: row.read(feeTable.year)!,
          term: row.read(feeTable.term)!,
          grade: row.read(feeTable.grade)!,
          title: row.read(feeTable.title)!,
          description: row.read(feeTable.description)!,
          amount: row.read(feeTable.amount)!,
          mandatory: row.read(feeTable.mandatory)!,
          due: row.read(feeTable.due)!,
          created: row.read(feeTable.created)!,
          updated: row.read(feeTable.updated)!,
        );
        return FeeWithStats(
          fee: feeRow,
          invoiceCount: row.read(countExpr) ?? 0,
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INVOICES — reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the payment totals map for a set of invoices.
  Future<Map<String, double>> _buildPaymentTotals() async {
    final allPayments = await (select(
      payments,
    )..where((p) => p.invoice.isNotNull())).get();

    final paymentTotals = <String, double>{};
    for (final p in allPayments) {
      if (p.invoice != null) {
        paymentTotals[p.invoice!] = (paymentTotals[p.invoice!] ?? 0) + p.amount;
      }
    }
    return paymentTotals;
  }

  /// Emits all invoices for a school/term with joined student name, fee
  /// title, and total payments.
  ///
  /// This is the primary stream for the owner/staff invoice list view.
  Stream<List<InvoiceWithDetails>> watchInvoicesForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    final invStream =
        (select(invoices).join([
                innerJoin(
                  students,
                  students.adm.equalsExp(invoices.student) &
                      students.school.equalsExp(invoices.school),
                ),
                leftOuterJoin(fees, fees.id.equalsExp(invoices.fee)),
              ])
              ..where(
                invoices.school.equals(schoolId) &
                    invoices.year.equals(year) &
                    invoices.term.equals(term),
              )
              ..orderBy([OrderingTerm.desc(invoices.created)]))
            .watch();

    return invStream.asyncMap((invRows) async {
      final paymentTotals = await _buildPaymentTotals();

      return invRows.map((row) {
        final inv = row.readTable(invoices);
        final stu = row.readTable(students);
        final feeRow = row.readTableOrNull(fees);

        return InvoiceWithDetails(
          invoice: inv,
          studentName: stu.name,
          studentAdm: stu.adm,
          feeTitle: feeRow?.title,
          totalPaid: paymentTotals[inv.id] ?? 0.0,
        );
      }).toList();
    });
  }

  /// Emits invoices for a specific student (guardian view).
  Stream<List<InvoiceWithDetails>> watchStudentInvoices({
    required String schoolId,
    required int studentAdm,
    required int year,
    required int term,
  }) {
    return (select(invoices).join([
            innerJoin(
              students,
              students.adm.equalsExp(invoices.student) &
                  students.school.equalsExp(invoices.school),
            ),
            leftOuterJoin(fees, fees.id.equalsExp(invoices.fee)),
          ])
          ..where(
            invoices.school.equals(schoolId) &
                invoices.student.equals(studentAdm) &
                invoices.year.equals(year) &
                invoices.term.equals(term),
          )
          ..orderBy([OrderingTerm.desc(invoices.created)]))
        .watch()
        .asyncMap((rows) async {
          final paymentTotals = await _buildPaymentTotals();

          return rows.map((row) {
            final inv = row.readTable(invoices);
            final stu = row.readTable(students);
            final feeRow = row.readTableOrNull(fees);

            return InvoiceWithDetails(
              invoice: inv,
              studentName: stu.name,
              studentAdm: stu.adm,
              feeTitle: feeRow?.title,
              totalPaid: paymentTotals[inv.id] ?? 0.0,
            );
          }).toList();
        });
  }

  /// Emits invoices filtered by status.
  Stream<List<InvoiceWithDetails>> watchInvoicesByStatus({
    required String schoolId,
    required int year,
    required int term,
    required InvoiceStatus status,
  }) {
    return (select(invoices).join([
            innerJoin(
              students,
              students.adm.equalsExp(invoices.student) &
                  students.school.equalsExp(invoices.school),
            ),
            leftOuterJoin(fees, fees.id.equalsExp(invoices.fee)),
          ])
          ..where(
            invoices.school.equals(schoolId) &
                invoices.year.equals(year) &
                invoices.term.equals(term) &
                invoices.status.equalsValue(status),
          )
          ..orderBy([OrderingTerm.desc(invoices.created)]))
        .watch()
        .asyncMap((rows) async {
          final paymentTotals = await _buildPaymentTotals();

          return rows.map((row) {
            final inv = row.readTable(invoices);
            final stu = row.readTable(students);
            final feeRow = row.readTableOrNull(fees);

            return InvoiceWithDetails(
              invoice: inv,
              studentName: stu.name,
              studentAdm: stu.adm,
              feeTitle: feeRow?.title,
              totalPaid: paymentTotals[inv.id] ?? 0.0,
            );
          }).toList();
        });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAYMENTS — reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits all payments linked to invoices in a school/term.
  Stream<List<PaymentWithDetails>> watchPaymentsForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    // Payments linked to invoices for this term.
    final query =
        select(payments).join([
            leftOuterJoin(invoices, invoices.id.equalsExp(payments.invoice)),
            innerJoin(
              students,
              // When payment has an invoice, use the invoice's school+student.
              // When direct, use payment's own school+student.
              students.school.equals(schoolId) &
                  (students.adm.equalsExp(invoices.student) |
                      students.adm.equalsExp(payments.student)),
            ),
          ])
          ..where(
            // Invoice-linked payments for this term.
            (invoices.school.equals(schoolId) &
                    invoices.year.equals(year) &
                    invoices.term.equals(term)) |
                // Direct payments for this school.
                (payments.invoice.isNull() & payments.school.equals(schoolId)),
          )
          ..orderBy([OrderingTerm.desc(payments.created)]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final pay = row.readTable(payments);
        final inv = row.readTableOrNull(invoices);
        final stu = row.readTable(students);

        return PaymentWithDetails(
          payment: pay,
          invoiceId: inv?.id,
          invoiceDescription: inv?.description,
          studentName: stu.name,
          studentAdm: stu.adm,
        );
      }).toList(),
    );
  }

  /// Emits all payments for a specific student.
  Stream<List<PaymentWithDetails>> watchStudentPayments({
    required String schoolId,
    required int studentAdm,
    required int year,
    required int term,
  }) {
    return (select(payments).join([
            leftOuterJoin(invoices, invoices.id.equalsExp(payments.invoice)),
            innerJoin(
              students,
              students.school.equals(schoolId) &
                  students.adm.equals(studentAdm),
            ),
          ])
          ..where(
            (invoices.school.equals(schoolId) &
                    invoices.student.equals(studentAdm) &
                    invoices.year.equals(year) &
                    invoices.term.equals(term)) |
                (payments.invoice.isNull() &
                    payments.school.equals(schoolId) &
                    payments.student.equals(studentAdm)),
          )
          ..orderBy([OrderingTerm.desc(payments.created)]))
        .watch()
        .map(
          (rows) => rows.map((row) {
            final pay = row.readTable(payments);
            final inv = row.readTableOrNull(invoices);
            final stu = row.readTable(students);

            return PaymentWithDetails(
              payment: pay,
              invoiceId: inv?.id,
              invoiceDescription: inv?.description,
              studentName: stu.name,
              studentAdm: stu.adm,
            );
          }).toList(),
        );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCOUNTS — reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits all discounts for a school/term joined with plan names.
  Stream<List<DiscountWithPlan>> watchDiscountsForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(
            discounts,
          ).join([innerJoin(plans, plans.id.equalsExp(discounts.plan))])
          ..where(
            discounts.school.equals(schoolId) &
                discounts.year.equals(year) &
                discounts.term.equals(term),
          )
          ..orderBy([
            OrderingTerm.asc(discounts.grade),
            OrderingTerm.asc(plans.name),
          ]))
        .watch()
        .map(
          (rows) => rows.map((row) {
            return DiscountWithPlan(
              discount: row.readTable(discounts),
              planName: row.readTable(plans).name,
            );
          }).toList(),
        );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY — aggregate finance data
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits a [TermFinanceSummary] for the owner/staff dashboard overview.
  ///
  /// Aggregates all invoices and their payment status for the given term.
  Stream<TermFinanceSummary> watchTermFinanceSummary({
    required String schoolId,
    required int year,
    required int term,
  }) {
    // Watch both invoices AND payments so that recording a payment
    // (even when invoice status doesn't change) triggers a re-compute.
    final invQuery = select(invoices)
      ..where(
        (i) =>
            i.school.equals(schoolId) &
            i.year.equals(year) &
            i.term.equals(term),
      );

    // Merge invoice and payment table-update triggers.
    final trigger = StreamGroup.merge([
      invQuery.watch(),
      tableUpdates(TableUpdateQuery.onTable(payments)).map((_) => <Invoice>[]),
    ]);

    return trigger.asyncMap((_) async {
      // Always re-fetch fresh invoice list.
      final invList = await invQuery.get();

      // Load all payments for these invoices.
      final invoiceIds = invList.map((i) => i.id).toList();
      final payList = invoiceIds.isEmpty
          ? <Payment>[]
          : await (select(
              payments,
            )..where((p) => p.invoice.isIn(invoiceIds))).get();

      final paymentTotals = <String, double>{};
      for (final p in payList) {
        if (p.invoice != null) {
          paymentTotals[p.invoice!] =
              (paymentTotals[p.invoice!] ?? 0) + p.amount;
        }
      }

      double totalInvoiced = 0;
      double totalPaid = 0;
      double totalPending = 0;
      double totalOverdue = 0;
      int paidCount = 0;
      int pendingCount = 0;
      int overdueCount = 0;

      for (final inv in invList) {
        totalInvoiced += inv.amount;
        final paid = paymentTotals[inv.id] ?? 0.0;
        totalPaid += paid;

        final balance = inv.amount - paid;
        if (balance <= 0.001) {
          paidCount++;
        } else if (inv.status == InvoiceStatus.overdue) {
          overdueCount++;
          totalOverdue += balance;
        } else {
          pendingCount++;
          totalPending += balance;
        }
      }

      return TermFinanceSummary(
        totalInvoiced: totalInvoiced,
        totalPaid: totalPaid,
        totalPending: totalPending,
        totalOverdue: totalOverdue,
        invoiceCount: invList.length,
        paidCount: paidCount,
        pendingCount: pendingCount,
        overdueCount: overdueCount,
      );
    });
  }

  /// Emits a per-student financial summary for the guardian view.
  Stream<StudentFinanceSummary> watchStudentFinanceSummary({
    required String schoolId,
    required int studentAdm,
    required int year,
    required int term,
  }) {
    return watchStudentInvoices(
      schoolId: schoolId,
      studentAdm: studentAdm,
      year: year,
      term: term,
    ).asyncMap((invDetails) async {
      final studentRow =
          await (select(students)..where(
                (s) => s.school.equals(schoolId) & s.adm.equals(studentAdm),
              ))
              .getSingleOrNull();

      final payDetails = await watchStudentPayments(
        schoolId: schoolId,
        studentAdm: studentAdm,
        year: year,
        term: term,
      ).first;

      return StudentFinanceSummary(
        studentName: studentRow?.name ?? 'Unknown',
        studentAdm: studentAdm,
        invoices: invDetails,
        payments: payDetails,
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTATIONS — fees
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new fee definition.
  ///
  /// Both the write and a [SyncAction.createFee] log entry are wrapped in a
  /// single transaction.
  Future<void> createFee({
    required String id,
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required String title,
    required String description,
    required double amount,
    required bool mandatory,
    required BigInt due,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(fees).insert(
        FeesCompanion(
          id: Value(id),
          school: Value(schoolId),
          year: Value(year),
          term: Value(term),
          grade: Value(grade),
          title: Value(title),
          description: Value(description),
          amount: Value(amount),
          mandatory: Value(mandatory),
          due: Value(due),
          created: Value(now),
          updated: Value(now),
        ),
      );

      final payload = sync_pb.CreateFeePayload(
        id: id,
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        title: title,
        description: description,
        amount: amount,
        mandatory: mandatory,
        due: fixnum.Int64(due.toInt()),
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createFee),
          resource: Value(title),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates an existing fee definition.
  Future<void> updateFee({
    required String id,
    String? title,
    String? description,
    double? amount,
    bool? mandatory,
    BigInt? due,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.UpdateFeePayload(id: id);
      bool hasChanges = false;

      if (title != null) {
        payload.title = title;
        hasChanges = true;
      }
      if (description != null) {
        payload.description = description;
        hasChanges = true;
      }
      if (amount != null) {
        payload.amount = amount;
        hasChanges = true;
      }
      if (mandatory != null) {
        payload.mandatory = mandatory;
        hasChanges = true;
      }
      if (due != null) {
        payload.due = fixnum.Int64(due.toInt());
        hasChanges = true;
      }
      if (!hasChanges) return;

      await (update(fees)..where((f) => f.id.equals(id))).write(
        FeesCompanion(
          title: title != null ? Value(title) : const Value.absent(),
          description: description != null
              ? Value(description)
              : const Value.absent(),
          amount: amount != null ? Value(amount) : const Value.absent(),
          mandatory: mandatory != null
              ? Value(mandatory)
              : const Value.absent(),
          due: due != null ? Value(due) : const Value.absent(),
          updated: Value(now),
        ),
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateFee),
          resource: Value(title ?? 'Fee $id'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes a fee definition.
  Future<void> deleteFee({
    required String id,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.DeleteFeePayload(id: id);

      await (delete(fees)..where((f) => f.id.equals(id))).go();

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteFee),
          resource: Value('Fee $id'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTATIONS — invoices
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new invoice.
  Future<void> createInvoice({
    required String id,
    required String schoolId,
    required int year,
    required int term,
    String? feeId,
    String? description,
    required int studentAdm,
    required double amount,
    InvoiceStatus status = InvoiceStatus.pending,
    BigInt? due,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(invoices).insert(
        InvoicesCompanion(
          id: Value(id),
          school: Value(schoolId),
          year: Value(year),
          term: Value(term),
          fee: Value(feeId),
          description: Value(description),
          student: Value(studentAdm),
          amount: Value(amount),
          status: Value(status),
          due: Value(due),
          created: Value(now),
          updated: Value(now),
        ),
      );

      final invPayload = sync_pb.CreateInvoicePayload(
        id: id,
        school: schoolId,
        year: year,
        term: term,
        student: studentAdm,
        amount: amount,
      );
      if (feeId != null) invPayload.fee = feeId;
      if (description != null) invPayload.description = description;
      if (due != null) invPayload.due = fixnum.Int64(due.toInt());

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createInvoice),
          resource: Value(description ?? 'Invoice $id'),
          payload: Value(invPayload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Generates invoices for all enrolled students in a grade from a fee.
  ///
  /// [generateId] is a callback that returns a unique ID for each invoice
  /// (e.g. a UUID generator).
  Future<int> generateInvoicesFromFee({
    required Fee fee,
    required String Function() generateId,
    required String accountId,
  }) async {
    final count = await transaction(() async {
      // Cross-reference with enrollments table to get students in this grade.
      final enrolledStudents = await customSelect(
        'SELECT DISTINCT e.student FROM enrollments e '
        'WHERE e.school = ? AND e.year = ? AND e.term = ? AND e.grade = ?',
        variables: [
          Variable.withString(fee.school),
          Variable.withInt(fee.year),
          Variable.withInt(fee.term),
          Variable.withInt(fee.grade),
        ],
        readsFrom: {},
      ).get();

      final studentAdms = enrolledStudents
          .map((r) => r.read<int>('student'))
          .toSet();

      int count = 0;
      for (final adm in studentAdms) {
        // Check for existing invoice from this fee for this student.
        final existing =
            await (select(invoices)..where(
                  (i) =>
                      i.school.equals(fee.school) &
                      i.fee.equals(fee.id) &
                      i.student.equals(adm),
                ))
                .getSingleOrNull();

        if (existing != null) continue; // already invoiced

        final id = generateId();
        await createInvoice(
          id: id,
          schoolId: fee.school,
          year: fee.year,
          term: fee.term,
          feeId: fee.id,
          studentAdm: adm,
          amount: fee.amount,
          due: fee.due,
          accountId: accountId,
        );
        count++;
      }
      return count;
    });
    sync.schedulePush();
    return count;
  }

  /// Updates an invoice's status.
  Future<void> updateInvoiceStatus({
    required String id,
    required InvoiceStatus status,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(invoices)..where((i) => i.id.equals(id))).write(
        InvoicesCompanion(status: Value(status), updated: Value(now)),
      );

      final payload = sync_pb.UpdateInvoicePayload(
        id: id,
        status: status.index,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateInvoice),
          resource: Value('Invoice $id'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Cancels an invoice.
  Future<void> cancelInvoice({required String id, required String accountId}) {
    return updateInvoiceStatus(
      id: id,
      status: InvoiceStatus.cancelled,
      accountId: accountId,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTATIONS — payments
  // ─────────────────────────────────────────────────────────────────────────

  /// Records a payment and automatically recalculates the invoice status.
  ///
  /// If the payment fully settles the invoice, the invoice status is updated
  /// to [InvoiceStatus.paid]. If it partially settles it, the status is
  /// updated to [InvoiceStatus.partial].
  Future<void> recordPayment({
    required String id,
    String? invoiceId,
    String? schoolId,
    int? studentAdm,
    required double amount,
    required PaymentMethod method,
    String? reference,
    String? recorderId,
    int? date,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(payments).insert(
        PaymentsCompanion(
          id: Value(id),
          invoice: Value(invoiceId),
          school: Value(schoolId),
          student: Value(studentAdm),
          amount: Value(amount),
          method: Value(method),
          reference: Value(reference),
          recorder: Value(recorderId),
          date: Value(date),
          created: Value(now),
          updated: Value(now),
        ),
      );

      final payPayload = sync_pb.CreatePaymentPayload(
        id: id,
        amount: amount,
        method: method.index,
      );
      if (invoiceId != null) payPayload.invoice = invoiceId;
      if (schoolId != null) payPayload.school = schoolId;
      if (studentAdm != null) payPayload.student = studentAdm;
      if (reference != null) payPayload.reference = reference;
      if (recorderId != null) payPayload.recorder = recorderId;
      if (date != null) payPayload.date = date;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createPayment),
          resource: Value('Payment $id'),
          payload: Value(payPayload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      // If the payment is linked to an invoice, recalculate the invoice status.
      if (invoiceId != null) {
        await _recalculateInvoiceStatus(invoiceId, accountId);
      }
    });
    sync.schedulePush();
  }

  /// Recalculates and updates the invoice status based on total payments.
  Future<void> _recalculateInvoiceStatus(
    String invoiceId,
    String accountId,
  ) async {
    final inv = await (select(
      invoices,
    )..where((i) => i.id.equals(invoiceId))).getSingleOrNull();

    if (inv == null) return;

    // Sum all payments for this invoice.
    final payList = await (select(
      payments,
    )..where((p) => p.invoice.equals(invoiceId))).get();

    final totalPaid = payList.fold(0.0, (sum, p) => sum + p.amount);
    final balance = inv.amount - totalPaid;

    InvoiceStatus newStatus;
    if (balance <= 0.001) {
      newStatus = InvoiceStatus.paid;
    } else if (totalPaid > 0.001) {
      newStatus = InvoiceStatus.partial;
    } else {
      return; // no change needed
    }

    if (newStatus != inv.status) {
      await updateInvoiceStatus(
        id: invoiceId,
        status: newStatus,
        accountId: accountId,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MUTATIONS — discounts
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates or replaces a discount for a plan/grade/term combination.
  Future<void> upsertDiscount({
    required String schoolId,
    required String planId,
    required int year,
    required int term,
    required int grade,
    required double amount,
    required DiscountUnit unit,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Check if exists.
      final existing =
          await (select(discounts)..where(
                (d) =>
                    d.school.equals(schoolId) &
                    d.plan.equals(planId) &
                    d.year.equals(year) &
                    d.term.equals(term) &
                    d.grade.equals(grade),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (update(discounts)..where(
              (d) =>
                  d.school.equals(schoolId) &
                  d.plan.equals(planId) &
                  d.year.equals(year) &
                  d.term.equals(term) &
                  d.grade.equals(grade),
            ))
            .write(
              DiscountsCompanion(
                amount: Value(amount),
                unit: Value(unit),
                updated: Value(now),
              ),
            );

        final updPayload = sync_pb.UpdateDiscountPayload(
          school: schoolId,
          plan: planId,
          year: year,
          term: term,
          grade: grade,
          amount: amount,
          unit: unit.index,
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.updateDiscount),
            resource: Value('Discount — $planId'),
            payload: Value(updPayload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );
      } else {
        await into(discounts).insert(
          DiscountsCompanion(
            school: Value(schoolId),
            plan: Value(planId),
            year: Value(year),
            term: Value(term),
            grade: Value(grade),
            amount: Value(amount),
            unit: Value(unit),
            created: Value(now),
            updated: Value(now),
          ),
        );

        final crtPayload = sync_pb.CreateDiscountPayload(
          school: schoolId,
          plan: planId,
          year: year,
          term: term,
          grade: grade,
          amount: amount,
          unit: unit.index,
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.createDiscount),
            resource: Value('Discount — $planId'),
            payload: Value(crtPayload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Deletes a discount.
  Future<void> deleteDiscount({
    required String schoolId,
    required String planId,
    required int year,
    required int term,
    required int grade,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteDiscountPayload(
        school: schoolId,
        plan: planId,
        year: year,
        term: term,
        grade: grade,
      );

      await (delete(discounts)..where(
            (d) =>
                d.school.equals(schoolId) &
                d.plan.equals(planId) &
                d.year.equals(year) &
                d.term.equals(term) &
                d.grade.equals(grade),
          ))
          .go();

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteDiscount),
          resource: Value('Discount — $planId'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITY reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a single fee by ID.
  Future<Fee?> getFee(String id) {
    return (select(fees)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  /// Returns the school ID for [feeId], or null if not found locally.
  ///
  /// Used by [AuthorizationService] to resolve the organisation context for
  /// [SyncAction.updateFee] and [SyncAction.deleteFee].
  Future<String?> getSchoolForFee(String feeId) async {
    final row = await (select(
      fees,
    )..where((t) => t.id.equals(feeId))).getSingleOrNull();
    return row?.school;
  }

  /// Returns the school ID for [invoiceId], or null if not found locally.
  ///
  /// Used by [AuthorizationService] to resolve the organisation context for
  /// [SyncAction.updateInvoice] and [SyncAction.deleteInvoice].
  Future<String?> getSchoolForInvoice(String invoiceId) async {
    final row = await (select(
      invoices,
    )..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    return row?.school;
  }

  /// Returns the school ID for [paymentId], or null if not found locally.
  ///
  /// Note: invoice-linked payments have a nullable [school] column; only
  /// direct payments carry an explicit school reference. Returns null for
  /// invoice-linked payments — the caller falls back to [schoolId] from
  /// the action payload in that case.
  ///
  /// Used by [AuthorizationService] to resolve the organisation context for
  /// [SyncAction.updatePayment], [SyncAction.deletePayment], and
  /// [SyncAction.approvePayment].
  Future<String?> getSchoolForPayment(String paymentId) async {
    final row = await (select(
      payments,
    )..where((t) => t.id.equals(paymentId))).getSingleOrNull();
    return row?.school;
  }

  /// Returns a single invoice by ID.
  Future<Invoice?> getInvoice(String id) {
    return (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  /// Returns total payments for an invoice.
  Future<double> getTotalPaymentsForInvoice(String invoiceId) async {
    final payList = await (select(
      payments,
    )..where((p) => p.invoice.equals(invoiceId))).get();
    var total = 0.0;
    for (final p in payList) {
      total += p.amount;
    }
    return total;
  }

  /// Returns all payments for a specific invoice.
  Stream<List<Payment>> watchPaymentsForInvoice(String invoiceId) {
    return (select(payments)
          ..where((p) => p.invoice.equals(invoiceId))
          ..orderBy([(p) => OrderingTerm.desc(p.created)]))
        .watch();
  }

  /// Returns enrolled student count for a grade/term (for invoice generation).
  Future<int> getEnrolledStudentCount({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
  }) async {
    final result = await customSelect(
      'SELECT COUNT(DISTINCT student) AS c FROM enrollments '
      'WHERE school = ? AND year = ? AND term = ? AND grade = ?',
      variables: [
        Variable.withString(schoolId),
        Variable.withInt(year),
        Variable.withInt(term),
        Variable.withInt(grade),
      ],
      readsFrom: {},
    ).getSingle();
    return result.read<int>('c');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STUDENT BALANCE — lightweight reactive lookup
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits a [StudentBalanceSummary] for a single student across ALL terms
  /// at the given school, or `null` if the student has no invoices.
  ///
  /// The query joins `students → invoices → payments` using a single
  /// `customSelect` so the aggregate is computed in SQL rather than Dart.
  /// The stream re-fires whenever the `invoices` or `payments` tables change.
  Stream<StudentBalanceSummary?> watchStudentBalance({
    required String schoolId,
    required int studentAdm,
  }) {
    // We merge update triggers from both invoices and payments so that
    // recording a new payment immediately re-fires the stream.
    final trigger = StreamGroup.merge([
      (select(invoices)..where(
            (i) => i.school.equals(schoolId) & i.student.equals(studentAdm),
          ))
          .watch(),
      tableUpdates(TableUpdateQuery.onTable(payments)).map((_) => <Invoice>[]),
    ]);

    return trigger.asyncMap((_) async {
      // 1. Look up the student row for the name.
      final studentRow =
          await (select(students)..where(
                (s) => s.school.equals(schoolId) & s.adm.equals(studentAdm),
              ))
              .getSingleOrNull();

      if (studentRow == null) return null;

      // 2. Fetch all invoices for this student at this school.
      final invList =
          await (select(invoices)
                ..where(
                  (i) =>
                      i.school.equals(schoolId) & i.student.equals(studentAdm),
                )
                ..orderBy([(i) => OrderingTerm.desc(i.created)]))
              .get();

      if (invList.isEmpty) return null;

      // 3. Load all payments linked to this student's invoices.
      final invoiceIds = invList.map((i) => i.id).toList();
      final payList = await (select(
        payments,
      )..where((p) => p.invoice.isIn(invoiceIds))).get();

      // Build payment totals per invoice.
      final payTotals = <String, double>{};
      for (final p in payList) {
        if (p.invoice != null) {
          payTotals[p.invoice!] = (payTotals[p.invoice!] ?? 0) + p.amount;
        }
      }

      // 4. Build balance items + grand totals.
      var totalInvoiced = 0.0;
      var totalPaid = 0.0;
      final items = <InvoiceBalanceItem>[];

      for (final inv in invList) {
        final paid = payTotals[inv.id] ?? 0.0;
        totalInvoiced += inv.amount;
        totalPaid += paid;

        items.add(
          InvoiceBalanceItem(
            invoiceId: inv.id,
            description: inv.description ?? inv.fee ?? 'Invoice',
            amount: inv.amount,
            paid: paid,
          ),
        );
      }

      return StudentBalanceSummary(
        studentName: studentRow.name,
        studentAdm: studentAdm,
        totalInvoiced: totalInvoiced,
        totalPaid: totalPaid,
        invoices: items,
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY COLLECTION — reactive summary
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits an aggregated summary of payments recorded today for [schoolId].
  ///
  /// [todayStartMs] and [todayEndMs] are milliseconds-since-epoch boundaries
  /// for the current day (inclusive start, exclusive end).  The query groups
  /// by payment method so the UI can show a per-method breakdown.
  Stream<DailyCollectionSummary> watchDailyCollection({
    required String schoolId,
    required int todayStartMs,
    required int todayEndMs,
  }) {
    return customSelect(
      'SELECT method, COUNT(*) AS cnt, COALESCE(SUM(amount), 0.0) AS total '
      'FROM payments '
      'WHERE school = ? AND created >= ? AND created < ? '
      'GROUP BY method',
      variables: [
        Variable.withString(schoolId),
        Variable.withInt(todayStartMs),
        Variable.withInt(todayEndMs),
      ],
      readsFrom: {payments},
    ).watch().map((rows) {
      var totalAmount = 0.0;
      var paymentCount = 0;
      final byMethod = <int, MethodSummary>{};

      for (final row in rows) {
        final methodIdx = row.read<int>('method');
        final cnt = row.read<int>('cnt');
        final total = row.read<double>('total');

        totalAmount += total;
        paymentCount += cnt;
        byMethod[methodIdx] = MethodSummary(count: cnt, amount: total);
      }

      return DailyCollectionSummary(
        totalAmount: totalAmount,
        paymentCount: paymentCount,
        byMethod: byMethod,
      );
    });
  }
}
