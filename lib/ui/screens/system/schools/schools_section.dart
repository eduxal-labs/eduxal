import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/status_indicator.dart';

import 'school_detail_screen.dart';

/// The Schools data section of the system dashboard.
///
/// Shows a reactive list of all schools from [SchoolsDao.watchAllSchools],
/// with client-side search (name / motto) and status filter.
///
/// On **mobile** this is the body of the Schools tab.
/// On **desktop** this is the content inside the Schools tab of the data area.
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

  Future<void> _setStatus(
    SchoolsData school,
    SchoolStatus status,
    String label,
  ) async {
    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await schoolsDao.updateSchoolStatus(
        school.id,
        status,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${school.name} $label')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<SchoolsData>>(
      stream: schoolsDao.watchAllSchools(),
      builder: (context, snapshot) {
        final allSchools = snapshot.data ?? [];
        final filtered = _applyFilters(allSchools);

        return Column(
          children: [
            // ── Toolbar ──────────────────────────────────────────────────
            _Toolbar(
              searchController: _searchController,
              filterExpanded: _filterExpanded,
              hasActiveFilters: _hasActiveFilters,
              onToggleFilter: () =>
                  setState(() => _filterExpanded = !_filterExpanded),
              cs: cs,
            ),

            // ── Filter panel ─────────────────────────────────────────────
            if (_filterExpanded)
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

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : SingleChildScrollView(
                      child: EduDataTable<SchoolsData>(
                        items: filtered,
                        emptyIcon: Icons.school_outlined,
                        emptyTitle: 'No schools found',
                        emptySubtitle:
                            _searchQuery.isNotEmpty || _hasActiveFilters
                            ? 'No schools match your filters.'
                            : 'Create a school to get started.',
                        onItemTap: _openDetail,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        actions: (school) => [
                          EduDataTableAction<SchoolsData>(
                            icon: Icons.open_in_new_rounded,
                            label: 'View',
                            onTap: (s) => _openDetail(s),
                          ),
                          // ── Activate: if trial, suspended, or cancelled ──
                          if (school.status == SchoolStatus.trial ||
                              school.status == SchoolStatus.suspended ||
                              school.status == SchoolStatus.cancelled)
                            EduDataTableAction<SchoolsData>(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Activate',
                              color: const Color(0xFF26A69A),
                              onTap: (s) => _setStatus(
                                s,
                                SchoolStatus.active,
                                'activated',
                              ),
                            ),
                          // ── Suspend: if active or trial ──
                          if (school.status == SchoolStatus.active ||
                              school.status == SchoolStatus.trial)
                            EduDataTableAction<SchoolsData>(
                              icon: Icons.block_rounded,
                              label: 'Suspend',
                              color: const Color(0xFFFFB300),
                              onTap: (s) => _setStatus(
                                s,
                                SchoolStatus.suspended,
                                'suspended',
                              ),
                            ),
                          // ── Restore: if deleted ──
                          if (school.status == SchoolStatus.deleted)
                            EduDataTableAction<SchoolsData>(
                              icon: Icons.restore_rounded,
                              label: 'Restore',
                              color: const Color(0xFF26A69A),
                              onTap: (s) => _setStatus(
                                s,
                                SchoolStatus.active,
                                'restored',
                              ),
                            ),
                          // ── Delete: if not already deleted ──
                          if (school.status != SchoolStatus.deleted)
                            EduDataTableAction<SchoolsData>(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              isDestructive: true,
                              onTap: (s) => _trashSchool(s),
                            ),
                          // ── Purge: super only ──
                          if (widget.permissions.canSeeDeleted)
                            EduDataTableAction<SchoolsData>(
                              icon: Icons.delete_forever_rounded,
                              label: 'Purge',
                              isDestructive: true,
                              onTap: (s) => _purgeSchool(s),
                            ),
                        ],
                        columns: const [
                          EduDataTableColumn(label: 'School', flex: 3),
                          EduDataTableColumn(label: 'Status', flex: 1),
                          EduDataTableColumn(label: 'Joined', flex: 1),
                        ],
                        cellBuilder: (context, school, index, isHovered) {
                          final cs = Theme.of(context).colorScheme;
                          return switch (index) {
                            0 => _SchoolIdentityCell(school: school),
                            1 => _SchoolStatusBadge(status: school.status),
                            2 => Text(
                              _formatRelativeDate(school.created.toInt()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            _ => const SizedBox.shrink(),
                          };
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// School status badge — compact chip
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolStatusBadge extends StatelessWidget {
  const _SchoolStatusBadge({required this.status});

  final SchoolStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final (label, color) = switch (status) {
      SchoolStatus.trial => ('Trial', const Color(0xFF42A5F5)),
      SchoolStatus.active => ('Active', const Color(0xFF26A69A)),
      SchoolStatus.suspended => ('Suspended', const Color(0xFFFFB300)),
      SchoolStatus.cancelled => ('Cancelled', cs.onSurfaceVariant),
      SchoolStatus.deleted => ('Deleted', cs.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// School row content — identity cell with logo + status dot + name + motto
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolIdentityCell extends StatelessWidget {
  const _SchoolIdentityCell({required this.school});

  final SchoolsData school;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // ── Logo with status dot overlay ─────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            _SchoolLogo(schoolId: school.id, cs: cs),
            Positioned(
              bottom: -1,
              right: -1,
              child: SchoolStatusDot(
                status: school.status,
                backgroundColor: cs.surface,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // ── Name + motto ──────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                school.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (school.motto != null && school.motto!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  school.motto!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel — status names only (no badges)
// ─────────────────────────────────────────────────────────────────────────────

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
          separatorBuilder: (_, __) => Divider(
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
// Relative date helper
// ─────────────────────────────────────────────────────────────────────────────

String _formatRelativeDate(int? epochMs) {
  if (epochMs == null) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays < 1) return 'Today';
  if (diff.inDays == 1) return '1d ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
