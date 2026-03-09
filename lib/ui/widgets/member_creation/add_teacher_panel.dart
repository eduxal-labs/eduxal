import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../../../ui/theme/app_theme.dart';
import '../inline_calendar.dart';
import 'phone_first_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a Teacher creation modal — slide-over dialog on desktop (≥ 600 px)
/// and a full-height bottom sheet on mobile.
///
/// Returns the [UsersData] of the newly linked teacher (existing or invited),
/// or `null` if the user dismissed without completing.
Future<UsersData?> showAddTeacherPanel({
  required BuildContext context,
  required String schoolId,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final service = MemberCreationService(MembersDao(db));

  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<UsersData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _AddTeacherDialog(schoolId: schoolId, service: service),
    );
  }
  return showModalBottomSheet<UsersData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddTeacherSheet(schoolId: schoolId, service: service),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop dialog wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _AddTeacherDialog extends StatelessWidget {
  const _AddTeacherDialog({required this.schoolId, required this.service});

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
        constraints: const BoxConstraints(maxWidth: 420),
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
              child: _AddTeacherForm(
                schoolId: schoolId,
                service: service,
                onDone: (user) => Navigator.of(context).pop(user),
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
// Mobile bottom-sheet wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _AddTeacherSheet extends StatelessWidget {
  const _AddTeacherSheet({required this.schoolId, required this.service});

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
          // Content
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: _AddTeacherForm(
                schoolId: schoolId,
                service: service,
                onDone: (user) => Navigator.of(context).pop(user),
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
// Form — orchestrates the phone-first panel with teacher-specific extra fields
// ─────────────────────────────────────────────────────────────────────────────

class _AddTeacherForm extends StatefulWidget {
  const _AddTeacherForm({
    required this.schoolId,
    required this.service,
    required this.onDone,
    required this.onCancel,
  });

  final String schoolId;
  final MemberCreationService service;
  final ValueChanged<UsersData> onDone;
  final VoidCallback onCancel;

  @override
  State<_AddTeacherForm> createState() => _AddTeacherFormState();
}

class _AddTeacherFormState extends State<_AddTeacherForm> {
  // Optional teacher-specific fields
  DateTime? _hiredDate;
  final _roleCtrl = TextEditingController();

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return PhoneFirstPanel(
      service: widget.service,
      title: 'Add Teacher',
      subtitle:
          'Enter the teacher\'s phone number. If they already exist in '
          'EduXal, they will be linked instantly.',
      ctaLabel: 'Add Teacher',
      alreadyExistsMessage: 'This person is already a teacher at this school.',
      checkAlreadyExists: (user) async {
        return await MembersDao(db).teacherExists(widget.schoolId, user.id);
      },
      extraFields: (_) => _TeacherExtras(
        hiredDate: _hiredDate,
        roleCtrl: _roleCtrl,
        cs: cs,
        isDark: isDark,
        onHiredDateChanged: (d) => setState(() => _hiredDate = d),
      ),
      onConfirmed:
          ({
            required String phone,
            String? name,
            UsersData? resolvedUser,
          }) async {
            final result = await widget.service.createTeacher(
              schoolId: widget.schoolId,
              phone: phone,
              name: name,
              hiredDate: _hiredDate,
              role: _roleCtrl.text.trim().isEmpty
                  ? null
                  : _roleCtrl.text.trim(),
            );

            switch (result) {
              case Ok(:final value):
                widget.onDone(value);
              case Err(:final error):
                final msg = _errorMessage(error);
                throw Exception(msg);
            }
          },
      onCancel: widget.onCancel,
    );
  }

  static String _errorMessage(MemberCreationError e) => switch (e) {
    MemberCreationError.noActiveAccount =>
      'No active account found. Please log in again.',
    MemberCreationError.alreadyExists =>
      'This person is already a teacher at this school.',
    MemberCreationError.invalidPhone => 'Please enter a valid phone number.',
    MemberCreationError.databaseError =>
      'A local database error occurred. Please try again.',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Teacher-specific optional fields
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherExtras extends StatelessWidget {
  const _TeacherExtras({
    required this.hiredDate,
    required this.roleCtrl,
    required this.cs,
    required this.isDark,
    required this.onHiredDateChanged,
  });

  final DateTime? hiredDate;
  final TextEditingController roleCtrl;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<DateTime?> onHiredDateChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionDivider(cs: cs, isDark: isDark, label: 'Optional Details'),
        const SizedBox(height: 14),
        // Role/designation field
        _FieldLabel(label: 'Role / Designation', cs: cs),
        const SizedBox(height: 7),
        _StyledInput(
          controller: roleCtrl,
          hint: 'e.g. Head of Mathematics',
          prefixIcon: Icons.badge_outlined,
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(height: 14),
        // Hired date picker
        _FieldLabel(label: 'Hire Date', cs: cs),
        const SizedBox(height: 7),
        InlineCalendar(
          value: hiredDate,
          hint: 'Select hire date (optional)',
          icon: Icons.calendar_today_outlined,
          firstDate: DateTime(1990),
          lastDate: DateTime.now(),
          onChanged: onHiredDateChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets (private to this file)
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
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool isDark;
  final ColorScheme cs;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.2 : 0.35,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
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
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          prefixIcon: Icon(
            prefixIcon,
            size: 17,
            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.cs,
    required this.isDark,
    required this.label,
  });

  final ColorScheme cs;
  final bool isDark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.40),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.40),
          ),
        ),
      ],
    );
  }
}
