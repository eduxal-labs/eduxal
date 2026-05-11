import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../models/result.dart';
import '../../../../models/question.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/school_config.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_empty_state.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_sheet.dart';
import 'bulk_import_sheet.dart';
import 'create_question_sheet.dart';
import 'questions_list_page.dart';
import 'multi_file_import_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubjectsSection — global subject catalog management
// ─────────────────────────────────────────────────────────────────────────────

/// Full subjects & topics management UI for the system settings screen.
///
/// - Curriculum toggle (CBC / 8-4-4) filters the subject list.
/// - Each subject row expands to show topics grouped by grade.
/// - Each topic row expands (ready for future learning materials).
/// - Create / edit / delete for both subjects and topics.
/// - All mutations go through [CatalogDao] which writes sync logs.
///
/// Accepts [SystemPermissions] to gate create/edit/delete actions.
class SubjectsSection extends StatefulWidget {
  const SubjectsSection({
    super.key,
    required this.permissions,
    required this.curriculumNotifier,
  });

  final SystemPermissions permissions;
  final ValueNotifier<CurriculumType> curriculumNotifier;

  @override
  State<SubjectsSection> createState() => _SubjectsSectionState();
}

class _SubjectsSectionState extends State<SubjectsSection> {
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  int _selectedGrade = -1;
  Map<int, String> _subjectNames = {};

  bool get _canCreate =>
      widget.permissions.can(Resource.subjects, Action.create);
  bool get _canEdit => widget.permissions.can(Resource.subjects, Action.update);
  bool get _canDelete =>
      widget.permissions.can(Resource.subjects, Action.delete);

  List<MapEntry<int, String>> get _gradeEntries {
    final labels = gradeLabelsFor(widget.curriculumNotifier.value);
    return labels.entries.where((e) {
      if (widget.curriculumNotifier.value == CurriculumType.cbc && e.key <= 2) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Read permission guard (E04) ──────────────────────────────────────────
    if (!widget.permissions.can(Resource.subjects, Action.read)) {
      return const EduEmptyState(
        icon: Icons.lock_outline,
        title: 'Access restricted',
        subtitle: 'You don\'t have permission to view subjects.',
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return ValueListenableBuilder<CurriculumType>(
      valueListenable: widget.curriculumNotifier,
      builder: (context, currentCurriculum, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search bar + actions ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
                top: 4,
                left: 16,
                right: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      cs: cs,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  if (_canCreate)
                    IconButton(
                      icon: const Icon(Icons.upload_file_rounded, size: 22),
                      tooltip: 'Import questions from JSON files',
                      onPressed: _openBulkFileImport,
                    ),
                ],
              ),
            ),

            // ── Grade tabs ─────────────────────────────────────────────────
            if (_gradeEntries.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8, bottom: 6),
                child: SizedBox(
                  height: 30,
                  child: Row(
                    children: [
                      _GradeChip(
                        label: 'All',
                        isSelected: _selectedGrade == -1,
                        onTap: () => setState(() => _selectedGrade = -1),
                        cs: cs,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _gradeEntries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 5),
                          itemBuilder: (context, index) {
                            final entry = _gradeEntries[index];
                            final isActive = _selectedGrade == entry.key;
                            return _GradeChip(
                              label: entry.value,
                              isSelected: isActive,
                              onTap: () {
                                setState(() {
                                  _selectedGrade =
                                      isActive ? -1 : entry.key;
                                });
                              },
                              cs: cs,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Subject list ───────────────────────────────────────────────
            Expanded(
              child: _selectedGrade >= 0
                  ? _buildGradeFilteredSubjects(currentCurriculum, cs, isDark)
                  : _buildAllSubjects(currentCurriculum, cs, isDark),
            ),
          ],
        );
      },
    );
  }

  /// Builds the subject list filtered by the selected grade.
  /// Uses [watchTopicsByCurriculum] to group topics by subject, then filters
  /// to topics matching [_selectedGrade]. Only subjects with ≥1 topic in that
  /// grade are shown. Subject names are resolved from a cached lookup map.
  Widget _buildGradeFilteredSubjects(
    CurriculumType curriculum,
    ColorScheme cs,
    bool isDark,
  ) {
    return StreamBuilder<List<Topic>>(
      stream: catalogDao.watchTopicsByCurriculum(curriculum),
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

        final allTopics = snapshot.data!;

        // Populate subject name cache for any new subject IDs
        catalogDao.getSubjects().then((subjects) {
          final map = <int, String>{};
          for (final s in subjects) {
            map[s.id] = s.name;
          }
          if (mounted) setState(() => _subjectNames = map);
        });

        // Group topics by subject, filtered to selected grade
        final grouped = <int, List<Topic>>{};
        for (final t in allTopics) {
          if (t.grade != _selectedGrade) continue;
          grouped.putIfAbsent(t.subject, () => []).add(t);
        }

        // Build sorted subject entries
        final entries = grouped.entries.toList()
          ..sort((a, b) {
            final nameA =
                _subjectNames[a.key]?.toLowerCase() ?? '';
            final nameB =
                _subjectNames[b.key]?.toLowerCase() ?? '';
            return nameA.compareTo(nameB);
          });

        // Apply search filter
        final filtered = _search.isEmpty
            ? entries
            : entries.where((e) {
                final name = _subjectNames[e.key] ?? '';
                return name.toLowerCase().contains(_search.toLowerCase());
              }).toList();

        if (filtered.isEmpty) {
          return _EmptyState(
            curriculum: curriculum,
            isFiltered: _search.isNotEmpty || _selectedGrade >= 0,
            cs: cs,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 2),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => AppTheme.tableRowDivider(isDark, cs),
          itemBuilder: (context, index) {
            final entry = filtered[index];
            final subjectId = entry.key;
            final topics = entry.value;
            final subjectName =
                _subjectNames[subjectId] ?? 'Subject #$subjectId';
            return _SubjectTile(
              subject: Subject(
                id: subjectId,
                name: subjectName,
                curriculum: curriculum,
                created: BigInt.zero,
                updated: BigInt.zero,
              ),
              curriculum: curriculum,
              canEdit: _canEdit,
              canDelete: _canDelete,
              canCreate: _canCreate,
              cs: cs,
              isDark: isDark,
              selectedGrade: _selectedGrade,
              topics: topics,
              onEdit: () {
                final s = Subject(
                  id: subjectId,
                  name: subjectName,
                  curriculum: curriculum,
                  created: BigInt.zero,
                  updated: BigInt.zero,
                );
                _showEditSubject(context, s);
              },
              onDelete: () {
                final s = Subject(
                  id: subjectId,
                  name: subjectName,
                  curriculum: curriculum,
                  created: BigInt.zero,
                  updated: BigInt.zero,
                );
                _deleteSubject(context, s);
              },
            );
          },
        );
      },
    );
  }

  /// Builds the subject list showing ALL subjects (no grade filter).
  /// Keeps the original per-subject grade selector behaviour.
  Widget _buildAllSubjects(
    CurriculumType curriculum,
    ColorScheme cs,
    bool isDark,
  ) {
    return StreamBuilder<List<Subject>>(
      stream: catalogDao.watchSubjectsByCurriculum(curriculum),
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
            curriculum: curriculum,
            isFiltered: _search.isNotEmpty,
            cs: cs,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 2),
          itemCount: subjects.length,
          separatorBuilder: (_, __) =>
              AppTheme.tableRowDivider(isDark, cs),
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return _SubjectTile(
              subject: subject,
              curriculum: curriculum,
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
    );
  }

  void _openBulkFileImport() {
    showEduSheet(
      context: context,
      builder: (_) => MultiFileImportSheet(
        subjectName: 'Auto-detect',
        subjectId: null, // null = auto-detect from JSON
        curriculum: widget.curriculumNotifier.value,
        onImported: () => setState(() {}),
      ),
      maxWidth: 680,
    );
  }

  void _showEditSubject(BuildContext context, Subject subject) {
    showEduSheet(
      context: context,
      title: 'Edit Subject',
      maxWidth: 420,
      builder: (_) => _EditSubjectSheet(subject: subject),
    );
  }

  Future<void> _deleteSubject(BuildContext context, Subject subject) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Subject',
      message:
          'Are you sure you want to delete "${subject.name}"? '
          'All topics under this subject will also be removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

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
// Small icon button — toolbar actions (28×28)
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
    this.selectedGrade = -1,
    this.topics,
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
  final int selectedGrade;
  final List<Topic>? topics;

  @override
  State<_SubjectTile> createState() => _SubjectTileState();
}

class _SubjectTileState extends State<_SubjectTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _hovered = false;
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
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: _hovered
                  ? cs.primary.withValues(alpha: 0.03)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Expand chevron
                  RotationTransition(
                    turns: _rotateAnim,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _expanded
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subject icon
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: isDark ? 0.10 : 0.06),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
                      size: 14,
                      color: cs.primary.withValues(alpha: isDark ? 0.7 : 0.55),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Subject name
                  Expanded(
                    child: Text(
                      subject.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _expanded
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: cs.onSurface,
                        letterSpacing: 0.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Topic count badge
                  StreamBuilder<int>(
                    stream: catalogDao.watchTopicCountForSubject(subject.id),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(
                            alpha: isDark ? 0.12 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: cs.primary.withValues(
                              alpha: isDark ? 0.8 : 0.7,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Actions — visible on hover or when expanded
                  AnimatedOpacity(
                    opacity: _hovered || _expanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.canCreate) ...[
                          _TinyAction(
                            icon: Icons.upload_file_outlined,
                            tooltip: 'Import question files',
                            onTap: () {
                              showEduSheet(
                                context: context,
                                maxWidth: 620,
                                builder: (_) => MultiFileImportSheet(
                                  subjectName: subject.name,
                                  subjectId: subject.id,
                                  curriculum: widget.curriculum,
                                  onImported: () {
                                    // Trigger rebuild so topic counts refresh
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                            cs: cs,
                          ),
                          const SizedBox(width: 2),
                        ],
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
                ],
              ),
            ),
          ),
        ),
        // ── Topics panel ─────────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: widget.selectedGrade >= 0 && widget.topics != null
              ? _TopicList(
                  subjectId: subject.id,
                  subjectName: subject.name,
                  grade: widget.selectedGrade,
                  gradeLabel:
                      gradeLabelsFor(widget.curriculum)[widget.selectedGrade] ??
                          'Grade ${widget.selectedGrade}',
                  canCreate: widget.canCreate,
                  canEdit: widget.canEdit,
                  canDelete: widget.canDelete,
                  cs: cs,
                  isDark: isDark,
                )
              : _TopicsPanel(
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
// Tiny action button (26×26) with hover effect
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
// Topics panel — grade filter + topic list
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

  /// Individual grade entries for the current curriculum as (gradeNumber, label)
  /// pairs, excluding PP1/PP2 for CBC.
  List<MapEntry<int, String>> get _gradeEntries {
    final labels = gradeLabelsFor(widget.curriculum);
    return labels.entries.where((e) {
      // Exclude PP1 (1) and PP2 (2) for CBC per AGENT.md §P8
      if (widget.curriculum == CurriculumType.cbc && e.key <= 2) {
        return false;
      }
      return true;
    }).toList();
  }

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
    final grades = _gradeEntries;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.20)
            : cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withValues(alpha: 0.15)
              : cs.outlineVariant.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Grade selector row ───────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.school_outlined,
                size: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 5),
              Text(
                'Select Grade',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (_selectedGrade >= 0)
                GestureDetector(
                  onTap: () => setState(() => _selectedGrade = -1),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: cs.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Grade chips ──────────────────────────────────────────────
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: grades.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final entry = grades[index];
                final gradeNum = entry.key;
                final isActive = _selectedGrade == gradeNum;
                return _GradeChip(
                  label: entry.value,
                  isSelected: isActive,
                  onTap: () {
                    setState(() {
                      _selectedGrade = _selectedGrade == gradeNum
                          ? -1
                          : gradeNum;
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
            Container(
              height: 0.5,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.18),
            ),
            const SizedBox(height: 6),
            _TopicList(
              subjectId: widget.subject.id,
              subjectName: widget.subject.name,
              grade: _selectedGrade,
              gradeLabel:
                  gradeLabelsFor(widget.curriculum)[_selectedGrade] ??
                  'Grade $_selectedGrade',
              canCreate: widget.canCreate,
              canEdit: widget.canEdit,
              canDelete: widget.canDelete,
              cs: cs,
              isDark: isDark,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tap a grade to view and manage topics',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade chip — selectable filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _GradeChip extends StatefulWidget {
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
  State<_GradeChip> createState() => _GradeChipState();
}

class _GradeChipState extends State<_GradeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: isDark ? 0.20 : 0.12)
                : _hovered
                ? cs.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.7 : 0.7,
                  )
                : cs.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.4 : 0.45,
                  ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? cs.primary.withValues(alpha: isDark ? 0.45 : 0.30)
                  : _hovered
                  ? cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.5)
                  : cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: _hovered ? 0.8 : 0.6),
              letterSpacing: 0.1,
            ),
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
    required this.gradeLabel,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
  });

  final int subjectId;
  final String subjectName;
  final int grade;
  final String gradeLabel;
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
            // ── Header row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  Text(
                    '$gradeLabel · ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${topics.length} topic${topics.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  if (canCreate)
                    _AddButton(
                      label: 'Add topic',
                      onTap: () => _showCreateTopic(context),
                      cs: cs,
                      isDark: isDark,
                    ),
                ],
              ),
            ),

            if (topics.isEmpty) ...[
              const SizedBox(height: 14),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.topic_outlined,
                      size: 22,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No topics for $gradeLabel yet',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: 6),
              ...List.generate(topics.length, (i) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i > 0)
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: cs.outlineVariant.withValues(
                          alpha: isDark ? 0.08 : 0.12,
                        ),
                      ),
                    _TopicTile(
                      topic: topics[i],
                      subjectName: subjectName,
                      canCreate: canCreate,
                      canEdit: canEdit,
                      canDelete: canDelete,
                      cs: cs,
                      isDark: isDark,
                    ),
                  ],
                );
              }),
            ],
          ],
        );
      },
    );
  }

  void _showCreateTopic(BuildContext context) {
    showEduSheet(
      context: context,
      title: 'New Topic',
      maxWidth: 380,
      builder: (_) => _CreateTopicSheet(
        subjectId: subjectId,
        subjectName: subjectName,
        grade: grade,
        gradeLabel: gradeLabel,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add button — small inline action button
// ─────────────────────────────────────────────────────────────────────────────

class _AddButton extends StatefulWidget {
  const _AddButton({
    required this.label,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.primary.withValues(alpha: isDark ? 0.16 : 0.10)
                : cs.primary.withValues(alpha: isDark ? 0.10 : 0.06),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 12,
                color: cs.primary.withValues(alpha: _hovered ? 1.0 : 0.8),
              ),
              const SizedBox(width: 3),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: cs.primary.withValues(alpha: _hovered ? 1.0 : 0.8),
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
// Topic tile — expandable row (mirrors subject tile pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _TopicTile extends StatefulWidget {
  const _TopicTile({
    required this.topic,
    required this.subjectName,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
  });

  final Topic topic;
  final String subjectName;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _hovered = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;
  int? _questionCount;
  bool _countLoading = true;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.25).animate(_expandAnim);
    _refreshQuestionCount();
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

  void _refreshQuestionCount() {
    setState(() => _countLoading = true);
    questionBankService
        .listQuestions(
          topicId: widget.topic.id,
          page: 0,
          pageSize: 1,
          accessToken: accessToken,
        )
        .then((result) {
          if (!mounted) return;
          setState(() {
            _countLoading = false;
            _questionCount = switch (result) {
              Ok(value: final v) => v.$2,
              Err() => null,
            };
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final topic = widget.topic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Topic row ────────────────────────────────────────────────────
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: _hovered
                    ? cs.primary.withValues(alpha: 0.03)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  // Expand chevron
                  RotationTransition(
                    turns: _rotateAnim,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: _expanded
                          ? cs.primary.withValues(alpha: 0.6)
                          : cs.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Topic color indicator
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(
                        alpha: isDark ? 0.10 : 0.06,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.topic_outlined,
                      size: 11,
                      color: cs.tertiary.withValues(alpha: isDark ? 0.6 : 0.45),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Topic name
                  Expanded(
                    child: Text(
                      topic.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _expanded
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: cs.onSurface.withValues(alpha: 0.85),
                        letterSpacing: 0.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Question count badge
                  if (_countLoading) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 30,
                      height: 14,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                    ),
                  ] else if (_questionCount != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(
                          alpha: isDark ? 0.30 : 0.60,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        '$_questionCount Qs',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.80),
                        ),
                      ),
                    ),
                  ],
                  // Actions — visible on hover or expanded
                  AnimatedOpacity(
                    opacity: _hovered || _expanded ? 1.0 : 0.0,
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
          ),
        ),
        // ── Expanded content — learning materials + questions ────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: _TopicExpandedContent(
            topic: topic,
            subjectName: widget.subjectName,
            canCreate: widget.canCreate,
            canEdit: widget.canEdit,
            canDelete: widget.canDelete,
            cs: cs,
            isDark: isDark,
            onQuestionCountChanged: _refreshQuestionCount,
          ),
        ),
      ],
    );
  }

  void _showEditTopic(BuildContext context, Topic topic) {
    showEduSheet(
      context: context,
      title: 'Edit Topic',
      maxWidth: 380,
      builder: (_) => _EditTopicSheet(topic: topic),
    );
  }

  Future<void> _deleteTopic(BuildContext context, Topic topic) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Topic',
      message: 'Are you sure you want to delete "${topic.name}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

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
// Topic expanded content — learning materials + question management panel
// ─────────────────────────────────────────────────────────────────────────────

class _TopicExpandedContent extends StatefulWidget {
  const _TopicExpandedContent({
    required this.topic,
    required this.subjectName,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
    this.onQuestionCountChanged,
  });

  final Topic topic;
  final String subjectName;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onQuestionCountChanged;

  @override
  State<_TopicExpandedContent> createState() => _TopicExpandedContentState();
}

class _TopicExpandedContentState extends State<_TopicExpandedContent> {
  List<Question>? _questions;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void didUpdateWidget(covariant _TopicExpandedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic.id != widget.topic.id) {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await questionBankService.listQuestions(
      topicId: widget.topic.id,
      page: 0,
      pageSize: 200,
      accessToken: accessToken,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Ok(value: final v):
          _questions = v.$1;
          _total = v.$2;
          _error = null;
        case Err():
          _error = 'Could not load questions';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.only(left: 28, right: 4, bottom: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.10 : 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Questions header with actions ───────────────────────────
          Row(
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.40),
              ),
              const SizedBox(width: 6),
              Text(
                'Questions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              if (widget.canCreate)
                _TinyAction(
                  icon: Icons.add_rounded,
                  tooltip: 'Add question',
                  onTap: () {
                    showEduSheet(
                      context: context,
                      maxWidth: 520,
                      builder: (_) => CreateQuestionSheet(
                        topicId: widget.topic.id,
                        topicName: widget.topic.name,
                        subjectName: widget.subjectName,
                        grade: widget.topic.grade,
                        onCreated: () {
                          _loadQuestions();
                          widget.onQuestionCountChanged?.call();
                        },
                      ),
                    );
                  },
                  cs: cs,
                ),
              if (widget.canCreate) const SizedBox(width: 2),
              _TinyAction(
                icon: Icons.file_upload_outlined,
                tooltip: 'Import questions',
                onTap: () {
                  showEduSheet(
                    context: context,
                    maxWidth: 520,
                    builder: (_) => BulkImportSheet(
                      topicId: widget.topic.id,
                      topicName: widget.topic.name,
                      subjectName: widget.subjectName,
                      onImported: () {
                        _loadQuestions();
                        widget.onQuestionCountChanged?.call();
                      },
                    ),
                  );
                },
                cs: cs,
              ),
              const SizedBox(width: 2),
              _TinyAction(
                icon: Icons.open_in_full_rounded,
                tooltip: 'Open full page',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionsListPage(
                        topicId: widget.topic.id,
                        topicName: widget.topic.name,
                        subjectName: widget.subjectName,
                        grade: widget.topic.grade,
                        canEdit: widget.canEdit,
                        canDelete: widget.canDelete,
                        canCreate: widget.canCreate,
                      ),
                    ),
                  );
                },
                cs: cs,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Question list ───────────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            )
          else if (_error != null)
            _QuestionErrorState(cs: cs, isDark: isDark)
          else
            _QuestionList(
              questions: _questions!,
              total: _total,
              topic: widget.topic,
              subjectName: widget.subjectName,
              canEdit: widget.canEdit,
              canDelete: widget.canDelete,
              cs: cs,
              isDark: isDark,
              onChanged: () {
                _loadQuestions();
                widget.onQuestionCountChanged?.call();
              },
            ),
        ],
      ),
    );
  }
}

class _QuestionErrorState extends StatelessWidget {
  const _QuestionErrorState({required this.cs, required this.isDark});
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 4),
            Text(
              'Could not load questions',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({
    required this.questions,
    required this.total,
    required this.topic,
    required this.subjectName,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final List<Question> questions;
  final int total;
  final Topic topic;
  final String subjectName;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'No questions yet',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    final shown = questions.length;
    final hasMore = total > shown;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Showing $shown of $total question${total == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 6),
        ...List.generate(questions.length, (i) {
          return Padding(
            padding: EdgeInsets.only(top: i > 0 ? 6 : 0),
            child: _QuestionTile(
              question: questions[i],
              index: i,
              topic: topic,
              subjectName: subjectName,
              canEdit: canEdit,
              canDelete: canDelete,
              cs: cs,
              isDark: isDark,
              onChanged: onChanged,
            ),
          );
        }),
        if (hasMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuestionsListPage(
                    topicId: topic.id,
                    topicName: topic.name,
                    subjectName: subjectName,
                    grade: topic.grade,
                    canEdit: canEdit,
                    canDelete: canDelete,
                    canCreate: true,
                  ),
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'View all $total questions →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question tile — expandable card with full question detail
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionTile extends StatefulWidget {
  const _QuestionTile({
    required this.question,
    required this.index,
    required this.topic,
    required this.subjectName,
    required this.canEdit,
    required this.canDelete,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final Question question;
  final int index;
  final Topic topic;
  final String subjectName;
  final bool canEdit;
  final bool canDelete;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onChanged;

  @override
  State<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<_QuestionTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
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
    final q = widget.question;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.25)
            : cs.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.18),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Question header (always visible) ──────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  // Expand indicator
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Question number
                  Text(
                    'Q${widget.index + 1}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Type badge
                  if (q.type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(
                          alpha: isDark ? 0.15 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        q.type,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: cs.tertiary.withValues(
                            alpha: isDark ? 0.7 : 0.55,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Marks badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(
                        alpha: isDark ? 0.12 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${q.marks}m',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cs.primary.withValues(
                          alpha: isDark ? 0.7 : 0.6,
                        ),
                      ),
                    ),
                  ),
                  // Difficulty dots
                  if (q.difficulty > 0) ...[
                    const SizedBox(width: 6),
                    ...List.generate(
                      q.difficulty.clamp(1, 5),
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 1),
                        child: Icon(
                          Icons.circle_rounded,
                          size: 6,
                          color: q.difficulty >= 4
                              ? cs.error.withValues(alpha: 0.5)
                              : q.difficulty >= 3
                                  ? cs.tertiary.withValues(alpha: 0.55)
                                  : cs.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Body preview (truncated)
                  Flexible(
                    flex: 2,
                    child: Text(
                      q.body.length > 100
                          ? '${q.body.substring(0, 100)}…'
                          : q.body,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          // ── Expanded detail ───────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 0.5,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.10 : 0.14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Full body
                  _DetailLabel(label: 'Question', cs: cs, isDark: isDark),
                  const SizedBox(height: 4),
                  Text(
                    q.body,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                  // Stimulus (if present)
                  if (q.stimulus != null && q.stimulus!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailLabel(
                      label: 'Stimulus / Context',
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 4),
                    _StimulusPreview(stimulus: q.stimulus!, cs: cs, isDark: isDark),
                  ],
                  // Parts
                  if (q.parts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailLabel(label: 'Parts', cs: cs, isDark: isDark),
                    const SizedBox(height: 6),
                    ...q.parts.map(
                      (p) => _PartRow(part: p, cs: cs, isDark: isDark),
                    ),
                  ],
                  // Rubric
                  if (q.rubric.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailLabel(label: 'Rubric', cs: cs, isDark: isDark),
                    const SizedBox(height: 6),
                    ...q.rubric.map(
                      (r) => _RubricRow(criterion: r, cs: cs, isDark: isDark),
                    ),
                  ],
                  // Meta row
                  const SizedBox(height: 12),
                  _DetailLabel(label: 'Meta', cs: cs, isDark: isDark),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (q.cognitiveLevel.isNotEmpty)
                        _MetaChip(
                          label: q.cognitiveLevel,
                          icon: Icons.psychology_outlined,
                          cs: cs,
                          isDark: isDark,
                        ),
                      if (q.answerSpaceType.isNotEmpty)
                        _MetaChip(
                          label: q.answerSpaceType == 'lines'
                              ? '${q.answerLines} lines'
                              : q.answerSpaceType.replaceAll('_', ' '),
                          icon: Icons.edit_note_outlined,
                          cs: cs,
                          isDark: isDark,
                        ),
                      if (q.maxMarks > 0)
                        _MetaChip(
                          label: 'Max ${q.maxMarks} marks',
                          icon: Icons.grade_outlined,
                          cs: cs,
                          isDark: isDark,
                        ),
                    ],
                  ),
                  // Example answer
                  if (q.exampleAnswer != null &&
                      q.exampleAnswer.toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailLabel(
                      label: 'Example Answer',
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.exampleAnswer.toString(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                  // Images note
                  if (q.images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${q.images.length} image${q.images.length == 1 ? '' : 's'} attached',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w300,
                        color: cs.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  // Actions row
                  if (widget.canDelete) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _TextAction(
                          label: 'Delete',
                          isDestructive: true,
                          onTap: () async {
                            final confirmed = await showEduConfirmDialog(
                              context: context,
                              title: 'Delete Question',
                              message:
                                  'Delete Q${widget.index + 1} permanently?',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                            );
                            if (!confirmed) return;
                            final result = await questionBankService
                                .deleteQuestion(
                                  id: q.id,
                                  accessToken: accessToken,
                                );
                            if (!mounted) return;
                            switch (result) {
                              case Ok():
                                widget.onChanged();
                              case Err():
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to delete question',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          },
                          cs: cs,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Question detail helper widgets ──────────────────────────────────────────

class _DetailLabel extends StatelessWidget {
  const _DetailLabel({
    required this.label,
    required this.cs,
    required this.isDark,
  });
  final String label;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.part, required this.cs, required this.isDark});
  final QuestionPart part;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              part.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  part.body,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                if (part.marks > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${part.marks} mark${part.marks == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RubricRow extends StatelessWidget {
  const _RubricRow({
    required this.criterion,
    required this.cs,
    required this.isDark,
  });
  final RubricCriterion criterion;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${criterion.marks}m',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: cs.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              criterion.criterion,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.icon,
    required this.cs,
    required this.isDark,
  });
  final String label;
  final IconData icon;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.5 : 0.6,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StimulusPreview extends StatelessWidget {
  const _StimulusPreview({
    required this.stimulus,
    required this.cs,
    required this.isDark,
  });
  final Map<String, dynamic> stimulus;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = stimulus['text'] as String?;
    if (text == null || text.isEmpty) {
      return Text(
        stimulus.toString(),
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          height: 1.5,
        ),
      ),
    );
  }
}

class _TextAction extends StatefulWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    required this.cs,
    this.isDestructive = false,
  });
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDestructive;

  @override
  State<_TextAction> createState() => _TextActionState();
}

class _TextActionState extends State<_TextAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? widget.cs.error
        : widget.cs.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: color.withValues(alpha: _hovered ? 1.0 : 0.55),
            decoration: _hovered ? TextDecoration.underline : null,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — no subjects
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

class CreateSubjectSheet extends StatefulWidget {
  const CreateSubjectSheet({
    super.key,
    required this.curriculum,
    this.permissions,
  });

  final CurriculumType curriculum;

  /// Optional [SystemPermissions] for defense-in-depth create guard.
  /// When provided, `_submit()` verifies `subjects.create` before writing.
  final SystemPermissions? permissions;

  @override
  State<CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<CreateSubjectSheet> {
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

    // Defense-in-depth: verify create permission if permissions were provided.
    if (widget.permissions != null &&
        !widget.permissions!.can(Resource.subjects, Action.create)) {
      setState(
        () => _submitError = 'You don\'t have permission to create subjects.',
      );
      return;
    }

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Save button row ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
          const SizedBox(height: 8),
          // ── Error ─────────────────────────────────────────────────
          if (_submitError != null) ...[
            _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
            const SizedBox(height: 10),
          ],
          // ── Name field ────────────────────────────────────────────
          EduFormField(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'e.g. Mathematics',
            error: _nameError,
          ),
          const SizedBox(height: 14),
          // ── Curriculum selector ───────────────────────────────────
          Text(
            'CURRICULUM',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
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
                onTap: () =>
                    setState(() => _curriculum = CurriculumType.eightFourFour),
                cs: cs,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Save button row ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
          const SizedBox(height: 8),
          // ── Error ─────────────────────────────────────────────────
          if (_submitError != null) ...[
            _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
            const SizedBox(height: 10),
          ],
          // ── Name field ────────────────────────────────────────────
          EduFormField(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'Subject name',
            error: _nameError,
          ),
          const SizedBox(height: 14),
          // ── Curriculum selector ───────────────────────────────────
          Text(
            'CURRICULUM',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
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
                onTap: () =>
                    setState(() => _curriculum = CurriculumType.eightFourFour),
                cs: cs,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
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
    required this.gradeLabel,
  });

  final int subjectId;
  final String subjectName;
  final int grade;
  final String gradeLabel;

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Subject + grade subtitle + save button ──────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.subjectName} · ${widget.gradeLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
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
          const SizedBox(height: 12),
          // ── Error ─────────────────────────────────────────────────
          if (_submitError != null) ...[
            _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
            const SizedBox(height: 10),
          ],
          // ── Name field ────────────────────────────────────────────
          EduFormField(
            controller: _nameCtrl,
            label: 'Topic Name',
            hint: 'e.g. Algebra, Trigonometry',
            error: _nameError,
          ),
          const SizedBox(height: 8),
        ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Save button row ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
          const SizedBox(height: 8),
          // ── Error ─────────────────────────────────────────────────
          if (_submitError != null) ...[
            _ErrorBanner(message: _submitError!, cs: cs, isDark: isDark),
            const SizedBox(height: 10),
          ],
          // ── Name field ────────────────────────────────────────────
          EduFormField(
            controller: _nameCtrl,
            label: 'Topic Name',
            hint: 'Topic name',
            error: _nameError,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

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
