import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard form text field following the EduXal design system.
///
/// Renders: uppercase label above, TextFormField with filled decoration,
/// optional error banner below.
class EduFormField extends StatelessWidget {
  const EduFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.error,
    this.keyboardType,
    this.prefixText,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final String? prefixText;
  final int maxLines;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Uppercase label ──────────────────────────────────────────────
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),

        const SizedBox(height: 6),

        // ── Text form field ─────────────────────────────────────────────
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          onChanged: onChanged,
          enabled: enabled,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E2A3A)
                : cs.surfaceContainerLowest,
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            prefixText: prefixText,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: isDark
                  ? BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    )
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: isDark
                  ? BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    )
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide(color: cs.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide(color: cs.error, width: 1),
            ),
            // Hide the default error text — we render our own banner below.
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),

        // ── Error banner ────────────────────────────────────────────────
        if (error != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: cs.error.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.error.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
