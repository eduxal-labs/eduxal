import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/mpesa_config.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_indicator.dart';

/// Full-page school detail screen, pushed onto the navigator from
/// [SchoolsSection] when the user taps a school row.
///
/// Contains:
/// - Header: logo + name + motto + status chip + quick stats
/// - Tabs: Details, Owners, Subscriptions, Settings, Integrations
class SchoolDetailScreen extends StatefulWidget {
  const SchoolDetailScreen({
    super.key,
    required this.school,
    required this.permissions,
  });

  final SchoolsData school;
  final SystemPermissions permissions;

  @override
  State<SchoolDetailScreen> createState() => _SchoolDetailScreenState();
}

class _SchoolDetailScreenState extends State<SchoolDetailScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  void _openEditSheet(SchoolsData school) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSchoolSheet(school: school),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTheme.kMobileBreakpoint;
    final isLight = cs.brightness == Brightness.light;

    final maxWidth = isDesktop ? 760.0 : double.infinity;
    final horizontalPadding = isDesktop ? 28.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: StreamBuilder<SchoolsData?>(
          stream: schoolsDao.watchSchools().map(
            (list) => list
                .where((s) => s.id == widget.school.id)
                .cast<SchoolsData?>()
                .firstOrNull,
          ),
          initialData: widget.school,
          builder: (context, snapshot) {
            return Text(
              snapshot.data?.name ?? widget.school.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (widget.permissions.can('owners.create'))
            IconButton(
              icon: Icon(
                Icons.person_add_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AddOwnerSheet(
                    schoolId: widget.school.id,
                    permissions: widget.permissions,
                  ),
                );
              },
              tooltip: 'Add owner',
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
          const SizedBox(width: 8),
          if (widget.permissions.can('schools.update'))
            StreamBuilder<SchoolsData?>(
              stream: schoolsDao.watchSchools().map(
                (list) => list
                    .where((s) => s.id == widget.school.id)
                    .cast<SchoolsData?>()
                    .firstOrNull,
              ),
              initialData: widget.school,
              builder: (context, snapshot) {
                final school = snapshot.data ?? widget.school;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => _openEditSheet(school),
                    tooltip: 'Edit school',
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: StreamBuilder<SchoolsData?>(
            stream: schoolsDao.watchSchools().map(
              (list) => list
                  .where((s) => s.id == widget.school.id)
                  .cast<SchoolsData?>()
                  .firstOrNull,
            ),
            initialData: widget.school,
            builder: (context, snapshot) {
              final school = snapshot.data ?? widget.school;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              4,
                              horizontalPadding,
                              12,
                            ),
                            child: _HeaderSection(school: school, cs: cs),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarDelegate(
                            tabController: _tabController,
                            cs: cs,
                            isLight: isLight,
                            horizontalPadding: horizontalPadding,
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _OwnersTab(
                          school: school,
                          permissions: widget.permissions,
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                        ),
                        _PlaceholderTab(
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                          icon: Icons.card_membership_outlined,
                          title: 'Subscriptions',
                          subtitle:
                              'Plan and billing information will appear here once subscription data is synced.',
                        ),
                        _PlaceholderTab(
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                          icon: Icons.tune_outlined,
                          title: 'Settings',
                          subtitle:
                              'School configuration is pending schema definition from the project owner (P10).',
                        ),
                        _IntegrationsTab(
                          school: school,
                          permissions: widget.permissions,
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Header — hero card with logo, identity, and quick stats
// ═════════════════════════════════════════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.school, required this.cs});

  final SchoolsData school;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity row ─────────────────────────────────────────
          Row(
            children: [
              _SchoolLogo(schoolId: school.id, cs: cs),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        height: 1.2,
                        letterSpacing: -0.15,
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
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(status: school.status, cs: cs),
            ],
          ),
          const SizedBox(height: 12),
          // ── Detail chips ─────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DetailChip(
                icon: Icons.location_on_outlined,
                label: 'County ${school.county}',
                cs: cs,
              ),
              if (school.phone != null)
                _DetailChip(
                  icon: Icons.phone_outlined,
                  label: school.phone!,
                  cs: cs,
                ),
              if (school.email != null)
                _DetailChip(
                  icon: Icons.email_outlined,
                  label: school.email!,
                  cs: cs,
                ),
              if (school.domain != null)
                _DetailChip(
                  icon: Icons.language_outlined,
                  label: school.domain!,
                  cs: cs,
                ),
              if (school.established != null)
                _DetailChip(
                  icon: Icons.calendar_today_outlined,
                  label: _daysToDateString(school.established!),
                  cs: cs,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _daysToDateString(int daysSinceEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      daysSinceEpoch * 86400 * 1000,
      isUtc: true,
    );
    const months = [
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _SchoolLogo extends StatelessWidget {
  const _SchoolLogo({required this.schoolId, required this.cs});

  final String schoolId;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.logoPath(schoolId)),
      builder: (context, snapshot) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: snapshot.data != null
              ? Image.file(snapshot.data!, fit: BoxFit.cover)
              : Center(
                  child: Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
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

// ═════════════════════════════════════════════════════════════════════════════
// Tab bar persistent header delegate
// ═════════════════════════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({
    required this.tabController,
    required this.cs,
    required this.isLight,
    required this.horizontalPadding,
  });

  final TabController tabController;
  final ColorScheme cs;
  final bool isLight;
  final double horizontalPadding;

  @override
  double get minExtent => 56.0;
  @override
  double get maxExtent => 56.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final hasScrolled = shrinkOffset > 0;

    return Container(
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(
          bottom: BorderSide(
            color: hasScrolled
                ? cs.outlineVariant
                : cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 10,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isLight
                ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isLight ? 0.3 : 0.4),
              width: 0.5,
            ),
          ),
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: isLight ? Colors.white : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
                if (isLight)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 1,
                  ),
              ],
            ),
            labelColor: cs.onSurface,
            unselectedLabelColor: cs.onSurfaceVariant.withValues(alpha: 0.6),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            tabs: const [
              Tab(text: 'Owners'),
              Tab(text: 'Subscriptions'),
              Tab(text: 'Settings'),
              Tab(text: 'Integrations'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// Owners Tab
// ═════════════════════════════════════════════════════════════════════════════

class _OwnersTab extends StatelessWidget {
  const _OwnersTab({
    required this.school,
    required this.permissions,
    required this.cs,
    required this.horizontalPadding,
  });

  final SchoolsData school;
  final SystemPermissions permissions;
  final ColorScheme cs;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<({OwnersData owner, UsersData user})>>(
      stream: schoolsDao.watchOwnersForSchool(school.id),
      builder: (context, snapshot) {
        final owners = snapshot.data ?? [];

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            40,
          ),
          children: [
            if (owners.isEmpty)
              _OwnersEmptyState(cs: cs)
            else
              _OwnersList(owners: owners, cs: cs),
          ],
        );
      },
    );
  }
}

class _OwnersEmptyState extends StatelessWidget {
  const _OwnersEmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 24,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No owners yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Owners added to this school will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnersList extends StatelessWidget {
  const _OwnersList({required this.owners, required this.cs});

  final List<({OwnersData owner, UsersData user})> owners;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < owners.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 60,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            _OwnerRow(user: owners[i].user, owner: owners[i].owner, cs: cs),
          ],
        ],
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({required this.user, required this.owner, required this.cs});

  final UsersData user;
  final OwnersData owner;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // ── Avatar with status dot ─────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              FutureBuilder<File?>(
                future: FileCache.get(FileCache.profilePath(user.id)),
                builder: (context, snap) {
                  return Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: snap.data != null
                        ? Image.file(snap.data!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              _initials(user.name),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                  );
                },
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: StatusIndicator(
                  status: user.status,
                  level: user.level,
                  backgroundColor: cs.surface,
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          // ── Info ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email ?? user.phone,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Placeholder Tab — reusable empty state for pending features
// ═════════════════════════════════════════════════════════════════════════════

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.cs,
    required this.horizontalPadding,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ColorScheme cs;
  final double horizontalPadding;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                icon,
                size: 28,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.65),
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Integrations Tab
// ═════════════════════════════════════════════════════════════════════════════

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab({
    required this.school,
    required this.permissions,
    required this.cs,
    required this.horizontalPadding,
  });

  final SchoolsData school;
  final SystemPermissions permissions;
  final ColorScheme cs;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Setting?>(
      stream: settingsDao.watchSettings(school.id),
      builder: (context, snapshot) {
        final settingsRow = snapshot.data;
        final MpesaConfig? config = _parseMpesaConfig(settingsRow?.mpesa);
        final isConfigured = config != null && config.isConfigured;
        final canEdit = permissions.can('settings.update');

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            40,
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.brandGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            size: 20,
                            color: AppTheme.brandGreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'M-Pesa',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isConfigured
                                    ? (config.enabled
                                          ? 'Integration active'
                                          : 'Configured but disabled')
                                    : 'Not configured',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: isConfigured && config.enabled
                                      ? AppTheme.brandGreen
                                      : cs.onSurfaceVariant.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConfigured && config.enabled
                                ? AppTheme.brandGreen
                                : cs.onSurfaceVariant.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Body ───────────────────────────────────────────
                  if (!isConfigured)
                    _MpesaNotConfigured(
                      cs: cs,
                      canEdit: canEdit,
                      schoolId: school.id,
                    )
                  else
                    _MpesaConfigured(
                      cs: cs,
                      config: config,
                      canEdit: canEdit,
                      schoolId: school.id,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  MpesaConfig? _parseMpesaConfig(String? mpesaJson) {
    if (mpesaJson == null || mpesaJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(mpesaJson);
      if (decoded is Map<String, dynamic>) {
        return MpesaConfig.fromJson(decoded);
      }
    } catch (_) {
      // Malformed JSON — treat as unconfigured.
    }
    return null;
  }
}

// ── M-Pesa "Not Configured" state ───────────────────────────────────────────

class _MpesaNotConfigured extends StatelessWidget {
  const _MpesaNotConfigured({
    required this.cs,
    required this.canEdit,
    required this.schoolId,
  });

  final ColorScheme cs;
  final bool canEdit;
  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'M-Pesa integration has not been configured for this school. '
                    'Configure it to enable STK Push payments.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppTheme.brandGreen.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: AppTheme.brandGreen,
                ),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text(
                  'Configure',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        _MpesaConfigSheet(schoolId: schoolId, existing: null),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── M-Pesa "Configured" detail view ─────────────────────────────────────────

class _MpesaConfigured extends StatelessWidget {
  const _MpesaConfigured({
    required this.cs,
    required this.config,
    required this.canEdit,
    required this.schoolId,
  });

  final ColorScheme cs;
  final MpesaConfig config;
  final bool canEdit;
  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _configRow('Short Code', config.shortCode),
          _configRow('Environment', config.environment.label),
          _configRow('Consumer Key', MpesaConfig.mask(config.consumerKey)),
          _configRow(
            'Consumer Secret',
            MpesaConfig.mask(config.consumerSecret),
          ),
          _configRow('Passkey', MpesaConfig.mask(config.passkey)),
          _configRow('Callback URL', config.callbackUrl),
          if (config.accountReference.isNotEmpty)
            _configRow('Account Ref', config.accountReference),
          if (canEdit) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: cs.onSurfaceVariant,
                ),
                label: Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        _MpesaConfigSheet(schoolId: schoolId, existing: config),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _configRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Edit School Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _EditSchoolSheet extends StatefulWidget {
  const _EditSchoolSheet({required this.school});
  final SchoolsData school;

  @override
  State<_EditSchoolSheet> createState() => _EditSchoolSheetState();
}

class _EditSchoolSheetState extends State<_EditSchoolSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mottoCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _domainCtrl;
  late final TextEditingController _countyCtrl;
  late SchoolStatus _editStatus;

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    _nameCtrl = TextEditingController(text: s.name);
    _mottoCtrl = TextEditingController(text: s.motto ?? '');
    _phoneCtrl = TextEditingController(text: s.phone ?? '');
    _emailCtrl = TextEditingController(text: s.email ?? '');
    _domainCtrl = TextEditingController(text: s.domain ?? '');
    _countyCtrl = TextEditingController(text: '${s.county}');
    _editStatus = s.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mottoCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _domainCtrl.dispose();
    _countyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'School name is required.');
      return;
    }

    final countyStr = _countyCtrl.text.trim();
    final county = int.tryParse(countyStr);
    if (county == null) {
      setState(() => _saveError = 'County must be a number.');
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
      final motto = _mottoCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final domain = _domainCtrl.text.trim();

      await schoolsDao.updateSchoolDetails(
        widget.school.id,
        SchoolsCompanion(
          name: Value(name),
          motto: Value(motto.isEmpty ? null : motto),
          phone: Value(phone.isEmpty ? null : phone),
          email: Value(email.isEmpty ? null : email),
          domain: Value(domain.isEmpty ? null : domain),
          county: Value(county),
          status: Value(_editStatus),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Title row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit School',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Error ──────────────────────────────────────────────────
          if (_saveError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // ── Form fields ────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final halfWidth = (constraints.maxWidth / 2) - 8;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Name',
                          controller: _nameCtrl,
                          cs: cs,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Motto',
                          controller: _mottoCtrl,
                          hint: 'Optional',
                          cs: cs,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Phone',
                          controller: _phoneCtrl,
                          hint: 'Optional',
                          cs: cs,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Email',
                          controller: _emailCtrl,
                          hint: 'Optional',
                          cs: cs,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Domain',
                          controller: _domainCtrl,
                          hint: 'Optional',
                          cs: cs,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'County',
                          controller: _countyCtrl,
                          cs: cs,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SheetFormLabel(label: 'Status', cs: cs),
                            const SizedBox(height: 5),
                            _StyledDropdown<SchoolStatus>(
                              value: _editStatus,
                              items: const [
                                (SchoolStatus.trial, 'Trial'),
                                (SchoolStatus.active, 'Active'),
                                (SchoolStatus.cancelled, 'Cancelled'),
                                (SchoolStatus.suspended, 'Suspended'),
                                (SchoolStatus.deleted, 'Deleted'),
                              ],
                              onChanged: (s) => setState(() => _editStatus = s),
                              cs: cs,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ── Save button ────────────────────────────────────────────
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// M-Pesa Config Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _MpesaConfigSheet extends StatefulWidget {
  const _MpesaConfigSheet({required this.schoolId, required this.existing});

  final String schoolId;
  final MpesaConfig? existing;

  @override
  State<_MpesaConfigSheet> createState() => _MpesaConfigSheetState();
}

class _MpesaConfigSheetState extends State<_MpesaConfigSheet> {
  late final TextEditingController _consumerKeyCtrl;
  late final TextEditingController _consumerSecretCtrl;
  late final TextEditingController _shortCodeCtrl;
  late final TextEditingController _passkeyCtrl;
  late final TextEditingController _accountRefCtrl;
  late final TextEditingController _callbackUrlCtrl;
  late MpesaEnvironment _environment;
  late bool _enabled;

  bool _saving = false;
  String? _saveError;

  // Visibility toggles for sensitive fields
  bool _showConsumerKey = false;
  bool _showConsumerSecret = false;
  bool _showPasskey = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _consumerKeyCtrl = TextEditingController(text: c?.consumerKey ?? '');
    _consumerSecretCtrl = TextEditingController(text: c?.consumerSecret ?? '');
    _shortCodeCtrl = TextEditingController(text: c?.shortCode ?? '');
    _passkeyCtrl = TextEditingController(text: c?.passkey ?? '');
    _accountRefCtrl = TextEditingController(text: c?.accountReference ?? '');
    _callbackUrlCtrl = TextEditingController(text: c?.callbackUrl ?? '');
    _environment = c?.environment ?? MpesaEnvironment.sandbox;
    _enabled = c?.enabled ?? false;
  }

  @override
  void dispose() {
    _consumerKeyCtrl.dispose();
    _consumerSecretCtrl.dispose();
    _shortCodeCtrl.dispose();
    _passkeyCtrl.dispose();
    _accountRefCtrl.dispose();
    _callbackUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shortCode = _shortCodeCtrl.text.trim();
    if (shortCode.isEmpty) {
      setState(() => _saveError = 'Business short code is required.');
      return;
    }

    final consumerKey = _consumerKeyCtrl.text.trim();
    if (consumerKey.isEmpty) {
      setState(() => _saveError = 'Consumer key is required.');
      return;
    }

    final consumerSecret = _consumerSecretCtrl.text.trim();
    if (consumerSecret.isEmpty) {
      setState(() => _saveError = 'Consumer secret is required.');
      return;
    }

    final passkey = _passkeyCtrl.text.trim();
    if (passkey.isEmpty) {
      setState(() => _saveError = 'Passkey is required.');
      return;
    }

    final callbackUrl = _callbackUrlCtrl.text.trim();
    if (callbackUrl.isEmpty) {
      setState(() => _saveError = 'Callback URL is required.');
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final config = MpesaConfig(
        consumerKey: consumerKey,
        consumerSecret: consumerSecret,
        shortCode: shortCode,
        passkey: passkey,
        accountReference: _accountRefCtrl.text.trim(),
        callbackUrl: callbackUrl,
        environment: _environment,
        enabled: _enabled,
      );

      await settingsDao.updateMpesa(
        widget.schoolId,
        mpesaJson: jsonEncode(config.toJson()),
        accountId: accountId,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disable() async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await settingsDao.updateMpesa(
        widget.schoolId,
        mpesaJson: null,
        accountId: accountId,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to disable: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Title row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'M-Pesa Configuration',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Error ──────────────────────────────────────────────────
          if (_saveError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // ── Form fields ────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final halfWidth = (constraints.maxWidth / 2) - 8;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Business Short Code',
                          controller: _shortCodeCtrl,
                          cs: cs,
                          hint: 'e.g. 174379',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SheetFormLabel(label: 'Environment', cs: cs),
                            const SizedBox(height: 5),
                            _StyledDropdown<MpesaEnvironment>(
                              value: _environment,
                              items: const [
                                (MpesaEnvironment.sandbox, 'Sandbox'),
                                (MpesaEnvironment.production, 'Production'),
                              ],
                              onChanged: (v) =>
                                  setState(() => _environment = v),
                              cs: cs,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SensitiveFormField(
                          label: 'Consumer Key',
                          controller: _consumerKeyCtrl,
                          cs: cs,
                          obscured: !_showConsumerKey,
                          onToggle: () => setState(
                            () => _showConsumerKey = !_showConsumerKey,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SensitiveFormField(
                          label: 'Consumer Secret',
                          controller: _consumerSecretCtrl,
                          cs: cs,
                          obscured: !_showConsumerSecret,
                          onToggle: () => setState(
                            () => _showConsumerSecret = !_showConsumerSecret,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SensitiveFormField(
                          label: 'Passkey',
                          controller: _passkeyCtrl,
                          cs: cs,
                          obscured: !_showPasskey,
                          onToggle: () =>
                              setState(() => _showPasskey = !_showPasskey),
                        ),
                      ),
                      SizedBox(
                        width: isWide ? halfWidth : double.infinity,
                        child: _SheetFormField(
                          label: 'Account Reference',
                          controller: _accountRefCtrl,
                          cs: cs,
                          hint: 'e.g. EduXal-INV (optional)',
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: _SheetFormField(
                          label: 'Callback URL',
                          controller: _callbackUrlCtrl,
                          cs: cs,
                          hint: 'https://...',
                          keyboardType: TextInputType.url,
                        ),
                      ),
                      // ── Enabled toggle ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Enable Integration',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurface,
                              ),
                            ),
                            Switch.adaptive(
                              value: _enabled,
                              onChanged: (v) => setState(() => _enabled = v),
                              activeTrackColor: AppTheme.brandGreen,
                              activeThumbColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Action buttons ─────────────────────────────────────────
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: cs.error,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: _saving ? null : _disable,
                      child: const Text('Disable'),
                    ),
                  ),
                ),
              if (widget.existing != null) const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sensitive form field with visibility toggle ─────────────────────────────

class _SensitiveFormField extends StatelessWidget {
  const _SensitiveFormField({
    required this.label,
    required this.controller,
    required this.cs,
    required this.obscured,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final ColorScheme cs;
  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetFormLabel(label: label, cs: cs),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscured,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintStyle: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.primary, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            isDense: true,
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs});

  final SchoolStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SchoolStatus.trial => ('Trial', const Color(0xFF42A5F5)),
      SchoolStatus.active => ('Active', const Color(0xFF26A69A)),
      SchoolStatus.cancelled => ('Cancelled', const Color(0xFFBDBDBD)),
      SchoolStatus.suspended => ('Suspended', const Color(0xFFFFB300)),
      SchoolStatus.deleted => ('Deleted', const Color(0xFFEF5350)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
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

// ── Sheet form widgets ───────────────────────────────────────────────────

class _SheetFormLabel extends StatelessWidget {
  const _SheetFormLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SheetFormField extends StatelessWidget {
  const _SheetFormField({
    required this.label,
    required this.controller,
    required this.cs,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final ColorScheme cs;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetFormLabel(label: label, cs: cs),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.primary, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Add Owner Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _AddOwnerSheet extends StatefulWidget {
  const _AddOwnerSheet({required this.schoolId, required this.permissions});

  final String schoolId;
  final SystemPermissions permissions;

  @override
  State<_AddOwnerSheet> createState() => _AddOwnerSheetState();
}

class _AddOwnerSheetState extends State<_AddOwnerSheet> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  UsersData? _foundUser;
  bool _notFound = false;
  bool _lookingUp = false;
  bool _submitting = false;
  String? _phoneError;
  String? _nameError;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Phone lookup ──────────────────────────────────────────────────────────

  void _onPhoneChanged(String value) {
    setState(() {
      _foundUser = null;
      _notFound = false;
      _phoneError = null;
      _error = null;
    });

    _debounce?.cancel();
    final phone = value.trim();
    if (phone.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _lookup(phone);
    });
  }

  Future<void> _lookup(String phone) async {
    if (!mounted) return;
    setState(() => _lookingUp = true);
    try {
      final user = await usersDao.getUserByPhone(phone);
      if (!mounted) return;

      if (user != null) {
        // Check if already an owner of this school.
        final already = await schoolsDao.isOwner(widget.schoolId, user.id);
        if (!mounted) return;

        if (already) {
          setState(() {
            _foundUser = null;
            _notFound = false;
            _error = '${user.name} is already an owner of this school.';
          });
        } else {
          setState(() {
            _foundUser = user;
            _notFound = false;
            _error = null;
          });
        }
      } else {
        setState(() {
          _foundUser = null;
          _notFound = true;
          _error = null;
        });
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  static bool _isValidPhone(String phone) =>
      RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone);

  bool _validate() {
    final phone = _phoneCtrl.text.trim();
    String? phoneErr;
    String? nameErr;

    if (phone.isEmpty) {
      phoneErr = 'Phone number is required.';
    } else if (!_isValidPhone(phone)) {
      phoneErr = 'Enter a valid phone number (7–15 digits).';
    }

    if (_notFound) {
      final name = _nameCtrl.text.trim();
      if (name.length < 2) nameErr = 'Name must be at least 2 characters.';
    }

    setState(() {
      _phoneError = phoneErr;
      _nameError = nameErr;
    });

    return phoneErr == null && nameErr == null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!widget.permissions.can('owners.create')) return;
    if (!_validate()) return;
    if (_error != null) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final phone = _phoneCtrl.text.trim();

      if (_foundUser != null) {
        // Re-verify not already an owner (race guard).
        final already = await schoolsDao.isOwner(
          widget.schoolId,
          _foundUser!.id,
        );
        if (already) {
          if (mounted) {
            setState(() {
              _error =
                  '${_foundUser!.name} is already an owner of this school.';
            });
          }
          return;
        }

        await schoolsDao.linkOwner(
          schoolId: widget.schoolId,
          userId: _foundUser!.id,
          accountId: accountId,
        );

        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_foundUser!.name} linked as owner.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (_notFound) {
        // Create a new invited user, then link as owner.
        final userId = ObjectId().oid;
        final nowSeconds = BigInt.from(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        final name = _nameCtrl.text.trim();
        final email = _emailCtrl.text.trim();

        await db.transaction(() async {
          await usersDao.inviteUser(
            UsersCompanion(
              id: Value(userId),
              phone: Value(phone),
              name: Value(name),
              email: Value(email.isEmpty ? null : email),
              level: const Value(UserLevel.normal),
              status: const Value(UserStatus.invited),
              created: Value(nowSeconds),
              updated: Value(nowSeconds),
            ),
            accountId: accountId,
          );

          await schoolsDao.linkOwner(
            schoolId: widget.schoolId,
            userId: userId,
            accountId: accountId,
          );
        });

        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name created and linked as owner.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final bool canSubmit =
        (_foundUser != null || _notFound) && _error == null && !_submitting;

    final String buttonLabel = _foundUser != null
        ? 'Link as Owner'
        : 'Create & Link';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Owner',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Subtitle ───────────────────────────────────────────────
          Text(
            'Enter a phone number to look up an existing user, or create a new one.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // ── Error banner ───────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Phone field ────────────────────────────────────────────
          _SheetFormLabel(label: 'Phone number', cs: cs),
          const SizedBox(height: 5),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onChanged: _onPhoneChanged,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. 0712345678',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                fontSize: 13,
              ),
              errorText: _phoneError,
              errorStyle: const TextStyle(fontSize: 11),
              filled: true,
              fillColor: cs.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.primary, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              isDense: true,
              suffixIcon: _lookingUp
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // ── Found user card ────────────────────────────────────────
          if (_foundUser != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF26A69A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
                border: Border.all(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  FutureBuilder<File?>(
                    future: FileCache.get(
                      FileCache.profilePath(_foundUser!.id),
                    ),
                    builder: (context, snap) {
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: snap.data != null
                            ? Image.file(snap.data!, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  _initials(_foundUser!.name),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _foundUser!.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _foundUser!.email ?? _foundUser!.phone,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF26A69A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: const Color(0xFF26A69A),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Not found — new user fields ────────────────────────────
          if (_notFound) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
                border: Border.all(color: cs.outlineVariant, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No user found. Fill in details to create and link.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SheetFormField(
              label: 'Name',
              controller: _nameCtrl,
              cs: cs,
              hint: 'Full name',
            ),
            if (_nameError != null) ...[
              const SizedBox(height: 4),
              Text(
                _nameError!,
                style: TextStyle(fontSize: 11, color: cs.error),
              ),
            ],
            const SizedBox(height: 12),
            _SheetFormField(
              label: 'Email (optional)',
              controller: _emailCtrl,
              cs: cs,
              hint: 'example@domain.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
          ],

          // ── Action button ──────────────────────────────────────────
          if (_foundUser != null || _notFound) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(buttonLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.cs,
  });

  final T value;
  final List<(T, String)> items;
  final void Function(T) onChanged;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          dropdownColor: cs.surface,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
