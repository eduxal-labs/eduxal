import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/subjects_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';

import '../../../../../models/school_context.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';

/// Teachers tab — shows class teacher (active + history) and subject-teacher
/// assignments for a specific stream within a grade.
///
/// Three sections:
/// 1. **Active Class Teacher** — prominent card with primary-tinted accent.
/// 2. **Past Class Teachers** — collapsible list (default collapsed).
/// 3. **Subject Teachers** — list of subject-teacher rows.
class TeachersTab extends StatefulWidget {
  const TeachersTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  @override
  State<TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<TeachersTab>
    with AutomaticKeepAliveClientMixin {
  late final SubjectsDao _dao;

  late Stream<({ClassTeacher classTeacher, UsersData user})?> _activeCtStream;
  late Stream<List<({ClassTeacher classTeacher, UsersData user})>>
  _historyStream;
  late Stream<
    List<({SubjectTeacher subject, UsersData teacher, String subjectName})>
  >
  _subjectsStream;

  bool _historyExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = SubjectsDao(db);
    _buildStreams();
  }

  @override
  void didUpdateWidget(covariant TeachersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() {
        _buildStreams();
        _historyExpanded = false;
      });
    }
  }

  void _buildStreams() {
    _activeCtStream = _dao.watchActiveClassTeacher(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    _historyStream = _dao.watchClassTeacherHistory(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    _subjectsStream = _dao.watchSubjectsForClass(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Section 1: Active class teacher ──────────────────────────────
        _buildActiveClassTeacherSection(cs, isDark),

        const SizedBox(height: 20),

        // ── Section 2: Past class teachers ───────────────────────────────
        _buildPastClassTeachersSection(cs, isDark),

        const SizedBox(height: 20),

        // ── Section 3: Subject teachers ──────────────────────────────────
        _buildSubjectTeachersSection(cs, isDark),
      ],
    );
  }

  // ── Section 1: Active Class Teacher ────────────────────────────────────────

  Widget _buildActiveClassTeacherSection(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionHeader(cs, isDark, 'Class Teacher', Icons.school_rounded),
        const SizedBox(height: 8),
        StreamBuilder<({ClassTeacher classTeacher, UsersData user})?>(
          stream: _activeCtStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildLoading(cs);
            }

            final active = snapshot.data;

            if (active == null) {
              return _buildEmptyPlaceholder(
                cs,
                Icons.person_outline_rounded,
                'No class teacher assigned',
              );
            }

            return _ActiveClassTeacherCard(
              active: active,
              cs: cs,
              isDark: isDark,
            );
          },
        ),
      ],
    );
  }

  // ── Section 2: Past Class Teachers ─────────────────────────────────────────

  Widget _buildPastClassTeachersSection(ColorScheme cs, bool isDark) {
    return StreamBuilder<List<({ClassTeacher classTeacher, UsersData user})>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allEntries = snapshot.data ?? [];
        // Filter to only past class teachers (end IS NOT NULL).
        final pastEntries = allEntries
            .where((e) => e.classTeacher.end != null)
            .toList();

        if (pastEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header with chevron toggle ─────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _historyExpanded = !_historyExpanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Left accent line
                  Container(
                    width: 2,
                    height: 14,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previous Class Teachers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _buildCountBadge(cs, isDark, pastEntries.length),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _historyExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Collapsible content ────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in pastEntries)
                    _PastClassTeacherCard(
                      entry: entry,
                      cs: cs,
                      isDark: isDark,
                    ),
                ],
              ),
              crossFadeState: _historyExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        );
      },
    );
  }

  // ── Section 3: Subject Teachers ────────────────────────────────────────────

  Widget _buildSubjectTeachersSection(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<
          List<
            ({SubjectTeacher subject, UsersData teacher, String subjectName})
          >
        >(
          stream: _subjectsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSectionHeader(
                    cs,
                    isDark,
                    'Subject Teachers',
                    Icons.menu_book_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildLoading(cs),
                ],
              );
            }

            final entries = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header with count badge ──────────────────────────────
                Row(
                  children: [
                    _buildSectionHeader(
                      cs,
                      isDark,
                      'Subject Teachers',
                      Icons.menu_book_rounded,
                    ),
                    if (entries.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildCountBadge(cs, isDark, entries.length),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                if (entries.isEmpty)
                  _buildEmptyPlaceholder(
                    cs,
                    Icons.menu_book_outlined,
                    'No subjects assigned to ${widget.streamName}',
                  )
                else
                  for (final entry in entries)
                    _SubjectTeacherCard(
                      entry: entry,
                      cs: cs,
                      isDark: isDark,
                    ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    ColorScheme cs,
    bool isDark,
    String title,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 14,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          icon,
          size: 13,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(ColorScheme cs, bool isDark, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 0.5,
        ),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.primary.withValues(alpha: 0.7),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(ColorScheme cs, IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Active Class Teacher Card
// ═════════════════════════════════════════════════════════════════════════════

class _ActiveClassTeacherCard extends StatefulWidget {
  const _ActiveClassTeacherCard({
    required this.active,
    required this.cs,
    required this.isDark,
  });

  final ({ClassTeacher classTeacher, UsersData user}) active;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_ActiveClassTeacherCard> createState() =>
      _ActiveClassTeacherCardState();
}

class _ActiveClassTeacherCardState extends State<_ActiveClassTeacherCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final active = widget.active;
    final startLabel = _formatDaysDate(active.classTeacher.start);
    final accentColor = cs.primary;

    final idleBg = isDark
        ? accentColor.withValues(alpha: 0.08)
        : accentColor.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.14)
        : accentColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? accentColor.withValues(alpha: 0.20)
        : accentColor.withValues(alpha: 0.12);

    return ScaleTransition(
      scale: _scaleAnim,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () {
            // Future: navigate to teacher detail
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isPressed
                  ? pressBg
                  : _isHovered
                      ? hoverBg
                      : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered || _isPressed
                    ? accentColor.withValues(alpha: isDark ? 0.40 : 0.30)
                    : accentColor.withValues(alpha: isDark ? 0.20 : 0.15),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Primary accent bar ─────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHovered || _isPressed ? 4 : 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(
                              alpha: _isHovered || _isPressed ? 1.0 : 0.8,
                            ),
                            accentColor.withValues(
                              alpha: _isHovered || _isPressed ? 0.7 : 0.4,
                            ),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),

                    // ── Content ────────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            UserAvatar(
                              userId: active.user.id,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    active.user.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(
                                            alpha: isDark ? 0.2 : 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.kChipRadius,
                                          ),
                                        ),
                                        child: Text(
                                          'Active',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: accentColor,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 10,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Since $startLabel',
                                        style: TextStyle(
                                          fontSize: 11,
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

                            const SizedBox(width: 4),

                            // ── Chevron ────────────────────────────────
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              offset: Offset(
                                _isHovered ? 0.15 : 0.0,
                                0,
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isHovered ? 0.8 : 0.3,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: _isHovered
                                      ? accentColor
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Past Class Teacher Card
// ═════════════════════════════════════════════════════════════════════════════

class _PastClassTeacherCard extends StatefulWidget {
  const _PastClassTeacherCard({
    required this.entry,
    required this.cs,
    required this.isDark,
  });

  final ({ClassTeacher classTeacher, UsersData user}) entry;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_PastClassTeacherCard> createState() => _PastClassTeacherCardState();
}

class _PastClassTeacherCardState extends State<_PastClassTeacherCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final entry = widget.entry;
    final startLabel = _formatDaysDate(entry.classTeacher.start);
    final endLabel = entry.classTeacher.end != null
        ? _formatDaysDate(entry.classTeacher.end!)
        : '—';

    // Muted neutral for past items
    final neutralColor = cs.onSurfaceVariant;

    final idleBg = isDark
        ? neutralColor.withValues(alpha: 0.04)
        : neutralColor.withValues(alpha: 0.03);
    final hoverBg = isDark
        ? neutralColor.withValues(alpha: 0.08)
        : neutralColor.withValues(alpha: 0.06);
    final pressBg = isDark
        ? neutralColor.withValues(alpha: 0.12)
        : neutralColor.withValues(alpha: 0.09);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () {
              // Future: navigate to teacher detail
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _isPressed
                    ? pressBg
                    : _isHovered
                        ? hoverBg
                        : idleBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? neutralColor.withValues(alpha: isDark ? 0.18 : 0.14)
                      : neutralColor.withValues(alpha: isDark ? 0.08 : 0.06),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Muted grey accent bar ───────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 3 : 2,
                        decoration: BoxDecoration(
                          color: neutralColor.withValues(
                            alpha: _isHovered || _isPressed ? 0.35 : 0.18,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Content ─────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(userId: entry.user.id, radius: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      entry.user.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 9,
                                          color:
                                              cs.onSurfaceVariant.withValues(
                                                alpha: 0.3,
                                              ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$startLabel — $endLabel',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color:
                                                cs.onSurfaceVariant.withValues(
                                                  alpha: 0.4,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // ── Chevron ──────────────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(
                                  _isHovered ? 0.15 : 0.0,
                                  0,
                                ),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isHovered ? 0.6 : 0.25,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Subject Teacher Card
// ═════════════════════════════════════════════════════════════════════════════

class _SubjectTeacherCard extends StatefulWidget {
  const _SubjectTeacherCard({
    required this.entry,
    required this.cs,
    required this.isDark,
  });

  final ({SubjectTeacher subject, UsersData teacher, String subjectName})
      entry;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_SubjectTeacherCard> createState() => _SubjectTeacherCardState();
}

class _SubjectTeacherCardState extends State<_SubjectTeacherCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final entry = widget.entry;
    final label = entry.subjectName;
    final subjectColor = _subjectColor(entry.subject.subject);

    final idleBg = isDark
        ? subjectColor.withValues(alpha: 0.06)
        : subjectColor.withValues(alpha: 0.03);
    final hoverBg = isDark
        ? subjectColor.withValues(alpha: 0.12)
        : subjectColor.withValues(alpha: 0.07);
    final pressBg = isDark
        ? subjectColor.withValues(alpha: 0.18)
        : subjectColor.withValues(alpha: 0.11);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () {
              // Future: navigate to subject detail
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _isPressed
                    ? pressBg
                    : _isHovered
                        ? hoverBg
                        : idleBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? subjectColor.withValues(alpha: isDark ? 0.30 : 0.20)
                      : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Subject color accent bar ────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 4 : 3,
                        decoration: BoxDecoration(
                          color: subjectColor.withValues(
                            alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Content ─────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Subject name
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Teacher avatar + name
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    userId: entry.teacher.id,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 120),
                                    child: Text(
                                      entry.teacher.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 4),

                              // ── Animated chevron ─────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(
                                  _isHovered ? 0.15 : 0.0,
                                  0,
                                ),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isHovered ? 0.8 : 0.3,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _isHovered
                                        ? subjectColor
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Subtle subject color based on subject code.
Color _subjectColor(int subject) {
  const palette = [
    Color(0xFF42A5F5), // blue
    Color(0xFF66BB6A), // green
    Color(0xFFAB47BC), // purple
    Color(0xFFEF5350), // red
    Color(0xFFFFA726), // orange
    Color(0xFF26A69A), // teal
    Color(0xFF5C6BC0), // indigo
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF78909C), // blue grey
  ];
  return palette[subject % palette.length];
}

/// Converts days since epoch to a readable date string (e.g. "12 Jan 2024").
String _formatDaysDate(int daysSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

const _months = [
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
