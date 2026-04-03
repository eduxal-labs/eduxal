import 'dart:io';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import 'package:image_picker/image_picker.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet (mobile) / dialog content (desktop) for inviting a new user.
///
/// Collects name, phone, and optional email. Checks for a duplicate phone
/// number locally before submitting. On submit, calls
/// [UsersDao.inviteUser] which writes both the `users` row and the `logs`
/// insert entry in a single transaction.
class InviteUserSheet extends StatefulWidget {
  const InviteUserSheet({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends State<InviteUserSheet> {
  // ── Form controllers ────────────────────────────────────────────────────────

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // ── Image picking ───────────────────────────────────────────────────────────

  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;

  // ── State ───────────────────────────────────────────────────────────────────

  /// Non-null when a user with the entered phone already exists locally.
  String? _duplicateWarning;

  String? _nameError;
  String? _phoneError;
  String? _emailError;

  bool _submitting = false;
  bool _submitted = false;

  /// The level to assign to the invited user. Defaults to [UserLevel.normal].
  /// System users with `Users.Create` and Super users may select
  /// [UserLevel.system]. Super-level cannot be assigned from this UI (§16a).
  UserLevel _selectedLevel = UserLevel.normal;

  /// Whether the current user may create system-level users.
  /// True for Super users (bypass all checks) and System users with
  /// `Users.Create` permission. System users without that permission
  /// can only invite Normal-level users.
  bool get _canCreateSystemUser =>
      widget.permissions.isElevated &&
      widget.permissions.can(Resource.users, Action.create);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ───────────────────────────────────────────────────────────

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

  // ── Validation ──────────────────────────────────────────────────────────────

  static bool _isValidPhone(String phone) {
    // Accept digits only, 7–15 chars (covers local and E.164).
    // Project owner must confirm the exact format — this is a permissive guard.
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone);
  }

  static bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  bool _validate() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    String? nameErr;
    String? phoneErr;
    String? emailErr;

    if (name.length < 2) {
      nameErr = 'Name must be at least 2 characters.';
    }
    if (phone.isEmpty) {
      phoneErr = 'Phone number is required.';
    } else if (!_isValidPhone(phone)) {
      phoneErr = 'Enter a valid phone number (7–15 digits).';
    }
    if (email.isNotEmpty && !_isValidEmail(email)) {
      emailErr = 'Enter a valid email address.';
    }

    setState(() {
      _nameError = nameErr;
      _phoneError = phoneErr;
      _emailError = emailErr;
    });

    return nameErr == null && phoneErr == null && emailErr == null;
  }

  // ── Duplicate phone check ───────────────────────────────────────────────────

  Future<void> _checkDuplicate() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _duplicateWarning = null);
      return;
    }

    final existing = await usersDao.getUserByPhone(phone);
    if (!mounted) return;

    setState(() {
      _duplicateWarning = existing != null
          ? 'A user with this phone number already exists (${existing.name}).'
          : null;
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validate()) return;
    if (_duplicateWarning != null) return; // hard block on duplicate

    // ── Privilege escalation guards ──────────────────────────────────────────
    // Super users can only be created by other super users AND only via a
    // different flow. Block unconditionally in the invite sheet.
    if (_selectedLevel == UserLevel.super_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot invite Super-level users')),
      );
      return;
    }

    // System users without Users.Create may not invite system-level users.
    if (_selectedLevel == UserLevel.system &&
        !widget.permissions.can(Resource.users, Action.create)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You do not have permission to create System-level users',
          ),
        ),
      );
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Re-check for duplicates right before insert to guard against races.
    final phone = _phoneCtrl.text.trim();
    final existing = await usersDao.getUserByPhone(phone);
    if (!mounted) return;

    if (existing != null) {
      setState(() {
        _duplicateWarning =
            'A user with this phone number already exists (${existing.name}).';
      });
      return;
    }

    setState(() => _submitting = true);

    try {
      final id = ObjectId().oid;
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final email = _emailCtrl.text.trim();

      // SyncAction note: There is no `SyncAction.createUser` — by design,
      // users are created as side-effects of member creation (§16a). For
      // standalone user creation (system-level management), inviteUser() uses
      // `SyncAction.updateUser` + `UpdateUserPayload` as an upsert. The
      // server handles the "user does not exist" case by creating the row.
      await usersDao.inviteUser(
        UsersCompanion(
          id: Value(id),
          phone: Value(phone),
          name: Value(_nameCtrl.text.trim()),
          email: Value(email.isEmpty ? null : email),
          level: Value(_selectedLevel),
          status: const Value(UserStatus.invited),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      // If an image was picked, save it to the local cache for the new user.
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        await FileCache.saveBytes(bytes, FileCache.profilePath(id));
      }

      if (!mounted) return;
      setState(() => _submitted = true);

      // Show snackbar and dismiss.
      final name = _nameCtrl.text.trim();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation created for $name.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create invitation: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          _SheetHandle(cs: cs),

          // ── Title ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              'Invite user',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
          ),

          Divider(height: 20, thickness: 0.5, color: cs.outlineVariant),

          // ── Form ─────────────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Optional profile image ────────────────────────────────
                  Center(
                    child: _ImagePicker(
                      pickedImage: _pickedImage,
                      onTap: _pickImage,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name
                  _FormLabel(label: 'Name', cs: cs),
                  const SizedBox(height: 6),
                  _FormField(
                    controller: _nameCtrl,
                    hint: 'Full name',
                    error: _nameError,
                    cs: cs,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  _FormLabel(label: 'Phone', cs: cs),
                  const SizedBox(height: 6),
                  _FormField(
                    controller: _phoneCtrl,
                    hint: 'e.g. 0712345678',
                    error: _phoneError,
                    cs: cs,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      // Clear duplicate warning while typing.
                      if (_duplicateWarning != null) {
                        setState(() => _duplicateWarning = null);
                      }
                    },
                    onEditingComplete: _checkDuplicate,
                  ),

                  // Duplicate warning.
                  if (_duplicateWarning != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      ),
                      child: Text(
                        _duplicateWarning!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Email (optional)
                  _FormLabel(label: 'Email (optional)', cs: cs),
                  const SizedBox(height: 6),
                  _FormField(
                    controller: _emailCtrl,
                    hint: 'example@domain.com',
                    error: _emailError,
                    cs: cs,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _submit,
                  ),

                  // ── Level picker (visible to System / Super creators) ───
                  if (_canCreateSystemUser) ...[
                    const SizedBox(height: 14),
                    _FormLabel(label: 'User level', cs: cs),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final level in [
                          UserLevel.normal,
                          UserLevel.system,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                level == UserLevel.normal ? 'Normal' : 'System',
                              ),
                              selected: _selectedLevel == level,
                              visualDensity: VisualDensity.compact,
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: _selectedLevel == level
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                              ),
                              selectedColor: cs.primary,
                              backgroundColor: isDark
                                  ? const Color(0xFF1E2A38)
                                  : cs.surfaceContainerLow,
                              side: BorderSide(
                                color: _selectedLevel == level
                                    ? cs.primary
                                    : cs.outlineVariant.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              onSelected: (sel) {
                                if (sel) {
                                  setState(() => _selectedLevel = level);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Submit button ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: _SubmitButton(
              label: 'Create invitation',
              loading: _submitting,
              disabled: _duplicateWarning != null || _submitted,
              onTap: _submit,
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.cs});
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

// ─────────────────────────────────────────────────────────────────────────────
// Image picker — tappable circle with camera overlay for optional profile photo
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({
    required this.pickedImage,
    required this.onTap,
    required this.cs,
  });

  final File? pickedImage;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          children: [
            if (pickedImage != null && pickedImage!.existsSync())
              CircleAvatar(
                radius: 42,
                backgroundImage: FileImage(pickedImage!),
                backgroundColor: cs.surfaceContainerHighest,
              )
            else
              CircleAvatar(
                radius: 42,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 36,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ),

            // Camera overlay badge.
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 13,
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
    required this.controller,
    required this.hint,
    required this.cs,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final String hint;
  final String? error;
  final ColorScheme cs;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onEditingComplete: onEditingComplete,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            errorText: error,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(color: cs.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(color: cs.error, width: 1.5),
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

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.disabled,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final active = !loading && !disabled;

    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.primary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: cs.onPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
