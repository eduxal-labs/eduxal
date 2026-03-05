import 'package:flutter/material.dart';
import '../../database/tables/enums.dart';

/// Application theme and design tokens.
///
/// Surface elevation staircase
/// ───────────────────────────
/// Dark mode (slate family) — wider gaps for clear visual separation:
///   scaffold bg  → slate-950  #0A0E13   deepest layer
///   surface/card → slate-900  #121A24   cards, sheets, AppBar
///   container    → slate-800  #1A2435   section containers, input fills
///   item/row bg  → slate-700  #243042   elevated items inside containers
///   border       → slate-600  #334155   dividers, outlines (primary)
///   border light → slate-550  #3E4F65   outlineVariant (softer dividers)
///
/// Light mode (neutral gray family):
///   scaffold bg  → white      #FFFFFF
///   surface/card → gray-50    #F8F9FA
///   container    → gray-100   #F1F3F5   section containers, input fills
///   item/row bg  → gray-150   #E8EBEE   elevated items inside containers
///   border       → gray-250   #CED4DA   dividers, outlines (primary)
///   border light → gray-200   #DEE2E6   outlineVariant (softer dividers)
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────────────
  // Brand colours
  // ─────────────────────────────────────────────────────────────────────────

  static const Color brandIndigo = Color(0xFF3F51B5);
  static const Color brandGreen = Color(
    0xFF4CAF50,
  ); // Material Green 500 — action/CTA colour

  /// Lighter indigo for dark-mode primary text/icons.
  static const Color _indigoDark = Color(0xFF8C9EFF);

  /// Public alias for [_indigoDark] — lighter indigo used as the active/accent
  /// colour in dark mode (e.g. sidebar nav items, role badges).
  static const Color brandIndigoDark = Color(0xFF8C9EFF);

  // ─────────────────────────────────────────────────────────────────────────
  // Dark palette — slate staircase (wider gaps for real differentiation)
  // ─────────────────────────────────────────────────────────────────────────

  /// slate-950 — scaffold / page background.
  static const Color _slateBg = Color(0xFF0A0E13);

  /// slate-900 — surface: cards, sheets, dialogs, AppBar.
  static const Color _slateSurface = Color(0xFF121A24);

  /// slate-800 — surfaceContainer: section containers, input fills.
  static const Color _slateContainer = Color(0xFF1A2435);

  /// slate-700 — surfaceContainerHighest: row backgrounds, elevated items.
  static const Color _slateItem = Color(0xFF243042);

  /// slate-600 — outline: borders, dividers (stronger).
  static const Color _slateBorder = Color(0xFF334155);

  /// slate-550 — outlineVariant: softer dividers, secondary borders.
  static const Color _slateBorderLight = Color(0xFF3E4F65);

  // ─────────────────────────────────────────────────────────────────────────
  // Light palette — neutral gray staircase
  // ─────────────────────────────────────────────────────────────────────────

  /// white — scaffold / page background.
  static const Color _lightBg = Color(0xFFFFFFFF);

  /// gray-50 — surface: cards, sheets, dialogs, AppBar.
  static const Color _lightSurface = Color(0xFFF8F9FA);

  /// gray-100 — surfaceContainer: section containers, input fills.
  static const Color _lightContainer = Color(0xFFF1F3F5);

  /// gray-150 — surfaceContainerHighest: row backgrounds, elevated items.
  static const Color _lightItem = Color(0xFFE8EBEE);

  /// gray-250 — outline: borders, dividers (stronger).
  static const Color _lightBorder = Color(0xFFCED4DA);

  /// gray-200 — outlineVariant: softer dividers, secondary borders.
  static const Color _lightBorderLight = Color(0xFFDEE2E6);

  // ─────────────────────────────────────────────────────────────────────────
  // Responsive breakpoints
  // ─────────────────────────────────────────────────────────────────────────

  static const double kMobileBreakpoint = 600;
  static const double kTabletBreakpoint = 960;

  /// Width at which the full labelled sidebar replaces the icon rail.
  static const double kDesktopBreakpoint = 1200;

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
      surfaceContainerLowest: _lightBg,
      onSurface: const Color(0xFF1A1C1E),
      onSurfaceVariant: const Color(0xFF555E68),
      surfaceContainer: _lightContainer, // section containers, input fills
      surfaceContainerHighest: _lightItem, // row/item backgrounds
      outline: _lightBorder,
      outlineVariant: _lightBorderLight,
    );
    return _build(cs, scaffoldBg: _lightBg);
  }

  /// Dark theme — slate staircase, never pure black.
  ///
  /// Key contrast decisions:
  /// - `onSurface` is warm off-white (#E3E8ED) — high contrast on all slates.
  /// - `onSurfaceVariant` is brighter (#94A3B3) than before — secondary text
  ///   is clearly readable without squinting.
  /// - `outline` and `outlineVariant` are now distinct colours: outline is
  ///   the stronger border (#334155), outlineVariant the softer one (#3E4F65).
  ///   Previously both were #243040 which made borders invisible.
  /// - Surface staircase gaps are ~12-14 luminance units instead of ~6-8,
  ///   so cards visibly float above the scaffold and containers visibly
  ///   separate from their card parents.
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
      surfaceContainerLowest: _slateBg,
      onSurface: const Color(0xFFE3E8ED), // warm off-white, high readability
      onSurfaceVariant: const Color(0xFF94A3B3), // brighter secondary text
      surfaceContainer: _slateContainer, // section containers, input fills
      surfaceContainerHighest: _slateItem, // row/item backgrounds
      outline: _slateBorder, // primary borders — clearly visible
      outlineVariant: _slateBorderLight, // softer borders — still visible
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
      // WhatsApp-style: filled, rounded, subtle border visible in dark mode.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        isDense: false,

        // In dark mode, show a faint border even in the resting state so the
        // input field is visually distinct from surrounding containers.
        border: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: isLight
              ? BorderSide.none
              : BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _borderRadiusLg,
          borderSide: isLight
              ? BorderSide.none
              : BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
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
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
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
      // In dark mode, cards get a clearly visible border.
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: _borderRadius,
          side: BorderSide(
            color: isLight
                ? cs.outline.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.7),
          ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: isLight
            ? BorderSide.none
            : BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                width: 1,
              ),
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
        backgroundColor: isLight ? const Color(0xFF323232) : _slateItem,
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
        thickness: isLight ? 0.5 : 1.0,
        space: isLight ? 0.5 : 1.0,
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
        shape: RoundedRectangleBorder(
          borderRadius: _borderRadius,
          side: isLight
              ? BorderSide.none
              : BorderSide(color: cs.outline, width: 1),
        ),
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
          color: isLight ? const Color(0xFF616161) : _slateItem,
          borderRadius: BorderRadius.circular(8),
          border: isLight
              ? null
              : Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        dividerHeight: isLight ? 0.5 : 1.0,
      ),

      // ── NavigationBar ─────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? cs.surface : _slateSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primary.withValues(alpha: 0.12),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
