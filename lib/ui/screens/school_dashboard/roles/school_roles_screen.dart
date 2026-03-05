import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:bson/bson.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/school_scopes_dao.dart';

import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import 'school_role_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class SchoolRolesScreen extends StatelessWidget {
  const SchoolRolesScreen({super.key, required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return _SchoolRolesBody(schoolContext: schoolContext);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body — single flat list of role cards + FAB
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolRolesBody extends StatefulWidget {
  const _SchoolRolesBody({required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  State<_SchoolRolesBody> createState() => _SchoolRolesBodyState();
}

class _SchoolRolesBodyState extends State<_SchoolRolesBody> {
  late final SchoolScopesDao _dao;

  @override
  void initState() {
    super.initState();
    _dao = SchoolScopesDao(db);
  }

  String get _schoolId => widget.schoolContext.membership.school.id;

  void _openDetail(BuildContext context, Role role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SchoolRoleDetailScreen(
          role: role,
          schoolContext: widget.schoolContext,
          dao: _dao,
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoleFormSheet(schoolId: _schoolId, dao: _dao),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Role>>(
      stream: _dao.watchSchoolRoles(_schoolId),
      builder: (ctx, snap) {
        final roles = snap.data ?? [];

        return Stack(
          children: [
            if (roles.isEmpty &&
                snap.connectionState != ConnectionState.waiting)
              _EmptyState(
                icon: Icons.shield_outlined,
                title: 'No Custom Roles',
                subtitle:
                    'Create roles with specific permissions to control what '
                    'staff members can see and do.',
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                itemCount: roles.length,
                itemBuilder: (_, i) => _RoleCard(
                  role: roles[i],
                  onTap: () => _openDetail(context, roles[i]),
                ),
              ),

            // ── FAB ─────────────────────────────────────────────────────
            Positioned(
              right: 20,
              bottom: 24,
              child: FloatingActionButton.small(
                onPressed: () => _showCreateSheet(context),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 4,
                highlightElevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role card — single item in the flat list
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap});
  final Role role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final permCount = _parsePermCount(role.permissions);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // ── Icon ─────────────────────────────────────────────────
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(width: 14),

                // ── Name + description ───────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (role.description != null &&
                          role.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            role.description!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // ── Permission count badge ───────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$permCount perm${permCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ── Chevron ──────────────────────────────────────────────
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _parsePermCount(String permJson) {
    try {
      final decoded = jsonDecode(permJson);
      if (decoded is List) {
        // Structured: [{"resource":"x","actions":["a","b"]}]
        int count = 0;
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final actions = entry['actions'];
            if (actions is List) count += actions.length;
          }
        }
        return count;
      }
      if (decoded is Map) return decoded.length;
    } catch (_) {}
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role create sheet (create-only — editing is now done in the detail screen)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleFormSheet extends StatefulWidget {
  const _RoleFormSheet({required this.schoolId, required this.dao});
  final String schoolId;
  final SchoolScopesDao dao;

  @override
  State<_RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<_RoleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = cache.currentUser?.user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final id = ObjectId().oid;

      await widget.dao.createRole(
        RolesCompanion(
          id: Value(id),
          school: Value(widget.schoolId),
          name: Value(_nameCtrl.text.trim()),
          description: Value(
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          ),
          permissions: const Value('[]'),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        accountId: user.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Handle ──────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ───────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: cs.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New Role',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    'Create a role first, then configure its permissions '
                    'on the detail page.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Role name ───────────────────────────────────────────
                _FieldLabel(label: 'Role Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: _inputDeco(cs, 'e.g. Registrar, Dean of Studies'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Role name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Description ─────────────────────────────────────────
                _FieldLabel(label: 'Description (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: _inputDeco(cs, 'What does this role do?'),
                ),
                const SizedBox(height: 24),

                // ── Save button ─────────────────────────────────────────
                AnimatedSaveButton(
                  isDirty: true,
                  isSaving: _saving,
                  onSave: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDeco(ColorScheme cs, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
    ),
    filled: true,
    fillColor: cs.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.1,
      ),
    );
  }
}
