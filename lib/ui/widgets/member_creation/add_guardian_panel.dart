import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../database/daos/members_dao.dart';
import '../../../database/tables/enums.dart';
import '../../../models/result.dart';
import '../../../services/members.dart';
import '../../../ui/theme/app_theme.dart';
import '../edu_sheet.dart';
import 'phone_first_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the guardian creation modal, **scoped to a specific student**.
///
/// Guardian creation is always nested inside the Student profile view so that
/// the ward relationship is established implicitly — the caller supplies
/// [studentAdm] and [studentName] and the form makes clear which student the
/// guardian will be linked to.
///
/// Returns the [UsersData] of the newly created or linked guardian, or `null`
/// if the user dismissed without completing.
Future<UsersData?> showAddGuardianPanel({
  required BuildContext context,
  required String schoolId,
  required int studentAdm,
  required String studentName,
}) {
  final service = MemberCreationService(MembersDao(db));

  return showEduSheet<UsersData>(
    context: context,
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
                child: _AddGuardianForm(
                  schoolId: schoolId,
                  studentAdm: studentAdm,
                  studentName: studentName,
                  service: service,
                  onDone: (user) => Navigator.of(context).pop(user),
                  onCancel: () => Navigator.of(context).pop(),
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

class _AddGuardianForm extends StatefulWidget {
  const _AddGuardianForm({
    required this.schoolId,
    required this.studentAdm,
    required this.studentName,
    required this.service,
    required this.onDone,
    required this.onCancel,
  });

  final String schoolId;
  final int studentAdm;
  final String studentName;
  final MemberCreationService service;
  final ValueChanged<UsersData> onDone;
  final VoidCallback onCancel;

  @override
  State<_AddGuardianForm> createState() => _AddGuardianFormState();
}

class _AddGuardianFormState extends State<_AddGuardianForm> {
  GuardianRelationship _relationship = GuardianRelationship.guardian;
  GuardianRole _role = GuardianRole.secondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return PhoneFirstPanel(
      service: widget.service,
      title: 'Add Guardian',
      subtitle:
          'Enter the guardian\'s phone number to link them to '
          '${widget.studentName}.',
      ctaLabel: 'Add Guardian',
      alreadyExistsMessage:
          'This person is already a guardian for this student.',
      checkAlreadyExists: (user) async {
        return await MembersDao(
          db,
        ).guardianExists(widget.schoolId, user.id, widget.studentAdm);
      },
      extraFields: (_) => _GuardianExtras(
        studentName: widget.studentName,
        relationship: _relationship,
        role: _role,
        cs: cs,
        isDark: isDark,
        onRelationshipChanged: (r) => setState(() => _relationship = r),
        onRoleChanged: (r) => setState(() => _role = r),
      ),
      onConfirmed:
          ({
            required String phone,
            String? name,
            UsersData? resolvedUser,
          }) async {
            final result = await widget.service.createGuardian(
              schoolId: widget.schoolId,
              studentAdm: widget.studentAdm,
              phone: phone,
              name: name,
              relationship: _relationship,
              role: _role,
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
      'This person is already a guardian for this student.',
    MemberCreationError.invalidPhone => 'Please enter a valid phone number.',
    MemberCreationError.databaseError =>
      'A local database error occurred. Please try again.',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardian-specific extra fields
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianExtras extends StatelessWidget {
  const _GuardianExtras({
    required this.studentName,
    required this.relationship,
    required this.role,
    required this.cs,
    required this.isDark,
    required this.onRelationshipChanged,
    required this.onRoleChanged,
  });

  final String studentName;
  final GuardianRelationship relationship;
  final GuardianRole role;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<GuardianRelationship> onRelationshipChanged;
  final ValueChanged<GuardianRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionDivider(cs: cs, isDark: isDark, label: 'Ward & Role'),
        const SizedBox(height: 14),

        // Ward context chip — read-only, just shows who they are linked to
        _WardChip(studentName: studentName, cs: cs, isDark: isDark),

        const SizedBox(height: 16),

        // Relationship selector
        _FieldLabel(label: 'Relationship to Student', cs: cs),
        const SizedBox(height: 8),
        _RelationshipSelector(
          value: relationship,
          cs: cs,
          isDark: isDark,
          onChanged: onRelationshipChanged,
        ),

        const SizedBox(height: 16),

        // Guardian role (Primary / Secondary / Sponsor)
        _FieldLabel(label: 'Guardian Role', cs: cs),
        const SizedBox(height: 8),
        _GuardianRoleSelector(
          value: role,
          cs: cs,
          isDark: isDark,
          onChanged: onRoleChanged,
        ),

        // Informational note about primary guardian uniqueness
        if (role == GuardianRole.primary)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _InfoNote(
              message:
                  'Only one primary guardian is allowed per student. If one '
                  'already exists, this will fail. Consider using Secondary.',
              cs: cs,
              isDark: isDark,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ward chip — read-only, shows who the guardian will be linked to
// ─────────────────────────────────────────────────────────────────────────────

class _WardChip extends StatelessWidget {
  const _WardChip({
    required this.studentName,
    required this.cs,
    required this.isDark,
  });

  final String studentName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final green = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: green.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            size: 15,
            color: green.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                children: [
                  const TextSpan(text: 'Will be linked to '),
                  TextSpan(
                    text: studentName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relationship selector — wrapping chip grid
// ─────────────────────────────────────────────────────────────────────────────

class _RelationshipSelector extends StatelessWidget {
  const _RelationshipSelector({
    required this.value,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final GuardianRelationship value;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<GuardianRelationship> onChanged;

  static const _labels = {
    GuardianRelationship.father: ('Father', Icons.man_outlined),
    GuardianRelationship.mother: ('Mother', Icons.woman_outlined),
    GuardianRelationship.brother: ('Brother', Icons.person_outline),
    GuardianRelationship.sister: ('Sister', Icons.person_outline),
    GuardianRelationship.guardian: (
      'Guardian',
      Icons.supervisor_account_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: GuardianRelationship.values.map((rel) {
        final meta = _labels[rel]!;
        final isSelected = value == rel;
        return _SelectableChip(
          label: meta.$1,
          icon: meta.$2,
          isSelected: isSelected,
          cs: cs,
          isDark: isDark,
          accent: accent,
          onTap: () => onChanged(rel),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardian role selector
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianRoleSelector extends StatelessWidget {
  const _GuardianRoleSelector({
    required this.value,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final GuardianRole value;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<GuardianRole> onChanged;

  static const _meta = {
    GuardianRole.primary: (
      'Primary',
      'Main guardian — receives all communications.',
      Icons.star_outline_rounded,
    ),
    GuardianRole.secondary: (
      'Secondary',
      'Secondary contact.',
      Icons.person_outline,
    ),
    GuardianRole.sponsor: (
      'Sponsor',
      'Financially responsible for fees.',
      Icons.account_balance_wallet_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return Column(
      children: GuardianRole.values.map((r) {
        final m = _meta[r]!;
        final isSelected = value == r;

        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _RoleRow(
            label: m.$1,
            description: m.$2,
            icon: m.$3,
            isSelected: isSelected,
            cs: cs,
            isDark: isDark,
            accent: accent,
            onTap: () => onChanged(r),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                    blurRadius: isDark ? 5 : 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? accent
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? accent
                    : cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.cs,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final ColorScheme cs;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? accent.withValues(alpha: isDark ? 0.12 : 0.07)
        : (isDark
              ? const Color(0xFF1A2435)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accent.withValues(alpha: isDark ? 0.12 : 0.08)
                  : Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
              blurRadius: isDark ? 6 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? accent
                    : cs.onSurfaceVariant.withValues(alpha: 0.50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? accent : cs.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 16,
                color: accent.withValues(alpha: 0.9),
              ),
          ],
        ),
      ),
    );
  }
}

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

class _InfoNote extends StatelessWidget {
  const _InfoNote({
    required this.message,
    required this.cs,
    required this.isDark,
  });

  final String message;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final amber = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: amber.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: amber.withValues(alpha: isDark ? 0.80 : 0.70),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
