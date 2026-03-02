import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/user_avatar.dart';

/// Modal bottom sheet showing the full details of a [UsersData] row.
///
/// Tapping the edit icon (if permitted) switches to an inline edit form.
/// The sheet is driven by a live [StreamBuilder] on [UsersDao.watchUser]
/// so any changes made elsewhere are reflected immediately.
class UserDetailSheet extends StatefulWidget {
  const UserDetailSheet({
    super.key,
    required this.user,
    required this.permissions,
  });

  /// The user row to display. The sheet watches this row for live updates.
  final UsersData user;
  final SystemPermissions permissions;

  @override
  State<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<UserDetailSheet> {
  bool _editing = false;

  // ── Edit form controllers ──────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  UserStatus? _editStatus;
  UserLevel? _editLevel;

  bool _saving = false;
  String? _saveError;

  // ── Image picking ──────────────────────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email ?? '');
    _editStatus = widget.user.status;
    _editLevel = widget.user.level;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Edit helpers ───────────────────────────────────────────────────────────

  void _startEditing(UsersData current) {
    setState(() {
      _nameCtrl.text = current.name;
      _emailCtrl.text = current.email ?? '';
      _editStatus = current.status;
      _editLevel = current.level;
      _editing = true;
      _saveError = null;
      _pickedImage = null;
    });
  }

  Future<void> _save(UsersData current) async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.length < 2) {
      setState(() => _saveError = 'Name must be at least 2 characters.');
      return;
    }
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => _saveError = 'Enter a valid email address.');
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

      await usersDao.updateUserDetails(
        current.id,
        UsersCompanion(
          name: Value(name),
          email: Value(email.isEmpty ? null : email),
          status: Value(_editStatus!),
          level: Value(_editLevel!),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      // If an image was picked, save it to the local cache.
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        await FileCache.saveBytes(bytes, FileCache.profilePath(current.id));
        // Log the intent to sync the profile image (currently a no-op — P8).
        await accountsDao.logProfileImageChange(current.id);
      }

      if (mounted) {
        setState(() {
          _editing = false;
          _pickedImage = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static bool _isValidEmail(String e) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  // ── Full-screen image viewer ───────────────────────────────────────────────

  Future<void> _viewImage(String userId) async {
    ImageProvider? provider;

    if (_pickedImage != null && _pickedImage!.existsSync()) {
      provider = FileImage(_pickedImage!);
    } else {
      final cached = await FileCache.get(FileCache.profilePath(userId));
      if (cached != null && cached.existsSync()) {
        provider = FileImage(cached);
      }
    }

    if (provider == null || !mounted) return;

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
                      child: Image(
                        image: provider!,
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<UsersData?>(
      stream: usersDao.watchUser(widget.user.id),
      initialData: widget.user,
      builder: (context, snapshot) {
        final user = snapshot.data ?? widget.user;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ────────────────────────────────────────────────────
              _SheetHandle(cs: cs),

              // ── Header ────────────────────────────────────────────────────
              _SheetHeader(
                user: user,
                editing: _editing,
                canEdit: widget.permissions.can('users.update'),
                saving: _saving,
                onEdit: () => _startEditing(user),
                onSave: () => _save(user),
                onCancel: () => setState(() {
                  _editing = false;
                  _saveError = null;
                  _pickedImage = null;
                }),
                cs: cs,
              ),

              Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),

              // ── Body ──────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: _editing
                      ? _EditBody(
                          user: user,
                          nameCtrl: _nameCtrl,
                          emailCtrl: _emailCtrl,
                          status: _editStatus!,
                          level: _editLevel!,
                          canEditLevel: widget.permissions.canSeeDeleted,
                          error: _saveError,
                          pickedImage: _pickedImage,
                          onStatusChanged: (s) =>
                              setState(() => _editStatus = s),
                          onLevelChanged: (l) => setState(() => _editLevel = l),
                          onPickImage: _pickImage,
                          cs: cs,
                        )
                      : _ViewBody(
                          user: user,
                          cs: cs,
                          onViewImage: () => _viewImage(user.id),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet handle
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet header — avatar + name + action icons
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.user,
    required this.editing,
    required this.canEdit,
    required this.saving,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.cs,
  });

  final UsersData user;
  final bool editing;
  final bool canEdit;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      child: Row(
        children: [
          // Status dot on the avatar.
          _AvatarWithDot(userId: user.id, status: user.status, cs: cs),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _statusLabel(user.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _statusColor(user.status),
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (user.level != UserLevel.normal) ...[
                      const SizedBox(width: 8),
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _levelLabel(user.level),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Edit / save / cancel icons.
          if (editing) ...[
            if (saving)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: cs.error),
                onPressed: onCancel,
                tooltip: 'Cancel',
              ),
              IconButton(
                icon: Icon(Icons.check_rounded, size: 20, color: cs.primary),
                onPressed: onSave,
                tooltip: 'Save',
              ),
            ],
          ] else if (canEdit)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar with status dot overlay
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarWithDot extends StatelessWidget {
  const _AvatarWithDot({
    required this.userId,
    required this.status,
    required this.cs,
  });

  final String userId;
  final UserStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(userId: userId, radius: 28),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _statusColor(status),
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View body — card-based read-only display with copy-to-clipboard
// ─────────────────────────────────────────────────────────────────────────────

class _ViewBody extends StatelessWidget {
  const _ViewBody({
    required this.user,
    required this.cs,
    required this.onViewImage,
  });

  final UsersData user;
  final ColorScheme cs;
  final VoidCallback onViewImage;

  @override
  Widget build(BuildContext context) {
    final created = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(user.created.toInt() * 1000),
    );
    final updated = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(user.updated.toInt() * 1000),
    );

    final isDark = cs.brightness == Brightness.dark;
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tappable profile image ──────────────────────────────────────
        Center(
          child: _ProfileImage(userId: user.id, cs: cs, onTap: onViewImage),
        ),

        const SizedBox(height: 24),

        // ── Contact section ─────────────────────────────────────────────
        _SectionHeader(title: 'Contact', cs: cs),
        const SizedBox(height: 4),
        _SectionCard(
          cs: cs,
          borderColor: borderColor,
          children: [
            _CopyableInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone,
              cs: cs,
            ),
            _RowDivider(cs: cs),
            _CopyableInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user.email ?? '—',
              copyable: user.email != null,
              cs: cs,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Account section ─────────────────────────────────────────────
        _SectionHeader(title: 'Account', cs: cs),
        const SizedBox(height: 4),
        _SectionCard(
          cs: cs,
          borderColor: borderColor,
          children: [
            _AccountInfoRow(
              icon: Icons.shield_outlined,
              label: 'Level',
              cs: cs,
              child: Text(
                _levelLabel(user.level),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            _RowDivider(cs: cs),
            _AccountInfoRow(
              icon: Icons.circle,
              iconSize: 8,
              iconColor: _statusColor(user.status),
              label: 'Status',
              cs: cs,
              child: Text(
                _statusLabel(user.status),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _statusColor(user.status),
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Timestamps section ──────────────────────────────────────────
        _SectionHeader(title: 'Timestamps', cs: cs),
        const SizedBox(height: 4),
        _SectionCard(
          cs: cs,
          borderColor: borderColor,
          children: [
            _CopyableInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: created,
              cs: cs,
            ),
            _RowDivider(cs: cs),
            _CopyableInfoRow(
              icon: Icons.update_rounded,
              label: 'Updated',
              value: updated,
              cs: cs,
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    final months = [
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

// ─────────────────────────────────────────────────────────────────────────────
// Profile image — tappable, shows full-screen viewer
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({
    required this.userId,
    required this.cs,
    required this.onTap,
  });

  final String userId;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<File?>(
        future: FileCache.get(FileCache.profilePath(userId)),
        builder: (context, snapshot) {
          final file = snapshot.data;
          final hasImage = file != null && file.existsSync();

          if (hasImage) {
            return CircleAvatar(
              radius: 48,
              backgroundImage: FileImage(file),
              backgroundColor: cs.surfaceContainerHighest,
            );
          }

          return CircleAvatar(
            radius: 48,
            backgroundColor: cs.surfaceContainerHighest,
            child: Icon(
              Icons.person,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header — uppercase label (account screen pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.cs});

  final String title;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card container (account screen pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.cs,
    required this.borderColor,
    required this.children,
  });

  final ColorScheme cs;
  final Color borderColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Divider between rows inside a section card
// ─────────────────────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 50,
      color: cs.outlineVariant,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Copyable info row — icon + label + value + copy button
// ─────────────────────────────────────────────────────────────────────────────

class _CopyableInfoRow extends StatelessWidget {
  const _CopyableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    this.copyable = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (copyable && value != '—')
            _CopyButton(value: value, label: label, cs: cs),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account info row — icon + label + custom child widget (for coloured text)
// ─────────────────────────────────────────────────────────────────────────────

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.child,
    required this.cs,
    this.iconSize = 20,
    this.iconColor,
  });

  final IconData icon;
  final double iconSize;
  final Color? iconColor;
  final String label;
  final Widget child;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? cs.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Copy button — small icon that copies to clipboard + shows snackbar
// ─────────────────────────────────────────────────────────────────────────────

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.value,
    required this.label,
    required this.cs,
  });

  final String value;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(
          Icons.copy_rounded,
          size: 14,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
        padding: EdgeInsets.zero,
        tooltip: 'Copy $label',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label copied'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit body — profile image picker + section-grouped form fields
// ─────────────────────────────────────────────────────────────────────────────

class _EditBody extends StatelessWidget {
  const _EditBody({
    required this.user,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.status,
    required this.level,
    required this.canEditLevel,
    required this.error,
    required this.pickedImage,
    required this.onStatusChanged,
    required this.onLevelChanged,
    required this.onPickImage,
    required this.cs,
  });

  final UsersData user;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final UserStatus status;
  final UserLevel level;

  /// Only super_ users can change another user's level.
  final bool canEditLevel;
  final String? error;
  final File? pickedImage;
  final void Function(UserStatus) onStatusChanged;
  final void Function(UserLevel) onLevelChanged;
  final VoidCallback onPickImage;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Error banner ────────────────────────────────────────────────
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
            ),
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Editable profile image ──────────────────────────────────────
        Center(
          child: _EditableProfileImage(
            userId: user.id,
            pickedImage: pickedImage,
            onTap: onPickImage,
            cs: cs,
          ),
        ),

        const SizedBox(height: 24),

        // ── Contact section ─────────────────────────────────────────────
        _SectionHeader(title: 'Contact', cs: cs),
        const SizedBox(height: 4),
        _SectionCard(
          cs: cs,
          borderColor: borderColor,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _FormField(
                label: 'Name',
                controller: nameCtrl,
                cs: cs,
                textInputAction: TextInputAction.next,
              ),
            ),
            _RowDivider(cs: cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _FormField(
                label: 'Email',
                controller: emailCtrl,
                hint: 'Optional',
                cs: cs,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Account section ─────────────────────────────────────────────
        _SectionHeader(title: 'Account', cs: cs),
        const SizedBox(height: 4),
        _SectionCard(
          cs: cs,
          borderColor: borderColor,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormLabel(label: 'Status', cs: cs),
                  const SizedBox(height: 6),
                  _StyledDropdown<UserStatus>(
                    value: status,
                    items: const [
                      (UserStatus.invited, 'Invited'),
                      (UserStatus.active, 'Active'),
                      (UserStatus.suspended, 'Suspended'),
                      (UserStatus.deleted, 'Deleted'),
                    ],
                    onChanged: onStatusChanged,
                    cs: cs,
                  ),
                ],
              ),
            ),
            if (canEditLevel) ...[
              _RowDivider(cs: cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormLabel(label: 'Level', cs: cs),
                    const SizedBox(height: 6),
                    _StyledDropdown<UserLevel>(
                      value: level,
                      items: const [
                        (UserLevel.normal, 'Normal'),
                        (UserLevel.system, 'System'),
                        (UserLevel.super_, 'Super'),
                      ],
                      onChanged: onLevelChanged,
                      cs: cs,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editable profile image — shows picked image or cached image with overlay
// ─────────────────────────────────────────────────────────────────────────────

class _EditableProfileImage extends StatelessWidget {
  const _EditableProfileImage({
    required this.userId,
    required this.pickedImage,
    required this.onTap,
    required this.cs,
  });

  final String userId;
  final File? pickedImage;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          children: [
            // Image circle.
            if (pickedImage != null && pickedImage!.existsSync())
              CircleAvatar(
                radius: 50,
                backgroundImage: FileImage(pickedImage!),
                backgroundColor: cs.surfaceContainerHighest,
              )
            else
              FutureBuilder<File?>(
                future: FileCache.get(FileCache.profilePath(userId)),
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  final hasImage = file != null && file.existsSync();

                  if (hasImage) {
                    return CircleAvatar(
                      radius: 50,
                      backgroundImage: FileImage(file),
                      backgroundColor: cs.surfaceContainerHighest,
                    );
                  }

                  return CircleAvatar(
                    radius: 50,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: 44,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  );
                },
              ),

            // Camera overlay badge.
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2.5),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 15,
                  color: cs.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

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
        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.cs,
    this.hint,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final ColorScheme cs;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label: label, cs: cs),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              fontSize: 13,
            ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(color: cs.primary, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

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
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: cs.brightness == Brightness.dark
              ? cs.outline.withValues(alpha: 0.5)
              : cs.outlineVariant,
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
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers — status colour + labels
// ─────────────────────────────────────────────────────────────────────────────

Color _statusColor(UserStatus status) => switch (status) {
  UserStatus.invited => const Color(0xFF7986CB),
  UserStatus.active => const Color(0xFF26A69A),
  UserStatus.suspended => const Color(0xFFFFB300),
  UserStatus.deleted => const Color(0xFFEF5350),
};

String _statusLabel(UserStatus status) => switch (status) {
  UserStatus.invited => 'Invited',
  UserStatus.active => 'Active',
  UserStatus.suspended => 'Suspended',
  UserStatus.deleted => 'Deleted',
};

String _levelLabel(UserLevel level) => switch (level) {
  UserLevel.normal => 'Normal',
  UserLevel.system => 'System',
  UserLevel.super_ => 'Super',
};
