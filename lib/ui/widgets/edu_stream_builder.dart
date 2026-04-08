import 'package:flutter/material.dart';

import '../../ui/theme/app_theme.dart';

/// A convenience wrapper around [StreamBuilder] that provides consistent
/// error-handling and loading states across the app.
///
/// Usage:
/// ```dart
/// EduStreamBuilder<List<StudentsData>>(
///   stream: dao.watchStudents(schoolId),
///   builder: (context, students) => StudentList(students: students),
/// )
/// ```
///
/// Optionally supply [loading] to override the default centered spinner,
/// or [errorBuilder] to override the default compact error card.
class EduStreamBuilder<T> extends StatelessWidget {
  const EduStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loading,
    this.errorBuilder,
  });

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(snapshot.error!, snapshot.stackTrace);
          }
          return _DefaultErrorWidget(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return loading ??
              const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Compact error card shown when a stream emits an error and no custom
/// [EduStreamBuilder.errorBuilder] is provided.
///
/// Follows §21 conventions: `kCardRadius`, `w400` body text, tinted icon
/// circle, subtle border.
class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.nestedBg(isDark, cs)
                : cs.errorContainer.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            border: Border.all(
              color: isDark
                  ? cs.error.withValues(alpha: 0.25)
                  : cs.error.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tinted icon circle (matches EduEmptyState pattern).
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: cs.error.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              // Error text.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
