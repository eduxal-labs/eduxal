import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../services/authorization_service.dart';
import '../../../../core/formatters.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_empty_state.dart';
import '../../../widgets/edu_tab_bar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// FeeDetailPage — grade-tabbed fee detail view
// ═════════════════════════════════════════════════════════════════════════════

/// Shows details for a group of [FeeWithStats] records that share the same
/// [feeTitle], one per grade. Grades are presented as tabs (like streams in
/// the academics grade_detail_page).
///
/// The page subscribes to [FinanceDao.watchFeesWithStats] for reactive
/// updates. If the filtered list becomes empty (all grades deleted), the
/// page automatically pops.
class FeeDetailPage extends StatefulWidget {
  const FeeDetailPage({
    super.key,
    required this.feeTitle,
    required this.fees,
    required this.schoolContext,
    required this.dao,
  });

  /// The shared fee title used to filter the stream.
  final String feeTitle;

  /// Initial fee records (one per grade) — used to seed tab creation before
  /// the first stream emission.
  final List<FeeWithStats> fees;

  final SchoolContext schoolContext;
  final FinanceDao dao;

  @override
  State<FeeDetailPage> createState() => _FeeDetailPageState();
}

class _FeeDetailPageState extends State<FeeDetailPage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  late TabController _tabController;
  late List<FeeWithStats> _sortedFees;

  /// Whether we've already scheduled a pop because the fee list became empty.
  bool _popping = false;

  // ── Entrance animation ─────────────────────────────────────────────────────

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Sort fees by grade ascending.
    _sortedFees = List<FeeWithStats>.from(widget.fees)
      ..sort((a, b) => a.fee.grade.compareTo(b.fee.grade));

    _tabController = TabController(length: _sortedFees.length, vsync: this);

    // Entrance animation.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _schoolId => widget.schoolContext.membership.school.id;

  bool get _canCreateFee {
    final entry = widget.schoolContext.currentEntry.value;
    return entry is OwnerEntry ||
        widget.schoolContext.permissions.can(Resource.fees, Action.create);
  }

  bool get _canDeleteFee {
    final entry = widget.schoolContext.currentEntry.value;
    return entry is OwnerEntry ||
        widget.schoolContext.permissions.can(Resource.fees, Action.delete);
  }

  // ── Tab reconstruction ─────────────────────────────────────────────────────

  /// Rebuilds the tab controller when the number of grades changes.
  void _rebuildTabs(List<FeeWithStats> newFees) {
    final oldIndex = _tabController.index;
    _tabController.dispose();

    _sortedFees = newFees;
    final newLength = newFees.length;
    final clampedIndex = oldIndex.clamp(0, newLength - 1);

    _tabController = TabController(
      length: newLength,
      initialIndex: clampedIndex,
      vsync: this,
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _generateInvoices(
    BuildContext context,
    FeeWithStats item,
  ) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    int counter = 0;
    try {
      final count = await widget.dao.generateInvoicesFromFee(
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
    } on PermissionException catch (e) {
      if (context.mounted) showPermissionDenied(context, e.reason);
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

  Future<void> _deleteFee(BuildContext context, FeeWithStats item) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final gradeLabel = _resolveGradeLabel(item.fee.grade);
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Fee',
      message:
          'Delete "${item.fee.title}" for $gradeLabel? '
          'This will not remove invoices already generated from this fee.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await widget.dao.deleteFee(id: item.fee.id, accountId: accountId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted fee for $gradeLabel'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // If this was the last grade, pop happens reactively via the stream.
    } on PermissionException catch (e) {
      if (context.mounted) showPermissionDenied(context, e.reason);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete fee: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final termCtx = ActiveTermProvider.read(context);
    final term = termCtx.currentTerm;

    // We need year/term to subscribe to the reactive stream.
    if (term == null) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: _buildAppBar(cs, null),
        body: const EduEmptyState(
          icon: Icons.calendar_today_outlined,
          title: 'No active term',
          subtitle: 'Select a term to view fee details.',
        ),
      );
    }

    return StreamBuilder<List<FeeWithStats>>(
      stream: widget.dao.watchFeesWithStats(
        schoolId: _schoolId,
        year: term.year,
        term: term.term,
      ),
      builder: (context, snap) {
        // Filter to only fees matching our title.
        List<FeeWithStats> filtered = [];
        if (snap.hasData) {
          filtered =
              snap.data!.where((f) => f.fee.title == widget.feeTitle).toList()
                ..sort((a, b) => a.fee.grade.compareTo(b.fee.grade));
        }

        // If the stream has emitted and the list is empty, pop back.
        if (snap.hasData && filtered.isEmpty && !_popping) {
          _popping = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return Scaffold(
            backgroundColor: cs.surfaceContainerLowest,
            appBar: _buildAppBar(cs, term),
            body: const SizedBox.shrink(),
          );
        }

        // While waiting for first emission, use the initial data.
        final fees = filtered.isNotEmpty ? filtered : _sortedFees;

        // Rebuild tabs if grade count changed.
        if (fees.length != _tabController.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _rebuildTabs(fees));
            }
          });
        } else {
          // Silently update the sorted list without rebuilding tabs.
          _sortedFees = fees;
        }

        final gradeTabs = fees
            .map((f) => EduTab(label: _resolveGradeLabel(f.fee.grade)))
            .toList();

        return Scaffold(
          backgroundColor: cs.surfaceContainerLowest,
          appBar: _buildAppBar(cs, term),
          body: SlideTransition(
            position: _slideUp,
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  // ── Grade tabs ─────────────────────────────────────────
                  if (fees.length > 1)
                    EduTabBar(controller: _tabController, tabs: gradeTabs),
                  if (fees.length == 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _resolveGradeLabel(fees.first.fee.grade),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),

                  // ── Tab content ────────────────────────────────────────
                  Expanded(
                    child: fees.length > 1
                        ? TabBarView(
                            controller: _tabController,
                            children: fees
                                .map(
                                  (f) => _GradeFeePage(
                                    item: f,
                                    dao: widget.dao,
                                    schoolId: _schoolId,
                                    cs: cs,
                                    isDark: isDark,
                                    canGenerateInvoices: _canCreateFee,
                                    canDelete: _canDeleteFee,
                                    onGenerateInvoices: () =>
                                        _generateInvoices(context, f),
                                    onDelete: () => _deleteFee(context, f),
                                  ),
                                )
                                .toList(),
                          )
                        : _GradeFeePage(
                            item: fees.first,
                            dao: widget.dao,
                            schoolId: _schoolId,
                            cs: cs,
                            isDark: isDark,
                            canGenerateInvoices: _canCreateFee,
                            canDelete: _canDeleteFee,
                            onGenerateInvoices: () =>
                                _generateInvoices(context, fees.first),
                            onDelete: () => _deleteFee(context, fees.first),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(ColorScheme cs, Term? term) {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.feeTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          if (term != null)
            Text(
              '${term.year} · Term ${term.term}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: cs.surface,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _GradeFeePage — content view for a single grade tab
// ═════════════════════════════════════════════════════════════════════════════

class _GradeFeePage extends StatelessWidget {
  const _GradeFeePage({
    required this.item,
    required this.dao,
    required this.schoolId,
    required this.cs,
    required this.isDark,
    required this.canGenerateInvoices,
    required this.canDelete,
    required this.onGenerateInvoices,
    required this.onDelete,
  });

  final FeeWithStats item;
  final FinanceDao dao;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;
  final bool canGenerateInvoices;
  final bool canDelete;
  final VoidCallback onGenerateInvoices;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fee = item.fee;
    final typeLabel = fee.mandatory ? 'Mandatory' : 'Optional';
    final typeColor = fee.mandatory ? cs.primary : cs.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Fee details card ───────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
                : cs.surface,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Amount row ───────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fmtCurrency(fee.amount),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fee amount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                AppTheme.tableRowDivider(isDark, cs),
                const SizedBox(height: 16),

                // ── Detail rows ──────────────────────────────────────
                if (fee.description.isNotEmpty) ...[
                  _DetailRow(
                    icon: Icons.description_outlined,
                    label: 'Description',
                    value: fee.description,
                    cs: cs,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                ],

                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Due date',
                  value: _fmtDateFromEpoch(fee.due.toInt()),
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _DetailRow(
                  icon: Icons.school_outlined,
                  label: 'Grade',
                  value: _resolveGradeLabel(fee.grade),
                  cs: cs,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Invoice count card ─────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
                : cs.surface,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.invoiceCount}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Invoice${item.invoiceCount == 1 ? '' : 's'} generated',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Enrolled student count (loaded async).
                _EnrolledCountBadge(
                  dao: dao,
                  schoolId: schoolId,
                  year: fee.year,
                  term: fee.term,
                  grade: fee.grade,
                  cs: cs,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Action buttons ─────────────────────────────────────────────
        if (canGenerateInvoices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: onGenerateInvoices,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Generate Invoices'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

        if (canDelete)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete Fee'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _DetailRow — label + value row with an icon
// ═════════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _EnrolledCountBadge — async-loaded enrolled student count
// ═════════════════════════════════════════════════════════════════════════════

class _EnrolledCountBadge extends StatefulWidget {
  const _EnrolledCountBadge({
    required this.dao,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.cs,
    required this.isDark,
  });

  final FinanceDao dao;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_EnrolledCountBadge> createState() => _EnrolledCountBadgeState();
}

class _EnrolledCountBadgeState extends State<_EnrolledCountBadge> {
  int? _enrolledCount;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void didUpdateWidget(covariant _EnrolledCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grade != widget.grade ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term) {
      _loadCount();
    }
  }

  Future<void> _loadCount() async {
    try {
      final count = await widget.dao.getEnrolledStudentCount(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
      );
      if (mounted) setState(() => _enrolledCount = count);
    } catch (_) {
      // Silently fail — the badge just won't show.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enrolledCount == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.cs.primary.withValues(alpha: widget.isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_enrolledCount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.cs.primary,
            ),
          ),
          Text(
            'enrolled',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: widget.cs.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Utility functions
// ═════════════════════════════════════════════════════════════════════════════

String _resolveGradeLabel(int grade) {
  return kCbcGradeLabels[grade] ??
      kEightFourFourGradeLabels[grade] ??
      'Grade $grade';
}

/// Thin adapter: epoch-seconds → formatted date via shared [fmtDateDt].
String _fmtDateFromEpoch(int epochSeconds) =>
    fmtDateDt(DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000));
