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
  final w = MediaQuery.sizeOf(context).width;
  final service = MemberCreationService(MembersDao(db));

  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<StudentsData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _AddStudentDialog(schoolId: schoolId, service: service),
    );
  }
  return showModalBottomSheet<StudentsData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddStudentSheet(schoolId: schoolId, service: service),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddStudentDialog extends StatelessWidget {
  const _AddStudentDialog({required this.schoolId, required this.service});

  final String schoolId;
  final MemberCreationService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18222E) : cs.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.14),
                blurRadius: isDark ? 48 : 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              child: _AddStudentForm(
                schoolId: schoolId,
                service: service,
                onDone: (s) => Navigator.of(context).pop(s),
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile bottom-sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddStudentSheet extends StatelessWidget {
  const _AddStudentSheet({required this.schoolId, required this.service});

  final String schoolId;
  final MemberCreationService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: _AddStudentForm(
                schoolId: schoolId,
                service: service,
                onDone: (s) => Navigator.of(context).pop(s),
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
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

  // ── Submission ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await widget.service.createStudent(
        schoolId: widget.schoolId,
        name: _nameCtrl.text.trim(),
        dob: _dob,
        gender: _gender,
        admitted: _admitted,
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

    return Form(
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

          const SizedBox(height: 20),

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

          const SizedBox(height: 20),

          // ── Name ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FieldLabel(label: 'Full Name', cs: cs),
                const SizedBox(height: 7),
                _StyledInput(
                  controller: _nameCtrl,
                  hint: 'e.g. John Kamau',
                  prefixIcon: Icons.person_outline,
                  isDark: isDark,
                  cs: cs,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Gender ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FieldLabel(label: 'Gender', cs: cs),
                const SizedBox(height: 7),
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

          const SizedBox(height: 16),

          // ── Date of birth ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FieldLabel(label: 'Date of Birth', cs: cs),
                const SizedBox(height: 7),
                _DatePickerTile(
                  value: _dob,
                  hint: 'Select date of birth (optional)',
                  icon: Icons.cake_outlined,
                  isDark: isDark,
                  cs: cs,
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _dob = d),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Admission date ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FieldLabel(label: 'Admission Date', cs: cs),
                const SizedBox(height: 7),
                _DatePickerTile(
                  value: _admitted,
                  hint: 'Select admission date (optional)',
                  icon: Icons.calendar_today_outlined,
                  isDark: isDark,
                  cs: cs,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (d) => setState(() => _admitted = d),
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

          // ── CTA ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _CtaButton(
              label: 'Add Student',
              saving: _saving,
              isDark: isDark,
              cs: cs,
              onTap: _saving ? null : _submit,
            ),
          ),
        ],
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
    return Row(
      children: [
        // Photo preview / placeholder
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.10 : 0.07),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(imageFile!, fit: BoxFit.cover),
                  )
                : Icon(
                    Icons.add_a_photo_outlined,
                    size: 24,
                    color: accent.withValues(alpha: isDark ? 0.55 : 0.45),
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
        ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
        : (isDark
              ? const Color(0xFF1A2435)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                    blurRadius: isDark ? 6 : 3,
                    offset: const Offset(0, 2),
                  ),
                ],
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _StyledInput extends StatelessWidget {
  const _StyledInput({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.isDark,
    required this.cs,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool isDark;
  final ColorScheme cs;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2435)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: isDark ? 6 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.38),
          ),
          prefixIcon: Icon(
            prefixIcon,
            size: 18,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.value,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.cs,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final DateTime? value;
  final String hint;
  final IconData icon;
  final bool isDark;
  final ColorScheme cs;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final display = value != null ? _fmt(value!) : null;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A2435)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: isDark ? 6 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                display ?? hint,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: display != null
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(
                  Icons.close,
                  size: 15,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';
}

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

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.saving,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool saving;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final enabled = onTap != null;
    final bgColor = enabled
        ? accent
        : accent.withValues(alpha: isDark ? 0.28 : 0.24);
    final fgColor = enabled
        ? Colors.white
        : Colors.white.withValues(alpha: isDark ? 0.45 : 0.50);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.30 : 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: saving
                  ? SizedBox(
                      key: const ValueKey('saving'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                      ),
                    )
                  : Text(
                      key: const ValueKey('label'),
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fgColor,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
