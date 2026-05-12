import 'dart:io';
import 'package:flutter/material.dart';

import '../../cache/file_cache.dart';

/// A reusable circular profile image widget that reads from the local file
/// cache and updates in real-time when the file changes.
///
/// Renders as a circle (WhatsApp/YouTube style). Falls back to a warm tinted
/// circle with a person icon when no cached image exists for [userId].
class UserAvatar extends StatefulWidget {
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
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _loadFile();
    FileCacheNotifier.of(FileCache.profilePath(widget.userId))
        .addListener(_onFileChanged);
  }

  @override
  void didUpdateWidget(covariant UserAvatar old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      FileCacheNotifier.of(FileCache.profilePath(old.userId))
          .removeListener(_onFileChanged);
      FileCacheNotifier.of(FileCache.profilePath(widget.userId))
          .addListener(_onFileChanged);
      _loadFile();
    }
  }

  @override
  void dispose() {
    FileCacheNotifier.of(FileCache.profilePath(widget.userId))
        .removeListener(_onFileChanged);
    super.dispose();
  }

  void _onFileChanged() {
    _loadFile();
  }

  Future<void> _loadFile() async {
    final file = await FileCache.get(FileCache.profilePath(widget.userId));
    if (!mounted) return;
    setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasImage = _file != null && _file!.existsSync();

    Widget avatar = CircleAvatar(
      radius: widget.radius,
      backgroundImage: hasImage ? FileImage(_file!) : null,
      backgroundColor: cs.surfaceContainerHighest,
      child: hasImage
          ? null
          : Icon(
              Icons.person,
              size: widget.radius * 0.9,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
    );

    if (widget.onTap != null) {
      avatar = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }

    return avatar;
  }
}
