import 'package:flutter/material.dart' hide Action;
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/result.dart';
import '../../../../models/school_context.dart';
import '../../../../services/member_management.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/student_avatar.dart';
import 'student_detail_page.dart';
import 'members_shared.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({
    super.key,
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
  });

  final String schoolId;
  final MembersDao dao;
  final SchoolContext schoolContext;

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentsData>>(
      stream: widget.dao.watchAllStudents(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyTab(
            icon: Icons.groups_outlined,
            label: 'No students yet',
            hint: 'Tap + to add a student.',
          );
        }

        // Apply search filter by name or admission number
        final filtered = _query.isEmpty
            ? list
            : list.where((s) {
                final q = _query.toLowerCase();
                return s.name.toLowerCase().contains(q) ||
                    s.adm.toString().contains(q);
              }).toList();

        return FlatMemberList(
          searchController: _searchCtrl,
          searchHint: 'Search by name or ADM…',
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final s = filtered[i];
            final row = _StudentRow(
              schoolId: widget.schoolId,
              student: s,
              canDelete: _canDelete,
            );
            final isMobile = MediaQuery.sizeOf(context).width < 600;
            if (!isMobile || !_canDelete) return row;
            return Dismissible(
              key: ValueKey('student_${s.adm}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              confirmDismiss: (_) async {
                final confirmed = await showEduConfirmDialog(
                  context: context,
                  title: 'Delete "${s.name}"?',
                  message: 'This will permanently delete the student record.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                );
                if (!confirmed || !context.mounted) return false;
                final service = MemberManagementService(MembersDao(db));
                await service.changeStudentStatus(
                  schoolId: widget.schoolId,
                  adm: s.adm,
                  status: StudentStatus.deleted,
                );
                return false; // Stream rebuild handles visual removal
              },
              child: row,
            );
          },
        );
      },
    );
  }

  bool get _canDelete {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.students, Action.delete);
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.schoolId,
    required this.student,
    this.canDelete = true,
  });
  final String schoolId;
  final StudentsData student;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FlatRow(
      leading: StudentAvatar(
        schoolId: schoolId,
        adm: student.adm,
        name: student.name,
      ),
      name: student.name,
      subtitle: 'ADM: ${student.adm}',
      trailing: student.status != StudentStatus.active
          ? SmallChip(label: student.status.name, cs: cs)
          : null,
      onTap: () {
        final w = MediaQuery.sizeOf(context).width;
        if (w >= 600) {
          _showStudentSideSheet(context);
        } else {
          _showStudentBottomSheet(context);
        }
      },
      actions: [
        if (canDelete)
          RowAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            isDestructive: true,
            onTap: () => _confirmDelete(context),
          ),
      ],
    );
  }

  void _showStudentBottomSheet(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => StudentDetailSheet(
          initialStudent: student,
          schoolId: schoolId,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  void _showStudentSideSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: StudentDetailSheet(
            initialStudent: student,
            schoolId: schoolId,
            isSideSheet: true,
          ),
        );
      },
      transitionBuilder: (ctx, anim, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete "${student.name}"?',
      message: 'This will permanently delete the student record.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final service = MemberManagementService(MembersDao(db));
    final result = await service.changeStudentStatus(
      schoolId: schoolId,
      adm: student.adm,
      status: StudentStatus.deleted,
    );
    switch (result) {
      case Err(:final error) when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete student: $error')),
        );
      default:
        break;
    }
  }
}

class StudentPickerSheet extends StatefulWidget {
  const StudentPickerSheet({super.key, required this.schoolId});
  final String schoolId;

  @override
  State<StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<StudentPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _dao = MembersDao(db);
  List<StudentsData> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await _dao.searchStudents(widget.schoolId, query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select student (ward)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2A3A)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by name or admission number...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
                onChanged: (q) => _search(q),
              ),
            ),
          ),
          const Divider(height: 1),
          // Results list
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'No active students found.'
                            : 'No students match "${_searchCtrl.text}"',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final s = _results[i];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: cs.surfaceContainerHighest,
                          child: Text(
                            _initials(s.name),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${s.adm}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}
