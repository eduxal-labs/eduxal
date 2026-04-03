import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/permissions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission helpers — shared across UI and service layers.
//
// Extracted from lib/ui/screens/school_dashboard/roles/_role_helpers.dart.
// See BUG-011 and BUG-012 in BUG.md for the history behind the resilient
// multi-format parser.
// ─────────────────────────────────────────────────────────────────────────────

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
/// format stored in `roles.permissions`.
///
/// Output shape: `[{"resource": "users", "actions": ["read", "create"]}, …]`
@Deprecated(
  'Use Permissions(map).toBlob() for sync payloads. '
  'This function is retained only for writing to the local DB '
  'roles.permissions text column.',
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
