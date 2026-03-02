import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_indicator.dart';
import 'school_detail_screen.dart';

/// The Schools data section of the system dashboard.
///
/// Shows a reactive list of all schools from [SchoolsDao.watchAllSchools],
/// with client-side search (name / motto) and status filter.
///
/// On **mobile** this is the body of the Schools tab.
/// On **desktop** this is the content inside the Schools tab of the data area.
/// [onCreateTap] is provided on desktop only — on mobile the FAB handles it.
class SchoolsSection extends StatefulWidget {
  const SchoolsSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<SchoolsSection> createState() => _SchoolsSectionState();
}

class _SchoolsSectionState extends State<SchoolsSection> {
  // ── Filter state ───────────────────────────────────────────────────────────

  final _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<SchoolStatus> _statusFilter = {};
  bool _filterExpanded = false;
  final Set<String> _selectedIds = {};

  // ── Search debounce ────────────────────────────────────────────────────────

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<SchoolsData> _applyFilters(List<SchoolsData> all) {
    var list = all;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.motto?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_statusFilter.isNotEmpty) {
      list = list.where((s) => _statusFilter.contains(s.status)).toList();
    }

    return list;
  }

  bool get _hasActiveFilters => _statusFilter.isNotEmpty;

  void _clearFilters() => setState(() => _statusFilter.clear());

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _trashSchool(SchoolsData school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trash School'),
        content: Text(
          'Set ${school.name} to Deleted status? '
          'This is a soft delete — the record can be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await schoolsDao.updateSchoolStatus(
        school.id,
        SchoolStatus.deleted,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${school.name} moved to trash')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to trash school: $e')));
      }
    }
  }

  Future<void> _purgeSchool(SchoolsData school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purge School'),
        content: Text(
          'Permanently delete ${school.name}?\n\n'
          'This action is irreversible and will permanently remove this record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Purge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await schoolsDao.purgeSchool(school.id, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${school.name} permanently deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to purge school: $e')));
      }
    }
  }

  void _openDetail(SchoolsData school) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SchoolDetailScreen(school: school, permissions: widget.permissions),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<SchoolsData>>(
      stream: schoolsDao.watchAllSchools(),
      builder: (context, snapshot) {
        final allSchools = snapshot.data ?? [];
        final filtered = _applyFilters(allSchools);

        return Column(
          children: [
            // ── Toolbar ────────────────────────────────────────────────────
            if (_selectedIds.isNotEmpty)
              Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                color: cs.primaryContainer.withValues(
                  alpha: isDark ? 0.2 : 0.3,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _selectedIds.clear()),
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${_selectedIds.length} selected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        // TODO: Bulk delete
                      },
                      color: cs.error,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () {
                        // TODO: Bulk actions
                      },
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              )
            else
              _Toolbar(
                searchController: _searchController,
                filterExpanded: _filterExpanded,
                hasActiveFilters: _hasActiveFilters,
                onToggleFilter: () =>
                    setState(() => _filterExpanded = !_filterExpanded),
                cs: cs,
              ),

            // ── Filter panel ───────────────────────────────────────────────
            if (_filterExpanded && _selectedIds.isEmpty)
              _FilterPanel(
                statusFilter: _statusFilter,
                showDeleted: widget.permissions.canSeeDeleted,
                hasActiveFilters: _hasActiveFilters,
                onStatusToggle: (s) => setState(
                  () => _statusFilter.contains(s)
                      ? _statusFilter.remove(s)
                      : _statusFilter.add(s),
                ),
                onClear: _clearFilters,
                cs: cs,
              ),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : filtered.isEmpty
                  ? _EmptyState(
                      hasQuery: _searchQuery.isNotEmpty || _hasActiveFilters,
                      cs: cs,
                    )
                  : _SchoolList(
                      schools: filtered,
                      permissions: widget.permissions,
                      selectedIds: _selectedIds,
                      onTap: (s) {
                        if (_selectedIds.isNotEmpty) {
                          setState(() {
                            if (_selectedIds.contains(s.id)) {
                              _selectedIds.remove(s.id);
                            } else {
                              _selectedIds.add(s.id);
                            }
                          });
                        } else {
                          _openDetail(s);
                        }
                      },
                      onLongPress: (s) {
                        setState(() {
                          _selectedIds.add(s.id);
                        });
                      },
                      onToggleSelection: (s) {
                        setState(() {
                          if (_selectedIds.contains(s.id)) {
                            _selectedIds.remove(s.id);
                          } else {
                            _selectedIds.add(s.id);
                          }
                        });
                      },
                      onTrash: (s) => _trashSchool(s),
                      onPurge: (s) => _purgeSchool(s),
                      cs: cs,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.filterExpanded,
    required this.hasActiveFilters,
    required this.onToggleFilter,
    required this.cs,
  });

  final TextEditingController searchController;
  final bool filterExpanded;
  final bool hasActiveFilters;
  final VoidCallback onToggleFilter;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: searchController,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or motto…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide(color: cs.outlineVariant, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide(color: cs.primary, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter toggle.
          _ToolbarIcon(
            icon: hasActiveFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            active: filterExpanded || hasActiveFilters,
            onTap: onToggleFilter,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.10)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: active
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/*
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap, required this.cs});

  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.brandGreen,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_business_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Create school',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
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

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel
// ─────────────────────────────────────────────────────────────────────────────

*/
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.statusFilter,
    required this.showDeleted,
    required this.hasActiveFilters,
    required this.onStatusToggle,
    required this.onClear,
    required this.cs,
  });

  final Set<SchoolStatus> statusFilter;
  final bool showDeleted;
  final bool hasActiveFilters;
  final void Function(SchoolStatus) onStatusToggle;
  final VoidCallback onClear;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final statuses = [
      (SchoolStatus.trial, 'Trial'),
      (SchoolStatus.active, 'Active'),
      (SchoolStatus.cancelled, 'Cancelled'),
      (SchoolStatus.suspended, 'Suspended'),
      if (showDeleted) (SchoolStatus.deleted, 'Deleted'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: statuses.map((e) {
                  final selected = statusFilter.contains(e.$1);
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: () => onStatusToggle(e.$1),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary.withValues(
                                  alpha: isDark ? 0.18 : 0.12,
                                )
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? cs.primary.withValues(
                                    alpha: isDark ? 0.55 : 0.4,
                                  )
                                : isDark
                                ? cs.outline.withValues(alpha: 0.5)
                                : cs.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          e.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onClear,
              child: Text(
                'Clear filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List shimmer — loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ListShimmer extends StatefulWidget {
  const _ListShimmer();

  @override
  State<_ListShimmer> createState() => _ListShimmerState();
}

class _ListShimmerState extends State<_ListShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainer;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 52,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Rounded rect logo placeholder.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
                        end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
                        colors: [baseColor, highlightColor, baseColor],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBar(140, 12, baseColor, highlightColor),
                        const SizedBox(height: 6),
                        _shimmerBar(90, 10, baseColor, highlightColor),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerBar(
    double width,
    double height,
    Color baseColor,
    Color highlightColor,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
          end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// School list
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolList extends StatelessWidget {
  const _SchoolList({
    required this.schools,
    required this.permissions,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onTrash,
    required this.onPurge,
    required this.cs,
  });

  final List<SchoolsData> schools;
  final SystemPermissions permissions;
  final Set<String> selectedIds;
  final void Function(SchoolsData) onTap;
  final void Function(SchoolsData) onLongPress;
  final void Function(SchoolsData) onToggleSelection;
  final void Function(SchoolsData) onTrash;
  final void Function(SchoolsData) onPurge;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final selectionMode = selectedIds.isNotEmpty;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: schools.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = schools[index];
        final isSelected = selectedIds.contains(s.id);

        return _SchoolRow(
          school: s,
          permissions: permissions,
          isSelected: isSelected,
          selectionMode: selectionMode,
          onTap: () => onTap(s),
          onLongPress: () => onLongPress(s),
          onToggleSelection: () => onToggleSelection(s),
          onTrash: () => onTrash(s),
          onPurge: () => onPurge(s),
          cs: cs,
        );
      },
    );
  }
}

class _SchoolRow extends StatefulWidget {
  const _SchoolRow({
    required this.school,
    required this.permissions,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onTrash,
    required this.onPurge,
    required this.cs,
  });

  final SchoolsData school;
  final SystemPermissions permissions;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;
  final VoidCallback onTrash;
  final VoidCallback onPurge;
  final ColorScheme cs;

  @override
  State<_SchoolRow> createState() => _SchoolRowState();
}

class _SchoolRowState extends State<_SchoolRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? cs.primaryContainer.withValues(alpha: isDark ? 0.2 : 0.3)
            : _isHovering && !widget.selectionMode
            ? cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.3)
            : isDark
            ? cs.surface
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected
              ? cs.primary
              : isDark
              ? cs.outline.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onHover: (hovering) {
            if (isDesktop) {
              setState(() => _isHovering = hovering);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (widget.selectionMode || (_isHovering && isDesktop)) ...[
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggleSelection(),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _SchoolLogo(schoolId: widget.school.id, cs: cs),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: SchoolStatusDot(
                        status: widget.school.status,
                        backgroundColor: widget.isSelected
                            ? cs.primaryContainer.withValues(
                                alpha: isDark ? 0.2 : 0.3,
                              )
                            : _isHovering && !widget.selectionMode
                            ? cs.surfaceContainerHighest.withValues(
                                alpha: isDark ? 0.5 : 0.3,
                              )
                            : isDark
                            ? cs.surface
                            : cs.surfaceContainerLowest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.school.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.school.motto != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.school.motto!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!widget.selectionMode) ...[
                  const SizedBox(width: 12),
                  if (isDesktop)
                    IgnorePointer(
                      ignoring: !_isHovering,
                      child: AnimatedOpacity(
                        opacity: _isHovering ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              iconSize: 18,
                              color: cs.onSurfaceVariant,
                              onPressed: widget.onTap,
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              iconSize: 18,
                              color: cs.onSurfaceVariant,
                              onPressed: widget.onTrash,
                              tooltip: 'Trash',
                            ),
                            if (widget.permissions.level == UserLevel.super_)
                              IconButton(
                                icon: const Icon(Icons.delete_forever_rounded),
                                iconSize: 18,
                                color: cs.error,
                                onPressed: widget.onPurge,
                                tooltip: 'Purge',
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      color: cs.surfaceContainerHighest,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: cs.outlineVariant, width: 1),
                      ),
                      position: PopupMenuPosition.under,
                      onSelected: (val) {
                        if (val == 'edit') {
                          widget.onTap();
                        } else if (val == 'trash') {
                          widget.onTrash();
                        } else if (val == 'purge') {
                          widget.onPurge();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: cs.onSurface,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'trash',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Trash',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.permissions.level == UserLevel.super_)
                          PopupMenuItem(
                            value: 'purge',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  size: 18,
                                  color: cs.error,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Purge',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.error,
                                  ),
                                ),
                              ],
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// School logo widget — loads from FileCache, falls back to placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolLogo extends StatelessWidget {
  const _SchoolLogo({required this.schoolId, required this.cs});

  final String schoolId;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.logoPath(schoolId)),
      builder: (context, snapshot) {
        final file = snapshot.data;

        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: isDark
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: file != null
              ? Image.file(file, fit: BoxFit.cover)
              : Icon(
                  Icons.school_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(
                    alpha: isDark ? 0.55 : 0.4,
                  ),
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.cs});

  final bool hasQuery;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'No schools match your search.' : 'No schools yet.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
