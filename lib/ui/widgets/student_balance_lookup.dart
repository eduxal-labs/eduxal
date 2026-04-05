import 'dart:async';

import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../database/daos/finance_dao.dart';
import '../../database/daos/members_dao.dart';
import '../../core/formatters.dart';
import '../theme/app_theme.dart';
import 'edu_search_field.dart';
import 'thin_progress_bar.dart';

/// A reusable widget for searching students by name or ADM number and
/// displaying their fee balance summary.
///
/// Shows a search field with 300ms debounce, a results list (max 5), and
/// on selection a balance card with progress bar, outstanding amount,
/// expandable invoice breakdown, and an optional "Record Payment" button.
///
/// ```dart
/// StudentBalanceLookup(
///   schoolId: 'abc123',
///   onStudentSelected: () => debugPrint('selected'),
///   showPaymentAction: true,
///   onRecordPayment: () => _openPaymentSheet(),
/// )
/// ```
class StudentBalanceLookup extends StatefulWidget {
  const StudentBalanceLookup({
    super.key,
    required this.schoolId,
    this.onStudentSelected,
    this.showPaymentAction = false,
    this.onRecordPayment,
  });

  final String schoolId;
  final VoidCallback? onStudentSelected;
  final bool showPaymentAction;
  final VoidCallback? onRecordPayment;

  @override
  State<StudentBalanceLookup> createState() => _StudentBalanceLookupState();
}

class _StudentBalanceLookupState extends State<StudentBalanceLookup> {
  final _searchCtrl = TextEditingController();
  late final MembersDao _membersDao;
  late final FinanceDao _financeDao;

  Timer? _debounce;
  List<StudentsData> _results = [];
  bool _searching = false;

  /// The currently selected student (null = none selected yet).
  StudentsData? _selectedStudent;

  /// Balance stream subscription for the selected student.
  StreamSubscription<StudentBalanceSummary?>? _balanceSub;
  StudentBalanceSummary? _balance;
  bool _balanceLoading = false;

  /// Whether the invoice list is expanded in the balance card.
  bool _invoicesExpanded = false;

  @override
  void initState() {
    super.initState();
    _membersDao = MembersDao(db);
    _financeDao = FinanceDao(db);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _balanceSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Search
  // ─────────────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _membersDao.searchStudents(widget.schoolId, query);
      if (!mounted) return;
      setState(() {
        // Cap at 5 results for the compact dropdown.
        _results = results.take(5).toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Selection
  // ─────────────────────────────────────────────────────────────────────────

  void _selectStudent(StudentsData student) {
    setState(() {
      _selectedStudent = student;
      _results = [];
      _searchCtrl.text = student.name;
      _balanceLoading = true;
      _balance = null;
      _invoicesExpanded = false;
    });

    widget.onStudentSelected?.call();

    // Subscribe to the balance stream for this student.
    _balanceSub?.cancel();
    _balanceSub = _financeDao
        .watchStudentBalance(schoolId: widget.schoolId, studentAdm: student.adm)
        .listen(
          (summary) {
            if (!mounted) return;
            setState(() {
              _balance = summary;
              _balanceLoading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _balanceLoading = false);
          },
        );
  }

  void _clearSelection() {
    _balanceSub?.cancel();
    _searchCtrl.clear();
    setState(() {
      _selectedStudent = null;
      _balance = null;
      _balanceLoading = false;
      _results = [];
      _invoicesExpanded = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search field ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: EduSearchField(
                controller: _searchCtrl,
                hint: 'Search by name or ADM…',
                onChanged: _selectedStudent != null ? null : _onSearchChanged,
                fillWidth: true,
              ),
            ),
            if (_selectedStudent != null) ...[
              const SizedBox(width: 6),
              _ClearButton(onTap: _clearSelection),
            ],
          ],
        ),

        // ── Search results dropdown ───────────────────────────────────────
        if (_selectedStudent == null && (_results.isNotEmpty || _searching))
          _buildResultsList(cs, isDark),

        // ── Balance card ──────────────────────────────────────────────────
        if (_selectedStudent != null) ...[
          const SizedBox(height: 12),
          _buildBalanceCard(cs, isDark),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Results list
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildResultsList(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _searching
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _results.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(
                          alpha: isDark ? 0.2 : 0.4,
                        ),
                      ),
                    _StudentResultRow(
                      student: _results[i],
                      onTap: () => _selectStudent(_results[i]),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Balance card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBalanceCard(ColorScheme cs, bool isDark) {
    if (_balanceLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.5,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    if (_balance == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.5,
          ),
        ),
        child: Text(
          'No invoices found for this student.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final bal = _balance!;
    final paidPercent = bal.totalInvoiced > 0
        ? (bal.totalPaid / bal.totalInvoiced) * 100
        : 0.0;
    final outstandingColor = bal.outstanding <= 0
        ? const Color(0xFF4CAF50)
        : const Color(0xFFF44336);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Summary header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student name + ADM tag
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bal.studentName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        'ADM ${bal.studentAdm}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress bar
                ThinProgressBar(percent: paidPercent, height: 6),
                const SizedBox(height: 6),

                // Paid / Invoiced labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${fmtCurrency(bal.totalPaid)} paid',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      'of ${fmtCurrency(bal.totalInvoiced)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Outstanding amount — large text
                Text(
                  bal.outstanding <= 0
                      ? 'Fully Paid'
                      : '${fmtCurrency(bal.outstanding)} outstanding',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: outstandingColor,
                  ),
                ),
              ],
            ),
          ),

          // ── Invoice breakdown (expandable) ──────────────────────────────
          if (bal.invoices.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
            ),
            _InvoiceExpandHeader(
              count: bal.invoices.length,
              expanded: _invoicesExpanded,
              onTap: () =>
                  setState(() => _invoicesExpanded = !_invoicesExpanded),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildInvoiceList(bal.invoices, cs, isDark),
              crossFadeState: _invoicesExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],

          // ── Record Payment button ───────────────────────────────────────
          if (widget.showPaymentAction && widget.onRecordPayment != null) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
            ),
            InkWell(
              onTap: widget.onRecordPayment,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Record Payment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Invoice list (inside expandable)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInvoiceList(
    List<InvoiceBalanceItem> items,
    ColorScheme cs,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 14,
              endIndent: 14,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.3),
            ),
          _InvoiceBalanceRow(item: items[i]),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Small × button to clear the current selection.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        ),
        child: Icon(Icons.close_rounded, size: 14, color: cs.error),
      ),
    );
  }
}

/// A single student row in the search results dropdown.
class _StudentResultRow extends StatelessWidget {
  const _StudentResultRow({required this.student, required this.onTap});

  final StudentsData student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Initials avatar (small)
            _MiniAvatar(name: student.name, adm: student.adm),
            const SizedBox(width: 8),
            // Name + ADM
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'ADM: ${student.adm}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny circle avatar with initials, deterministic color from ADM.
class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.name, required this.adm});

  final String name;
  final int adm;

  static const _colors = <Color>[
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFF42A5F5),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = _colors[adm % _colors.length];
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.isNotEmpty && parts.first.isNotEmpty
              ? parts.first[0].toUpperCase()
              : '?');

    return CircleAvatar(
      radius: 14,
      backgroundColor: bg.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: bg),
      ),
    );
  }
}

/// Tap header to expand/collapse the invoice breakdown.
class _InvoiceExpandHeader extends StatelessWidget {
  const _InvoiceExpandHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Text(
              '$count invoice${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single invoice balance row inside the expanded breakdown.
class _InvoiceBalanceRow extends StatelessWidget {
  const _InvoiceBalanceRow({required this.item});

  final InvoiceBalanceItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPaid = item.balance <= 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPaid ? const Color(0xFF4CAF50) : const Color(0xFFFFA726),
            ),
          ),
          const SizedBox(width: 8),
          // Description
          Expanded(
            child: Text(
              item.description,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Amount / balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtCurrency(item.amount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
              if (!isPaid)
                Text(
                  '${fmtCurrency(item.balance)} due',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
