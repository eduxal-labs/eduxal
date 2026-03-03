/// Pure Dart models for the system dashboard statistics section.
///
/// These are assembled by [SystemStatsDao] and consumed by the stats UI.
/// They have no dependency on Drift or gRPC — they are plain data holders.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Current term context
// ─────────────────────────────────────────────────────────────────────────────

/// Identifies the "current" academic term used to scope term-sensitive stats.
///
/// Resolution order (performed by the DAO):
///   1. Any term whose `start <= now AND end >= now` → most recently started.
///   2. Fallback: the term with the highest `end` in the past (last completed).
///   3. If the local DB has no terms at all → null (stats show lifetime totals).
///
/// [year] is the calendar year (e.g. 2025).
/// [term] is the 0-based term index within the year (0, 1, or 2).
/// [label] is a human-readable string shown in the card header, e.g. "T1 2025".
class CurrentTerm {
  const CurrentTerm({
    required this.year,
    required this.term,
    required this.startEpochSecs,
    required this.endEpochSecs,
  });

  final int year;

  /// 0-based term index (0 = first term, 1 = second, 2 = third).
  final int term;

  /// Term start — seconds since Unix epoch (same unit as `terms.start`).
  final int startEpochSecs;

  /// Term end — seconds since Unix epoch.
  final int endEpochSecs;

  /// Human-readable label, e.g. "T1 2025".
  String get label => 'T${term + 1} $year';

  /// Term start converted to days since Unix epoch (same unit as `payments.date`).
  int get startDays => startEpochSecs ~/ 86400;

  /// Term end converted to days since Unix epoch.
  int get endDays => endEpochSecs ~/ 86400;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared stat bar segment — used by the UI to render inline mini bars
// ─────────────────────────────────────────────────────────────────────────────

/// A single named value with an associated label, used by the stat card UI
/// to build inline vertical bars. Colour is assigned by the UI layer.
class StatSegment {
  const StatSegment({required this.label, required this.value});

  final String label;
  final int value;
}

// ─────────────────────────────────────────────────────────────────────────────
// User stats
// ─────────────────────────────────────────────────────────────────────────────

/// Counts of users grouped by [UserStatus].
///
/// The [deleted] count is always populated — the UI layer decides whether to
/// display it based on the current user's [UserLevel].
class UserStats {
  const UserStats({
    required this.total,
    required this.invited,
    required this.active,
    required this.suspended,
    required this.deleted,
  });

  /// Total number of users across all statuses (including deleted).
  final int total;

  /// Users with status = invited (0).
  final int invited;

  /// Users with status = active (1).
  final int active;

  /// Users with status = suspended (2).
  final int suspended;

  /// Users with status = deleted (3).
  /// Only meaningful for [UserLevel.super_] users — always populated but
  /// only shown in the UI when the current user is super_.
  final int deleted;

  /// Returns a zeroed-out [UserStats] — used as the initial state before the
  /// stream emits its first value.
  static const empty = UserStats(
    total: 0,
    invited: 0,
    active: 0,
    suspended: 0,
    deleted: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// School stats
// ─────────────────────────────────────────────────────────────────────────────

/// Counts of schools grouped by [SchoolStatus].
///
/// The [deleted] count is always populated — the UI layer decides whether to
/// display it based on the current user's [UserLevel].
class SchoolStats {
  const SchoolStats({
    required this.total,
    required this.trial,
    required this.active,
    required this.cancelled,
    required this.suspended,
    required this.deleted,
  });

  /// Total number of schools (including deleted).
  final int total;

  /// Schools with status = trial (0).
  final int trial;

  /// Schools with status = active (1).
  final int active;

  /// Schools with status = cancelled (2).
  final int cancelled;

  /// Schools with status = suspended (3).
  final int suspended;

  /// Schools with status = deleted (4).
  /// Only shown in the UI for [UserLevel.super_] users.
  final int deleted;

  /// Returns a zeroed-out [SchoolStats] — used as initial state.
  static const empty = SchoolStats(
    total: 0,
    trial: 0,
    active: 0,
    cancelled: 0,
    suspended: 0,
    deleted: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Student stats
// ─────────────────────────────────────────────────────────────────────────────

/// Counts of students grouped by [StudentStatus].
class StudentStats {
  const StudentStats({
    required this.total,
    required this.active,
    required this.expelled,
    required this.graduated,
    required this.transferred,
    required this.withdrawn,
    required this.deleted,
    this.currentTerm,
  });

  final int total;

  /// Students with status = active (0).
  final int active;

  /// Students with status = expelled (1).
  final int expelled;

  /// Students with status = graduated (2).
  final int graduated;

  /// Students with status = transferred (3).
  final int transferred;

  /// Students with status = withdrawn (4).
  final int withdrawn;

  /// Students with status = deleted (5).
  final int deleted;

  static const empty = StudentStats(
    total: 0,
    active: 0,
    expelled: 0,
    graduated: 0,
    transferred: 0,
    withdrawn: 0,
    deleted: 0,
  );

  /// The term these counts are scoped to. Null means lifetime totals
  /// (no terms exist in the local DB yet).
  final CurrentTerm? currentTerm;

  String get subtitle {
    final parts = <String>[];
    if (active > 0) parts.add('$active active');
    if (graduated > 0) parts.add('$graduated graduated');
    if (transferred > 0) parts.add('$transferred transferred');
    if (expelled > 0) parts.add('$expelled expelled');
    if (withdrawn > 0) parts.add('$withdrawn withdrawn');
    return parts.isEmpty ? 'No students' : parts.join(', ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student / plan subscription stats
// ─────────────────────────────────────────────────────────────────────────────

/// Per-plan subscription count used inside [StudentPlanStats].
class PlanSubscriptionCount {
  const PlanSubscriptionCount({
    required this.planId,
    required this.planName,
    required this.count,
  });

  /// The plan's id (TEXT PK from the `plans` table).
  final String planId;

  /// Human-readable name of the plan.
  final String planName;

  /// Number of active subscriptions (status = active) for this plan
  /// across all schools in the local database.
  final int count;
}

/// Total student count plus per-plan subscription breakdown.
///
/// Used to build the donut chart on the stats section.
class StudentPlanStats {
  const StudentPlanStats({
    required this.totalStudents,
    required this.perPlan,
    required this.unsubscribed,
  });

  /// Total number of students across all schools in the local database.
  final int totalStudents;

  /// Subscription counts for every active plan that has at least one
  /// active subscription.
  final List<PlanSubscriptionCount> perPlan;

  /// Students with no active subscription to any plan.
  /// Computed as: [totalStudents] − sum of [perPlan] counts.
  final int unsubscribed;

  /// Returns an empty [StudentPlanStats] — used as initial state.
  static const empty = StudentPlanStats(
    totalStudents: 0,
    perPlan: [],
    unsubscribed: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Teacher stats
// ─────────────────────────────────────────────────────────────────────────────

/// Counts of teachers grouped by [TeacherStatus].
class TeacherStats {
  const TeacherStats({
    required this.total,
    required this.active,
    required this.resigned,
    required this.transferred,
    required this.fired,
    required this.retired,
  });

  final int total;

  /// Teachers with status = active (0).
  final int active;

  /// Teachers with status = resigned (1).
  final int resigned;

  /// Teachers with status = transferred (2).
  final int transferred;

  /// Teachers with status = fired (3).
  final int fired;

  /// Teachers with status = retired (4).
  final int retired;

  static const empty = TeacherStats(
    total: 0,
    active: 0,
    resigned: 0,
    transferred: 0,
    fired: 0,
    retired: 0,
  );

  /// Returns a brief human-readable summary string for the subtitle.
  String get subtitle {
    final parts = <String>[];
    if (active > 0) parts.add('$active active');
    if (resigned > 0) parts.add('$resigned resigned');
    if (transferred > 0) parts.add('$transferred transferred');
    if (fired > 0) parts.add('$fired fired');
    if (retired > 0) parts.add('$retired retired');
    return parts.isEmpty ? 'No teachers' : parts.join(', ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription stats
// ─────────────────────────────────────────────────────────────────────────────

/// Counts of subscriptions grouped by [SubscriptionStatus].
class SubscriptionStats {
  const SubscriptionStats({
    required this.total,
    required this.pending,
    required this.active,
    required this.cancelled,
    required this.deleted,
    this.currentTerm,
  });

  final int total;

  /// Subscriptions with status = pending (0).
  final int pending;

  /// Subscriptions with status = active (1).
  final int active;

  /// Subscriptions with status = cancelled (2).
  final int cancelled;

  /// Subscriptions with status = deleted (3).
  final int deleted;

  /// The term these counts are scoped to. Null means lifetime totals.
  final CurrentTerm? currentTerm;

  static const empty = SubscriptionStats(
    total: 0,
    pending: 0,
    active: 0,
    cancelled: 0,
    deleted: 0,
  );

  /// Returns a brief human-readable summary string for the subtitle.
  String get subtitle {
    final parts = <String>[];
    if (active > 0) parts.add('$active active');
    if (pending > 0) parts.add('$pending pending');
    if (cancelled > 0) parts.add('$cancelled cancelled');
    return parts.isEmpty ? 'No subscriptions' : parts.join(', ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Revenue stats
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregate payment/revenue statistics.
///
/// Revenue is derived from the `payments` table — sum of `amount` grouped
/// by [PaymentMethod]. If no payments exist, all values are zero.
class RevenueStats {
  const RevenueStats({
    required this.totalAmount,
    required this.totalCount,
    required this.cash,
    required this.cheque,
    required this.mpesa,
    required this.bank,
    this.currentTerm,
  });

  /// Sum of all payment amounts.
  final double totalAmount;

  /// Total number of payment records.
  final int totalCount;

  /// Sum of cash payments.
  final double cash;

  /// Sum of cheque payments.
  final double cheque;

  /// Sum of M-Pesa payments.
  final double mpesa;

  /// Sum of bank payments.
  final double bank;

  /// The term these totals are scoped to. Null means lifetime totals.
  final CurrentTerm? currentTerm;

  static const empty = RevenueStats(
    totalAmount: 0,
    totalCount: 0,
    cash: 0,
    cheque: 0,
    mpesa: 0,
    bank: 0,
  );

  /// Returns a brief human-readable summary string for the subtitle.
  String get subtitle {
    if (totalCount == 0) return 'No payments';
    final parts = <String>[];
    if (cash > 0) parts.add('cash ${_fmt(cash)}');
    if (mpesa > 0) parts.add('mpesa ${_fmt(mpesa)}');
    if (bank > 0) parts.add('bank ${_fmt(bank)}');
    if (cheque > 0) parts.add('cheque ${_fmt(cheque)}');
    return parts.isEmpty ? '$totalCount payments' : parts.join(', ');
  }

  static String _fmt(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}K';
    }
    return v.toStringAsFixed(0);
  }
}
