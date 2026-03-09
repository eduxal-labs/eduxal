import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_tab_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level entry point for the Finance section.
///
/// Role dispatch:
/// - **Owner / Staff:** Full financial management — Fees, Invoices, Payments,
///   Discounts tabs with creation FABs.
/// - **Guardian:** Read-only per-ward statement — invoices and payments.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
    }

    final entry = schoolContext.currentEntry.value;

    return switch (entry) {
      OwnerEntry() => _OwnerFinanceShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      StaffEntry() => _OwnerFinanceShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      GuardianEntry(:final ward) => _GuardianFinanceView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: ward.adm,
        studentName: ward.name,
      ),
      _ => _OwnerFinanceShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COLOUR CONSTANTS
// ═════════════════════════════════════════════════════════════════════════════

const _kPaidColor = Color(0xFF26A69A);
const _kPendingColor = Color(0xFFFF9800);
const _kOverdueColor = Color(0xFFEF5350);
const _kPartialColor = Color(0xFF42A5F5);
const _kCancelledColor = Color(0xFF9E9E9E);

Color _invoiceStatusColor(InvoiceStatus status) => switch (status) {
  InvoiceStatus.pending => _kPendingColor,
  InvoiceStatus.partial => _kPartialColor,
  InvoiceStatus.paid => _kPaidColor,
  InvoiceStatus.overdue => _kOverdueColor,
  InvoiceStatus.cancelled => _kCancelledColor,
};

String _invoiceStatusLabel(InvoiceStatus status) => switch (status) {
  InvoiceStatus.pending => 'Pending',
  InvoiceStatus.partial => 'Partial',
  InvoiceStatus.paid => 'Paid',
  InvoiceStatus.overdue => 'Overdue',
  InvoiceStatus.cancelled => 'Cancelled',
};

String _paymentMethodLabel(PaymentMethod m) => switch (m) {
  PaymentMethod.cash => 'Cash',
  PaymentMethod.cheque => 'Cheque',
  PaymentMethod.mpesa => 'M-Pesa',
  PaymentMethod.bank => 'Bank',
};

// ═════════════════════════════════════════════════════════════════════════════
// OWNER / STAFF — FINANCE SHELL (4-tab layout)
// ═════════════════════════════════════════════════════════════════════════════

enum _FinanceTab { overview, invoices, payments, fees }

class _OwnerFinanceShell extends StatefulWidget {
  const _OwnerFinanceShell({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_OwnerFinanceShell> createState() => _OwnerFinanceShellState();
}

class _OwnerFinanceShellState extends State<_OwnerFinanceShell>
    with TickerProviderStateMixin {
  late final FinanceDao _dao;
  late TabController _tabController;
  _FinanceTab _currentTab = _FinanceTab.overview;
  SchoolConfig _config = SchoolConfig.defaults();

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = FinanceDao(db);
    _tabController = TabController(
      length: _FinanceTab.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final row = await settingsDao.getSettings(_schoolId);
    if (row != null && mounted) {
      setState(() {
        _config = SchoolConfig.fromJson(
          jsonDecode(row.data) as Map<String, dynamic>,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final newTab = _FinanceTab.values[_tabController.index];
    if (newTab != _currentTab) {
      setState(() => _currentTab = newTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;
    if (term == null) return const _NoTermState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EduTabBar(
          controller: _tabController,
          tabs: const [
            EduTab(label: 'Overview'),
            EduTab(label: 'Invoices'),
            EduTab(label: 'Payments'),
            EduTab(label: 'Fees'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(
                schoolId: _schoolId,
                year: term.year,
                term: term.term,
                dao: _dao,
                cs: cs,
              ),
              _InvoicesTab(
                schoolId: _schoolId,
                year: term.year,
                term: term.term,
                dao: _dao,
                config: _config,
                cs: cs,
              ),
              _PaymentsTab(
                schoolId: _schoolId,
                year: term.year,
                term: term.term,
                dao: _dao,
                cs: cs,
              ),
              _FeesTab(
                schoolId: _schoolId,
                year: term.year,
                term: term.term,
                dao: _dao,
                config: _config,
                cs: cs,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW (Summary cards)
// ═════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.dao,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TermFinanceSummary>(
      stream: dao.watchTermFinanceSummary(
        schoolId: schoolId,
        year: year,
        term: term,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final summary = snap.data!;
        return _OverviewContent(summary: summary, cs: cs);
      },
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.summary, required this.cs});

  final TermFinanceSummary summary;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collection Rate hero ────────────────────────────────────
              _CollectionRateCard(summary: summary, cs: cs, isDark: isDark),
              const SizedBox(height: 20),

              // ── Metric cards ────────────────────────────────────────────
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Total Invoiced',
                        value: _fmtCurrency(summary.totalInvoiced),
                        count: summary.invoiceCount,
                        countLabel: 'invoices',
                        color: cs.primary,
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MetricCard(
                        label: 'Total Collected',
                        value: _fmtCurrency(summary.totalPaid),
                        count: summary.paidCount,
                        countLabel: 'paid',
                        color: _kPaidColor,
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MetricCard(
                        label: 'Pending',
                        value: _fmtCurrency(summary.totalPending),
                        count: summary.pendingCount,
                        countLabel: 'pending',
                        color: _kPendingColor,
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MetricCard(
                        label: 'Overdue',
                        value: _fmtCurrency(summary.totalOverdue),
                        count: summary.overdueCount,
                        countLabel: 'overdue',
                        color: _kOverdueColor,
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      label: 'Total Invoiced',
                      value: _fmtCurrency(summary.totalInvoiced),
                      count: summary.invoiceCount,
                      countLabel: 'invoices',
                      color: cs.primary,
                      cs: cs,
                      isDark: isDark,
                      width: (constraints.maxWidth - 32) / 2,
                    ),
                    _MetricCard(
                      label: 'Total Collected',
                      value: _fmtCurrency(summary.totalPaid),
                      count: summary.paidCount,
                      countLabel: 'paid',
                      color: _kPaidColor,
                      cs: cs,
                      isDark: isDark,
                      width: (constraints.maxWidth - 32) / 2,
                    ),
                    _MetricCard(
                      label: 'Pending',
                      value: _fmtCurrency(summary.totalPending),
                      count: summary.pendingCount,
                      countLabel: 'pending',
                      color: _kPendingColor,
                      cs: cs,
                      isDark: isDark,
                      width: (constraints.maxWidth - 32) / 2,
                    ),
                    _MetricCard(
                      label: 'Overdue',
                      value: _fmtCurrency(summary.totalOverdue),
                      count: summary.overdueCount,
                      countLabel: 'overdue',
                      color: _kOverdueColor,
                      cs: cs,
                      isDark: isDark,
                      width: (constraints.maxWidth - 32) / 2,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionRateCard extends StatelessWidget {
  const _CollectionRateCard({
    required this.summary,
    required this.cs,
    required this.isDark,
  });

  final TermFinanceSummary summary;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final rate = summary.collectionRate;
    final pct = (rate * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.kRadiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular rate indicator
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: rate.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    rate > 0.75
                        ? _kPaidColor
                        : rate > 0.4
                        ? _kPendingColor
                        : _kOverdueColor,
                  ),
                ),
                Center(
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection Rate',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtCurrency(summary.totalPaid)} of ${_fmtCurrency(summary.totalInvoiced)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.invoiceCount} invoices · ${summary.paidCount} paid · ${summary.pendingCount} pending · ${summary.overdueCount} overdue',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.count,
    required this.countLabel,
    required this.color,
    required this.cs,
    required this.isDark,
    this.width,
  });

  final String label;
  final String value;
  final int count;
  final String countLabel;
  final Color color;
  final ColorScheme cs;
  final bool isDark;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count $countLabel',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — INVOICES
// ═════════════════════════════════════════════════════════════════════════════

class _InvoicesTab extends StatefulWidget {
  const _InvoicesTab({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.dao,
    required this.config,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final SchoolConfig config;
  final ColorScheme cs;

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> {
  InvoiceStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;

    final stream = _statusFilter != null
        ? widget.dao.watchInvoicesByStatus(
            schoolId: widget.schoolId,
            year: widget.year,
            term: widget.term,
            status: _statusFilter!,
          )
        : widget.dao.watchInvoicesForTerm(
            schoolId: widget.schoolId,
            year: widget.year,
            term: widget.term,
          );

    return Column(
      children: [
        // ── Filter strip ──────────────────────────────────────────────────
        _InvoiceFilterStrip(
          selectedStatus: _statusFilter,
          cs: cs,
          onStatusChanged: (s) => setState(() => _statusFilter = s),
        ),
        // ── Invoice list ──────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<InvoiceWithDetails>>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  label: _statusFilter != null
                      ? 'No ${_invoiceStatusLabel(_statusFilter!).toLowerCase()} invoices'
                      : 'No invoices yet',
                  sublabel: 'Create fees and generate invoices to get started',
                  cs: cs,
                );
              }
              return _InvoiceListView(
                items: items,
                dao: widget.dao,
                schoolId: widget.schoolId,
                cs: cs,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InvoiceFilterStrip extends StatelessWidget {
  const _InvoiceFilterStrip({
    required this.selectedStatus,
    required this.cs,
    required this.onStatusChanged,
  });

  final InvoiceStatus? selectedStatus;
  final ColorScheme cs;
  final ValueChanged<InvoiceStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: selectedStatus == null,
            cs: cs,
            isDark: isDark,
            onTap: () => onStatusChanged(null),
          ),
          const SizedBox(width: 8),
          for (final status in [
            InvoiceStatus.pending,
            InvoiceStatus.partial,
            InvoiceStatus.paid,
            InvoiceStatus.overdue,
            InvoiceStatus.cancelled,
          ]) ...[
            _FilterChip(
              label: _invoiceStatusLabel(status),
              isSelected: selectedStatus == status,
              color: _invoiceStatusColor(status),
              cs: cs,
              isDark: isDark,
              onTap: () =>
                  onStatusChanged(selectedStatus == status ? null : status),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color? color;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? cs.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected ? effectiveColor : cs.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _InvoiceListView extends StatelessWidget {
  const _InvoiceListView({
    required this.items,
    required this.dao,
    required this.schoolId,
    required this.cs,
    required this.isDark,
  });

  final List<InvoiceWithDetails> items;
  final FinanceDao dao;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _InvoiceTile(
          item: item,
          dao: dao,
          schoolId: schoolId,
          cs: cs,
          isDark: isDark,
          onRecordPayment: () =>
              _showRecordPaymentSheet(context, item, dao, schoolId, cs),
        );
      },
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.item,
    required this.dao,
    required this.schoolId,
    required this.cs,
    required this.isDark,
    required this.onRecordPayment,
  });

  final InvoiceWithDetails item;
  final FinanceDao dao;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final statusColor = _invoiceStatusColor(item.invoice.status);
    final balance = item.balance;
    final title = item.feeTitle ?? item.invoice.description ?? 'Invoice';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.studentName} · Adm #${item.studentAdm}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: _invoiceStatusLabel(item.invoice.status),
                color: statusColor,
                cs: cs,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AmountCell(
                label: 'Invoiced',
                value: _fmtCurrency(item.invoice.amount),
                cs: cs,
              ),
              const SizedBox(width: 20),
              _AmountCell(
                label: 'Paid',
                value: _fmtCurrency(item.totalPaid),
                cs: cs,
                color: _kPaidColor,
              ),
              const SizedBox(width: 20),
              _AmountCell(
                label: 'Balance',
                value: _fmtCurrency(balance),
                cs: cs,
                color: balance > 0.01 ? _kOverdueColor : _kPaidColor,
                isBold: true,
              ),
              const Spacer(),
              if (item.invoice.status != InvoiceStatus.paid &&
                  item.invoice.status != InvoiceStatus.cancelled)
                _CompactButton(
                  label: 'Record Payment',
                  icon: Icons.add_rounded,
                  color: _kPaidColor,
                  cs: cs,
                  isDark: isDark,
                  onTap: onRecordPayment,
                ),
            ],
          ),
          if (item.invoice.due != null) ...[
            const SizedBox(height: 8),
            Text(
              'Due: ${_fmtDateFromEpoch(item.invoice.due!.toInt())}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({
    required this.label,
    required this.value,
    required this.cs,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w500 : FontWeight.w400,
            color: color ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final Color color;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — PAYMENTS
// ═════════════════════════════════════════════════════════════════════════════

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.dao,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<PaymentWithDetails>>(
      stream: dao.watchPaymentsForTerm(
        schoolId: schoolId,
        year: year,
        term: term,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.payments_outlined,
            label: 'No payments recorded',
            sublabel: 'Record payments against invoices to track collections',
            cs: cs,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _PaymentTile(item: item, cs: cs, isDark: isDark);
          },
        );
      },
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.item,
    required this.cs,
    required this.isDark,
  });

  final PaymentWithDetails item;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final methodLabel = _paymentMethodLabel(item.payment.method);
    final ref = item.payment.reference;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Leading icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kPaidColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _paymentMethodIcon(item.payment.method),
              size: 18,
              color: _kPaidColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.studentName} · Adm #${item.studentAdm}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$methodLabel${ref != null && ref.isNotEmpty ? ' · $ref' : ''}'
                  '${item.invoiceDescription != null ? ' · ${item.invoiceDescription}' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _fmtCurrency(item.payment.amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kPaidColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _paymentMethodIcon(PaymentMethod m) => switch (m) {
    PaymentMethod.cash => Icons.money_rounded,
    PaymentMethod.cheque => Icons.receipt_outlined,
    PaymentMethod.mpesa => Icons.phone_android_rounded,
    PaymentMethod.bank => Icons.account_balance_rounded,
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — FEES
// ═════════════════════════════════════════════════════════════════════════════

class _FeesTab extends StatelessWidget {
  const _FeesTab({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.dao,
    required this.config,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final SchoolConfig config;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return Stack(
      children: [
        StreamBuilder<List<FeeWithStats>>(
          stream: dao.watchFeesWithStats(
            schoolId: schoolId,
            year: year,
            term: term,
          ),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return _EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                label: 'No fee structures defined',
                sublabel: 'Tap the button below to create your first fee',
                cs: cs,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _FeeTile(
                  item: item,
                  dao: dao,
                  config: config,
                  cs: cs,
                  isDark: isDark,
                  onGenerateInvoices: () => _generateInvoices(context, item),
                );
              },
            );
          },
        ),
        // FAB
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.small(
            onPressed: () => _showCreateFeeSheet(
              context,
              dao,
              schoolId,
              year,
              term,
              config,
              cs,
            ),
            tooltip: 'New Fee',
            elevation: 4,
            highlightElevation: 6,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _generateInvoices(
    BuildContext context,
    FeeWithStats item,
  ) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    int counter = 0;
    try {
      final count = await dao.generateInvoicesFromFee(
        fee: item.fee,
        generateId: () {
          counter++;
          return '${item.fee.id}_inv_${DateTime.now().millisecondsSinceEpoch}_$counter';
        },
        accountId: accountId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Generated $count invoice${count == 1 ? '' : 's'}'
                  : 'All enrolled students already have invoices for this fee',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoices: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _FeeTile extends StatelessWidget {
  const _FeeTile({
    required this.item,
    required this.dao,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.onGenerateInvoices,
  });

  final FeeWithStats item;
  final FinanceDao dao;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onGenerateInvoices;

  @override
  Widget build(BuildContext context) {
    final fee = item.fee;
    final gradeLabel = _gradeLabel(fee.grade, config);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$gradeLabel · ${fee.mandatory ? 'Mandatory' : 'Optional'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _fmtCurrency(fee.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.receipt_outlined,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                '${item.invoiceCount} invoice${item.invoiceCount == 1 ? '' : 's'} generated',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.event_outlined,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Due: ${_fmtDateFromEpoch(fee.due.toInt())}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              _CompactButton(
                label: 'Generate Invoices',
                icon: Icons.send_rounded,
                color: cs.primary,
                cs: cs,
                isDark: isDark,
                onTap: onGenerateInvoices,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GUARDIAN VIEW — Read-only per-ward finances
// ═════════════════════════════════════════════════════════════════════════════

class _GuardianFinanceView extends StatefulWidget {
  const _GuardianFinanceView({
    required this.schoolContext,
    required this.termContext,
    required this.studentAdm,
    required this.studentName,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final int studentAdm;
  final String studentName;

  @override
  State<_GuardianFinanceView> createState() => _GuardianFinanceViewState();
}

class _GuardianFinanceViewState extends State<_GuardianFinanceView> {
  late final FinanceDao _dao;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = FinanceDao(db);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final term = widget.termContext.currentTerm;

    if (term == null) return const _NoTermState();

    return StreamBuilder<StudentFinanceSummary>(
      stream: _dao.watchStudentFinanceSummary(
        schoolId: _schoolId,
        studentAdm: widget.studentAdm,
        year: term.year,
        term: term.term,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final summary = snap.data!;

        return _GuardianFinanceContent(
          summary: summary,
          studentName: widget.studentName,
          cs: cs,
          isDark: isDark,
        );
      },
    );
  }
}

class _GuardianFinanceContent extends StatelessWidget {
  const _GuardianFinanceContent({
    required this.summary,
    required this.studentName,
    required this.cs,
    required this.isDark,
  });

  final StudentFinanceSummary summary;
  final String studentName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Student header ──────────────────────────────────────────────
          Text(
            studentName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Adm #${summary.studentAdm}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),

          // ── Balance summary card ────────────────────────────────────────
          _GuardianBalanceCard(summary: summary, cs: cs, isDark: isDark),
          const SizedBox(height: 24),

          // ── Invoices section ────────────────────────────────────────────
          _SectionHeader(label: 'Invoices', cs: cs),
          const SizedBox(height: 10),
          if (summary.invoices.isEmpty)
            _EmptyState(
              icon: Icons.receipt_long_outlined,
              label: 'No invoices',
              sublabel: 'No fees have been invoiced yet',
              cs: cs,
              compact: true,
            )
          else
            ...summary.invoices.map(
              (inv) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GuardianInvoiceTile(item: inv, cs: cs, isDark: isDark),
              ),
            ),

          const SizedBox(height: 20),

          // ── Payments section ────────────────────────────────────────────
          _SectionHeader(label: 'Payments', cs: cs),
          const SizedBox(height: 10),
          if (summary.payments.isEmpty)
            _EmptyState(
              icon: Icons.payments_outlined,
              label: 'No payments',
              sublabel: 'No payments have been recorded yet',
              cs: cs,
              compact: true,
            )
          else
            ...summary.payments.map(
              (pay) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GuardianPaymentTile(item: pay, cs: cs, isDark: isDark),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardianBalanceCard extends StatelessWidget {
  const _GuardianBalanceCard({
    required this.summary,
    required this.cs,
    required this.isDark,
  });

  final StudentFinanceSummary summary;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final balance = summary.totalBalance;
    final balanceColor = balance > 0.01 ? _kOverdueColor : _kPaidColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.kRadiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BalanceColumn(
              label: 'Total Invoiced',
              value: _fmtCurrency(summary.totalInvoiced),
              cs: cs,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: cs.onSurfaceVariant.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _BalanceColumn(
              label: 'Total Paid',
              value: _fmtCurrency(summary.totalPaid),
              cs: cs,
              color: _kPaidColor,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: cs.onSurfaceVariant.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _BalanceColumn(
              label: 'Balance',
              value: _fmtCurrency(balance),
              cs: cs,
              color: balanceColor,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceColumn extends StatelessWidget {
  const _BalanceColumn({
    required this.label,
    required this.value,
    required this.cs,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w500 : FontWeight.w400,
            color: color ?? cs.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _GuardianInvoiceTile extends StatelessWidget {
  const _GuardianInvoiceTile({
    required this.item,
    required this.cs,
    required this.isDark,
  });

  final InvoiceWithDetails item;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final statusColor = _invoiceStatusColor(item.invoice.status);
    final title = item.feeTitle ?? item.invoice.description ?? 'Invoice';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 5,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invoiced: ${_fmtCurrency(item.invoice.amount)} · '
                  'Paid: ${_fmtCurrency(item.totalPaid)} · '
                  'Balance: ${_fmtCurrency(item.balance)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: _invoiceStatusLabel(item.invoice.status),
            color: statusColor,
            cs: cs,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _GuardianPaymentTile extends StatelessWidget {
  const _GuardianPaymentTile({
    required this.item,
    required this.cs,
    required this.isDark,
  });

  final PaymentWithDetails item;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final method = _paymentMethodLabel(item.payment.method);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 5,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kPaidColor.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: _kPaidColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (item.payment.reference != null &&
                    item.payment.reference!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Ref: ${item.payment.reference}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _fmtCurrency(item.payment.amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kPaidColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEETS — Create Fee / Record Payment
// ═════════════════════════════════════════════════════════════════════════════

Future<void> _showCreateFeeSheet(
  BuildContext context,
  FinanceDao dao,
  String schoolId,
  int year,
  int term,
  SchoolConfig config,
  ColorScheme cs,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => _CreateFeeSheet(
      dao: dao,
      schoolId: schoolId,
      year: year,
      term: term,
      config: config,
    ),
  );
}

class _CreateFeeSheet extends StatefulWidget {
  const _CreateFeeSheet({
    required this.dao,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
  });

  final FinanceDao dao;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;

  @override
  State<_CreateFeeSheet> createState() => _CreateFeeSheetState();
}

class _CreateFeeSheetState extends State<_CreateFeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _mandatory = true;
  int? _selectedGrade;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  List<MapEntry<int, String>> get _gradeOptions {
    final entries = <MapEntry<int, String>>[];
    for (final curr in widget.config.curricula) {
      final labels = gradeLabelsFor(curr.type);
      for (final gc in curr.grades) {
        final label = labels[gc.grade] ?? 'Grade ${gc.grade}';
        entries.add(MapEntry(gc.grade, label));
      }
    }
    return entries;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a grade'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving = true);

    try {
      final id =
          '${widget.schoolId}_fee_${DateTime.now().millisecondsSinceEpoch}';
      final amount = double.parse(_amountCtrl.text.trim());
      final dueEpoch = BigInt.from(_dueDate.millisecondsSinceEpoch ~/ 1000);

      await widget.dao.createFee(
        id: id,
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: _selectedGrade!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        amount: amount,
        mandatory: _mandatory,
        due: dueEpoch,
        accountId: accountId,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: cs),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final gradeOptions = _gradeOptions;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Create Fee Structure',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                _SheetField(
                  controller: _titleCtrl,
                  label: 'Title',
                  hint: 'e.g. Tuition Fee',
                  cs: cs,
                  isDark: isDark,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Description
                _SheetField(
                  controller: _descCtrl,
                  label: 'Description',
                  hint: 'Describe the fee',
                  cs: cs,
                  isDark: isDark,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Amount
                _SheetField(
                  controller: _amountCtrl,
                  label: 'Amount (KES)',
                  hint: '0.00',
                  cs: cs,
                  isDark: isDark,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Grade dropdown
                DropdownButtonFormField<int>(
                  initialValue: _selectedGrade,
                  decoration: _fieldDecoration(
                    label: 'Grade',
                    cs: cs,
                    isDark: isDark,
                  ),
                  dropdownColor: isDark
                      ? cs.surfaceContainerHighest
                      : cs.surface,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                  items: gradeOptions
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGrade = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Due date
                GestureDetector(
                  onTap: _pickDueDate,
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                      label: 'Due Date',
                      cs: cs,
                      isDark: isDark,
                    ),
                    child: Text(
                      _fmtDateDt(_dueDate),
                      style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Mandatory toggle
                Row(
                  children: [
                    Text(
                      'Mandatory',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: _mandatory,
                      onChanged: (v) => setState(() => _mandatory = v),
                      activeTrackColor: cs.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Fee',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showRecordPaymentSheet(
  BuildContext context,
  InvoiceWithDetails item,
  FinanceDao dao,
  String schoolId,
  ColorScheme cs,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) =>
        _RecordPaymentSheet(item: item, dao: dao, schoolId: schoolId),
  );
}

class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.item,
    required this.dao,
    required this.schoolId,
  });

  final InvoiceWithDetails item;
  final FinanceDao dao;
  final String schoolId;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with outstanding balance.
    _amountCtrl.text = widget.item.balance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving = true);

    try {
      final id =
          '${widget.item.invoice.id}_pay_${DateTime.now().millisecondsSinceEpoch}';
      final amount = double.parse(_amountCtrl.text.trim());
      final ref = _refCtrl.text.trim();

      await widget.dao.recordPayment(
        id: id,
        invoiceId: widget.item.invoice.id,
        amount: amount,
        method: _method,
        reference: ref.isEmpty ? null : ref,
        recorderId: accountId,
        accountId: accountId,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final title =
        widget.item.feeTitle ?? widget.item.invoice.description ?? 'Invoice';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Record Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$title · ${widget.item.studentName}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Balance: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    Text(
                      _fmtCurrency(widget.item.balance),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.item.balance > 0.01
                            ? _kOverdueColor
                            : _kPaidColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount
                _SheetField(
                  controller: _amountCtrl,
                  label: 'Amount (KES)',
                  hint: '0.00',
                  cs: cs,
                  isDark: isDark,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Payment method
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _method,
                  decoration: _fieldDecoration(
                    label: 'Payment Method',
                    cs: cs,
                    isDark: isDark,
                  ),
                  dropdownColor: isDark
                      ? cs.surfaceContainerHighest
                      : cs.surface,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                  items: PaymentMethod.values
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(_paymentMethodLabel(m)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _method = v);
                  },
                ),
                const SizedBox(height: 14),

                // Reference
                _SheetField(
                  controller: _refCtrl,
                  label: 'Reference (optional)',
                  hint: 'e.g. M-Pesa code, cheque number',
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPaidColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Record Payment',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    this.hint,
    required this.cs,
    required this.isDark,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ColorScheme cs;
  final bool isDark;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      decoration: _fieldDecoration(label: label, cs: cs, isDark: isDark)
          .copyWith(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required ColorScheme cs,
  required bool isDark,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
    ),
    filled: true,
    fillColor: isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
        : cs.surfaceContainerHighest.withValues(alpha: 0.4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.primary, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: cs.onSurface,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.cs,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final ColorScheme cs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 42 : 52,
          height: compact ? 42 : 52,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: compact ? 18 : 22,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: compact ? 11.5 : 12.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: content,
      );
    }
    return Center(child: content);
  }
}

class _NoTermState extends StatelessWidget {
  const _NoTermState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.event_busy_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No terms configured',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create a term to manage finances',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═════════════════════════════════════════════════════════════════════════════

String _fmtCurrency(double amount) {
  // Format with commas and 2 decimal places.
  final isNegative = amount < 0;
  final absAmount = amount.abs();
  final parts = absAmount.toStringAsFixed(2).split('.');
  final wholePart = parts[0];
  final decimalPart = parts[1];

  // Add comma separators.
  final buffer = StringBuffer();
  for (var i = 0; i < wholePart.length; i++) {
    if (i > 0 && (wholePart.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(wholePart[i]);
  }

  return '${isNegative ? '-' : ''}KES ${buffer.toString()}.$decimalPart';
}

String _fmtDateFromEpoch(int epochSeconds) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return _fmtDateDt(dt);
}

String _fmtDateDt(DateTime dt) {
  final months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${dt.day} ${months[dt.month]} ${dt.year}';
}

String _gradeLabel(int grade, SchoolConfig config) {
  for (final curr in config.curricula) {
    final labels = gradeLabelsFor(curr.type);
    if (labels.containsKey(grade)) {
      return labels[grade]!;
    }
  }
  return 'Grade $grade';
}
