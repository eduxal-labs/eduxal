import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EduSheet — standard bottom sheet wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Standard bottom sheet wrapper following the EduXal design system.
///
/// Renders: modalBg background, kModalRadius top corners, drag handle,
/// optional title row with close button, and child content.
class EduSheet extends StatelessWidget {
  const EduSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.showHandle = true,
    this.maxHeight = 0.9,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onClose;

  /// Whether to show the drag-handle pill at the top.
  final bool showHandle;

  /// Maximum height as a fraction of the screen. Defaults to 0.9 (90%).
  /// Pass `null` to let the sheet size itself unconstrained.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle) _SheetHandle(cs: cs),
        if (title != null)
          _SheetTitleRow(
            title: title!,
            cs: cs,
            onClose: onClose ?? () => Navigator.of(context).pop(),
          ),
        Flexible(child: child),
      ],
    );

    if (maxHeight != null) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * maxHeight!),
        child: content,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppTheme.borderColor(isDark, cs)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: content,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet handle
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet title row
// ─────────────────────────────────────────────────────────────────────────────

class _SheetTitleRow extends StatelessWidget {
  const _SheetTitleRow({
    required this.title,
    required this.cs,
    required this.onClose,
  });

  final String title;
  final ColorScheme cs;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: cs.onSurfaceVariant,
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// showEduSheet — adaptive launcher (desktop dialog / mobile bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

/// Convenience launcher — desktop (≥ 600 px): dialog, mobile: bottom sheet.
///
/// On desktop, wraps the [builder] content in a standard EduXal dialog with
/// modalBg, border, shadow, and constrained width.
///
/// On mobile, returns the [builder] content directly inside a
/// [showModalBottomSheet] (each sheet provides its own header).
Future<T?> showEduSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  // title parameter is deprecated — sheets render their own headers
  String? title,
  double maxWidth = 480,
}) {
  final w = MediaQuery.sizeOf(context).width;

  if (w >= AppTheme.kMobileBreakpoint) {
    // ── Desktop: dialog ──────────────────────────────────────────────────
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = cs.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.modalBg(isDark, cs),
                borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
                border: Border.all(
                  color: AppTheme.borderColor(isDark, cs),
                  width: 1,
                ),
                boxShadow: AppTheme.modalShadow(isDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Flexible(child: builder(ctx))],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Mobile: bottom sheet ─────────────────────────────────────────────────
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => builder(ctx),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog title row (used inside desktop dialog variant of showEduSheet)
// ─────────────────────────────────────────────────────────────────────────────

class _DialogTitleRow extends StatelessWidget {
  const _DialogTitleRow({required this.title, required this.ctx});

  final String title;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.3)),
      ],
    );
  }
}
