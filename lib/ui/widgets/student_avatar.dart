import 'dart:io';
import 'package:flutter/material.dart';

import '../../cache/file_cache.dart';

/// A circular profile image for a student, reading from the local file cache.
///
/// Falls back to a circle with the student's initials when no cached image
/// exists. The background color is deterministically derived from [adm] for
/// visual variety.
///
/// Automatically rebuilds whenever [FileCacheNotifier] signals that the
/// student's cached image file has been written or updated on disk — both
/// for local saves (image picker) and remote downloads (sync engine).
class StudentAvatar extends StatefulWidget {
  final String schoolId;
  final int adm;
  final String name;

  /// Half-size of the avatar. The rendered widget is `radius * 2` in both
  /// dimensions.
  final double radius;

  final VoidCallback? onTap;

  const StudentAvatar({
    super.key,
    required this.schoolId,
    required this.adm,
    required this.name,
    this.radius = 16,
    this.onTap,
  });

  static const _colors = <Color>[
    Color(0xFF5C6BC0), // indigo
    Color(0xFF26A69A), // teal
    Color(0xFFEF5350), // red
    Color(0xFFFFA726), // amber
    Color(0xFF66BB6A), // green
    Color(0xFFAB47BC), // purple
    Color(0xFF42A5F5), // blue
    Color(0xFFEC407A), // pink
  ];

  @override
  State<StudentAvatar> createState() => _StudentAvatarState();
}

class _StudentAvatarState extends State<StudentAvatar> {
  late Future<File?> _future;
  late String _path;

  @override
  void initState() {
    super.initState();
    _path = FileCache.studentImagePath(widget.schoolId, widget.adm);
    _future = FileCache.get(_path);
    FileCacheNotifier.of(_path).addListener(_onFileChanged);
  }

  @override
  void didUpdateWidget(StudentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPath = FileCache.studentImagePath(widget.schoolId, widget.adm);
    if (newPath != _path) {
      FileCacheNotifier.of(_path).removeListener(_onFileChanged);
      _path = newPath;
      _future = FileCache.get(_path);
      FileCacheNotifier.of(_path).addListener(_onFileChanged);
    }
  }

  @override
  void dispose() {
    FileCacheNotifier.of(_path).removeListener(_onFileChanged);
    super.dispose();
  }

  void _onFileChanged() {
    setState(() {
      _future = FileCache.get(_path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor =
        StudentAvatar._colors[widget.adm % StudentAvatar._colors.length];

    // Extract initials: first letter of first word + first letter of last word
    final parts = widget.name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.isNotEmpty && parts.first.isNotEmpty
              ? parts.first[0].toUpperCase()
              : '?');

    Widget avatar = FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        // Fallback: colored circle with initials.
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: bgColor.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: TextStyle(
              fontSize: widget.radius * 0.7,
              fontWeight: FontWeight.w500,
              color: bgColor,
            ),
          ),
        );
      },
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
