import 'package:flutter/material.dart';
import '../../database/tables/enums.dart';

/// Application theme and design tokens.
///
/// Surface elevation staircase
/// ───────────────────────────
/// Dark mode (slate family):
///   scaffold bg  → slate-950  #0B0F14
///   surface/card → slate-900  #111720
///   container    → slate-850  #161E28  (section containers, input fills)
///   item/row bg  → slate-800  #1C2530  (elevated items inside containers)
///   border       → slate-700  #243040  (dividers, outlines)
///
/// Light mode (neutral gray family):
///   scaffold bg  → white      #FFFFFF
///   surface/card → gray-50    #F8F9FA
///   container    → gray-100   #F1F3F5  (section containers, input fills)
///   item/row bg  → gray-150   #E9ECEF  (elevated items inside containers)
///   border       → gray-200   #DEE2E6  (dividers, outlines)
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────────────
  // Brand colours
  // ─────────────────────────────────────────────────────────────────────────

  static const Color brandIndigo = Color(0xFF3F51B5);
  static const Color brandGreen = Color(0xFF00A884); // WhatsApp-ish teal-green

  /// Lighter indigo for dark-mode primary text/icons.
  static const Color _indigoDark = Color(0xFF8C9EFF);

  // ─────────────────────────────────────────────────────────────────────────
  // Dark palette — slate staircase (950 → 700)
  // ─────────────────────────────────────────────────────────────────────────

  /// slate-950 — scaffold / page background.
  static const Color _slateBg = Color(0xFF0B0F14);

  /// slate-900 — surface: cards, sheets, dialogs, AppBar.
  static const Color _slateSurface = Color(0xFF111720);

  /// slate-850 — surfaceContainer: section containers, input fills.
  static const Color _slateContainer = Color(0xFF161E28);

  /// slate-800 — surfaceContainerHighest: row backgrounds, elevated items.
  static const Color _slateItem = Color(0xFF1C2530);

  /// slate-700 — outline / border / divider.
  static const Color _slateBorder = Color(0xFF243040);

  // ─────────────────────────────────────────────────────────────────────────
  // Light palette — neutral gray staircase (white → gray-200)
  // ─────────────────────────────────────────────────────────────────────────

  /// white — scaffold / page background.
  static const Color _lightBg = Color(0xFFFFFFFF);

  /// gray-50 — surface: cards, sheets, dialogs, AppBar.
  static const Color _lightSurface = Color(0xFFF8F9FA);

  /// gray-100 — surfaceContainer: section containers, input fills.
  static const Color _lightContainer = Color(0xFFF1F3F5);

  /// gray-150 — surfaceContainerHighest: row backgrounds, elevated items.
  static const Color _lightItem = Color(0xFFE9ECEF);

  /// gray-200 — outline / border / divider.
  static const Color _lightBorder = Color(0xFFDEE2E6);

  // ─────────────────────────────────────────────────────────────────────────
  // Responsive breakpoints
  // ─────────────────────────────────────────────────────────────────────────

  static const double kMobileBreakpoint = 600;
  static const double kTabletBreakpoint = 960;

  // ─────────────────────────────────────────────────────────────────────────
  // Corner radius — single source of truth
  // ─────────────────────────────────────────────────────────────────────────

  /// Comfortable radius: not sharp, not pill. Feels like WhatsApp/YouTube.
  static const double kRadius = 12.0;
  static const Radius _radius = Radius.circular(kRadius);
  static const BorderRadius _borderRadius = BorderRadius.all(_radius);

  /// Larger radius for full-width CTAs and inputs.
  static const double kRadiusLg = 14.0;
  static const BorderRadius _borderRadiusLg = BorderRadius.all(
    Radius.circular(kRadiusLg),
  );

  /// Bottom sheets: comfortable top corners.
  static const BorderRadius _sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Theme mode mapping
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps the database [AppThemeMode] to Flutter's [ThemeMode].
  static ThemeMode resolveThemeMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Public theme constructors
  // ─────────────────────────────────────────────────────────────────────────

  /// Light theme.
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: brandIndigo,
      brightness: Brightness.light,
    );
    final cs = base.copyWith(
      primary: brandIndigo,
      secondary: brandGreen,
      // Scaffold bg is pure white — set via scaffoldBg below.
      surface: _lightSurface, // cards, sheets, AppBar
      onSurface: const Color(0xFF1A1C1E),
      onSurfaceVariant: const Color(0xFF5F6368),
      surfaceContainer: _lightContainer, // section containers, input fills
      surfaceContainerHighest: _lightItem, // row/item backgrounds
      outline: _lightBorder,
      outlineVariant: _lightBorder,
    );
    return _build(cs, scaffoldBg: _lightBg);
  }

  /// Dark theme — slate staircase, never pure black.
  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: brandIndigo,
      brightness: Brightness.dark,
    );
    final cs = base.copyWith(
      primary: _indigoDark,
      secondary: brandGreen,
      // Scaffold bg is slate-950 — set via scaffoldBg below.
      surface: _slateSurface, // cards, sheets, AppBar
      onSurface: const Color(0xFFE9EDEF),
      onSurfaceVariant: const Color(0xFF8696A0),
      surfaceContainer: _slateContainer, // section containers, input fills
      surfaceContainerHighest: _slateItem, // row/item backgrounds
      outline: _slateBorder,
      outlineVariant: _slateBorder,
    );
    return _build(cs, scaffoldBg: _slateBg);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal builder
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData _build(ColorScheme cs, {Color? scaffoldBg}) {
    final isLight = cs.brightness == Brightness.light;
    final bg = scaffoldBg ?? cs.surface;

    // Input fill: one step above the surface — surfaceContainer.
    final inputFill = isLight ? _lightContainer : _slateContainer;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      dividerColor: cs.outlineVariant,
      splashFactory: InkRipple.splashFactory,

      // ── Typography ──────────────────────────────────────────────────────
      // Normal, readable weights. No ultra-thin w200/w300 on body text.
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
        ),
        displayMedium: const TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
        ),
        displaySmall: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
        ),
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: cs.onSurface, size: 22),
      ),

      // ── Elevated Button (primary CTA — green) ──────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: brandGreen.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white60,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: _borderRadiusLg),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          elevation: 0,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(borderRadius: _borderRadiusLg),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      // ── Text Button (secondary actions) ────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ── Icon Button ───────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 22,
          padding: const EdgeInsets.all(8),
          shape: const CircleBorder(),
        ),
      ),

      // ── Input Decoration (text fields) ─────────────────────────────────
      // WhatsApp-style: filled, rounded, no visible border by default.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        isDense: false,

        border: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),

        hintStyle: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
        labelStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
        floatingLabelStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        errorStyle: TextStyle(
          color: cs.error,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────────
      // slate-900 / gray-50 surface — one step above the scaffold bg.
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: _borderRadius,
          side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        backgroundColor: cs.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Dialogs ────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isLight ? Colors.white : _slateSurface,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 4 : 0,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        contentTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),

      // ── Bottom Sheet ───────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? Colors.white : _slateSurface,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 8 : 0,
        shape: const RoundedRectangleBorder(borderRadius: _sheetRadius),
        showDragHandle: false,
        modalBarrierColor: Colors.black54,
      ),

      // ── SnackBar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        backgroundColor: isLight ? const Color(0xFF323232) : _slateContainer,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        elevation: 2,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ── Divider ────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),

      // ── ListTile ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── PopupMenu ─────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        color: isLight ? Colors.white : _slateSurface,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 4 : 2,
        textStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── Tooltip ────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFF616161) : _slateContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Progress Indicator ─────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brandGreen,
        linearTrackColor: brandGreen.withValues(alpha: 0.15),
        circularTrackColor: brandGreen.withValues(alpha: 0.15),
      ),

      // ── FloatingActionButton ──────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── TabBar ────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        dividerColor: cs.outlineVariant,
        dividerHeight: 0.5,
      ),
    );
  }
}
