import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/permissions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission helpers — shared across UI and service layers.
//
// Extracted from lib/ui/screens/school_dashboard/roles/_role_helpers.dart.
// See BUG-011 and BUG-012 in BUG.md for the history behind the resilient
// multi-format parser.
//
// As of Task A01 the `roles.permissions` column is a `BlobColumn` storing the
// canonical binary blob format `[resource_id: u8, actions_lo: u8, actions_hi:
// u8]` triplets.  The new canonical parser is [parsePermissionsBlob].
// [parsePermissions] is retained (deprecated) only for the schema migration
// that converts old text data to blob.
// ─────────────────────────────────────────────────────────────────────────────

/// Parses permissions from a [Uint8List] blob — the canonical storage format
/// as of schema version 10 (`roles.permissions` is now a `BlobColumn`).
///
/// The canonical encoding is `[resource_id: u8, actions_lo: u8, actions_hi:
/// u8]` triplets (see [Permissions.fromBlob]).
///
/// As a **fallback** for data that may still be UTF-8-encoded JSON (e.g. rows
/// that survived a partial migration or delta-writer edge cases), the function
/// also tries to interpret the bytes as a UTF-8 JSON string and parse via the
/// legacy [parsePermissions] path.
///
/// Never throws — returns an empty map on null/empty/bad input.
Map<Resource, int> parsePermissionsBlob(Uint8List? blob) {
  if (blob == null || blob.isEmpty) return {};

  // ── Attempt 1: canonical binary blob ─────────────────────────────────────
  final perms = Permissions.fromBlob(blob);
  if (perms.isNotEmpty) {
    final result = Map<Resource, int>.from(perms.map);
    debugPrint(
      '[parsePermissionsBlob] Parsed binary blob: ${result.length} resources',
    );
    return result;
  }

  // ── Attempt 2: bytes might be UTF-8 JSON (legacy / migration compat) ────
  try {
    final json = utf8.decode(blob);
    // ignore: deprecated_member_use_from_same_package
    final legacy = parsePermissions(json);
    if (legacy.isNotEmpty) {
      debugPrint(
        '[parsePermissionsBlob] Parsed via UTF-8 JSON fallback: '
        '${legacy.length} resources',
      );
      return legacy;
    }
  } catch (_) {
    // Not valid UTF-8 — that's fine, just means the blob was truly empty or
    // in an unknown format.
  }

  debugPrint(
    '[parsePermissionsBlob] No permissions parsed from ${blob.length} bytes',
  );
  return {};
}

/// Parses the JSON string stored in `roles.permissions` into a mutable
/// `Map<Resource, int>` bitmask map.
///
/// Handles all known storage formats:
///   1. Standard JSON (list of objects or flat map) via [Permissions.fromJson].
///   2. Seeder binary-int array: `[5,2,0,7,2,0,...]` — a JSON array of raw
///      integers representing the `[resource_id, lo, hi]` binary blob format.
///   3. Base64-encoded string — decoded to bytes, then tried as UTF-8 JSON
///      (format 1) or as a raw binary blob (format 2).
///
/// Never throws — always returns an empty map on bad input.
///
/// **Deprecated:** As of Task A01 the `roles.permissions` column is a
/// `BlobColumn`.  Use [parsePermissionsBlob] for all new code.  This function
/// is retained only for the schema migration that converts old text rows and
/// for the delta-writer fallback path.
@Deprecated(
  'Use parsePermissionsBlob() — roles.permissions is now a blob column',
)
Map<Resource, int> parsePermissions(String? jsonStr) {
  if (jsonStr == null ||
      jsonStr.isEmpty ||
      jsonStr == '[]' ||
      jsonStr == '{}') {
    debugPrint('[parsePermissions] Empty/null input: "$jsonStr"');
    return {};
  }
  debugPrint('[parsePermissions] Input (${jsonStr.length} chars): $jsonStr');

  // ── Attempt 1: Standard JSON decode ──────────────────────────────────────
  try {
    final decoded = jsonDecode(jsonStr);
    final perms = Permissions.fromJson(decoded);
    if (perms.isNotEmpty) {
      final result = Map<Resource, int>.from(perms.map);
      debugPrint(
        '[parsePermissions] Parsed via fromJson: ${result.length} resources: $result',
      );
      return result;
    }

    // fromJson returned empty but decoded was a non-empty List<int> →
    // might be the seeder's binary blob format: [resource_id, lo, hi, ...]
    if (decoded is List && decoded.isNotEmpty && decoded.first is int) {
      try {
        final bytes = Uint8List.fromList(decoded.cast<int>());
        final blobPerms = Permissions.fromBlob(bytes);
        if (blobPerms.isNotEmpty) {
          final result = Map<Resource, int>.from(blobPerms.map);
          debugPrint(
            '[parsePermissions] Parsed via fromBlob (int-list JSON): ${result.length} resources: $result',
          );
          return result;
        }
      } catch (e) {
        debugPrint('[parsePermissions] fromBlob on int-list failed: $e');
      }
    }

    debugPrint('[parsePermissions] JSON decoded but no permissions found');
    return {};
  } catch (_) {
    // jsonDecode failed — might be base64
    debugPrint('[parsePermissions] jsonDecode failed, trying base64 decode');
  }

  // ── Attempt 2: base64 decode → UTF-8 JSON string ────────────────────────
  try {
    final bytes = base64Decode(jsonStr);
    final jsonFromBytes = utf8.decode(bytes);
    final decoded = jsonDecode(jsonFromBytes);
    final perms = Permissions.fromJson(decoded);
    if (perms.isNotEmpty) {
      final result = Map<Resource, int>.from(perms.map);
      debugPrint(
        '[parsePermissions] Parsed via base64→utf8→fromJson: ${result.length} resources: $result',
      );
      return result;
    }
  } catch (e) {
    debugPrint('[parsePermissions] base64→utf8→fromJson failed: $e');
  }

  // ── Attempt 3: base64 decode → raw binary blob ──────────────────────────
  try {
    final bytes = Uint8List.fromList(base64Decode(jsonStr));
    final blobPerms = Permissions.fromBlob(bytes);
    if (blobPerms.isNotEmpty) {
      final result = Map<Resource, int>.from(blobPerms.map);
      debugPrint(
        '[parsePermissions] Parsed via base64→fromBlob: ${result.length} resources: $result',
      );
      return result;
    }
  } catch (e) {
    debugPrint('[parsePermissions] base64→fromBlob failed: $e');
  }

  debugPrint(
    '[parsePermissions] All parse attempts exhausted — returning empty map',
  );
  return {};
}

/// Serialises a `Map<Resource, int>` bitmask map back to the JSON string
/// format formerly stored in `roles.permissions`.
///
/// Output shape: `[{"resource": "users", "actions": ["read", "create"]}, …]`
///
/// **Deprecated:** As of Task A01 the column is a `BlobColumn`.  Use
/// `Permissions(map).toBlob()` instead.  This function is retained only for
/// the schema migration and for debug logging.
@Deprecated(
  'Use Permissions(map).toBlob() — roles.permissions is now a blob column.',
)
String serialisePermissions(Map<Resource, int> perms) {
  final list = <Map<String, dynamic>>[];
  for (final entry in perms.entries) {
    if (entry.value == 0) continue;
    final actions = Action.values
        .where((a) => entry.value & a.mask != 0)
        .map((a) => a.name)
        .toList();
    if (actions.isNotEmpty) {
      list.add({'resource': entry.key.name, 'actions': actions});
    }
  }
  return jsonEncode(list);
}

/// Returns the total count of granted permissions across all resources.
int countPermissions(Map<Resource, int> perms) {
  var count = 0;
  for (final mask in perms.values) {
    count += popcount(mask);
  }
  return count;
}

/// Count set bits in a 16-bit integer (Hamming weight / popcount).
int popcount(int v) {
  var n = v & 0xFFFF;
  n = n - ((n >> 1) & 0x5555);
  n = (n & 0x3333) + ((n >> 2) & 0x3333);
  return (((n + (n >> 4)) & 0x0F0F) * 0x0101) & 0xFF;
}
