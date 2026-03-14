import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../edu_sheet.dart';
import 'phone_first_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a Staff creation modal — slide-over dialog on desktop (≥ 600 px)
/// and a full-height bottom sheet on mobile.
///
/// Returns the [UsersData] of the newly linked staff member (existing or
/// invited), or `null` if the user dismissed without completing.
Future<UsersData?> showAddStaffPanel({
  required BuildContext context,
  required String schoolId,
}) {
  final service = MemberCreationService(MembersDao(db));

  return showEduSheet<UsersData>(
    context: context,
    maxWidth: 420,
    builder: (ctx) => SingleChildScrollView(
      child: _AddStaffForm(
        schoolId: schoolId,
        service: service,
        onDone: (user) => Navigator.of(ctx).pop(user),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Form
// ─────────────────────────────────────────────────────────────────────────────

class _AddStaffForm extends StatefulWidget {
  const _AddStaffForm({
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
  State<_AddStaffForm> createState() => _AddStaffFormState();
}

class _AddStaffFormState extends State<_AddStaffForm> {
  final _idNumberCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return PhoneFirstPanel(
      service: widget.service,
      title: 'Add Staff Member',
      subtitle:
          'Enter the staff member\'s phone number. If they already have '
          'an EduXal account, they will be linked automatically.',
      ctaLabel: 'Add Staff Member',
      alreadyExistsMessage:
          'This person is already a staff member at this school.',
      checkAlreadyExists: (user) async {
        return await MembersDao(db).staffExists(widget.schoolId, user.id);
      },
      extraFields: (_) => _StaffExtras(
        idNumberCtrl: _idNumberCtrl,
        roleCtrl: _roleCtrl,
        cs: cs,
        isDark: isDark,
      ),
      onConfirmed:
          ({
            required String phone,
            String? name,
            UsersData? resolvedUser,
          }) async {
            final result = await widget.service.createStaff(
              schoolId: widget.schoolId,
              phone: phone,
              name: name,
              idNumber: _idNumberCtrl.text.trim().isEmpty
                  ? null
                  : _idNumberCtrl.text.trim(),
              role: _roleCtrl.text.trim().isEmpty
                  ? null
                  : _roleCtrl.text.trim(),
            );

            switch (result) {
              case Ok(:final value):
                widget.onDone(value);
              case Err(:final error):
                throw Exception(_errorMessage(error));
            }
          },
      onCancel: widget.onCancel,
    );
  }

  static String _errorMessage(MemberCreationError e) => switch (e) {
    MemberCreationError.noActiveAccount =>
      'No active account found. Please log in again.',
    MemberCreationError.alreadyExists =>
      'This person is already a staff member at this school.',
    MemberCreationError.invalidPhone => 'Please enter a valid phone number.',
    MemberCreationError.databaseError =>
      'A local database error occurred. Please try again.',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff-specific optional fields
// ─────────────────────────────────────────────────────────────────────────────

class _StaffExtras extends StatelessWidget {
  const _StaffExtras({
    required this.idNumberCtrl,
    required this.roleCtrl,
    required this.cs,
    required this.isDark,
  });

  final TextEditingController idNumberCtrl;
  final TextEditingController roleCtrl;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionDivider(cs: cs, isDark: isDark, label: 'Optional Details'),
        const SizedBox(height: 14),
        // National ID / Employee number
        _FieldLabel(label: 'ID Number / Employee No.', cs: cs),
        const SizedBox(height: 7),
        _StyledInput(
          controller: idNumberCtrl,
          hint: 'e.g. 12345678',
          prefixIcon: Icons.credit_card_outlined,
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(height: 14),
        // Role/title
        _FieldLabel(label: 'Role / Title', cs: cs),
        const SizedBox(height: 7),
        _StyledInput(
          controller: roleCtrl,
          hint: 'e.g. School Secretary',
          prefixIcon: Icons.badge_outlined,
          isDark: isDark,
          cs: cs,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared private widgets
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
    this.keyboardType, // ignore: unused_element_parameter
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
