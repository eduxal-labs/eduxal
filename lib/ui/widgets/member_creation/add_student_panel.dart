import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../client.dart';
import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../database/tables/enums.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../../../ui/theme/app_theme.dart';
import '../edu_form_field.dart';
import '../edu_sheet.dart';
import '../inline_calendar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the student creation modal — a slide-over dialog on desktop (≥ 600 px)
/// and a full-height bottom sheet on mobile.
///
/// Returns the newly created [StudentsData] row, or `null` if dismissed.
Future<StudentsData?> showAddStudentPanel({
  required BuildContext context,
  required String schoolId,
}) {
  final service = MemberCreationService(MembersDao(db));

  return showEduSheet<StudentsData>(
    context: context,
    maxWidth: 460,
    builder: (ctx) => SingleChildScrollView(
      child: _AddStudentForm(
        schoolId: schoolId,
        service: service,
        onDone: (s) => Navigator.of(ctx).pop(s),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Form
// ─────────────────────────────────────────────────────────────────────────────

class _AddStudentForm extends StatefulWidget {
  const _AddStudentForm({
    required this.schoolId,
    required this.service,
    required this.onDone,
    required this.onCancel,
  });

  final String schoolId;
  final MemberCreationService service;
  final ValueChanged<StudentsData> onDone;
  final VoidCallback onCancel;

  @override
  State<_AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends State<_AddStudentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  Gender? _gender;
  DateTime? _dob;
  DateTime? _admitted;
  File? _imageFile;

  // ── Phone (optional user link) ──────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  Timer? _phoneDebounce;
  UsersData? _resolvedUser; // non-null when phone matched an existing user
  bool _phoneLooking = false; // true while debounce lookup is in flight
  bool _phoneChecked = false; // true after at least one lookup completed

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneDebounce?.cancel();
    super.dispose();
  }

  // ── Image picker ────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  // ── Phone lookup ────────────────────────────────────────────────────────────

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    final trimmed = value.trim();
    final digitCount = trimmed.replaceAll(RegExp(r'[^\d]'), '').length;

    // Reset state if phone is cleared or too short.
    if (digitCount < 9) {
      if (_phoneChecked || _resolvedUser != null) {
        setState(() {
          _resolvedUser = null;
          _phoneLooking = false;
          _phoneChecked = false;
        });
      }
      return;
    }

    setState(() => _phoneLooking = true);
    _phoneDebounce = Timer(const Duration(milliseconds: 480), () async {
      if (!mounted) return;
      final result = await widget.service.lookupPhone(trimmed);
      if (!mounted) return;
      setState(() {
        _phoneLooking = false;
        _phoneChecked = true;
        switch (result) {
          case UserFound(:final user):
            _resolvedUser = user;
          case UserNotFound():
            _resolvedUser = null;
        }
      });
    });
  }

  // ── Submission ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final phone = _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim();
      final result = await widget.service.createStudent(
        schoolId: widget.schoolId,
        name: _nameCtrl.text.trim(),
        dob: _dob,
        gender: _gender,
        admitted: _admitted,
        phone: phone,
      );

      switch (result) {
        case Ok(:final value):
          // If the user picked an image, save it to the predictable local path.
          if (_imageFile != null) {
            final accountId = cache.currentUser?.user.id;
            if (accountId != null) {
              await widget.service.saveStudentImage(
                schoolId: widget.schoolId,
                adm: value.adm,
                sourceFile: _imageFile!,
                accountId: accountId,
              );
            }
          }
          if (mounted) widget.onDone(value);

        case Err(:final error):
          if (mounted) {
            setState(() {
              _saving = false;
              _error = _errorMessage(error);
            });
          }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  static String _errorMessage(MemberCreationError e) => switch (e) {
    MemberCreationError.noActiveAccount =>
      'No active account found. Please log in again.',
    MemberCreationError.alreadyExists =>
      'A student with this admission number already exists.',
    MemberCreationError.invalidPhone => 'Invalid input.',
    MemberCreationError.databaseError =>
      'A local database error occurred. Please try again.',
  };

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add Student',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Fill in the student\'s details. An admission number '
                          'will be assigned automatically.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Photo picker ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PhotoPicker(
                imageFile: _imageFile,
                cs: cs,
                isDark: isDark,
                accent: accent,
                onTap: _pickImage,
                onClear: () => setState(() => _imageFile = null),
              ),
            ),

            const SizedBox(height: 14),

            // ── Name ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EduFormField(
                controller: _nameCtrl,
                label: 'Full Name',
                hint: 'e.g. John Kamau',
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 14),

            // ── Gender ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GENDER',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _GenderSelector(
                    value: _gender,
                    cs: cs,
                    isDark: isDark,
                    accent: accent,
                    onChanged: (g) => setState(() => _gender = g),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Date of birth ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DATE OF BIRTH',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InlineCalendar(
                    value: _dob,
                    hint: 'Select date of birth (optional)',
                    icon: Icons.cake_outlined,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() => _dob = d),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Admission date ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ADMISSION DATE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InlineCalendar(
                    value: _admitted,
                    hint: 'Select admission date (optional)',
                    icon: Icons.calendar_today_outlined,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onChanged: (d) => setState(() => _admitted = d),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Phone (optional) ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PHONE (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Link this student to a user account.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
                    ],
                    onChanged: _onPhoneChanged,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2A3A)
                          : cs.surfaceContainerLowest,
                      hintText: 'e.g. 0712345678',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      suffixIcon: _phoneLooking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              ),
                            )
                          : _phoneChecked && _resolvedUser != null
                          ? Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: Colors.green.shade600,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: isDark
                            ? BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.3),
                                width: 0.5,
                              )
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: isDark
                            ? BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.3),
                                width: 0.5,
                              )
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                  ),
                  // ── Lookup result hint ──────────────────────────────────────
                  if (_phoneChecked &&
                      _phoneCtrl.text
                              .trim()
                              .replaceAll(RegExp(r'[^\d]'), '')
                              .length >=
                          9)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            _resolvedUser != null
                                ? Icons.person_outline_rounded
                                : Icons.person_add_outlined,
                            size: 14,
                            color: _resolvedUser != null
                                ? Colors.green.shade600
                                : cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _resolvedUser != null
                                  ? 'Will link to ${_resolvedUser!.name} (${_resolvedUser!.phone})'
                                  : 'New invitation will be sent',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: _resolvedUser != null
                                    ? Colors.green.shade600
                                    : cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Error banner ──────────────────────────────────────────────────
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _ErrorBanner(message: _error!, cs: cs, isDark: isDark),
              ),

            // ── Action buttons ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cancel',
                    style: IconButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _saving ? null : _submit,
                    tooltip: 'Save',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.green.shade600.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo picker widget
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.imageFile,
    required this.cs,
    required this.isDark,
    required this.accent,
    required this.onTap,
    required this.onClear,
  });

  final File? imageFile;
  final ColorScheme cs;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.25 : 0.4,
    );

    return Row(
      children: [
        // Photo preview / placeholder
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: imageFile != null
                  ? Colors.transparent
                  : (isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLow),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: imageFile != null
                    ? accent.withValues(alpha: 0.4)
                    : borderColor,
              ),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(imageFile!, fit: BoxFit.cover),
                  )
                : Icon(
                    Icons.add_a_photo_outlined,
                    size: 22,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                imageFile != null ? 'Photo selected' : 'Student Photo',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                imageFile != null
                    ? 'Tap photo to change'
                    : 'Optional — tap to pick from gallery',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
              if (imageFile != null) ...[
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Remove photo',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: cs.error.withValues(alpha: 0.70),
                    ),
                  ),
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
// Gender selector
// ─────────────────────────────────────────────────────────────────────────────

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.value,
    required this.cs,
    required this.isDark,
    required this.accent,
    required this.onChanged,
  });

  final Gender? value;
  final ColorScheme cs;
  final bool isDark;
  final Color accent;
  final ValueChanged<Gender?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GenderChip(
          label: 'Male',
          icon: Icons.male,
          isSelected: value == Gender.male,
          cs: cs,
          isDark: isDark,
          accent: accent,
          onTap: () => onChanged(value == Gender.male ? null : Gender.male),
        ),
        const SizedBox(width: 10),
        _GenderChip(
          label: 'Female',
          icon: Icons.female,
          isSelected: value == Gender.female,
          cs: cs,
          isDark: isDark,
          accent: accent,
          onTap: () => onChanged(value == Gender.female ? null : Gender.female),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.cs,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final ColorScheme cs;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? accent.withValues(alpha: isDark ? 0.14 : 0.08)
        : (isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLow);

    final borderColor = isSelected
        ? accent.withValues(alpha: isDark ? 0.45 : 0.35)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? accent
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? accent
                    : cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared private helpers
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 15,
              color: cs.error.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.error.withValues(alpha: isDark ? 0.85 : 0.75),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
