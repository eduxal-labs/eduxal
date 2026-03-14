import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import 'package:image_picker/image_picker.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/curriculum_subjects.dart';

import '../../../../database/tables/enums.dart';
import '../../../../models/mpesa_config.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_sheet.dart';
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
    showEduSheet(
      context: context,
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
          if (widget.permissions.can(Resource.owners, Action.create))
            IconButton(
              icon: Icon(
                Icons.person_add_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () {
                showEduSheet(
                  context: context,
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
          if (widget.permissions.can(Resource.schools, Action.update))
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
                        _SettingsTab(
                          school: school,
                          permissions: widget.permissions,
                          cs: cs,
                          horizontalPadding: horizontalPadding,
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
              _StatusDot(status: school.status),
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
                label: _countyName(school.county),
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

  static String _countyName(int countyNumber) {
    try {
      return KenyaCounty.values
          .firstWhere((c) => c.number == countyNumber)
          .label;
    } catch (_) {
      return 'County $countyNumber';
    }
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

  void _viewLogo(BuildContext context, File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.logoPath(schoolId)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();
        final container = Container(
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
          child: hasImage
              ? Image.file(file, fit: BoxFit.cover)
              : Center(
                  child: Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
        );

        if (!hasImage) return container;

        return GestureDetector(
          onTap: () => _viewLogo(context, file),
          child: container,
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
              for (int i = 0; i < owners.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _OwnerCard(
                  user: owners[i].user,
                  owner: owners[i].owner,
                  cs: cs,
                ),
              ],
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

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.user, required this.owner, required this.cs});

  final UsersData user;
  final OwnersData owner;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final joinedDate = _formatDate(owner.created);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: avatar + name/email + level badge ─────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with status dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FutureBuilder<File?>(
                    future: FileCache.get(FileCache.profilePath(user.id)),
                    builder: (context, snap) {
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
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
                      backgroundColor: cs.surfaceContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Name + email
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
              // Level badge (only for non-normal users)
              if (user.level != UserLevel.normal) ...[
                const SizedBox(width: 8),
                _LevelBadge(level: user.level, cs: cs),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // ── Bottom row: join date ──────────────────────────────
          Text(
            'Joined $joinedDate',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              height: 1.3,
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

  /// Formats a seconds-since-epoch [BigInt] as "DD Mon YYYY".
  String _formatDate(BigInt secondsSinceEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      secondsSinceEpoch.toInt() * 1000,
      isUtc: true,
    ).toLocal();
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
    return '${dt.day.toString().padLeft(2, '0')} '
        '${months[dt.month - 1]} '
        '${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.cs});

  final UserLevel level;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final label = switch (level) {
      UserLevel.system => 'SYSTEM',
      UserLevel.super_ => 'SUPER',
      UserLevel.normal => '',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Settings Tab — Grades & Streams configuration (CBC + 8-4-4)
// ═════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
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
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object?>(
      stream: Stream.value(null),
      builder: (context, snapshot) {
        final SchoolConfig config = _parseConfig(null);
        final canEdit = widget.permissions.can(Resource.schools, Action.update);

        final width = MediaQuery.sizeOf(context).width;
        final isDesktop = width >= AppTheme.kMobileBreakpoint;
        final contentMaxWidth = isDesktop ? 680.0 : double.infinity;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.015),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _editMode
                  ? KeyedSubtree(
                      key: const ValueKey('edit'),
                      child: _SettingsEditMode(
                        school: widget.school,
                        cs: widget.cs,
                        horizontalPadding: widget.horizontalPadding,
                        initialConfig: config,
                        onCancel: () => setState(() => _editMode = false),
                        onSaved: () => setState(() => _editMode = false),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('view'),
                      child: _SettingsViewMode(
                        cs: widget.cs,
                        horizontalPadding: widget.horizontalPadding,
                        config: config,
                        canEdit: canEdit,
                        onEdit: () => setState(() => _editMode = true),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  SchoolConfig _parseConfig(String? dataJson) {
    if (dataJson == null || dataJson.isEmpty) return SchoolConfig.defaults();
    try {
      final decoded = jsonDecode(dataJson);
      if (decoded is Map<String, dynamic>) {
        return SchoolConfig.fromJson(decoded);
      }
    } catch (_) {
      // Malformed JSON — return defaults.
    }
    return SchoolConfig.defaults();
  }
}

// ── Settings View Mode ────────────────────────────────────────────────────────

class _SettingsViewMode extends StatefulWidget {
  const _SettingsViewMode({
    required this.cs,
    required this.horizontalPadding,
    required this.config,
    required this.canEdit,
    required this.onEdit,
  });

  final ColorScheme cs;
  final double horizontalPadding;
  final SchoolConfig config;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  State<_SettingsViewMode> createState() => _SettingsViewModeState();
}

class _SettingsViewModeState extends State<_SettingsViewMode> {
  // Tracks which grade rows are expanded per curriculum type.
  final Map<CurriculumType, Set<int>> _expandedGrades = {};

  bool _isExpanded(CurriculumType type, int grade) =>
      (_expandedGrades[type] ?? {}).contains(grade);

  void _toggleGrade(CurriculumType type, int grade) {
    setState(() {
      final set = _expandedGrades.putIfAbsent(type, () => {});
      if (set.contains(grade)) {
        set.remove(grade);
      } else {
        set.add(grade);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isLight = cs.brightness == Brightness.light;

    if (widget.config.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding,
          20,
          widget.horizontalPadding,
          40,
        ),
        children: [
          _SettingsSectionCard(
            cs: cs,
            icon: Icons.school_outlined,
            iconColor: AppTheme.brandIndigo,
            header: 'Curricula',
            subtitle: 'No curricula configured',
            trailing: widget.canEdit ? _editButton(cs) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xFFF5F5FC).withValues(alpha: 0.7)
                      : cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'No curriculum has been set up yet. ',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            height: 1.45,
                          ),
                          children: widget.canEdit
                              ? [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: widget.onEdit,
                                      child: Text(
                                        'Configure now',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.brandIndigo,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final curricula = widget.config.curricula;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        20,
        widget.horizontalPadding,
        40,
      ),
      children: [
        for (int ci = 0; ci < curricula.length; ci++) ...[
          if (ci > 0) const SizedBox(height: 14),
          _buildCurriculumCard(cs, isLight, curricula[ci], isFirst: ci == 0),
        ],
      ],
    );
  }

  Widget _buildCurriculumCard(
    ColorScheme cs,
    bool isLight,
    CurriculumConfig curriculum, {
    required bool isFirst,
  }) {
    final isCbc = curriculum.type == CurriculumType.cbc;
    final typeLabel = isCbc ? 'CBC' : '8-4-4';
    final typeSubtitle = isCbc ? 'Competency-Based Curriculum' : '8-4-4 System';
    final gradeLabels = gradeLabelsFor(curriculum.type);
    final gradeCount = curriculum.grades.length;
    final totalStreams = curriculum.grades.fold<int>(
      0,
      (sum, g) => sum + g.streams.length,
    );

    return _SettingsSectionCard(
      cs: cs,
      icon: isCbc ? Icons.auto_awesome_outlined : Icons.menu_book_outlined,
      iconColor: isCbc ? AppTheme.brandIndigo : const Color(0xFF7B61FF),
      header: typeLabel,
      subtitle: typeSubtitle,
      trailing: isFirst && widget.canEdit ? _editButton(cs) : null,
      child: curriculum.grades.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xFFF5F5FC).withValues(alpha: 0.7)
                      : cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'No grades configured. ',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            height: 1.45,
                          ),
                          children: widget.canEdit
                              ? [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: widget.onEdit,
                                      child: Text(
                                        'Configure',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.brandIndigo,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary badges row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      _summaryBadge(
                        cs,
                        isLight,
                        Icons.layers_outlined,
                        '$gradeCount ${gradeCount == 1 ? 'grade' : 'grades'}',
                      ),
                      const SizedBox(width: 8),
                      _summaryBadge(
                        cs,
                        isLight,
                        Icons.view_stream_outlined,
                        '$totalStreams ${totalStreams == 1 ? 'stream' : 'streams'}',
                      ),
                    ],
                  ),
                ),
                // Grade rows
                for (int i = 0; i < curriculum.grades.length; i++) ...[
                  _buildViewGradeRow(
                    cs,
                    isLight,
                    curriculum.type,
                    curriculum.grades[i],
                    gradeLabels,
                    isEven: i.isEven,
                    isLast: i == curriculum.grades.length - 1,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _summaryBadge(
    ColorScheme cs,
    bool isLight,
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLight
            ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewGradeRow(
    ColorScheme cs,
    bool isLight,
    CurriculumType type,
    GradeConfig gradeConfig,
    Map<int, String> gradeLabels, {
    required bool isEven,
    required bool isLast,
  }) {
    final gradeLabel =
        gradeLabels[gradeConfig.grade] ?? 'Grade ${gradeConfig.grade}';
    final expanded = _isExpanded(type, gradeConfig.grade);
    final streamCount = gradeConfig.streams.length;
    final streamBadge = streamCount == 0
        ? 'No streams'
        : streamCount == 1
        ? '1 stream'
        : '$streamCount streams';

    // Alternate row tinting for scanability
    final rowBg = isEven
        ? Colors.transparent
        : (isLight
              ? cs.surfaceContainerHighest.withValues(alpha: 0.18)
              : cs.surfaceContainerHigh.withValues(alpha: 0.25));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Grade header row ─────────────────────────────────────
        Container(
          color: rowBg,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: streamCount > 0
                  ? () => _toggleGrade(type, gradeConfig.grade)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Expand arrow
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: streamCount > 0
                            ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                            : cs.onSurfaceVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gradeLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    // Stream count badge — tinted by count
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: streamCount > 0
                            ? AppTheme.brandIndigo.withValues(alpha: 0.07)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        streamBadge,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: streamCount > 0
                              ? AppTheme.brandIndigo.withValues(alpha: 0.7)
                              : cs.onSurfaceVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Expanded streams list ────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: expanded && gradeConfig.streams.isNotEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF0F1F8).withValues(alpha: 0.5)
                        : cs.surfaceContainerHigh.withValues(alpha: 0.6),
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                      bottom: isLast
                          ? BorderSide.none
                          : BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: gradeConfig.streams.asMap().entries.map((entry) {
                      final stream = entry.value;
                      return Container(
                        margin: EdgeInsets.only(top: entry.key == 0 ? 0 : 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.white.withValues(alpha: 0.75)
                              : cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.brandIndigo.withValues(
                                  alpha: 0.35,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stream.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurface,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${stream.code}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _editButton(ColorScheme cs) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: widget.onEdit,
        icon: Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
        label: Text(
          'Edit',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── Settings Edit Mode ────────────────────────────────────────────────────────

class _SettingsEditMode extends StatefulWidget {
  const _SettingsEditMode({
    required this.school,
    required this.cs,
    required this.horizontalPadding,
    required this.initialConfig,
    required this.onCancel,
    required this.onSaved,
  });

  final SchoolsData school;
  final ColorScheme cs;
  final double horizontalPadding;
  final SchoolConfig initialConfig;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_SettingsEditMode> createState() => _SettingsEditModeState();
}

class _SettingsEditModeState extends State<_SettingsEditMode> {
  late List<CurriculumConfig> _curricula;
  bool _saving = false;
  String? _error;

  // Two-tap confirm for removal. Stores the type pending removal.
  CurriculumType? _pendingRemoval;

  // Tracks which grade rows are expanded per curriculum type.
  final Map<CurriculumType, Set<int>> _expandedGrades = {};

  // TextEditingControllers keyed by (curriculumType, gradeIndex, streamIndex).
  // We regenerate them on grade/stream structural changes.
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _codeControllers = {};

  @override
  void initState() {
    super.initState();
    // Deep-copy so cancel fully reverts.
    _curricula = widget.initialConfig.curricula
        .map(
          (c) => CurriculumConfig(
            type: c.type,
            grades: c.grades
                .map(
                  (g) => GradeConfig(
                    grade: g.grade,
                    streams: g.streams
                        .map((s) => GradeStream(name: s.name, code: s.code))
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    _rebuildControllers();
  }

  @override
  void dispose() {
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    for (final c in _codeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Controller management ────────────────────────────────────

  void _rebuildControllers() {
    // Dispose all existing controllers.
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    for (final c in _codeControllers.values) {
      c.dispose();
    }
    _nameControllers.clear();
    _codeControllers.clear();

    for (int ci = 0; ci < _curricula.length; ci++) {
      final curriculum = _curricula[ci];
      for (int gi = 0; gi < curriculum.grades.length; gi++) {
        final grade = curriculum.grades[gi];
        for (int si = 0; si < grade.streams.length; si++) {
          final key = '${curriculum.type.index_}:$gi:$si';
          _nameControllers[key] = TextEditingController(
            text: grade.streams[si].name,
          );
          _codeControllers[key] = TextEditingController(
            text: grade.streams[si].code.toString(),
          );
        }
      }
    }
  }

  String _controllerKey(int ci, int gi, int si) {
    return '${_curricula[ci].type.index_}:$gi:$si';
  }

  // ── Data mutation helpers ─────────────────────────────────────

  bool _hasCurriculum(CurriculumType type) =>
      _curricula.any((c) => c.type == type);

  void _toggleCurriculum(CurriculumType type) {
    setState(() {
      _error = null;
      if (_hasCurriculum(type)) {
        if (_pendingRemoval == type) {
          // Second tap — confirm removal.
          // Flush first so other curricula retain their typed values.
          _flushControllers();
          _curricula.removeWhere((c) => c.type == type);
          _pendingRemoval = null;
          _rebuildControllers();
        } else {
          // First tap — set pending.
          _pendingRemoval = type;
        }
      } else {
        _pendingRemoval = null;
        // Flush first so existing curricula retain their typed values.
        _flushControllers();
        _curricula.add(CurriculumConfig(type: type, grades: []));
        // Keep CBC before 8-4-4.
        _curricula.sort((a, b) => a.type.index_.compareTo(b.type.index_));
        _rebuildControllers();
      }
    });
  }

  int _curriculumIndex(CurriculumType type) =>
      _curricula.indexWhere((c) => c.type == type);

  void _addGrade(CurriculumType type, int grade) {
    final ci = _curriculumIndex(type);
    if (ci < 0) return;
    // Capture in-progress text before structural change.
    _flushControllers();
    setState(() {
      final grades = List<GradeConfig>.from(_curricula[ci].grades);
      grades.add(GradeConfig(grade: grade, streams: []));
      grades.sort((a, b) => a.grade.compareTo(b.grade));
      _curricula[ci] = CurriculumConfig(type: type, grades: grades);
      _rebuildControllers();
      // Auto-expand newly added grade.
      (_expandedGrades[type] ??= {}).add(grade);
    });
  }

  void _removeGrade(CurriculumType type, int grade) {
    final ci = _curriculumIndex(type);
    if (ci < 0) return;
    // Capture in-progress text before structural change.
    _flushControllers();
    setState(() {
      final grades = List<GradeConfig>.from(_curricula[ci].grades)
        ..removeWhere((g) => g.grade == grade);
      _curricula[ci] = CurriculumConfig(type: type, grades: grades);
      _expandedGrades[type]?.remove(grade);
      _rebuildControllers();
    });
  }

  void _addStream(CurriculumType type, int gradeIndex) {
    final ci = _curriculumIndex(type);
    if (ci < 0) return;
    // Capture in-progress text before structural change.
    _flushControllers();
    final grade = _curricula[ci].grades[gradeIndex];
    final nextCode = grade.streams.isEmpty
        ? 1
        : grade.streams.map((s) => s.code).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {
      final updatedStreams = List<GradeStream>.from(grade.streams)
        ..add(GradeStream(name: '', code: nextCode));
      final updatedGrades = List<GradeConfig>.from(_curricula[ci].grades);
      updatedGrades[gradeIndex] = GradeConfig(
        grade: grade.grade,
        streams: updatedStreams,
      );
      _curricula[ci] = CurriculumConfig(type: type, grades: updatedGrades);
      _rebuildControllers();
    });
  }

  void _removeStream(CurriculumType type, int gradeIndex, int streamIndex) {
    final ci = _curriculumIndex(type);
    if (ci < 0) return;
    // Capture in-progress text before structural change.
    _flushControllers();
    final grade = _curricula[ci].grades[gradeIndex];
    setState(() {
      final updatedStreams = List<GradeStream>.from(grade.streams)
        ..removeAt(streamIndex);
      final updatedGrades = List<GradeConfig>.from(_curricula[ci].grades);
      updatedGrades[gradeIndex] = GradeConfig(
        grade: grade.grade,
        streams: updatedStreams,
      );
      _curricula[ci] = CurriculumConfig(type: type, grades: updatedGrades);
      _rebuildControllers();
    });
  }

  // ── Validation ────────────────────────────────────────────────

  String? _validate() {
    for (final curriculum in _curricula) {
      for (final grade in curriculum.grades) {
        // Check for empty stream names.
        for (final stream in grade.streams) {
          if (stream.name.trim().isEmpty) {
            final gradeLabel =
                gradeLabelsFor(curriculum.type)[grade.grade] ??
                'Grade ${grade.grade}';
            return 'Stream name cannot be empty in $gradeLabel.';
          }
        }
        // Check for duplicate codes within a grade.
        final codes = grade.streams.map((s) => s.code).toList();
        final uniqueCodes = codes.toSet();
        if (uniqueCodes.length != codes.length) {
          final gradeLabel =
              gradeLabelsFor(curriculum.type)[grade.grade] ??
              'Grade ${grade.grade}';
          return 'Stream codes must be unique within $gradeLabel.';
        }
      }
    }
    return null;
  }

  // ── Sync controller values back into model before save/validate ──

  void _flushControllers() {
    for (int ci = 0; ci < _curricula.length; ci++) {
      final curriculum = _curricula[ci];
      final newGrades = <GradeConfig>[];
      for (int gi = 0; gi < curriculum.grades.length; gi++) {
        final grade = curriculum.grades[gi];
        final newStreams = <GradeStream>[];
        for (int si = 0; si < grade.streams.length; si++) {
          final key = _controllerKey(ci, gi, si);
          final name = _nameControllers[key]?.text ?? grade.streams[si].name;
          final codeStr = _codeControllers[key]?.text ?? '';
          final code = int.tryParse(codeStr) ?? grade.streams[si].code;
          newStreams.add(GradeStream(name: name.trim(), code: code));
        }
        newGrades.add(GradeConfig(grade: grade.grade, streams: newStreams));
      }
      _curricula[ci] = CurriculumConfig(
        type: curriculum.type,
        grades: newGrades,
      );
    }
  }

  // ── Save ──────────────────────────────────────────────────────

  Future<void> _save() async {
    _flushControllers();
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // TODO: persist config via new settings source when available
    widget.onSaved();
  }

  // ── Grade expand/collapse ─────────────────────────────────────

  bool _isExpanded(CurriculumType type, int grade) =>
      (_expandedGrades[type] ?? {}).contains(grade);

  void _toggleGrade(CurriculumType type, int grade) {
    setState(() {
      final set = _expandedGrades.putIfAbsent(type, () => {});
      if (set.contains(grade)) {
        set.remove(grade);
      } else {
        set.add(grade);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        20,
        widget.horizontalPadding,
        40,
      ),
      children: [
        // ── Curriculum toggle row ────────────────────────────────
        _SettingsSectionCard(
          cs: cs,
          icon: Icons.school_outlined,
          iconColor: AppTheme.brandIndigo,
          header: 'Curricula',
          subtitle: 'Select active curriculum systems',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _CurriculumToggleCard(
                    label: 'CBC',
                    subtitle: 'Competency-Based',
                    active: _hasCurriculum(CurriculumType.cbc),
                    pendingRemoval: _pendingRemoval == CurriculumType.cbc,
                    cs: cs,
                    onTap: () => _toggleCurriculum(CurriculumType.cbc),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CurriculumToggleCard(
                    label: '8-4-4',
                    subtitle: 'Classic System',
                    active: _hasCurriculum(CurriculumType.eightFourFour),
                    pendingRemoval:
                        _pendingRemoval == CurriculumType.eightFourFour,
                    cs: cs,
                    onTap: () =>
                        _toggleCurriculum(CurriculumType.eightFourFour),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_pendingRemoval != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: cs.error.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap again to confirm removing '
                    '${_pendingRemoval == CurriculumType.cbc ? "CBC" : "8-4-4"}.'
                    ' This will delete all its grade and stream configuration.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.error.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // ── Per-curriculum grade sections ────────────────────────
        for (int ci = 0; ci < _curricula.length; ci++) ...[
          if (ci > 0) const SizedBox(height: 14),
          _buildCurriculumSection(cs, ci),
        ],

        const SizedBox(height: 18),

        // ── Validation / error banner ────────────────────────────
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Action row ───────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.brandGreen.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurriculumSection(ColorScheme cs, int ci) {
    final curriculum = _curricula[ci];
    final isCbc = curriculum.type == CurriculumType.cbc;
    final typeLabel = isCbc ? 'CBC' : '8-4-4';
    final typeSubtitle = isCbc ? 'Competency-Based Curriculum' : '8-4-4 System';
    final gradeLabels = gradeLabelsFor(curriculum.type);
    final addedGrades = curriculum.grades.map((g) => g.grade).toSet();

    return _SettingsSectionCard(
      cs: cs,
      icon: isCbc ? Icons.auto_awesome_outlined : Icons.menu_book_outlined,
      iconColor: isCbc ? AppTheme.brandIndigo : const Color(0xFF7B61FF),
      header: typeLabel,
      subtitle: typeSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Grade rows ─────────────────────────────────────────
          for (int gi = 0; gi < curriculum.grades.length; gi++) ...[
            _buildEditGradeRow(cs, ci, gi, curriculum, gradeLabels),
          ],

          // ── Add grade button ───────────────────────────────────
          if (curriculum.grades.length < gradeLabels.length) ...[
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.2),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openGradePicker(curriculum.type, addedGrades),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.brandIndigo.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: AppTheme.brandIndigo.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add grade',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.brandIndigo.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEditGradeRow(
    ColorScheme cs,
    int ci,
    int gi,
    CurriculumConfig curriculum,
    Map<int, String> gradeLabels,
  ) {
    final grade = curriculum.grades[gi];
    final gradeLabel = gradeLabels[grade.grade] ?? 'Grade ${grade.grade}';
    final expanded = _isExpanded(curriculum.type, grade.grade);
    final isLight = cs.brightness == Brightness.light;

    // Alternate row tinting for edit mode too
    final rowBg = gi.isEven
        ? Colors.transparent
        : (isLight
              ? cs.surfaceContainerHighest.withValues(alpha: 0.18)
              : cs.surfaceContainerHigh.withValues(alpha: 0.25));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Grade header ─────────────────────────────────────
        Container(
          color: rowBg,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleGrade(curriculum.type, grade.grade),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gradeLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    // Stream count badge
                    if (grade.streams.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.brandIndigo.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${grade.streams.length}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandIndigo.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    // Remove grade button
                    GestureDetector(
                      onTap: () => _removeGrade(curriculum.type, grade.grade),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Streams editor (expanded) ─────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: expanded
              ? Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF0F1F8).withValues(alpha: 0.5)
                        : cs.surfaceContainerHigh.withValues(alpha: 0.6),
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                      bottom: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stream label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 2),
                        child: Text(
                          'STREAMS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      // Stream rows
                      for (int si = 0; si < grade.streams.length; si++) ...[
                        if (si > 0) const SizedBox(height: 6),
                        _buildStreamRow(cs, ci, gi, si, curriculum.type, grade),
                      ],

                      const SizedBox(height: 10),

                      // Add stream button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _addStream(curriculum.type, gi),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandIndigo.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 13,
                                    color: AppTheme.brandIndigo.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add stream',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.brandIndigo.withValues(
                                      alpha: 0.85,
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
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStreamRow(
    ColorScheme cs,
    int ci,
    int gi,
    int si,
    CurriculumType type,
    GradeConfig grade,
  ) {
    final key = _controllerKey(ci, gi, si);
    final nameCtrl = _nameControllers[key];
    final codeCtrl = _codeControllers[key];
    if (nameCtrl == null || codeCtrl == null) return const SizedBox.shrink();
    final isLight = cs.brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isLight ? 0.35 : 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Name field
          Expanded(
            flex: 5,
            child: TextField(
              controller: nameCtrl,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: 'Stream name',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 36,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          // Code field
          Container(
            width: 56,
            color: isLight
                ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
                : cs.surfaceContainerHigh.withValues(alpha: 0.3),
            child: TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 2,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '#',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 0.5,
            height: 36,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          // Remove stream button
          GestureDetector(
            onTap: () => _removeStream(type, gi, si),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGradePicker(CurriculumType type, Set<int> alreadyAdded) {
    final cs = widget.cs;
    showEduSheet<void>(
      context: context,
      builder: (_) => _GradePickerSheet(
        curriculumType: type,
        alreadyAdded: alreadyAdded,
        onPick: (grade) {
          Navigator.of(context).pop();
          _addGrade(type, grade);
        },
        cs: cs,
      ),
    );
  }
}

// ── Curriculum toggle card ────────────────────────────────────────────────────

class _CurriculumToggleCard extends StatelessWidget {
  const _CurriculumToggleCard({
    required this.label,
    required this.subtitle,
    required this.active,
    required this.pendingRemoval,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool active;
  final bool pendingRemoval;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.brandIndigo;
    final isLight = cs.brightness == Brightness.light;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: pendingRemoval
              ? cs.errorContainer.withValues(alpha: 0.12)
              : active
              ? activeColor.withValues(alpha: 0.06)
              : isLight
              ? Colors.white
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: pendingRemoval
                ? cs.error.withValues(alpha: 0.4)
                : active
                ? activeColor.withValues(alpha: 0.45)
                : cs.outlineVariant.withValues(alpha: 0.4),
            width: active || pendingRemoval ? 1.5 : 1,
          ),
          boxShadow: active && !pendingRemoval
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: pendingRemoval
                          ? cs.error
                          : active
                          ? activeColor
                          : cs.onSurface,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (active && !pendingRemoval)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 14, color: activeColor),
              )
            else if (pendingRemoval)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.remove_rounded,
                  size: 14,
                  color: cs.error.withValues(alpha: 0.7),
                ),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Grade picker bottom sheet ─────────────────────────────────────────────────

class _GradePickerSheet extends StatelessWidget {
  const _GradePickerSheet({
    required this.curriculumType,
    required this.alreadyAdded,
    required this.onPick,
    required this.cs,
  });

  final CurriculumType curriculumType;
  final Set<int> alreadyAdded;
  final void Function(int grade) onPick;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final labels = gradeLabelsFor(curriculumType);
    final entries = labels.entries.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Handle bar ───────────────────────────────────────
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Text(
            curriculumType == CurriculumType.cbc
                ? 'Select CBC Grade'
                : 'Select 8-4-4 Grade',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Divider(
          height: 0.5,
          thickness: 0.5,
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, _) => Divider(
              height: 0.5,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.3),
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isAdded = alreadyAdded.contains(entry.key);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isAdded ? null : () => onPick(entry.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isAdded
                                  ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                        if (isAdded)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.brandIndigo.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppTheme.brandIndigo.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
      ],
    );
  }
}

// ── Settings section card ─────────────────────────────────────────────────────

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.cs,
    required this.header,
    required this.child,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
  });

  final ColorScheme cs;
  final String header;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final effectiveIconColor = iconColor ?? cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Rich header ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: effectiveIconColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: effectiveIconColor),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        header,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          // ── Separator between header and content ────────────
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
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
    return StreamBuilder<Object?>(
      stream: Stream.value(null),
      builder: (context, snapshot) {
        final MpesaConfig? config = _parseMpesaConfig(null);
        final isConfigured = config != null && config.isConfigured;
        final canEdit = permissions.can(Resource.schools, Action.update);

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
                  showEduSheet(
                    context: context,
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
                  showEduSheet(
                    context: context,
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
  late KenyaCounty? _selectedCounty;

  File? _logoImage;
  final _picker = ImagePicker();

  bool _saving = false;
  bool _isDirty = false;
  String? _saveError;
  String? _countyError;

  // ── Dirty-tracking helpers ────────────────────────────────────────────────

  bool _computeDirty() {
    final s = widget.school;
    if (_nameCtrl.text.trim() != s.name) return true;
    if (_mottoCtrl.text.trim() != (s.motto ?? '')) return true;
    if (_phoneCtrl.text.trim() != (s.phone ?? '')) return true;
    if (_emailCtrl.text.trim() != (s.email ?? '')) return true;
    if (_domainCtrl.text.trim() != (s.domain ?? '')) return true;
    final originalCounty = KenyaCounty.values
        .where((c) => c.number == s.county)
        .firstOrNull;
    if (_selectedCounty != originalCounty) return true;
    if (_logoImage != null) return true;
    return false;
  }

  void _onTextChanged() {
    final dirty = _computeDirty();
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    _nameCtrl = TextEditingController(text: s.name);
    _mottoCtrl = TextEditingController(text: s.motto ?? '');
    _phoneCtrl = TextEditingController(text: s.phone ?? '');
    _emailCtrl = TextEditingController(text: s.email ?? '');
    _domainCtrl = TextEditingController(text: s.domain ?? '');
    _selectedCounty = KenyaCounty.values
        .where((c) => c.number == s.county)
        .firstOrNull;

    // Attach listeners for dirty tracking.
    _nameCtrl.addListener(_onTextChanged);
    _mottoCtrl.addListener(_onTextChanged);
    _phoneCtrl.addListener(_onTextChanged);
    _emailCtrl.addListener(_onTextChanged);
    _domainCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mottoCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  // ── Logo picking ─────────────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() {
        _logoImage = File(picked.path);
        _isDirty = true;
      });
    }
  }

  void _clearLogo() {
    setState(() {
      _logoImage = null;
      _isDirty = _computeDirty();
    });
  }

  // ── Status update (instant, independent of save) ─────────────────────────

  Future<void> _updateStatus(SchoolStatus newStatus) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await schoolsDao.updateSchoolStatus(
        widget.school.id,
        newStatus,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.name}.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── County picker ────────────────────────────────────────────────────────

  Future<void> _openCountyPicker() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showEduSheet<KenyaCounty>(
      context: context,
      builder: (_) => _EditCountyPickerSheet(selected: _selectedCounty, cs: cs),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCounty = selected;
        _countyError = null;
        _isDirty = _computeDirty();
      });
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'School name is required.');
      return;
    }

    if (_selectedCounty == null) {
      setState(() => _countyError = 'Please select a county.');
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
      _countyError = null;
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
          county: Value(_selectedCounty!.number),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      // Save logo to local cache if a new one was picked.
      if (_logoImage != null) {
        final bytes = await _logoImage!.readAsBytes();
        await FileCache.saveBytes(bytes, FileCache.logoPath(widget.school.id));
        await schoolsDao.logLogoChange(widget.school.id, accountId: accountId);
      }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          _EditSheetHandle(cs: cs),

          // ── Title row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
            child: Row(
              children: [
                Text(
                  'Edit details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Text(
                  'Edit school',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSaveButton(
                  isDirty: _isDirty,
                  isSaving: _saving,
                  onSave: (_isDirty && !_saving) ? _save : null,
                ),
              ],
            ),
          ),

          Divider(height: 20, thickness: 1, color: cs.outlineVariant),

          // ── Scrollable form content ─────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo picker ───────────────────────────────────
                  Center(
                    child: _EditLogoSection(
                      schoolId: widget.school.id,
                      logoImage: _logoImage,
                      onPick: _pickLogo,
                      onClear: _clearLogo,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Error banner ─────────────────────────────────
                  if (_saveError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.error.withValues(alpha: 0.2),
                        ),
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

                  // ── Section: Identity ─────────────────────────────
                  _EditSectionCard(
                    cs: cs,
                    header: 'Identity',
                    children: [
                      _SheetFormField(
                        label: 'Name',
                        controller: _nameCtrl,
                        cs: cs,
                      ),
                      const SizedBox(height: 12),
                      _SheetFormField(
                        label: 'Motto',
                        controller: _mottoCtrl,
                        hint: 'Optional',
                        cs: cs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Section: Contact ──────────────────────────────
                  _EditSectionCard(
                    cs: cs,
                    header: 'Contact',
                    children: [
                      _SheetFormField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        hint: 'Optional',
                        cs: cs,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _SheetFormField(
                        label: 'Email',
                        controller: _emailCtrl,
                        hint: 'Optional',
                        cs: cs,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      _SheetFormField(
                        label: 'Domain',
                        controller: _domainCtrl,
                        hint: 'Optional — e.g. school.ac.ke',
                        cs: cs,
                      ),
                      const SizedBox(height: 12),
                      // County picker
                      _EditCountyPicker(
                        selected: _selectedCounty,
                        error: _countyError,
                        onTap: _openCountyPicker,
                        cs: cs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Status actions ────────────────────────────────
                  _SchoolStatusActions(
                    status: widget.school.status,
                    isSuperUser:
                        cache.currentUser?.user.level == UserLevel.super_,
                    onUpdate: _updateStatus,
                    cs: cs,
                  ),

                  const SizedBox(height: 20),
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
// Status action buttons — contextual transitions for the school edit sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolStatusActions extends StatelessWidget {
  const _SchoolStatusActions({
    required this.status,
    required this.isSuperUser,
    required this.onUpdate,
    required this.cs,
  });

  final SchoolStatus status;
  final bool isSuperUser;
  final void Function(SchoolStatus) onUpdate;
  final ColorScheme cs;

  static const _green = Color(0xFF4CAF50);
  static const _amber = Color(0xFFFF8F00);
  static const _grey = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    final actions = _actionsFor(status);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
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
        ),
      ],
    );
  }

  List<({SchoolStatus target, String label, Color color})> _actionsFor(
    SchoolStatus s,
  ) {
    return switch (s) {
      SchoolStatus.trial => [
        (target: SchoolStatus.active, label: 'Activate', color: _green),
        (target: SchoolStatus.suspended, label: 'Suspend', color: _amber),
        (target: SchoolStatus.cancelled, label: 'Cancel', color: _grey),
      ],
      SchoolStatus.active => [
        (target: SchoolStatus.suspended, label: 'Suspend', color: _amber),
        (target: SchoolStatus.cancelled, label: 'Cancel', color: _grey),
      ],
      SchoolStatus.cancelled => [
        (target: SchoolStatus.active, label: 'Reactivate', color: _green),
      ],
      SchoolStatus.suspended => [
        (target: SchoolStatus.active, label: 'Reactivate', color: _green),
        (target: SchoolStatus.cancelled, label: 'Cancel', color: _grey),
      ],
      SchoolStatus.deleted =>
        isSuperUser
            ? [(target: SchoolStatus.active, label: 'Restore', color: _green)]
            : [],
    };
  }
}

// ── Edit sheet helpers ────────────────────────────────────────────────────────

/// Sheet handle (drag indicator) for the edit school sheet.
class _EditSheetHandle extends StatelessWidget {
  const _EditSheetHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
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

/// Grouped section card used in the edit school sheet.
class _EditSectionCard extends StatelessWidget {
  const _EditSectionCard({
    required this.cs,
    required this.header,
    required this.children,
  });

  final ColorScheme cs;
  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo viewer + picker for the edit sheet. Pre-populates from the file cache.
class _EditLogoSection extends StatelessWidget {
  const _EditLogoSection({
    required this.schoolId,
    required this.logoImage,
    required this.onPick,
    required this.onClear,
    required this.cs,
  });

  final String schoolId;
  final File? logoImage;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant, width: 1),
              ),
              clipBehavior: Clip.hardEdge,
              child: logoImage != null && logoImage!.existsSync()
                  ? Image.file(logoImage!, fit: BoxFit.cover)
                  : FutureBuilder<File?>(
                      future: FileCache.get(FileCache.logoPath(schoolId)),
                      builder: (context, snapshot) {
                        final file = snapshot.data;
                        if (file != null && file.existsSync()) {
                          return Image.file(file, fit: BoxFit.cover);
                        }
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 22,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add logo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          if (logoImage != null)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 11,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Field-shaped county picker for the edit school sheet.
class _EditCountyPicker extends StatelessWidget {
  const _EditCountyPicker({
    required this.selected,
    required this.onTap,
    required this.cs,
    this.error,
  });

  final KenyaCounty? selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetFormLabel(label: 'County', cs: cs),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null
                    ? cs.error
                    : cs.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? 'Select county',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: selected != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: TextStyle(fontSize: 12, color: cs.error)),
        ],
      ],
    );
  }
}

/// County picker bottom sheet for the edit school sheet.
class _EditCountyPickerSheet extends StatefulWidget {
  const _EditCountyPickerSheet({required this.selected, required this.cs});

  final KenyaCounty? selected;
  final ColorScheme cs;

  @override
  State<_EditCountyPickerSheet> createState() => _EditCountyPickerSheetState();
}

class _EditCountyPickerSheetState extends State<_EditCountyPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<KenyaCounty> _filtered = KenyaCounty.values;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? KenyaCounty.values
          : KenyaCounty.values
                .where((c) => c.label.toLowerCase().contains(q))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.65;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Counties',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          Divider(height: 16, thickness: 1, color: cs.outlineVariant),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search counties…',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          // County list
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final county = _filtered[index];
                final isSelected = county == widget.selected;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(county),
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              county.number.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              county.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: isSelected ? cs.primary : cs.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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

    // TODO: persist M-Pesa config via new settings source when available
    if (mounted) Navigator.of(context).pop();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _disable() async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    // TODO: disable M-Pesa config via new settings source when available
    if (mounted) Navigator.of(context).pop();
    if (mounted) setState(() => _saving = false);
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final SchoolStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SchoolStatus.trial => ('Trial', _kColorTrial),
      SchoolStatus.active => ('Active', _kColorActive),
      SchoolStatus.cancelled => ('Cancelled', _kColorCancelled),
      SchoolStatus.suspended => ('Suspended', _kColorSuspended),
      SchoolStatus.deleted => ('Deleted', _kColorDeleted),
    };

    return Tooltip(
      message: label,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    if (!widget.permissions.can(Resource.owners, Action.create)) return;
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
          ownerUser: _foundUser!,
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

        // Fetch the freshly created user row.
        final createdUser = await usersDao.getUser(userId);

        await schoolsDao.linkOwner(
          schoolId: widget.schoolId,
          ownerUser: createdUser!,
          accountId: accountId,
        );

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

// ── Status dot colour constants ───────────────────────────────────────────────
const Color _kColorTrial = Color(0xFF42A5F5);
const Color _kColorActive = Color(0xFF26A69A);
const Color _kColorCancelled = Color(0xFFBDBDBD);
const Color _kColorSuspended = Color(0xFFFFB300);
const Color _kColorDeleted = Color(0xFFEF5350);
