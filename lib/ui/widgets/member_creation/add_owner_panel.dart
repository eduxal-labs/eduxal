import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../../theme/app_theme.dart';
import '../edu_sheet.dart';
import 'phone_first_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows an Owner creation modal — slide-over dialog on desktop (≥ 600 px)
/// and a full-height bottom sheet on mobile.
///
/// Returns the [UsersData] of the newly linked owner (existing or invited),
/// or `null` if the user dismissed without completing.
Future<UsersData?> showAddOwnerPanel({
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
                child: _AddOwnerForm(
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
// Form — orchestrates the phone-first panel (no extra fields for owners)
// ─────────────────────────────────────────────────────────────────────────────

class _AddOwnerForm extends StatelessWidget {
  const _AddOwnerForm({
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
  Widget build(BuildContext context) {
    return PhoneFirstPanel(
      service: service,
      title: 'Add Owner',
      subtitle:
          'Enter the owner\'s phone number. If they already exist in '
          'EduXal, they will be linked instantly.',
      ctaLabel: 'Add Owner',
      alreadyExistsMessage: 'This person is already an owner at this school.',
      checkAlreadyExists: (user) async {
        return await MembersDao(db).ownerExists(schoolId, user.id);
      },
      onConfirmed:
          ({
            required String phone,
            String? name,
            UsersData? resolvedUser,
          }) async {
            final result = await service.createOwner(
              schoolId: schoolId,
              phone: phone,
              name: name,
            );

            switch (result) {
              case Ok(:final value):
                onDone(value);
              case Err(:final error):
                final msg = _errorMessage(error);
                throw Exception(msg);
            }
          },
      onCancel: onCancel,
    );
  }

  static String _errorMessage(MemberCreationError e) => switch (e) {
    MemberCreationError.noActiveAccount =>
      'No active account found. Please log in again.',
    MemberCreationError.alreadyExists =>
      'This person is already an owner at this school.',
    MemberCreationError.invalidPhone => 'Please enter a valid phone number.',
    MemberCreationError.databaseError =>
      'A local database error occurred. Please try again.',
  };
}
