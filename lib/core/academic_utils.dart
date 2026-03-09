import 'package:flutter/material.dart';

/// Shared utility functions used across the Academics section.
///
/// Centralises color-coding, formatting, and date conversion logic that was
/// previously duplicated as private helpers (`_pctColor`, `_fmtDate`,
/// `_fmtScore`, etc.) across many tab and page files.

// ─────────────────────────────────────────────────────────────────────────────
// Color utilities
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a color for a percentage score (0–100).
///
/// - ≥ 75%: green
/// - ≥ 50%: amber
/// - < 50%: red
Color percentageColor(double percent) {
  if (percent >= 75) return const Color(0xFF4CAF50);
  if (percent >= 50) return const Color(0xFFFFC107);
  return const Color(0xFFF44336);
}

/// Returns a mastery-specific color with 4 tiers.
///
/// - ≥ 80%: green
/// - ≥ 60%: amber
/// - ≥ 40%: orange
/// - < 40%: red
Color masteryColor(double percent) {
  if (percent >= 80) return const Color(0xFF4CAF50);
  if (percent >= 60) return const Color(0xFFFFC107);
  if (percent >= 40) return const Color(0xFFFF9800);
  return const Color(0xFFF44336);
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatting utilities
// ─────────────────────────────────────────────────────────────────────────────

/// Formats a percentage for display: "72.4%" or "—" if null.
String formatPercent(double? percent) {
  if (percent == null) return '—';
  return '${percent.toStringAsFixed(1)}%';
}

/// Formats a score as "72/100" or "—" if null.
String formatScore(double? score, int? total) {
  if (score == null || total == null) return '—';
  final scoreStr = score.truncateToDouble() == score
      ? score.toInt().toString()
      : score.toStringAsFixed(1);
  return '$scoreStr/$total';
}

/// Formats days-since-epoch to a readable date string.
/// E.g. "12 Mar 2025".
String formatDateFromDays(int? daysSinceEpoch) {
  if (daysSinceEpoch == null) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// Formats seconds-since-epoch to a readable date string.
String formatDateFromSeconds(int? secondsSinceEpoch) {
  if (secondsSinceEpoch == null) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// Formats seconds since midnight to "HH:MM".
String formatTimeOfDay(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

const _months = [
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
