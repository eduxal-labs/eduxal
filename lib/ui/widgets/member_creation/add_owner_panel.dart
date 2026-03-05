import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../../../ui/theme/app_theme.dart';
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
  final w = MediaQuery.sizeOf(context).width;
  final service = MemberCreationService(MembersDao(db));

  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<UsersData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _AddOwnerDialog(schoolId: schoolId, service: service),
    );
  }
  return showModalBottomSheet<UsersData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddOwnerSheet(schoolId: schoolId, service: service),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop dialog wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _AddOwnerDialog extends StatelessWidget {
  const _AddOwnerDialog({required this.schoolId, required this.service});

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
              child: _AddOwnerForm(
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

class _AddOwnerSheet extends StatelessWidget {
  const _AddOwnerSheet({required this.schoolId, required this.service});

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
              child: _AddOwnerForm(
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
