import 'dart:io';
import 'package:flutter/material.dart';

import '../../cache/file_cache.dart';

/// A reusable circular profile image widget that reads from the local file
/// cache.
///
/// Renders as a circle (WhatsApp/YouTube style). Falls back to a warm tinted
/// circle with a person icon when no cached image exists for [userId].
class UserAvatar extends StatelessWidget {
  final String userId;

  /// Half-size of the avatar. The rendered widget is `radius * 2` in both
  /// dimensions. Named [radius] to match [CircleAvatar]'s convention.
  final double radius;

  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.userId,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget avatar = FutureBuilder<File?>(
      future: FileCache.get(FileCache.profilePath(userId)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        // Warm fallback — tinted circle with person icon.
        return CircleAvatar(
          radius: radius,
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: radius * 0.9,
            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        );
      },
    );

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }

    return avatar;
  }
}
