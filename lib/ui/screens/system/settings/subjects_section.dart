import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/curriculum_levels.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubjectsSection — global subject catalog management
// ─────────────────────────────────────────────────────────────────────────────

/// Full subjects & topics management UI for the system settings screen.
///
/// - Curriculum toggle (CBC / 8-4-4) filters the subject list.
/// - Each subject row expands to show topics grouped by grade.
/// - Create / edit / delete for both subjects and topics.
/// - All mutations go through [CatalogDao] which writes sync logs.
///
/// Accepts [SystemPermissions] to gate create/edit/delete actions.
class SubjectsSection extends StatefulWidget {
  const SubjectsSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<SubjectsSection> createState() => _SubjectsSectionState();
}

class _SubjectsSectionState extends State<SubjectsSection> {
  CurriculumType _curriculum = CurriculumType.cbc;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchVisible = false;

  bool get _canCreate =>
      widget.permissions.can(Resource.subjects, Action.create);
  bool get _canEdit => widget.permissions.can(Resource.subjects, Action.update);
  bool get _canDelete =>
      widget.permissions.can(Resource.subjects, Action.delete);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchCtrl.clear();
        _search = '';
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _searchFocus.requestFocus();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header row ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Subjects',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 12),
              // ── Curriculum toggle ──────────────────────────────────────
              _CurriculumToggle(
                selected: _curriculum,
                onChanged: (c) => setState(() => _curriculum = c),
                cs: cs,
                isDark: isDark,
              ),
              const Spacer(),
              // ── Search toggle ──────────────────────────────────────────
              _SmallIconButton(
                icon: _searchVisible
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
                tooltip: _searchVisible ? 'Close search' : 'Search subjects',
                onTap: _toggleSearch,
                cs: cs,
              ),
              if (_canCreate) ...[
                const SizedBox(width: 4),
                _SmallIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Add subject',
                  onTap: () => _showCreateSubject(context),
                  cs: cs,
                  isPrimary: true,
                ),
              ],
            ],
          ),
        ),

        // ── Search bar ─────────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _searchVisible
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    cs: cs,
                    isDark: isDark,
                    onChanged: (v) => setState(() => _search = v),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── Subject list ───────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Subject>>(
            stream: catalogDao.watchSubjectsByCurriculum(_curriculum),
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

              var subjects = snapshot.data!;
              if (_search.isNotEmpty) {
                final q = _search.toLowerCase();
                subjects = subjects
                    .where((s) => s.name.toLowerCase().contains(q))
                    .toList();
              }

              if (subjects.isEmpty) {
                return _EmptyState(
                  curriculum: _curriculum,
                  isFiltered: _search.isNotEmpty,
                  cs: cs,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: subjects.length,
                separatorBuilder: (_, __) =>
                    AppTheme.tableRowDivider(isDark, cs),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return _SubjectTile(
                    subject: subject,
                    curriculum: _curriculum,
                    canEdit: _canEdit,
                    canDelete: _canDelete,
                    canCreate: _canCreate,
                    cs: cs,
                    isDark: isDark,
                    onEdit: () => _showEditSubject(context, subject),
                    onDelete: () => _deleteSubject(context, subject),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Create subject ─────────────────────────────────────────────────────────

  void _showCreateSubject(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 420,
            child: _CreateSubjectSheet(curriculum: _curriculum),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreateSubjectSheet(curriculum: _curriculum),
      );
    }
  }

  // ── Edit subject ───────────────────────────────────────────────────────────

  void _showEditSubject(BuildContext context, Subject subject) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 420,
            child: _EditSubjectSheet(subject: subject),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditSubjectSheet(subject: subject),
      );
    }
  }

  // ── Delete subject ─────────────────────────────────────────────────────────

  Future<void> _deleteSubject(BuildContext context, Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Delete Subject',
        message:
            'Are you sure you want to delete "${subject.name}"? '
            'All topics under this subject will also be removed.',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );
    if (confirmed != true) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await catalogDao.deleteSubject(
        id: subject.id,
        subjectName: subject.name,
        accountId: accountId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete subject: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Curriculum toggle — CBC / 8-4-4 pill switcher
// ─────────────────────────────────────────────────────────────────────────────

class _CurriculumToggle extends StatelessWidget {
  const _CurriculumToggle({
    required this.selected,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });

  final CurriculumType selected;
  final ValueChanged<CurriculumType> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.5),
        borderRadius: BorderRadius.circular(7),
        border: isDark
            ? Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TogglePill(
            label: 'CBC',
            isSelected: selected == CurriculumType.cbc,
            onTap: () => onChanged(CurriculumType.cbc),
            cs: cs,
            isDark: isDark,
          ),
          _TogglePill(
            label: '8-4-4',
            isSelected: selected == CurriculumType.eightFourFour,
            onTap: () => onChanged(CurriculumType.eightFourFour),
            cs: cs,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected && isDark
              ? Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 0.5,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon button — used for toolbar actions
// ─────────────────────────────────────────────────────────────────────────────

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.cs,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isPrimary
            ? cs.primary
            : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.4),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              icon,
              size: 15,
              color: isPrimary ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search subjects…',
          hintStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Icon(
              Icons.search_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 0,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          filled: true,
          fillColor: isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark
                  ? cs.outlineVariant.withValues(alpha: 0.3)
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark
                  ? cs.outlineVariant.withValues(alpha: 0.3)
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 1),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject tile — expandable row with topics
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectTile extends StatefulWidget {
  const _SubjectTile({
    required this.subject,
    required this.curriculum,
    required this.canEdit,
    required this.canDelete,
    required this.canCreate,
    required this.cs,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  final Subject subject;
  final CurriculumType curriculum;
  final bool canEdit;
  final bool canDelete;
  final bool canCreate;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SubjectTile> createState() => _SubjectTileState();
}

class _SubjectTileState extends State<_SubjectTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.25).animate(_expandAnim);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final subject = widget.subject;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Subject row ──────────────────────────────────────────────────
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            child: Row(
              children: [
                // Expand chevron
                RotationTransition(
                  turns: _rotateAnim,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                // Subject icon
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.07),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    size: 14,
                    color: cs.primary.withValues(alpha: isDark ? 0.8 : 0.65),
                  ),
                ),
                const SizedBox(width: 10),
                // Name
                Expanded(
                  child: Text(
                    subject.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Actions
                if (widget.canEdit)
                  _TinyAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit subject',
                    onTap: widget.onEdit,
                    cs: cs,
                  ),
                if (widget.canDelete) ...[
                  const SizedBox(width: 2),
                  _TinyAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete subject',
                    onTap: widget.onDelete,
                    cs: cs,
                    isDestructive: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        // ── Topics panel ─────────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: _TopicsPanel(
            subject: subject,
            curriculum: widget.curriculum,
            canCreate: widget.canCreate,
            canEdit: widget.canEdit,
            canDelete: widget.canDelete,
            cs: cs,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiny action button (26×26)
// ─────────────────────────────────────────────────────────────────────────────

class _TinyAction extends StatefulWidget {
  const _TinyAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.cs,
    this.isDestructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDestructive;

  @override
  State<_TinyAction> createState() => _TinyActionState();
}

class _TinyActionState extends State<_TinyAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? widget.cs.error
        : widget.cs.onSurfaceVariant;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered
                  ? color.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: color.withValues(alpha: _hovered ? 0.9 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topics panel — grade tabs + topic list
// ─────────────────────────────────────────────────────────────────────────────

class _TopicsPanel extends StatefulWidget {
  const _TopicsPanel({
    required this.subject,
    required this.curriculum,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
  });

  final Subject subject;
  final CurriculumType curriculum;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_TopicsPanel> createState() => _TopicsPanelState();
}

class _TopicsPanelState extends State<_TopicsPanel> {
  int _selectedGrade = -1;

  List<CurriculumLevel> get _levels => levelsFor(widget.curriculum);

  @override
  void didUpdateWidget(covariant _TopicsPanel old) {
    super.didUpdateWidget(old);
    if (old.curriculum != widget.curriculum) {
      _selectedGrade = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 0, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withValues(alpha: 0.2)
              : cs.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Grade selector header ────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.topic_outlined,
                size: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Topics by Grade',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Grade chips ──────────────────────────────────────────────
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _levels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final level = _levels[index];
                final isActive = _selectedGrade == level.index;
                return _GradeChip(
                  label: _shortGradeLabel(level),
                  isSelected: isActive,
                  onTap: () {
                    setState(() {
                      _selectedGrade = _selectedGrade == level.index
                          ? -1
                          : level.index;
                    });
                  },
                  cs: cs,
                  isDark: isDark,
                );
              },
            ),
          ),
          // ── Topic list for selected grade ────────────────────────────
          if (_selectedGrade >= 0) ...[
            const SizedBox(height: 10),
            _TopicList(
              subjectId: widget.subject.id,
              subjectName: widget.subject.name,
              grade: _selectedGrade,
              canCreate: widget.canCreate,
              canEdit: widget.canEdit,
              canDelete: widget.canDelete,
              cs: cs,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  String _shortGradeLabel(CurriculumLevel level) {
    final label = level.label;
    if (label.contains('—')) {
      final after = label.split('—').last.trim();
      final parenIdx = after.indexOf('(');
      return parenIdx > 0 ? after.substring(0, parenIdx).trim() : after;
    }
    final parenIdx = label.indexOf('(');
    return parenIdx > 0 ? label.substring(0, parenIdx).trim() : label;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade chip
// ─────────────────────────────────────────────────────────────────────────────

class _GradeChip extends StatelessWidget {
  const _GradeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.5 : 0.5,
                ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: isDark ? 0.5 : 0.35)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic list for a specific subject + grade
// ─────────────────────────────────────────────────────────────────────────────

class _TopicList extends StatelessWidget {
  const _TopicList({
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
  });

  final int subjectId;
  final String subjectName;
  final int grade;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Topic>>(
      stream: catalogDao.watchTopicsBySubjectAndGrade(
        subjectId: subjectId,
        grade: grade,
      ),
      builder: (context, snapshot) {
        final topics = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  '${topics.length} topic${topics.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                if (canCreate)
                  GestureDetector(
                    onTap: () => _showCreateTopic(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 12, color: cs.primary),
                          const SizedBox(width: 3),
                          Text(
                            'Add topic',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (topics.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No topics for this grade yet.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 6),
              ...topics.map(
                (topic) => _TopicRow(
                  topic: topic,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showCreateTopic(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 380,
            child: _CreateTopicSheet(
              subjectId: subjectId,
              subjectName: subjectName,
              grade: grade,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreateTopicSheet(
          subjectId: subjectId,
          subjectName: subjectName,
          grade: grade,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic row — single topic with edit/delete
// ─────────────────────────────────────────────────────────────────────────────

class _TopicRow extends StatefulWidget {
  const _TopicRow({
    required this.topic,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
  });

  final Topic topic;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_TopicRow> createState() => _TopicRowState();
}

class _TopicRowState extends State<_TopicRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final topic = widget.topic;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: _hovered
              ? cs.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                topic.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Actions — visible on hover
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canEdit)
                    _TinyAction(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit topic',
                      onTap: () => _showEditTopic(context, topic),
                      cs: cs,
                    ),
                  if (widget.canDelete) ...[
                    const SizedBox(width: 2),
                    _TinyAction(
                      icon: Icons.close_rounded,
                      tooltip: 'Delete topic',
                      onTap: () => _deleteTopic(context, topic),
                      cs: cs,
                      isDestructive: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTopic(BuildContext context, Topic topic) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(width: 380, child: _EditTopicSheet(topic: topic)),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditTopicSheet(topic: topic),
      );
    }
  }

  Future<void> _deleteTopic(BuildContext context, Topic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Delete Topic',
        message: 'Are you sure you want to delete "${topic.name}"?',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );
    if (confirmed != true) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await catalogDao.deleteTopic(
        id: topic.id,
        topicName: topic.name,
        accountId: accountId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete topic: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.curriculum,
    required this.isFiltered,
    required this.cs,
  });

  final CurriculumType curriculum;
  final bool isFiltered;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.search_off_rounded : Icons.menu_book_outlined,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered
                  ? 'No subjects match your search.'
                  : 'No ${curriculum == CurriculumType.cbc ? 'CBC' : '8-4-4'} subjects yet.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 0.1,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 4),
              Text(
                'Add subjects from the global catalog.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create subject sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateSubjectSheet extends StatefulWidget {
  const _CreateSubjectSheet({required this.curriculum});

  final CurriculumType curriculum;

  @override
  State<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<_CreateSubjectSheet> {
  final _nameCtrl = TextEditingController();
  late CurriculumType _curriculum;
  String? _nameError;
  String? _submitError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _curriculum = widget.curriculum;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Subject name is required.');
      return false;
    }
    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters.');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      setState(() => _submitError = 'No active account.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await catalogDao.createSubject(
        name: _nameCtrl.text.trim(),
        curriculum: _curriculum,
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = 'Failed to create subject. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ────────────────────────────────────────────────
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
            const SizedBox(height: 14),
            // ── Title row ─────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'New Subject',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                if (_submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  _SmallIconButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Create',
                    onTap: _submit,
                    cs: cs,
                    isPrimary: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Error ─────────────────────────────────────────────────
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],
            // ── Name field ────────────────────────────────────────────
            _SheetLabel(label: 'Name', cs: cs),
            const SizedBox(height: 6),
            _SheetTextField(
              controller: _nameCtrl,
              hint: 'e.g. Mathematics',
              error: _nameError,
              cs: cs,
              isDark: isDark,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            // ── Curriculum selector ───────────────────────────────────
            _SheetLabel(label: 'Curriculum', cs: cs),
            const SizedBox(height: 6),
            Row(
              children: [
                _CurriculumOption(
                  label: 'CBC',
                  isSelected: _curriculum == CurriculumType.cbc,
                  onTap: () => setState(() => _curriculum = CurriculumType.cbc),
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _CurriculumOption(
                  label: '8-4-4',
                  isSelected: _curriculum == CurriculumType.eightFourFour,
                  onTap: () => setState(
                    () => _curriculum = CurriculumType.eightFourFour,
                  ),
                  cs: cs,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit subject sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditSubjectSheet extends StatefulWidget {
  const _EditSubjectSheet({required this.subject});

  final Subject subject;

  @override
  State<_EditSubjectSheet> createState() => _EditSubjectSheetState();
}

class _EditSubjectSheetState extends State<_EditSubjectSheet> {
  late final TextEditingController _nameCtrl;
  late CurriculumType _curriculum;
  String? _nameError;
  String? _submitError;
  bool _submitting = false;

  bool get _isDirty =>
      _nameCtrl.text.trim() != widget.subject.name ||
      _curriculum != widget.subject.curriculum;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.subject.name);
    _curriculum = widget.subject.curriculum;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Subject name is required.');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    if (!_validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      setState(() => _submitError = 'No active account.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await catalogDao.updateSubject(
        id: widget.subject.id,
        name: _nameCtrl.text.trim() != widget.subject.name
            ? _nameCtrl.text.trim()
            : null,
        curriculum: _curriculum != widget.subject.curriculum
            ? _curriculum
            : null,
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = 'Failed to update subject. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ────────────────────────────────────────────────
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
            const SizedBox(height: 14),
            // ── Title row ─────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Edit Subject',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                if (_submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  _SmallIconButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Save',
                    onTap: _submit,
                    cs: cs,
                    isPrimary: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Error ─────────────────────────────────────────────────
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],
            // ── Name field ────────────────────────────────────────────
            _SheetLabel(label: 'Name', cs: cs),
            const SizedBox(height: 6),
            _SheetTextField(
              controller: _nameCtrl,
              hint: 'Subject name',
              error: _nameError,
              cs: cs,
              isDark: isDark,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            // ── Curriculum selector ───────────────────────────────────
            _SheetLabel(label: 'Curriculum', cs: cs),
            const SizedBox(height: 6),
            Row(
              children: [
                _CurriculumOption(
                  label: 'CBC',
                  isSelected: _curriculum == CurriculumType.cbc,
                  onTap: () => setState(() => _curriculum = CurriculumType.cbc),
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _CurriculumOption(
                  label: '8-4-4',
                  isSelected: _curriculum == CurriculumType.eightFourFour,
                  onTap: () => setState(
                    () => _curriculum = CurriculumType.eightFourFour,
                  ),
                  cs: cs,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create topic sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTopicSheet extends StatefulWidget {
  const _CreateTopicSheet({
    required this.subjectId,
    required this.subjectName,
    required this.grade,
  });

  final int subjectId;
  final String subjectName;
  final int grade;

  @override
  State<_CreateTopicSheet> createState() => _CreateTopicSheetState();
}

class _CreateTopicSheetState extends State<_CreateTopicSheet> {
  final _nameCtrl = TextEditingController();
  String? _nameError;
  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Topic name is required.');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      setState(() => _submitError = 'No active account.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await catalogDao.createTopic(
        subjectId: widget.subjectId,
        grade: widget.grade,
        name: _nameCtrl.text.trim(),
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = 'Failed to create topic. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ────────────────────────────────────────────────
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
            const SizedBox(height: 14),
            // ── Title ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Topic',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subjectName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  _SmallIconButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Create',
                    onTap: _submit,
                    cs: cs,
                    isPrimary: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Error ─────────────────────────────────────────────────
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],
            // ── Name field ────────────────────────────────────────────
            _SheetLabel(label: 'Topic name', cs: cs),
            const SizedBox(height: 6),
            _SheetTextField(
              controller: _nameCtrl,
              hint: 'e.g. Algebra, Trigonometry',
              error: _nameError,
              cs: cs,
              isDark: isDark,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit topic sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditTopicSheet extends StatefulWidget {
  const _EditTopicSheet({required this.topic});

  final Topic topic;

  @override
  State<_EditTopicSheet> createState() => _EditTopicSheetState();
}

class _EditTopicSheetState extends State<_EditTopicSheet> {
  late final TextEditingController _nameCtrl;
  String? _nameError;
  String? _submitError;
  bool _submitting = false;

  bool get _isDirty => _nameCtrl.text.trim() != widget.topic.name;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.topic.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Topic name is required.');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    if (!_validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      setState(() => _submitError = 'No active account.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await catalogDao.updateTopic(
        id: widget.topic.id,
        name: _nameCtrl.text.trim(),
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = 'Failed to update topic. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ────────────────────────────────────────────────
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
            const SizedBox(height: 14),
            // ── Title row ─────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Edit Topic',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                if (_submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  _SmallIconButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Save',
                    onTap: _submit,
                    cs: cs,
                    isPrimary: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Error ─────────────────────────────────────────────────
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],
            // ── Name field ────────────────────────────────────────────
            _SheetLabel(label: 'Topic name', cs: cs),
            const SizedBox(height: 6),
            _SheetTextField(
              controller: _nameCtrl,
              hint: 'Topic name',
              error: _nameError,
              cs: cs,
              isDark: isDark,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.hint,
    required this.cs,
    required this.isDark,
    this.error,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ColorScheme cs;
  final bool isDark;
  final String? error;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onSubmitted: onSubmitted,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: isDark
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: error != null
                      ? cs.error.withValues(alpha: 0.6)
                      : (isDark
                            ? cs.outlineVariant.withValues(alpha: 0.3)
                            : cs.outlineVariant.withValues(alpha: 0.4)),
                  width: 0.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: error != null
                      ? cs.error.withValues(alpha: 0.6)
                      : (isDark
                            ? cs.outlineVariant.withValues(alpha: 0.3)
                            : cs.outlineVariant.withValues(alpha: 0.4)),
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: error != null ? cs.error : cs.primary,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.error.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

class _CurriculumOption extends StatelessWidget {
  const _CurriculumOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.10)
              : cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.4 : 0.4,
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: isDark ? 0.5 : 0.35)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.4),
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF18222E) : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: isDestructive ? cs.error : cs.primary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.cs,
    required this.isDark,
  });

  final String message;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.error.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: cs.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.error.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
