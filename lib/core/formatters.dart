/// Shared formatting utilities used across the UI layer.
///
/// All date conversions use the app convention:
/// - `int` dates = days since Unix epoch
/// - `int` timestamps = milliseconds since Unix epoch
/// - `int` times = minutes since midnight (NOTE: some existing code uses seconds since midnight)
///
/// This file is pure Dart — no Flutter imports needed.
library;

/// Abbreviated month names (3-letter).
const List<String> kMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Full month names.
const List<String> kMonthNamesFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Abbreviated day names (Mon–Sun).
const List<String> kDayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

/// Converts days-since-epoch to a [DateTime] (UTC midnight).
DateTime dateFromDays(int daysSinceEpoch) =>
    DateTime.utc(1970, 1, 1).add(Duration(days: daysSinceEpoch));

/// Converts a [DateTime] to days-since-epoch.
int daysFromDate(DateTime dt) {
  final utc = DateTime.utc(dt.year, dt.month, dt.day);
  return utc.difference(DateTime.utc(1970, 1, 1)).inDays;
}

// ---------------------------------------------------------------------------
// Date formatting
// ---------------------------------------------------------------------------

/// Formats days-since-epoch to "12 Jan 2025".
String fmtDate(int daysSinceEpoch) {
  final d = dateFromDays(daysSinceEpoch);
  return '${d.day.toString().padLeft(2, '0')} ${kMonthNames[d.month - 1]} ${d.year}';
}

/// Formats days-since-epoch to "12 January 2025" (full month).
String fmtDateFull(int daysSinceEpoch) {
  final d = dateFromDays(daysSinceEpoch);
  return '${d.day.toString().padLeft(2, '0')} ${kMonthNamesFull[d.month - 1]} ${d.year}';
}

/// Formats a [DateTime] to "12 Jan 2025".
String fmtDateDt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${kMonthNames[d.month - 1]} ${d.year}';

/// Returns "Today", "Yesterday", or the formatted date ("12 Jan 2025").
String fmtDateContextual(int daysSinceEpoch) {
  final now = DateTime.now();
  final today = daysFromDate(now);
  final diff = today - daysSinceEpoch;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return fmtDate(daysSinceEpoch);
}

// ---------------------------------------------------------------------------
// Time formatting
// ---------------------------------------------------------------------------

/// Formats minutes-since-midnight to "8:30 AM".
String fmtTime(int minutesSinceMidnight) {
  final totalMinutes = minutesSinceMidnight.clamp(0, 1439);
  final h24 = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  final period = h24 < 12 ? 'AM' : 'PM';
  final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// Formats seconds-since-midnight to "08:30" (24-hour, zero-padded).
String fmtTimeSecs(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Formats a [DateTime] to "08:30" (24-hour, zero-padded).
String fmtTimeDt(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Numeric formatting
// ---------------------------------------------------------------------------

/// Formats a double score: shows 1 decimal place if fractional, otherwise integer.
///
/// Examples: `92.0` → `"92"`, `91.6` → `"91.6"`.
String fmtScore(double score) => score == score.truncateToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(1);

/// Formats a percentage: 1 decimal if fractional, otherwise integer, with "%".
///
/// Examples: `92.0` → `"92%"`, `91.6` → `"91.6%"`.
String fmtPercent(double value) => value == value.truncateToDouble()
    ? '${value.toInt()}%'
    : '${value.toStringAsFixed(1)}%';

/// Formats a currency amount with thousands separators.
///
/// Defaults to KES. The [currency] parameter allows overriding.
///
/// Examples: `12500.0` → `"KES 12,500.00"`, `-1234.5` → `"-KES 1,234.50"`.
String fmtCurrency(double amount, {String currency = 'KES'}) {
  final isNegative = amount < 0;
  final absAmount = amount.abs();
  final parts = absAmount.toStringAsFixed(2).split('.');
  final wholePart = parts[0];
  final decimalPart = parts[1];

  final buffer = StringBuffer();
  for (var i = 0; i < wholePart.length; i++) {
    if (i > 0 && (wholePart.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(wholePart[i]);
  }

  return '${isNegative ? '-' : ''}$currency ${buffer.toString()}.$decimalPart';
}

// ---------------------------------------------------------------------------
// Relative time
// ---------------------------------------------------------------------------

/// Formats milliseconds-since-epoch to relative time.
///
/// Returns "Just now", "2 minutes ago", "1 hour ago", "3 days ago", etc.
String fmtRelativeTime(int msSinceEpoch) {
  final time = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch);
  final diff = DateTime.now().difference(time);

  if (diff.isNegative) return 'Just now';
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  final d = diff.inDays;
  return '$d ${d == 1 ? 'day' : 'days'} ago';
}
