import 'package:flutter/material.dart';

import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/active_term_provider.dart';
import 'guardian_overview.dart';
import 'owner_overview.dart';
import 'staff_overview.dart';
import 'student_overview.dart';
import 'teacher_overview.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Overview Screen — role-dispatched school dashboard landing page
// ─────────────────────────────────────────────────────────────────────────────

/// The Overview screen is the first page a user sees when entering a school
/// dashboard. It adapts its content based on the user's active role.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: schoolContext.currentEntry,
      builder: (context, entry, _) {
        return switch (entry) {
          OwnerEntry() => OwnerOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          TeacherEntry() => TeacherOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
          StaffEntry() => StaffOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          StudentEntry() => StudentOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
          GuardianEntry() => GuardianOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
        };
      },
    );
  }
}
