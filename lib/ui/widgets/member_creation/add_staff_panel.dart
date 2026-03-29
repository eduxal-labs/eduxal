import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../../theme/app_theme.dart';
import '../edu_form_field.dart';
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
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = cs.brightness == Brightness.dark;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.kModalRadius),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  MediaQuery.viewInsetsOf(ctx).bottom + 16,
                ),
                child: _AddStaffForm(
                  schoolId: schoolId,
                  service: service,
                  onDone: (user) => Navigator.of(ctx).pop(user),
                  onCancel: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      );
    },
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
      extraFields: (_) =>
          _StaffExtras(idNumberCtrl: _idNumberCtrl, roleCtrl: _roleCtrl),
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
  const _StaffExtras({required this.idNumberCtrl, required this.roleCtrl});

  final TextEditingController idNumberCtrl;
  final TextEditingController roleCtrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionDivider(cs: cs, isDark: isDark, label: 'Optional Details'),
        const SizedBox(height: 14),
        // National ID / Employee number
        EduFormField(
          controller: idNumberCtrl,
          label: 'ID Number / Employee No.',
          hint: 'e.g. 12345678',
        ),
        const SizedBox(height: 14),
        // Role/title
        EduFormField(
          controller: roleCtrl,
          label: 'Role / Title',
          hint: 'e.g. School Secretary',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared private widgets
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
