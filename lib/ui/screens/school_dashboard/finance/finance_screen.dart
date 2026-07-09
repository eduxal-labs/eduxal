import 'dart:math' as math;

import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';

import '../../../../services/authorization_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/inline_date_picker_dialog.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../../client.dart';
import '../../../../core/formatters.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_empty_state.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import 'fee_detail_page.dart';

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
    // C02: Finance is non-academic — no top-level term-gating.
    // Individual sub-views handle null term gracefully.

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: schoolContext.currentEntry,
      builder: (context, entry, _) {
        return switch (entry) {
          OwnerEntry() => _OwnerFinanceShell(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          StaffEntry() =>
            (schoolContext.permissions.canAny(Resource.fees, [Action.read]) ||
                    schoolContext.permissions.canAny(Resource.payments, [
                      Action.read,
                    ]))
                ? _OwnerFinanceShell(
                    schoolContext: schoolContext,
                    termContext: termCtx,
                  )
                : const EduEmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'No finance access',
                    subtitle:
                        'You don\'t have permission to view financial data.',
                  ),
          TeacherEntry() =>
            (schoolContext.permissions.canAny(Resource.fees, [Action.read]) ||
                    schoolContext.permissions.canAny(Resource.payments, [
                      Action.read,
                    ]))
                ? _OwnerFinanceShell(
                    schoolContext: schoolContext,
                    termContext: termCtx,
                  )
                : const EduEmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'No finance access',
                    subtitle:
                        'You don\'t have permission to view financial data.',
                  ),
          GuardianEntry(:final ward) => _GuardianFinanceView(
            key: ValueKey('guardian_finance_${ward.adm}'),
            schoolContext: schoolContext,
            termContext: termCtx,
            studentAdm: ward.adm,
            studentName: ward.name,
          ),
          // Student gets a read-only view of their own invoices/payments
          StudentEntry(:final student) => _GuardianFinanceView(
            key: ValueKey('student_finance_${student.adm}'),
            schoolContext: schoolContext,
            termContext: termCtx,
            studentAdm: student.adm,
            studentName: student.name,
          ),
        };
      },
    );
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

/// Returns an urgency border color for a guardian invoice tile, or null
/// if no urgency indicator is needed.
Color? _invoiceUrgencyColor(InvoiceWithDetails item) {
  // No urgency for fully paid or cancelled invoices.
  if (item.isFullyPaid || item.invoice.status == InvoiceStatus.cancelled) {
    return null;
  }
  if (item.invoice.status == InvoiceStatus.overdue) {
    return _kOverdueColor;
  }
  final due = item.invoice.due;
  if (due != null) {
    final dueSecs = due.toInt();
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (dueSecs <= nowSecs) return _kOverdueColor;
    if (dueSecs <= nowSecs + 7 * 86400) return _kPendingColor; // within 7 days
  }
  return null;
}

/// Icon for a payment method — used in the guardian payment timeline.
IconData _paymentTimelineIcon(PaymentMethod m) => switch (m) {
  PaymentMethod.mpesa => Icons.phone_android,
  PaymentMethod.cash => Icons.payments_rounded,
  PaymentMethod.bank => Icons.account_balance_rounded,
  PaymentMethod.cheque => Icons.receipt_long_rounded,
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
  late List<_FinanceTab> _visibleTabs;
  _FinanceTab _currentTab = _FinanceTab.overview;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = FinanceDao(db);
    _visibleTabs = _computeVisibleTabs();
    _tabController = TabController(length: _visibleTabs.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant _OwnerFinanceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTabs = _computeVisibleTabs();
    if (newTabs.length != _visibleTabs.length ||
        !_tabsEqual(newTabs, _visibleTabs)) {
      _tabController
        ..removeListener(_onTabChanged)
        ..dispose();
      _visibleTabs = newTabs;
      _currentTab = _visibleTabs.isNotEmpty
          ? _visibleTabs.first
          : _FinanceTab.overview;
      _tabController = TabController(length: _visibleTabs.length, vsync: this)
        ..addListener(_onTabChanged);
      setState(() {});
    }
  }

  static bool _tabsEqual(List<_FinanceTab> a, List<_FinanceTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// B06: Compute which tabs the current user may see.
  List<_FinanceTab> _computeVisibleTabs() {
    final perms = widget.schoolContext.permissions;
    final entry = widget.schoolContext.currentEntry.value;
    final isOwner = entry is OwnerEntry;

    final tabs = <_FinanceTab>[];

    // Overview — visible when the user has any finance permission.
    if (isOwner ||
        perms.canAny(Resource.fees, [Action.read]) ||
        perms.canAny(Resource.payments, [Action.read])) {
      tabs.add(_FinanceTab.overview);
    }

    // Invoices — requires fees.read
    if (isOwner || perms.can(Resource.fees, Action.read)) {
      tabs.add(_FinanceTab.invoices);
    }

    // Payments — requires payments.read
    if (isOwner || perms.can(Resource.payments, Action.read)) {
      tabs.add(_FinanceTab.payments);
    }

    // Fees — requires fees.read
    if (isOwner || perms.can(Resource.fees, Action.read)) {
      tabs.add(_FinanceTab.fees);
    }

    return tabs;
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
    if (_tabController.index >= _visibleTabs.length) return;
    final newTab = _visibleTabs[_tabController.index];
    if (newTab != _currentTab) {
      setState(() => _currentTab = newTab);
    }
  }

  String _tabLabel(_FinanceTab tab) => switch (tab) {
    _FinanceTab.overview => 'Overview',
    _FinanceTab.invoices => 'Invoices',
    _FinanceTab.payments => 'Payments',
    _FinanceTab.fees => 'Fees',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    // C02: Instead of blocking the entire section with _NoTermState, show a
    // friendly informational message.  Finance data is term-scoped so we
    // cannot render the tabs without a term, but we no longer hide the
    // section entirely.
    if (term == null) {
      final hasTerms = widget.termContext.hasTerms;
      return _EmptyState(
        icon: Icons.event_note_outlined,
        label: hasTerms ? 'No term selected' : 'No terms configured',
        sublabel: hasTerms
            ? 'Select a term to view financial data'
            : 'Create a term to start managing finances',
        cs: cs,
      );
    }

    if (_visibleTabs.isEmpty) {
      return const EduEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No finance access',
        subtitle: 'You don\'t have permission to view financial data.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EduTabBar(
          controller: _tabController,
          tabs: [for (final tab in _visibleTabs) EduTab(label: _tabLabel(tab))],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final tab in _visibleTabs) _buildTabContent(tab, term, cs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(_FinanceTab tab, Term term, ColorScheme cs) {
    return switch (tab) {
      _FinanceTab.overview => _OverviewTab(
        schoolId: _schoolId,
        year: term.year,
        term: term.term,
        dao: _dao,
        cs: cs,
      ),
      _FinanceTab.invoices => _InvoicesTab(
        schoolId: _schoolId,
        year: term.year,
        term: term.term,
        dao: _dao,
        cs: cs,
        schoolContext: widget.schoolContext,
      ),
      _FinanceTab.payments => _PaymentsTab(
        schoolId: _schoolId,
        year: term.year,
        term: term.term,
        dao: _dao,
        cs: cs,
        schoolContext: widget.schoolContext,
      ),
      _FinanceTab.fees => _FeesTab(
        schoolId: _schoolId,
        year: term.year,
        term: term.term,
        dao: _dao,
        cs: cs,
        schoolContext: widget.schoolContext,
      ),
    };
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
        return _OverviewContent(
          summary: summary,
          cs: cs,
          dao: dao,
          schoolId: schoolId,
        );
      },
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.summary,
    required this.cs,
    required this.dao,
    required this.schoolId,
  });

  final TermFinanceSummary summary;
  final ColorScheme cs;
  final FinanceDao dao;
  final String schoolId;

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
              const SizedBox(height: 14),

              // ── Daily collection summary ────────────────────────────────
              _DailyCollectionCard(
                dao: dao,
                schoolId: schoolId,
                cs: cs,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // ── Metric cards ────────────────────────────────────────────
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Total Invoiced',
                        value: fmtCurrency(summary.totalInvoiced),
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
                        value: fmtCurrency(summary.totalPaid),
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
                        value: fmtCurrency(summary.totalPending),
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
                        value: fmtCurrency(summary.totalOverdue),
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
                Builder(
                  builder: (context) {
                    // Available width after ScrollView padding (20 each side).
                    final available = constraints.maxWidth - 40;
                    const spacing = 12.0;
                    const minCardWidth = 130.0;
                    // Optimal column count that fills width without waste.
                    final columns = math.min(
                      4,
                      math.max(
                        1,
                        ((available + spacing) / (minCardWidth + spacing))
                            .floor(),
                      ),
                    );
                    final cardWidth =
                        (available - (columns - 1) * spacing) / columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        _MetricCard(
                          label: 'Total Invoiced',
                          value: fmtCurrency(summary.totalInvoiced),
                          count: summary.invoiceCount,
                          countLabel: 'invoices',
                          color: cs.primary,
                          cs: cs,
                          isDark: isDark,
                          width: cardWidth,
                        ),
                        _MetricCard(
                          label: 'Total Collected',
                          value: fmtCurrency(summary.totalPaid),
                          count: summary.paidCount,
                          countLabel: 'paid',
                          color: _kPaidColor,
                          cs: cs,
                          isDark: isDark,
                          width: cardWidth,
                        ),
                        _MetricCard(
                          label: 'Pending',
                          value: fmtCurrency(summary.totalPending),
                          count: summary.pendingCount,
                          countLabel: 'pending',
                          color: _kPendingColor,
                          cs: cs,
                          isDark: isDark,
                          width: cardWidth,
                        ),
                        _MetricCard(
                          label: 'Overdue',
                          value: fmtCurrency(summary.totalOverdue),
                          count: summary.overdueCount,
                          countLabel: 'overdue',
                          color: _kOverdueColor,
                          cs: cs,
                          isDark: isDark,
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
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
                  '${fmtCurrency(summary.totalPaid)} of ${fmtCurrency(summary.totalInvoiced)}',
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
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────────────────────────────────────
// Daily Collection Card
// ─────────────────────────────────────────────────────────────────────────────

class _DailyCollectionCard extends StatelessWidget {
  const _DailyCollectionCard({
    required this.dao,
    required this.schoolId,
    required this.cs,
    required this.isDark,
  });

  final FinanceDao dao;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    // payments.created stores seconds since epoch
    final startSecs = todayStart.millisecondsSinceEpoch ~/ 1000;
    final endSecs = todayEnd.millisecondsSinceEpoch ~/ 1000;

    return StreamBuilder<DailyCollectionSummary>(
      stream: dao.watchDailyCollection(
        schoolId: schoolId,
        todayStartMs: startSecs,
        todayEndMs: endSecs,
      ),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();

        // Build per-method breakdown chips.
        final methodChips = <Widget>[];
        for (final entry in data.byMethod.entries) {
          final methodIdx = entry.key;
          final ms = entry.value;
          if (methodIdx < 0 || methodIdx >= PaymentMethod.values.length) {
            continue;
          }
          final method = PaymentMethod.values[methodIdx];
          if (methodChips.isNotEmpty) {
            methodChips.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '\u00b7',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }
          methodChips.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _paymentTimelineIcon(method),
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${ms.count} ${_paymentMethodLabel(method)} '
                  '(${fmtCurrency(ms.amount)})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? _kPaidColor.withValues(alpha: 0.08)
                : _kPaidColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: _kPaidColor.withValues(alpha: isDark ? 0.18 : 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today_rounded, size: 16, color: _kPaidColor),
                  const SizedBox(width: 6),
                  Text(
                    "Today's Collections",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${fmtCurrency(data.totalAmount)} today',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              if (data.paymentCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${data.paymentCount} payment${data.paymentCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
              if (methodChips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: methodChips,
                ),
              ],
            ],
          ),
        );
      },
    );
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
    required this.cs,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final ColorScheme cs;
  final SchoolContext schoolContext;

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
                schoolContext: widget.schoolContext,
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
    required this.schoolContext,
  });

  final List<InvoiceWithDetails> items;
  final FinanceDao dao;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: items.length * 2 - 1,
      itemBuilder: (context, index) {
        if (index.isOdd) {
          return AppTheme.tableRowDivider(isDark, cs);
        }
        final item = items[index ~/ 2];
        final isOwner = schoolContext.currentEntry.value is OwnerEntry;
        final perms = schoolContext.permissions;
        final canRecord =
            isOwner || perms.can(Resource.payments, Action.create);
        final canEditInvoice =
            isOwner || perms.can(Resource.fees, Action.update);
        final canDeleteInvoice =
            isOwner || perms.can(Resource.fees, Action.delete);
        return _InvoiceRow(
          item: item,
          dao: dao,
          schoolId: schoolId,
          cs: cs,
          isDark: isDark,
          canRecordPayment: canRecord,
          canEdit: canEditInvoice,
          canDelete: canDeleteInvoice,
          onRecordPayment: () =>
              _showRecordPaymentSheet(context, item, dao, schoolId, cs),
        );
      },
    );
  }
}

class _InvoiceRow extends StatefulWidget {
  const _InvoiceRow({
    required this.item,
    required this.dao,
    required this.schoolId,
    required this.cs,
    required this.isDark,
    required this.onRecordPayment,
    this.canRecordPayment = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  final InvoiceWithDetails item;
  final FinanceDao dao;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onRecordPayment;
  final bool canRecordPayment;
  final bool canEdit;
  final bool canDelete;

  /// Whether the row has any actionable permission (used to hide empty menus).
  bool get hasAnyAction => canRecordPayment || canEdit || canDelete;

  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> {
  bool _isHovered = false;

  void _showMobileMenu(BuildContext context, List<_FinanceRowAction> actions) {
    showEduSheet<void>(
      context: context,
      builder: (ctx) {
        return EduSheet(
          title: widget.item.feeTitle ?? widget.item.invoice.description ?? 'Invoice Actions',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...actions.map(
                (a) => ListTile(
                  leading: Icon(a.icon, size: 20, color: a.color),
                  title: Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: a.color,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    a.onTap();
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  minLeadingWidth: 20,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final item = widget.item;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final statusColor = _invoiceStatusColor(item.invoice.status);
    final balance = item.balance;
    final title = item.feeTitle ?? item.invoice.description ?? 'Invoice';
    final canRecordPayment =
        widget.canRecordPayment &&
        item.invoice.status != InvoiceStatus.paid &&
        item.invoice.status != InvoiceStatus.cancelled;
    final hasAnyAction = canRecordPayment || widget.canEdit || widget.canDelete;

    final rowActions = [
      if (canRecordPayment)
        _FinanceRowAction(
          icon: Icons.add_card_outlined,
          label: 'Record Payment',
          color: _kPaidColor,
          onTap: widget.onRecordPayment,
        ),
      if (widget.canEdit)
        _FinanceRowAction(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: cs.onSurface,
          onTap: () {
            // TODO: implement invoice edit
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
      if (widget.canDelete)
        _FinanceRowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: cs.error,
          onTap: () {
            // TODO: implement invoice delete
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: (!isDesktop && hasAnyAction) ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: (!isDesktop && hasAnyAction)
            ? () => _showMobileMenu(context, rowActions)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _isHovered
              ? cs.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Main info ──────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            label: _invoiceStatusLabel(item.invoice.status),
                            color: statusColor,
                            cs: cs,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Student name + amount + due
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.studentName} · Adm #${item.studentAdm}'
                              '${item.invoice.due != null ? ' · Due ${_fmtDateFromEpoch(item.invoice.due!.toInt())}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmtCurrency(item.invoice.amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          if (balance > 0.01) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(bal: ${fmtCurrency(balance)})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: _kOverdueColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Desktop actions ────────────────────────────────────────
                if (isDesktop) ...[
                  const SizedBox(width: 4),
                  _FinanceRowActions(
                    isHovered: _isHovered,
                    cs: cs,
                    actions: [
                      if (canRecordPayment)
                        _FinanceRowAction(
                          icon: Icons.add_card_outlined,
                          label: 'Record Payment',
                          color: _kPaidColor,
                          onTap: widget.onRecordPayment,
                        ),
                      if (widget.canEdit)
                        _FinanceRowAction(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          color: cs.onSurfaceVariant,
                          onTap: () {
                            // TODO: implement invoice edit
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon')),
                            );
                          },
                        ),
                      if (widget.canDelete)
                        _FinanceRowAction(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          color: cs.error,
                          onTap: () {
                            // TODO: implement invoice delete
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon')),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final ColorScheme cs;
  final SchoolContext schoolContext;

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
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
          itemCount: items.length * 2 - 1,
          itemBuilder: (context, index) {
            if (index.isOdd) {
              return AppTheme.tableRowDivider(isDark, cs);
            }
            final item = items[index ~/ 2];
            final isOwner = schoolContext.currentEntry.value is OwnerEntry;
            final perms = schoolContext.permissions;
            return _PaymentRow(
              item: item,
              cs: cs,
              isDark: isDark,
              canApprove:
                  isOwner || perms.can(Resource.payments, Action.approve),
              canEdit: isOwner || perms.can(Resource.payments, Action.update),
              canDelete: isOwner || perms.can(Resource.payments, Action.delete),
            );
          },
        );
      },
    );
  }
}

class _PaymentRow extends StatefulWidget {
  const _PaymentRow({
    required this.item,
    required this.cs,
    required this.isDark,
    this.canApprove = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  final PaymentWithDetails item;
  final ColorScheme cs;
  final bool isDark;
  final bool canApprove;
  final bool canEdit;
  final bool canDelete;

  @override
  State<_PaymentRow> createState() => _PaymentRowState();
}

class _PaymentRowState extends State<_PaymentRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final item = widget.item;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final methodLabel = _paymentMethodLabel(item.payment.method);
    final ref = item.payment.reference;
    final hasAnyAction =
        widget.canApprove || widget.canEdit || widget.canDelete;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered
            ? cs.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // ── Method icon ────────────────────────────────────────────
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kPaidColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _paymentMethodIcon(item.payment.method),
                  size: 16,
                  color: _kPaidColor,
                ),
              ),
              const SizedBox(width: 12),

              // ── Main info ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 2),
                    Text(
                      '$methodLabel${ref != null && ref.isNotEmpty ? ' · $ref' : ''}'
                      '${item.invoiceDescription != null ? ' · ${item.invoiceDescription}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Amount ─────────────────────────────────────────────────
              const SizedBox(width: 12),
              Text(
                fmtCurrency(item.payment.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kPaidColor,
                  letterSpacing: -0.2,
                ),
              ),

              // ── Desktop actions ────────────────────────────────────────
              if (isDesktop) ...[
                const SizedBox(width: 4),
                _FinanceRowActions(
                  isHovered: _isHovered,
                  cs: cs,
                  actions: [
                    if (widget.canApprove)
                      _FinanceRowAction(
                        icon: Icons.thumb_up_outlined,
                        label: 'Approve',
                        color: _kPaidColor,
                        onTap: () {
                          // TODO: implement payment approve
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    if (widget.canEdit)
                      _FinanceRowAction(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: cs.onSurfaceVariant,
                        onTap: () {
                          // TODO: implement payment edit
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    if (widget.canDelete)
                      _FinanceRowAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: cs.error,
                        onTap: () {
                          // TODO: implement payment delete
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                  ],
                ),
              ],

              // ── Mobile three-dot ───────────────────────────────────────
              if (!isDesktop && hasAnyAction)
                _FinanceMobileMenu(
                  cs: cs,
                  isDark: isDark,
                  actions: [
                    if (widget.canApprove)
                      _FinanceRowAction(
                        icon: Icons.thumb_up_outlined,
                        label: 'Approve',
                        color: _kPaidColor,
                        onTap: () {
                          // TODO: implement payment approve
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    if (widget.canEdit)
                      _FinanceRowAction(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: cs.onSurface,
                        onTap: () {
                          // TODO: implement payment edit
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    if (widget.canDelete)
                      _FinanceRowAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: cs.error,
                        onTap: () {
                          // TODO: implement payment delete
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
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
    required this.cs,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final FinanceDao dao;
  final ColorScheme cs;
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final isOwner = schoolContext.currentEntry.value is OwnerEntry;
    final canCreateFee =
        isOwner || schoolContext.permissions.can(Resource.fees, Action.create);

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

            // Group fees by title for consolidated display.
            final grouped = <String, List<FeeWithStats>>{};
            for (final item in items) {
              grouped.putIfAbsent(item.fee.title, () => []).add(item);
            }
            final groups = grouped.entries.toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
              itemCount: groups.length * 2 - 1,
              itemBuilder: (context, index) {
                if (index.isOdd) {
                  return AppTheme.tableRowDivider(isDark, cs);
                }
                final group = groups[index ~/ 2];
                return _FeeGroupRow(
                  title: group.key,
                  fees: group.value,
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActiveTermProvider(
                          termContext: ActiveTermProvider.read(context),
                          child: FeeDetailPage(
                            feeTitle: group.key,
                            fees: group.value,
                            schoolContext: schoolContext,
                            dao: dao,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        // FAB — only if user can create fees
        if (canCreateFee)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.small(
              heroTag: 'fab_finance_fees',
              onPressed: () =>
                  _showCreateFeeSheet(context, dao, schoolId, year, term, cs),
              tooltip: 'New Fee',
              elevation: 4,
              highlightElevation: 6,
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              child: const Icon(Icons.add, size: 20),
            ),
          ),
      ],
    );
  }
}

class _FeeGroupRow extends StatefulWidget {
  const _FeeGroupRow({
    required this.title,
    required this.fees,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final List<FeeWithStats> fees;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_FeeGroupRow> createState() => _FeeGroupRowState();
}

class _FeeGroupRowState extends State<_FeeGroupRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final fees = widget.fees;
    final totalInvoices = fees.fold<int>(0, (sum, f) => sum + f.invoiceCount);
    final amount = fees.first.fee.amount;
    final gradeCount = fees.length;
    final isMandatory = fees.first.fee.mandatory;
    final typeLabel = isMandatory ? 'Mandatory' : 'Optional';
    final typeColor = isMandatory ? cs.primary : cs.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _isHovered
              ? cs.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Main info ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fee title + amount
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmtCurrency(amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Grade count + invoices + type badge
                      Row(
                        children: [
                          // Grade count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(
                                alpha: isDark ? 0.15 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$gradeCount grade${gradeCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$totalInvoices invoice${totalInvoices == 1 ? '' : 's'} · Due ${_fmtDateFromEpoch(fees.first.fee.due.toInt())}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(
                                alpha: isDark ? 0.15 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: typeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Chevron ──────────────────────────────────────────────
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared finance row action helpers ────────────────────────────────────────

class _FinanceRowAction {
  const _FinanceRowAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _FinanceRowActions extends StatelessWidget {
  const _FinanceRowActions({
    required this.isHovered,
    required this.cs,
    required this.actions,
  });

  final bool isHovered;
  final ColorScheme cs;
  final List<_FinanceRowAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map((a) => _FinanceActionBtn(action: a, isRowHovered: isHovered))
          .toList(),
    );
  }
}

class _FinanceActionBtn extends StatefulWidget {
  const _FinanceActionBtn({required this.action, required this.isRowHovered});

  final _FinanceRowAction action;
  final bool isRowHovered;

  @override
  State<_FinanceActionBtn> createState() => _FinanceActionBtnState();
}

class _FinanceActionBtnState extends State<_FinanceActionBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveAlpha = (_isHovered || widget.isRowHovered) ? 1.0 : 0.0;
    final color = widget.action.color;

    return Tooltip(
      message: widget.action.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.action.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered
                  ? color.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: effectiveAlpha,
              child: Icon(widget.action.icon, size: 16, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanceMobileMenu extends StatelessWidget {
  const _FinanceMobileMenu({
    required this.cs,
    required this.isDark,
    required this.actions,
  });

  final ColorScheme cs;
  final bool isDark;
  final List<_FinanceRowAction> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
        tooltip: 'More actions',
        onPressed: () => _showSheet(context),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showEduSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...actions.map(
                (a) => ListTile(
                  leading: Icon(a.icon, size: 20, color: a.color),
                  title: Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: a.color,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    a.onTap();
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  minLeadingWidth: 20,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GUARDIAN VIEW — Read-only per-ward finances
// ═════════════════════════════════════════════════════════════════════════════

class _GuardianFinanceView extends StatefulWidget {
  const _GuardianFinanceView({
    super.key,
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
  void didUpdateWidget(covariant _GuardianFinanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentAdm != widget.studentAdm) {
      // StreamBuilder will pick up new stream params on rebuild.
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final term = widget.termContext.currentTerm;

    // C02: Show a friendlier message instead of the full _NoTermState blocker.
    if (term == null) {
      return _EmptyState(
        icon: Icons.event_note_outlined,
        label: 'No term selected',
        sublabel: 'Financial data will appear once a term is active',
        cs: cs,
      );
    }

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
          bottomPadding: 0.0,
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
    this.bottomPadding = 0.0,
  });

  final StudentFinanceSummary summary;
  final String studentName;
  final ColorScheme cs;
  final bool isDark;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 8),

        // ── Balance summary card ────────────────────────────────────────
        _GuardianBalanceCard(summary: summary, cs: cs, isDark: isDark),
        const SizedBox(height: 16),

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

        const SizedBox(height: 12),

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
          _GuardianPaymentTimeline(
            payments: summary.payments,
            cs: cs,
            isDark: isDark,
          ),
      ],
    );

    // Use CustomScrollView so short content pins to the top and the
    // remaining viewport area shows the scaffold background instead of
    // the card's white surface.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + bottomPadding),
          sliver: SliverToBoxAdapter(child: content),
        ),
        // Fill leftover viewport space with the scaffold background so
        // short content doesn't leave a white void at the bottom.
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: scaffoldBg),
        ),
      ],
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
    final totalInvoiced = summary.totalInvoiced;
    final totalPaid = summary.totalPaid;
    final paidFraction = totalInvoiced > 0
        ? (totalPaid / totalInvoiced).clamp(0.0, 1.0)
        : 0.0;
    final pctStr = (paidFraction * 100).toStringAsFixed(1);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _BalanceColumn(
                  label: 'Total Invoiced',
                  value: fmtCurrency(totalInvoiced),
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
                  value: fmtCurrency(totalPaid),
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
                  value: fmtCurrency(balance),
                  cs: cs,
                  color: balanceColor,
                  isBold: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Progress summary line ─────────────────────────────────
          Text(
            '${fmtCurrency(totalPaid)} / ${fmtCurrency(totalInvoiced)} ($pctStr%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // ── Balance progress bar ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: paidFraction,
                backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(_kPaidColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // ── Remaining line ────────────────────────────────────────
          Text(
            '${fmtCurrency(balance > 0 ? balance : 0)} remaining',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
    final urgencyColor = _invoiceUrgencyColor(item);

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            urgencyColor != null ? 18 : 14,
            14,
            14,
            14,
          ),
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
                      'Invoiced: ${fmtCurrency(item.invoice.amount)} · '
                      'Paid: ${fmtCurrency(item.totalPaid)} · '
                      'Balance: ${fmtCurrency(item.balance)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    if (item.invoice.due != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Due: ${_fmtDateFromEpoch(item.invoice.due!.toInt())}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color:
                              urgencyColor ??
                              cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
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
        ),
        // ── Urgency left-border strip ─────────────────────────────────
        if (urgencyColor != null)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.kRadius),
                  bottomLeft: Radius.circular(AppTheme.kRadius),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders all guardian payments as a vertical timeline with connected dots.
class _GuardianPaymentTimeline extends StatelessWidget {
  const _GuardianPaymentTimeline({
    required this.payments,
    required this.cs,
    required this.isDark,
  });

  final List<PaymentWithDetails> payments;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < payments.length; i++)
          _GuardianTimelineEntry(
            item: payments[i],
            cs: cs,
            isDark: isDark,
            isFirst: i == 0,
            isLast: i == payments.length - 1,
          ),
      ],
    );
  }
}

/// A single entry in the guardian payment timeline.
class _GuardianTimelineEntry extends StatelessWidget {
  const _GuardianTimelineEntry({
    required this.item,
    required this.cs,
    required this.isDark,
    required this.isFirst,
    required this.isLast,
  });

  final PaymentWithDetails item;
  final ColorScheme cs;
  final bool isDark;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final method = _paymentMethodLabel(item.payment.method);
    final icon = _paymentTimelineIcon(item.payment.method);
    // All recorded payments are confirmed (no pending status on Payment).
    const dotColor = _kPaidColor;
    final lineColor = cs.onSurfaceVariant.withValues(alpha: 0.15);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline rail (dot + connecting lines) ───────────────────
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Line above the dot (hidden for the first entry).
                if (!isFirst)
                  Expanded(
                    child: Center(child: Container(width: 2, color: lineColor)),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
                // Timeline dot.
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                // Line below the dot (hidden for the last entry).
                if (!isLast)
                  Expanded(
                    child: Center(child: Container(width: 2, color: lineColor)),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Payment content ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  // Method icon chip.
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 16, color: dotColor),
                  ),
                  const SizedBox(width: 10),
                  // Details.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                method,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              fmtCurrency(item.payment.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _kPaidColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (item.payment.reference != null &&
                                item.payment.reference!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  'Ref: ${item.payment.reference}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            Text(
                              fmtRelativeTime(
                                item.payment.created.toInt() * 1000,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
  ColorScheme cs,
) {
  return showEduSheet(
    context: context,
    title: 'Create Fee Structure',
    builder: (_) =>
        _CreateFeeSheet(dao: dao, schoolId: schoolId, year: year, term: term),
  );
}

class _CreateFeeSheet extends StatefulWidget {
  const _CreateFeeSheet({
    required this.dao,
    required this.schoolId,
    required this.year,
    required this.term,
  });

  final FinanceDao dao;
  final String schoolId;
  final int year;
  final int term;

  @override
  State<_CreateFeeSheet> createState() => _CreateFeeSheetState();
}

class _CreateFeeSheetState extends State<_CreateFeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _mandatory = true;
  final Set<int> _selectedGrades = {};
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  String? _gradeError;

  late final CatalogDao _catalogDao;
  List<MapEntry<int, String>> _gradeOptions = [];

  @override
  void initState() {
    super.initState();
    _catalogDao = CatalogDao(db);
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    final streams = await _catalogDao.getStreamsForSchool(widget.schoolId);
    if (!mounted) return;

    // Collect distinct grades and resolve labels.
    final gradeSet = <int>{};
    for (final s in streams) {
      gradeSet.add(s.grade);
    }
    final sortedGrades = gradeSet.toList()..sort();

    setState(() {
      _gradeOptions = sortedGrades.map((g) {
        final label =
            kCbcGradeLabels[g] ?? kEightFourFourGradeLabels[g] ?? 'Grade $g';
        return MapEntry(g, label);
      }).toList();
    });
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
    if (_selectedGrades.isEmpty) {
      setState(() => _gradeError = 'Please select at least one grade');
      return;
    }
    setState(() => _gradeError = null);

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving = true);

    try {
      final amount = double.parse(_amountCtrl.text.trim());
      final dueEpoch = BigInt.from(_dueDate.millisecondsSinceEpoch ~/ 1000);
      final title = _titleCtrl.text.trim();
      final description = _descCtrl.text.trim();
      final baseTs = DateTime.now().millisecondsSinceEpoch;

      // Create one fee record per selected grade.
      var i = 0;
      for (final grade in _selectedGrades) {
        final id = '${widget.schoolId}_fee_${baseTs}_$i';
        i++;

        await widget.dao.createFee(
          id: id,
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          grade: grade,
          title: title,
          description: description,
          amount: amount,
          mandatory: _mandatory,
          due: dueEpoch,
          accountId: accountId,
        );
      }

      if (mounted) Navigator.pop(context);
    } on PermissionException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showPermissionDenied(context, e.reason);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showInlineDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      title: 'Due date',
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        if (v == null || v.trim().isEmpty) {
                          return 'Amount is required';
                        }
                        final n = double.tryParse(v.trim());
                        if (n == null) return 'Enter a valid number';
                        if (n <= 0) return 'Amount must be greater than zero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Grade selection — multi-select chips
                    Text(
                      'Grades',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_gradeOptions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.kRadius),
                        ),
                        child: Text(
                          'No grades configured. Add grades in school settings.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _gradeOptions.map((entry) {
                          final isSelected = _selectedGrades.contains(
                            entry.key,
                          );
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedGrades.remove(entry.key);
                                } else {
                                  _selectedGrades.add(entry.key);
                                }
                                if (_gradeError != null) _gradeError = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withValues(
                                        alpha: isDark ? 0.2 : 0.1,
                                      )
                                    : cs.surfaceContainerHighest.withValues(
                                        alpha: 0.4,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? cs.primary
                                          : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    if (_selectedGrades.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${_selectedGrades.length} grade${_selectedGrades.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: cs.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    if (_gradeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _gradeError!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: cs.error,
                          ),
                        ),
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
                          fmtDateDt(_dueDate),
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

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Cancel',
                          style: IconButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _saving ? null : _save,
                          tooltip: 'Save',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.green.shade600
                                .withValues(alpha: 0.5),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  return showEduSheet(
    context: context,
    title: 'Record Payment',
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
        schoolId: widget.schoolId,
        amount: amount,
        method: _method,
        reference: ref.isEmpty ? null : ref,
        recorderId: accountId,
        accountId: accountId,
      );

      if (mounted) Navigator.pop(context);
    } on PermissionException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showPermissionDenied(context, e.reason);
      }
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

    final invoiceTitle =
        widget.item.feeTitle ?? widget.item.invoice.description ?? 'Invoice';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Invoice subtitle + balance summary
                    Text(
                      '$invoiceTitle · ${widget.item.studentName}',
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
                          fmtCurrency(widget.item.balance),
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
                        if (v == null || v.trim().isEmpty) {
                          return 'Amount is required';
                        }
                        final n = double.tryParse(v.trim());
                        if (n == null) return 'Enter a valid number';
                        if (n <= 0) return 'Amount must be greater than zero';
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.kRadius,
                            ),
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
        ],
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

// ═════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═════════════════════════════════════════════════════════════════════════════

/// Thin adapter: epoch-seconds → formatted date via shared [fmtDateDt].
String _fmtDateFromEpoch(int epochSeconds) =>
    fmtDateDt(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));
