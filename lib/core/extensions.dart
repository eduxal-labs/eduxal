/// Dart extension methods with no Flutter dependencies.
///
/// All logic here is pure Dart — safe to use in services, DAOs, and tests
/// without a Flutter binding.
library;

import '../models/school_config.dart';

/// Kenyan phone number normalisation.
///
/// Kenyan mobile numbers use the prefixes 07xx and 01xx (Safaricom, Airtel,
/// Telkom). The canonical local format is 10 digits: `07xxxxxxxx` / `01xxxxxxxx`.
/// Inputs may arrive from the user in any of several formats — this extension
/// collapses them all to the single canonical form.
extension PhoneNormalisation on String {
  /// Normalises a Kenyan phone number to 10-digit local format.
  ///
  /// Accepted input formats (spaces/dashes ignored via trim):
  /// - `07xxxxxxxx`       — already local format
  /// - `01xxxxxxxx`       — already local format
  /// - `+2547xxxxxxxx`    — international with leading `+`
  /// - `+2541xxxxxxxx`    — international with leading `+`
  /// - `2547xxxxxxxx`     — international without leading `+`
  /// - `2541xxxxxxxx`     — international without leading `+`
  ///
  /// Returns the 10-digit local string, or `null` if the input is not a
  /// recognisable Kenyan mobile number.
  ///
  /// Examples:
  /// ```dart
  /// '+254712345678'.toKenyanPhone() // '0712345678'
  /// '254712345678'.toKenyanPhone()  // '0712345678'
  /// '0712345678'.toKenyanPhone()    // '0712345678'
  /// '123'.toKenyanPhone()           // null
  /// ```
  String? toKenyanPhone() {
    final s = trim();

    // Strip a leading `+` if present, then work with digits only.
    final digitsOnly = s.startsWith('+') ? s.substring(1) : s;

    // Must contain only digits after stripping the optional `+`.
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) return null;

    // International format: 254 7xx xxx xxx  or  254 1xx xxx xxx
    // Length: 3 (country code) + 9 (subscriber) = 12 digits total.
    if (digitsOnly.startsWith('254') && digitsOnly.length == 12) {
      final subscriber = digitsOnly.substring(
        3,
      ); // 9 digits: 7xxxxxxxx / 1xxxxxxxx
      if (subscriber.startsWith('7') || subscriber.startsWith('1')) {
        return '0$subscriber';
      }
      return null;
    }

    // Local format: 07xxxxxxxx or 01xxxxxxxx — exactly 10 digits.
    if (digitsOnly.length == 10) {
      if (digitsOnly.startsWith('07') || digitsOnly.startsWith('01')) {
        return digitsOnly;
      }
      return null;
    }

    // 9-digit subscriber number without leading zero: 7xxxxxxxx / 1xxxxxxxx.
    // Prepend '0' to normalise to the canonical 10-digit local format.
    if (digitsOnly.length == 9) {
      if (digitsOnly.startsWith('7') || digitsOnly.startsWith('1')) {
        return '0$digitsOnly';
      }
      return null;
    }

    return null;
  }
}

// ============================================================
// Grade label utilities
// ============================================================

/// Converts a raw grade integer to a human-readable label.
///
/// Uses the dual-lookup pattern: checks CBC labels first, then 8-4-4.
/// Grade numbers 41–44 are unambiguous (only exist in 8-4-4: Form 1–4).
/// Grade numbers 1–14 check CBC first (PP1, PP2, Grade 1–12).
///
/// If [config] is provided, it constrains the lookup to only the school's
/// active curricula. If null, the dual-lookup fallback is used.
///
/// **Never returns the raw integer.** Falls back to 'Level $grade' only as
/// a last resort for truly unknown values.
String gradeLabel(int grade, {SchoolConfig? config}) {
  if (config != null) {
    for (final c in config.curricula) {
      final labels = gradeLabelsFor(c.type);
      if (labels.containsKey(grade)) return labels[grade]!;
    }
  }
  // Dual-lookup fallback (no config or grade not found in config's curricula)
  return kCbcGradeLabels[grade] ??
      kEightFourFourGradeLabels[grade] ??
      'Level $grade';
}

/// Builds a "Grade · Stream" display string.
///
/// [streamName] is the resolved stream name (from CatalogDao). If null,
/// only the grade label is returned (no " · Stream X" fallback — raw stream
/// IDs must never leak to the UI).
String gradeStreamLabel(int grade, {String? streamName, SchoolConfig? config}) {
  final g = gradeLabel(grade, config: config);
  if (streamName != null && streamName.isNotEmpty) return '$g · $streamName';
  return g;
}
