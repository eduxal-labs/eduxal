import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../edu_form_field.dart';
import '../edu_sheet.dart';
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
  final service = MemberCreationService(MembersDao(db));

  return showEduSheet<UsersData>(
    context: context,
    builder: (ctx) => SingleChildScrollView(
      child: _AddTeacherForm(
        schoolId: schoolId,
        service: service,
        onDone: (user) => Navigator.of(ctx).pop(user),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
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
        EduFormField(
          controller: roleCtrl,
          label: 'Role / Designation',
          hint: 'e.g. Head of Mathematics',
        ),
        const SizedBox(height: 14),
        // Hired date picker
        Text(
          'HIRE DATE',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
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
