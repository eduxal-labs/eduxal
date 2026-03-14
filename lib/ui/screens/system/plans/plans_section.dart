import 'dart:async';
import 'dart:convert';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/plan_features.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_filter_toolbar.dart';
import '../../../widgets/edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlansSection — standalone plans management widget
// ─────────────────────────────────────────────────────────────────────────────

/// Full plans management UI: reactive list of plans, create plan sheet,
/// plan detail/edit sheet.
///
/// Accepts [SystemPermissions] to gate create/edit/delete actions.
/// Can be used as tab content in the system dashboard or embedded in
/// the settings screen.
class PlansSection extends StatefulWidget {
  const PlansSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<PlansSection> createState() => _PlansSectionState();
}

class _PlansSectionState extends State<PlansSection> {
  // ── Search & filter state ──────────────────────────────────────────────────

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchVisible = false;
  bool _filterVisible = false;
  PlanStatus? _statusFilter;
  Timer? _debounce;

  SystemPermissions get permissions => widget.permissions;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchCtrl.clear();
        _searchQuery = '';
      }
    });
  }

  void _toggleFilters() {
    setState(() => _filterVisible = !_filterVisible);
  }

  // ── Filtering logic ────────────────────────────────────────────────────────

  List<Plan> _applyFilters(List<Plan> all) {
    var plans = all
        .where(
          (p) => permissions.canSeeDeleted || p.status != PlanStatus.deleted,
        )
        .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      plans = plans.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    if (_statusFilter != null) {
      plans = plans.where((p) => p.status == _statusFilter).toList();
    }

    return plans;
  }

  List<EduFilterChipData> _buildFilterChips() {
    final statuses = [
      PlanStatus.active,
      PlanStatus.suspended,
      if (permissions.canSeeDeleted) PlanStatus.deleted,
    ];

    return statuses.map((s) {
      final label = switch (s) {
        PlanStatus.active => 'Active',
        PlanStatus.suspended => 'Suspended',
        PlanStatus.deleted => 'Deleted',
        _ => s.name,
      };
      return EduFilterChipData(
        label: label,
        isSelected: _statusFilter == s,
        onTap: () =>
            setState(() => _statusFilter = _statusFilter == s ? null : s),
        activeColor: switch (s) {
          PlanStatus.active => AppTheme.statusActive,
          PlanStatus.suspended => AppTheme.statusSuspended,
          PlanStatus.deleted => AppTheme.statusDeleted,
          _ => null,
        },
      );
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<Plan>>(
          stream: plansDao.watchAllPlans(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              );
            }

            final plans = _applyFilters(snapshot.data!);

            return EduDataTable<Plan>(
              items: plans,
              emptyIcon: Icons.credit_card_outlined,
              emptyTitle: 'No plans yet',
              emptySubtitle: 'Create a subscription plan to get started.',
              onItemTap: (plan) => _openPlanDetail(context, plan),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              // ── Search & filters ───────────────────────────────────────
              searchController: _searchCtrl,
              searchHint: 'Search plans…',
              onSearchChanged: (_) {},
              showSearch: _searchVisible,
              onToggleSearch: _toggleSearch,
              filters: _buildFilterChips(),
              showFilters: _filterVisible,
              onToggleFilters: _toggleFilters,
              // ── Actions ────────────────────────────────────────────────
              actions: (plan) => [
                EduDataTableAction<Plan>(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: (p) => _openPlanDetail(context, p),
                ),
                if (plan.status != PlanStatus.deleted &&
                    permissions.can(Resource.plans, Action.delete))
                  EduDataTableAction<Plan>(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    isDestructive: true,
                    onTap: (p) => _deletePlan(context, p),
                  ),
                if (plan.status == PlanStatus.deleted &&
                    permissions.canSeeDeleted)
                  EduDataTableAction<Plan>(
                    icon: Icons.delete_forever_rounded,
                    label: 'Purge',
                    isDestructive: true,
                    onTap: (p) => _purgePlan(context, p),
                  ),
              ],
              columns: const [
                EduDataTableColumn(label: 'Plan', flex: 3),
                EduDataTableColumn(label: 'Status', flex: 1),
              ],
              cellBuilder: (context, plan, index, isHovered) {
                final cs = Theme.of(context).colorScheme;
                return switch (index) {
                  0 => _PlanIdentityCell(plan: plan),
                  1 => _PlanStatusBadge(status: plan.status, cs: cs),
                  _ => const SizedBox.shrink(),
                };
              },
            );
          },
        ),
        // ── Inline FAB ─────────────────────────────────────────────────────
        if (permissions.can(Resource.plans, Action.create))
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'fab_plans',
              backgroundColor: AppTheme.statusActive,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onPressed: () => openCreatePlan(context, permissions),
              tooltip: 'New Plan',
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _deletePlan(BuildContext context, Plan plan) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    try {
      await plansDao.updatePlanStatus(
        plan.id,
        PlanStatus.deleted,
        accountId: accountId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete plan: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _purgePlan(BuildContext context, Plan plan) async {
    final confirmed = await _showPurgeDialog(context, plan.name);
    if (!confirmed) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    try {
      await plansDao.purgePlan(plan.id, accountId: accountId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to purge plan: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openPlanDetail(BuildContext context, Plan plan) {
    showEduSheet(
      context: context,
      builder: (_) => _PlanDetailSheet(plan: plan, permissions: permissions),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan row — data-table row content
// ─────────────────────────────────────────────────────────────────────────────

class _PlanIdentityCell extends StatelessWidget {
  const _PlanIdentityCell({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Parse grade level label.
    final levelText = gradeLabel(plan.levels);

    // Parse grade count.
    int gradeCount = 0;
    final levelsVal = plan.levels;
    if (levelsVal != 0) {
      for (int i = 0; i < 32; i++) {
        if ((levelsVal >> i) & 1 == 1) gradeCount++;
      }
    }

    return Row(
      children: [
        // ── Plan icon ────────────────────────────────────────────────────
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          ),
          child: Icon(
            Icons.credit_card_outlined,
            size: 16,
            color: cs.primary.withValues(alpha: isDark ? 0.85 : 0.7),
          ),
        ),
        const SizedBox(width: 12),

        // ── Name + price ─────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                plan.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'KES ${plan.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // ── Grade count badge ────────────────────────────────────────────
        if (gradeCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              border: Border.all(
                color: isDark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: 1,
              ),
            ),
            child: Text(
              levelText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan status badge — compact inline chip
// ─────────────────────────────────────────────────────────────────────────────

class _PlanStatusBadge extends StatelessWidget {
  const _PlanStatusBadge({required this.status, required this.cs});

  final PlanStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PlanStatus.active => ('Active', const Color(0xFF26A69A)),
      PlanStatus.pending => ('Pending', cs.onSurfaceVariant),
      PlanStatus.suspended => ('Suspended', const Color(0xFFFF8F00)),
      PlanStatus.deleted => ('Deleted', cs.error),
    };
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: color.withValues(alpha: isDark ? 0.9 : 0.85),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Opens the create plan bottom sheet. Exposed as a top-level function
/// so that both [PlansSection] and external callers (e.g. FAB actions)
/// can invoke it without needing a [PlansSection] instance.
void openCreatePlan(BuildContext context, SystemPermissions permissions) {
  showEduSheet(
    context: context,
    builder: (_) => _CreatePlanSheet(permissions: permissions),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.permissions,
    required this.onTap,
  });

  final Plan plan;
  final SystemPermissions permissions;
  final VoidCallback onTap;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _actioning = false;

  Future<void> _updateStatus(PlanStatus newStatus) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _actioning = true);
    try {
      await plansDao.updatePlanStatus(
        widget.plan.id,
        newStatus,
        accountId: accountId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _purge() async {
    final plan = widget.plan;
    final confirmed = await _showPurgeDialog(context, plan.name);
    if (!confirmed || !mounted) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _actioning = true);
    try {
      await plansDao.purgePlan(plan.id, accountId: accountId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to purge plan: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final permissions = widget.permissions;
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Accent colour derived from status.
    final accentColor = switch (plan.status) {
      PlanStatus.active => const Color(0xFF26A69A),
      PlanStatus.pending => cs.onSurfaceVariant,
      PlanStatus.suspended => const Color(0xFFFF8F00),
      PlanStatus.deleted => cs.error,
    };

    // Parse feature count.
    int featureCount = 0;
    final featuresJson = plan.features;
    if (featuresJson != null) {
      try {
        final decoded = jsonDecode(featuresJson);
        if (decoded is Map) featureCount = decoded.length;
      } catch (_) {}
    }

    final levelText = gradeLabel(plan.levels);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(
            color: isDark
                ? cs.outlineVariant.withValues(alpha: 0.35)
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: icon + name + status ────────────────────────
                Row(
                  children: [
                    // Plan icon with accent tint.
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.14 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      ),
                      child: Icon(
                        Icons.credit_card_outlined,
                        size: 17,
                        color: accentColor.withValues(
                          alpha: isDark ? 0.85 : 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PlanStatusChip(status: plan.status, cs: cs),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Price ────────────────────────────────────────────────
                Text(
                  'KES ${plan.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                // ── Metadata chips row ───────────────────────────────────
                Row(
                  children: [
                    // Grade levels chip.
                    Flexible(
                      child: _MetaChip(
                        icon: Icons.school_outlined,
                        label: levelText,
                        cs: cs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Feature count chip.
                    _MetaChip(
                      icon: Icons.check_circle_outline_rounded,
                      label:
                          '$featureCount ${featureCount == 1 ? 'feature' : 'features'}',
                      cs: cs,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ],
                ),

                // ── Status action buttons ────────────────────────────────
                if (permissions.can(Resource.plans, Action.update) ||
                    (plan.status == PlanStatus.deleted &&
                        permissions.canSeeDeleted)) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (_actioning)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.primary,
                          ),
                        )
                      else ...[
                        if (plan.status == PlanStatus.pending ||
                            plan.status == PlanStatus.suspended)
                          _CardActionButton(
                            icon: Icons.play_arrow_rounded,
                            tooltip: 'Activate',
                            color: const Color(0xFF4CAF50),
                            onTap: () => _updateStatus(PlanStatus.active),
                            cs: cs,
                          ),
                        if (plan.status == PlanStatus.active)
                          _CardActionButton(
                            icon: Icons.pause_rounded,
                            tooltip: 'Suspend',
                            color: const Color(0xFFFF8F00),
                            onTap: () => _updateStatus(PlanStatus.suspended),
                            cs: cs,
                          ),
                        if (plan.status == PlanStatus.deleted)
                          _CardActionButton(
                            icon: Icons.restore_rounded,
                            tooltip: 'Restore',
                            color: const Color(0xFF26A69A),
                            onTap: () => _updateStatus(PlanStatus.pending),
                            cs: cs,
                          ),
                        if (plan.status != PlanStatus.deleted &&
                            permissions.can(Resource.plans, Action.delete))
                          _CardActionButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete',
                            color: cs.error,
                            onTap: () => _updateStatus(PlanStatus.deleted),
                            cs: cs,
                          ),
                        if (plan.status == PlanStatus.deleted &&
                            permissions.canSeeDeleted)
                          _CardActionButton(
                            icon: Icons.delete_forever_rounded,
                            tooltip: 'Purge',
                            color: cs.error,
                            onTap: _purge,
                            cs: cs,
                          ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Metadata chip — small icon + label inline badge
// ─────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.cs});

  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan status chip
// ─────────────────────────────────────────────────────────────────────────────

class _PlanStatusChip extends StatelessWidget {
  const _PlanStatusChip({required this.status, required this.cs});

  final PlanStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final (label, color) = switch (status) {
      PlanStatus.pending => ('Pending', cs.onSurfaceVariant),
      PlanStatus.active => ('Active', const Color(0xFF26A69A)),
      PlanStatus.suspended => ('Suspended', const Color(0xFFFF8F00)),
      PlanStatus.deleted => ('Deleted', cs.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isDark ? color.withValues(alpha: 0.95) : color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade level picker — expandable CBC level group tree
// ─────────────────────────────────────────────────────────────────────────────

class _GradeLevelPicker extends StatefulWidget {
  const _GradeLevelPicker({
    required this.selectedLevels,
    required this.onLevelToggled,
    required this.cs,
  });

  final Set<GradeLevel> selectedLevels;
  final void Function(GradeLevel level) onLevelToggled;
  final ColorScheme cs;

  @override
  State<_GradeLevelPicker> createState() => _GradeLevelPickerState();
}

class _GradeLevelPickerState extends State<_GradeLevelPicker> {
  final Set<int> _expandedGroups = {};

  void _toggleGroup(int index) {
    setState(() {
      if (_expandedGroups.contains(index)) {
        _expandedGroups.remove(index);
      } else {
        _expandedGroups.add(index);
      }
    });
  }

  void _toggleAllInGroup(GradeLevelGroup group) {
    final allSelected = group.levels.every(widget.selectedLevels.contains);
    if (allSelected) {
      for (final level in group.levels) {
        if (widget.selectedLevels.contains(level)) {
          widget.onLevelToggled(level);
        }
      }
    } else {
      for (final level in group.levels) {
        if (!widget.selectedLevels.contains(level)) {
          widget.onLevelToggled(level);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kCbcGroups.length; i++) ...[
          _buildGroupHeader(cs, isDark, i, kCbcGroups[i]),
          _buildGroupChildren(cs, isDark, i, kCbcGroups[i]),
          if (i < kCbcGroups.length - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.6),
            ),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(
    ColorScheme cs,
    bool isDark,
    int index,
    GradeLevelGroup group,
  ) {
    final selectedCount = group.levels
        .where(widget.selectedLevels.contains)
        .length;
    final allSelected = selectedCount == group.levels.length;
    final someSelected = selectedCount > 0 && !allSelected;
    final expanded = _expandedGroups.contains(index);

    return InkWell(
      onTap: () => _toggleGroup(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Tri-state checkbox.
            GestureDetector(
              onTap: () => _toggleAllInGroup(group),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: allSelected
                          ? cs.primary
                          : someSelected
                          ? cs.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: allSelected || someSelected
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: allSelected
                        ? Icon(Icons.check, size: 13, color: cs.onPrimary)
                        : someSelected
                        ? Icon(Icons.remove, size: 13, color: cs.primary)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Group label.
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            // Count badge.
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '$selectedCount/${group.levels.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            // Chevron.
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChildren(
    ColorScheme cs,
    bool isDark,
    int index,
    GradeLevelGroup group,
  ) {
    final expanded = _expandedGroups.contains(index);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: expanded
          ? Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.only(left: 24),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var j = 0; j < group.levels.length; j++) ...[
                    _buildGradeRow(cs, group.levels[j]),
                    if (j < group.levels.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 38,
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                  ],
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildGradeRow(ColorScheme cs, GradeLevel level) {
    final selected = widget.selectedLevels.contains(level);

    return InkWell(
      onTap: () => widget.onLevelToggled(level),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: selected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 11, color: cs.onPrimary)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              level.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: selected
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withValues(alpha: 0.8),
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            Text(
              level.description,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create plan sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePlanSheet extends StatefulWidget {
  const _CreatePlanSheet({required this.permissions});

  final SystemPermissions permissions;

  @override
  State<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<_CreatePlanSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _nameError;
  String? _amountError;
  String? _submitError;
  bool _submitting = false;

  /// Selected grade levels — bitmask built from toggled [GradeLevel] values.
  final Set<GradeLevel> _selectedLevels = {};

  /// Feature toggles — keyed by feature key from [kPlanFeatures].
  final Map<String, bool> _features = {
    for (final f in kPlanFeatures) f.key: false,
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _levelsBitmask {
    var mask = 0;
    for (final level in _selectedLevels) {
      mask |= level.mask;
    }
    return mask;
  }

  String _serialiseFeatures() {
    return jsonEncode(_features);
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();

    String? nameErr;
    String? amountErr;

    if (name.length < 2) {
      nameErr = 'Plan name must be at least 2 characters.';
    }

    if (amountStr.isEmpty) {
      amountErr = 'Amount is required.';
    } else {
      final parsed = double.tryParse(amountStr);
      if (parsed == null || parsed < 0) {
        amountErr = 'Enter a valid amount.';
      }
    }

    setState(() {
      _nameError = nameErr;
      _amountError = amountErr;
      _submitError = null;
    });

    return nameErr == null && amountErr == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final id = ObjectId().oid;
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final amount = double.parse(_amountCtrl.text.trim());

      await plansDao.createPlan(
        PlansCompanion(
          id: Value(id),
          name: Value(name),
          description: Value(desc.isEmpty ? null : desc),
          amount: Value(amount),
          levels: Value(_levelsBitmask),
          features: Value(_serialiseFeatures()),
          status: const Value(PlanStatus.pending),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Plan '$name' created."),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitError = 'Failed to create plan: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildSectionHeader(ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 1.1,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(cs: cs),
          _SheetHeader(
            title: 'Create Plan',
            submitting: _submitting,
            onSubmit: _submit,
            cs: cs,
          ),
          Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Error banner ──────────────────────────────────
                  if (_submitError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(AppTheme.kRadius),
                        border: Border.all(
                          color: cs.error.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _submitError!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Card 1 — Basic Info ───────────────────────────
                  _buildSectionHeader(cs, 'Basic Info'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormLabel(label: 'Name', cs: cs),
                        const SizedBox(height: 6),
                        _FormTextField(
                          controller: _nameCtrl,
                          hint: 'Plan name',
                          error: _nameError,
                          cs: cs,
                        ),
                        const SizedBox(height: 12),
                        _FormLabel(label: 'Description', cs: cs),
                        const SizedBox(height: 6),
                        _FormTextField(
                          controller: _descCtrl,
                          hint: 'Optional',
                          cs: cs,
                        ),
                        const SizedBox(height: 12),
                        _FormLabel(label: 'Amount', cs: cs),
                        const SizedBox(height: 6),
                        _FormTextField(
                          controller: _amountCtrl,
                          hint: '0',
                          error: _amountError,
                          cs: cs,
                          keyboardType: TextInputType.number,
                          prefixText: 'KES  ',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Card 2 — Grade Levels ─────────────────────────
                  _buildSectionHeader(cs, 'Grade Levels'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: _GradeLevelPicker(
                      selectedLevels: _selectedLevels,
                      onLevelToggled: (level) => setState(() {
                        if (_selectedLevels.contains(level)) {
                          _selectedLevels.remove(level);
                        } else {
                          _selectedLevels.add(level);
                        }
                      }),
                      cs: cs,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Card 3 — Features ─────────────────────────────
                  _buildSectionHeader(cs, 'Features'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < kPlanFeatures.length; i++)
                          _FeatureToggleRow(
                            feature: kPlanFeatures[i],
                            enabled: _features[kPlanFeatures[i].key] == true,
                            isLast: i == kPlanFeatures.length - 1,
                            onTap: () => setState(() {
                              final key = kPlanFeatures[i].key;
                              _features[key] = !(_features[key] == true);
                            }),
                            cs: cs,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan detail / edit sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PlanDetailSheet extends StatefulWidget {
  const _PlanDetailSheet({required this.plan, required this.permissions});

  final Plan plan;
  final SystemPermissions permissions;

  @override
  State<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends State<_PlanDetailSheet> {
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;
  bool _purging = false;
  bool _isDirty = false;
  String? _saveError;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late Set<GradeLevel> _editLevels;
  late Map<String, bool> _editFeatures;
  PlanStatus? _editStatus;

  // ── Dirty-tracking helpers ────────────────────────────────────────────────

  bool _computeDirty() {
    final p = widget.plan;
    if (_nameCtrl.text.trim() != p.name) return true;
    if (_descCtrl.text.trim() != (p.description ?? '')) return true;
    if (_amountCtrl.text.trim() != p.amount.toStringAsFixed(0)) return true;
    if (_editStatus != p.status) return true;
    if (_levelsBitmask != p.levels) return true;
    final originalFeatures = _parseFeatures(p.features);
    for (final key in _editFeatures.keys) {
      if (_editFeatures[key] != originalFeatures[key]) return true;
    }
    return false;
  }

  void _onTextChanged() {
    final dirty = _computeDirty();
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.plan.name);
    _descCtrl = TextEditingController(text: widget.plan.description ?? '');
    _amountCtrl = TextEditingController(
      text: widget.plan.amount.toStringAsFixed(0),
    );
    _editLevels = _parseLevels(widget.plan.levels);
    _editFeatures = _parseFeatures(widget.plan.features);
    _editStatus = widget.plan.status;

    _nameCtrl.addListener(_onTextChanged);
    _descCtrl.addListener(_onTextChanged);
    _amountCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  static Set<GradeLevel> _parseLevels(int mask) {
    final set = <GradeLevel>{};
    for (final level in GradeLevel.values) {
      if (mask & level.mask != 0) set.add(level);
    }
    return set;
  }

  static Map<String, bool> _parseFeatures(String? json) {
    if (json == null || json.isEmpty) {
      return {for (final f in kPlanFeatures) f.key: false};
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return {for (final f in kPlanFeatures) f.key: decoded[f.key] == true};
      }
    } catch (_) {}
    return {for (final f in kPlanFeatures) f.key: false};
  }

  int get _levelsBitmask {
    var mask = 0;
    for (final level in _editLevels) {
      mask |= level.mask;
    }
    return mask;
  }

  void _startEditing(Plan current) {
    setState(() {
      _nameCtrl.text = current.name;
      _descCtrl.text = current.description ?? '';
      _amountCtrl.text = current.amount.toStringAsFixed(0);
      _editLevels = _parseLevels(current.levels);
      _editFeatures = _parseFeatures(current.features);
      _editStatus = current.status;
      _editing = true;
      _isDirty = false;
      _saveError = null;
    });
  }

  Future<void> _save([Plan? currentOverride]) async {
    final current = currentOverride ?? widget.plan;
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _saveError = 'Plan name must be at least 2 characters.');
      return;
    }

    final amountStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount < 0) {
      setState(() => _saveError = 'Enter a valid amount.');
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final desc = _descCtrl.text.trim();

      await plansDao.updatePlan(
        current.id,
        PlansCompanion(
          name: Value(name),
          description: Value(desc.isEmpty ? null : desc),
          amount: Value(amount),
          levels: Value(_levelsBitmask),
          features: Value(jsonEncode(_editFeatures)),
          status: Value(_editStatus!),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      if (mounted) {
        setState(() {
          _editing = false;
          _isDirty = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Plan current) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete plan?',
      message:
          'Mark "${current.name}" as deleted? '
          'It can be restored or purged later.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _deleting = true);

    try {
      await plansDao.updatePlanStatus(
        current.id,
        PlanStatus.deleted,
        accountId: accountId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan "${current.name}" deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete plan: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmPurge(Plan current) async {
    final confirmed = await _showPurgeDialog(context, current.name);
    if (!confirmed || !mounted) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _purging = true);

    try {
      await plansDao.purgePlan(current.id, accountId: accountId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan "${current.name}" permanently deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to purge plan: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final plan = widget.plan;
    final canEdit = widget.permissions.can(Resource.plans, Action.update);
    final canDelete = widget.permissions.can(Resource.plans, Action.delete);

    final accentColor = switch (plan.status) {
      PlanStatus.active => const Color(0xFF26A69A),
      PlanStatus.pending => cs.onSurfaceVariant,
      PlanStatus.suspended => const Color(0xFFFF8F00),
      PlanStatus.deleted => cs.error,
    };

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(cs: cs),

          // ── Action bar (thin, right-aligned) ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                if (_editing) ...[
                  TextButton(
                    onPressed: () => setState(() {
                      _editing = false;
                      _isDirty = false;
                      _saveError = null;
                    }),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AnimatedSaveButton(
                    isDirty: _isDirty,
                    isSaving: _saving,
                    onSave: (_isDirty && !_saving) ? _save : null,
                  ),
                ] else ...[
                  // Purge — only for deleted plans, super users only
                  if (plan.status == PlanStatus.deleted &&
                      widget.permissions.canSeeDeleted)
                    IconButton(
                      icon: _purging
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: cs.error,
                              ),
                            )
                          : Icon(
                              Icons.delete_forever_rounded,
                              size: 19,
                              color: cs.error.withValues(alpha: 0.8),
                            ),
                      onPressed: _purging ? null : () => _confirmPurge(plan),
                      tooltip: 'Purge permanently',
                      visualDensity: VisualDensity.compact,
                    ),
                  // Soft delete — for non-deleted plans
                  if (plan.status != PlanStatus.deleted && canDelete)
                    IconButton(
                      icon: _deleting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: cs.error,
                              ),
                            )
                          : Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: cs.error.withValues(alpha: 0.65),
                            ),
                      onPressed: _deleting ? null : () => _confirmDelete(plan),
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                    ),
                  if (canEdit)
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 19,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _startEditing(plan),
                      tooltip: 'Edit',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ],
            ),
          ),

          // ── Hero header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent icon.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                  ),
                  child: Icon(
                    Icons.credit_card_outlined,
                    size: 20,
                    color: accentColor.withValues(alpha: isDark ? 0.85 : 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'KES ${plan.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _PlanStatusChip(status: plan.status, cs: cs),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: _editing
                  ? _PlanEditForm(
                      nameCtrl: _nameCtrl,
                      descCtrl: _descCtrl,
                      amountCtrl: _amountCtrl,
                      selectedLevels: _editLevels,
                      features: _editFeatures,
                      status: _editStatus!,
                      error: _saveError,
                      onLevelToggled: (level) => setState(() {
                        if (_editLevels.contains(level)) {
                          _editLevels.remove(level);
                        } else {
                          _editLevels.add(level);
                        }
                        _isDirty = _computeDirty();
                      }),
                      onFeatureToggled: (key, value) => setState(() {
                        _editFeatures[key] = value;
                        _isDirty = _computeDirty();
                      }),
                      onStatusChanged: (s) => setState(() {
                        _editStatus = s;
                        _isDirty = _computeDirty();
                      }),
                      cs: cs,
                    )
                  : _PlanViewBody(plan: plan, cs: cs),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan view body (read-only) — card-based sectioned layout
// ─────────────────────────────────────────────────────────────────────────────

class _PlanViewBody extends StatelessWidget {
  const _PlanViewBody({required this.plan, required this.cs});

  final Plan plan;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final features = _parseFeatures(plan.features);
    final enabledFeatures = kPlanFeatures
        .where((f) => features[f.key] == true)
        .toList();
    final disabledFeatures = kPlanFeatures
        .where((f) => features[f.key] != true)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Description card (only if present) ───────────────────────────
        if (plan.description != null && plan.description!.isNotEmpty) ...[
          _DetailCard(
            cs: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailSectionLabel(label: 'DESCRIPTION', cs: cs),
                const SizedBox(height: 8),
                Text(
                  plan.description!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.85),
                    height: 1.5,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Grade levels card ────────────────────────────────────────────
        _DetailCard(
          cs: cs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailSectionLabel(label: 'GRADE LEVELS', cs: cs),
              const SizedBox(height: 10),
              plan.levels == 0
                  ? Text(
                      'No levels selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: GradeLevel.values
                          .where((l) => plan.levels & l.mask != 0)
                          .map((level) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(
                                  alpha: isDark ? 0.12 : 0.07,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: cs.primary.withValues(
                                    alpha: isDark ? 0.3 : 0.18,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                level.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.primary.withValues(
                                    alpha: isDark ? 0.9 : 0.8,
                                  ),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Included features ────────────────────────────────────────────
        Row(
          children: [
            _DetailSectionLabel(label: 'INCLUDED', cs: cs),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF26A69A,
                ).withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(
                    0xFF26A69A,
                  ).withValues(alpha: isDark ? 0.35 : 0.22),
                  width: 1,
                ),
              ),
              child: Text(
                '${enabledFeatures.length}/${kPlanFeatures.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(
                    0xFF26A69A,
                  ).withValues(alpha: isDark ? 0.9 : 0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (enabledFeatures.isEmpty)
          _DetailCard(
            cs: cs,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'No features included',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          )
        else
          ...enabledFeatures.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _IncludedFeatureTile(feature: f, cs: cs),
            ),
          ),

        // ── Not included features ────────────────────────────────────────
        if (disabledFeatures.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DetailSectionLabel(label: 'NOT INCLUDED', cs: cs),
          const SizedBox(height: 10),
          ...disabledFeatures.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DisabledFeatureTile(feature: f, cs: cs),
            ),
          ),
        ],
      ],
    );
  }

  static Map<String, bool> _parseFeatures(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) => MapEntry(k, v == true));
      }
    } catch (_) {}
    return {};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail card — elevated container for view-mode sections
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.cs, required this.child});

  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: isDark ? 0 : 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(
            color: isDark
                ? cs.outlineVariant.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail section label — thin uppercase heading inside cards
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSectionLabel extends StatelessWidget {
  const _DetailSectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Included feature tile — mini-card with left accent bar
// ─────────────────────────────────────────────────────────────────────────────

class _IncludedFeatureTile extends StatelessWidget {
  const _IncludedFeatureTile({required this.feature, required this.cs});

  final PlanFeature feature;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    const accent = Color(0xFF26A69A);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Row(
          children: [
            // Left accent bar.
            Container(
              width: 3,
              height: 56,
              color: accent.withValues(alpha: isDark ? 0.7 : 0.55),
            ),
            const SizedBox(width: 12),
            // Check icon.
            Icon(
              Icons.check_rounded,
              size: 15,
              color: accent.withValues(alpha: isDark ? 0.85 : 0.7),
            ),
            const SizedBox(width: 10),
            // Title + description.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feature.description,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        height: 1.35,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disabled feature tile — muted inline row
// ─────────────────────────────────────────────────────────────────────────────

class _DisabledFeatureTile extends StatelessWidget {
  const _DisabledFeatureTile({required this.feature, required this.cs});

  final PlanFeature feature;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.remove_rounded,
          size: 14,
          color: cs.onSurfaceVariant.withValues(alpha: 0.25),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            feature.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan edit form
// ─────────────────────────────────────────────────────────────────────────────

class _PlanEditForm extends StatelessWidget {
  const _PlanEditForm({
    required this.nameCtrl,
    required this.descCtrl,
    required this.amountCtrl,
    required this.selectedLevels,
    required this.features,
    required this.status,
    required this.error,
    required this.onLevelToggled,
    required this.onFeatureToggled,
    required this.onStatusChanged,
    required this.cs,
  });

  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController amountCtrl;
  final Set<GradeLevel> selectedLevels;
  final Map<String, bool> features;
  final PlanStatus status;
  final String? error;
  final void Function(GradeLevel) onLevelToggled;
  final void Function(String key, bool value) onFeatureToggled;
  final void Function(PlanStatus) onStatusChanged;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          _ErrorBanner(message: error!, cs: cs),
          const SizedBox(height: 12),
        ],

        // Name.
        _FormLabel(label: 'Name', cs: cs),
        const SizedBox(height: 6),
        _FormTextField(controller: nameCtrl, hint: 'Plan name', cs: cs),
        const SizedBox(height: 12),

        // Description.
        _FormLabel(label: 'Description', cs: cs),
        const SizedBox(height: 6),
        _FormTextField(controller: descCtrl, hint: 'Optional', cs: cs),
        const SizedBox(height: 12),

        // Amount.
        _FormLabel(label: 'Amount (KES)', cs: cs),
        const SizedBox(height: 6),
        _FormTextField(
          controller: amountCtrl,
          hint: '0',
          cs: cs,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        // Status action buttons — contextual transitions only.
        _FormLabel(label: 'Status', cs: cs),
        const SizedBox(height: 8),
        _PlanStatusActions(status: status, onUpdate: onStatusChanged, cs: cs),
        const SizedBox(height: 20),

        // Level selector.
        _FormLabel(label: 'Grade Levels', cs: cs),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(color: cs.outlineVariant, width: 1),
          ),
          child: _GradeLevelPicker(
            selectedLevels: selectedLevels,
            onLevelToggled: onLevelToggled,
            cs: cs,
          ),
        ),
        const SizedBox(height: 20),

        // Feature toggles.
        _FormLabel(label: 'Features', cs: cs),
        const SizedBox(height: 8),
        ...kPlanFeatures.asMap().entries.map((entry) {
          final i = entry.key;
          final feature = entry.value;
          final enabled = features[feature.key] == true;
          return _FeatureToggleRow(
            feature: feature,
            enabled: enabled,
            isLast: i == kPlanFeatures.length - 1,
            onTap: () => onFeatureToggled(feature.key, !enabled),
            cs: cs,
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sheet / form widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.submitting,
    required this.onSubmit,
    required this.cs,
  });

  final String title;
  final bool submitting;
  final VoidCallback onSubmit;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
          ),
          TextButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.hint,
    required this.cs,
    this.error,
    this.keyboardType,
    this.prefixText,
  });

  final TextEditingController controller;
  final String hint;
  final ColorScheme cs;
  final String? error;
  final TextInputType? keyboardType;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: error != null
                    ? cs.error
                    : cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: error != null
                    ? cs.error
                    : cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: error != null ? cs.error : cs.primary,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.error,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature toggle row — dot indicator instead of Switch
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureToggleRow extends StatelessWidget {
  const _FeatureToggleRow({
    required this.feature,
    required this.enabled,
    required this.isLast,
    required this.onTap,
    required this.cs,
  });

  final PlanFeature feature;
  final bool enabled;
  final bool isLast;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature.description,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Dot indicator
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: enabled
                        ? const Color(0xFF4CAF50)
                        : cs.onSurfaceVariant.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card action button — compact icon button for plan card status actions
// ─────────────────────────────────────────────────────────────────────────────

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan status action buttons — contextual transitions (edit form)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanStatusActions extends StatelessWidget {
  const _PlanStatusActions({
    required this.status,
    required this.onUpdate,
    required this.cs,
  });

  final PlanStatus status;
  final void Function(PlanStatus) onUpdate;
  final ColorScheme cs;

  static const _green = Color(0xFF4CAF50);
  static const _amber = Color(0xFFFF8F00);

  @override
  Widget build(BuildContext context) {
    final actions = _actionsFor(status);
    if (actions.isEmpty) {
      return Text(
        status.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        return SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: () => onUpdate(action.target),
            style: OutlinedButton.styleFrom(
              foregroundColor: action.color,
              side: BorderSide(color: action.color.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: Text(action.label),
          ),
        );
      }).toList(),
    );
  }

  List<({PlanStatus target, String label, Color color})> _actionsFor(
    PlanStatus s,
  ) {
    return switch (s) {
      PlanStatus.pending => [
        (target: PlanStatus.active, label: 'Activate', color: _green),
        (target: PlanStatus.suspended, label: 'Suspend', color: _amber),
      ],
      PlanStatus.active => [
        (target: PlanStatus.suspended, label: 'Suspend', color: _amber),
      ],
      PlanStatus.suspended => [
        (target: PlanStatus.active, label: 'Reactivate', color: _green),
      ],
      PlanStatus.deleted => [],
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Purge confirmation dialog — requires typed "DELETE" confirmation
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a serious purge confirmation dialog that requires the user to type
/// "DELETE" before the confirm button is enabled.
///
/// Returns `true` if the user confirmed, `false` otherwise.
Future<bool> _showPurgeDialog(BuildContext context, String itemName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PurgeConfirmDialog(itemName: itemName),
  );
  return confirmed == true;
}

class _PurgeConfirmDialog extends StatefulWidget {
  const _PurgeConfirmDialog({required this.itemName});
  final String itemName;

  @override
  State<_PurgeConfirmDialog> createState() => _PurgeConfirmDialogState();
}

class _PurgeConfirmDialogState extends State<_PurgeConfirmDialog> {
  final _ctrl = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim() == 'DELETE';
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Text(
            'Permanently delete?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${widget.itemName}" will be permanently removed and cannot be recovered.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Type DELETE to confirm',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'DELETE',
              hintStyle: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: cs.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: cs.error, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            'Purge',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _confirmed
                  ? cs.error
                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.cs});

  final String message;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onErrorContainer,
        ),
      ),
    );
  }
}
