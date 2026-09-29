import 'package:flutter/material.dart';
import 'tokens.dart';

/// PULSE light + dark themes. Dark mode is intentionally designed:
/// lifted brand colors for contrast, warm-tinted charcoal surfaces,
/// elevated surface layering instead of inverted whites.
class PulseTheme {
  const PulseTheme._();

  static ThemeData light({bool highContrast = false}) {
    final scheme = const ColorScheme.light(
      primary: PulseColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD3EDE6),
      onPrimaryContainer: PulseColors.primaryDark,
      secondary: PulseColors.secondary,
      onSecondary: Colors.white,
      tertiary: PulseColors.accent,
      onTertiary: Colors.white,
      error: PulseColors.error,
      onError: Colors.white,
      surface: PulseColors.lightSurface,
      onSurface: PulseColors.lightText,
      surfaceContainerHighest: PulseColors.lightSurfaceAlt,
      outline: PulseColors.lightDivider,
    );
    return _base(scheme, Brightness.light, highContrast);
  }

  static ThemeData dark({bool highContrast = false}) {
    final scheme = const ColorScheme.dark(
      primary: PulseColors.darkPrimary,
      onPrimary: Color(0xFF07211C),
      primaryContainer: Color(0xFF1E4A40),
      onPrimaryContainer: Color(0xFFBDE9DD),
      secondary: PulseColors.secondary,
      onSecondary: Colors.white,
      tertiary: PulseColors.darkAccent,
      onTertiary: Color(0xFF2B0F08),
      error: Color(0xFFFF8f88),
      onError: Color(0xFF420E0E),
      surface: PulseColors.darkSurface,
      onSurface: PulseColors.darkText,
      surfaceContainerHighest: PulseColors.darkSurfaceAlt,
      outline: PulseColors.darkDivider,
    );
    return _base(scheme, Brightness.dark, highContrast);
  }

  static ThemeData _base(ColorScheme scheme, Brightness b, bool hc) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? PulseColors.darkBg : PulseColors.lightBg;
    final surface = isDark ? PulseColors.darkSurface : PulseColors.lightSurface;
    final divider = isDark ? PulseColors.darkDivider : PulseColors.lightDivider;
    final textMain = isDark ? PulseColors.darkText : PulseColors.lightText;
    final textSec =
        isDark ? PulseColors.darkTextSecondary : PulseColors.lightTextSecondary;

    final cardShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PulseRadius.l));
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.m));

    // High Contrast mode: heavier outlines, pure-on backgrounds, thicker strokes.
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: hc
          ? scheme.copyWith(
              surface: isDark ? Colors.black : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black,
            )
          : scheme,
      scaffoldBackgroundColor: hc ? (isDark ? Colors.black : Colors.white) : bg,
      textTheme: PulseTypography.textTheme(b),
      dividerColor: divider,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        foregroundColor: textMain,
        titleTextStyle: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w700, color: textMain),
      ),
      cardTheme: CardTheme(
        color: hc ? (isDark ? PulseColors.darkSurfaceAlt : Colors.white) : surface,
        elevation: hc ? 0 : (isDark ? 0 : 0.5),
        margin: EdgeInsets.zero,
        shape: cardShape.copyWith(
          side: BorderSide(color: hc ? textSec : divider, width: hc ? 1.5 : PulseStroke.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52), // a11y: ≥52dp tap targets
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.l),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          foregroundColor: scheme.primary,
          side: BorderSide(color: hc ? textMain : scheme.primary, width: hc ? 2 : 1.4),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          foregroundColor: scheme.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? PulseColors.darkSurfaceAlt : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: PulseSpacing.m, vertical: PulseSpacing.m),
        hintStyle: TextStyle(color: textSec, fontSize: 15.5),
        labelStyle: TextStyle(color: textSec, fontSize: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PulseRadius.m),
            borderSide: BorderSide(color: divider, width: PulseStroke.regular)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PulseRadius.m),
            borderSide: BorderSide(color: divider, width: PulseStroke.regular)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PulseRadius.m),
            borderSide: BorderSide(
                color: hc ? textMain : scheme.primary, width: PulseStroke.thick)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PulseRadius.m),
            borderSide: const BorderSide(color: PulseColors.error, width: PulseStroke.thick)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PulseRadius.m),
            borderSide: const BorderSide(color: PulseColors.error, width: 2.4)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: textSec,
        selectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? scheme.primary : (isDark ? Colors.white70 : Colors.white)),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primary.withOpacity(0.35)
                : (isDark ? PulseColors.darkElevated : PulseColors.lightSurfaceAlt)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: divider,
        thumbColor: scheme.primary,
        trackHeight: 6,
        overlayColor: scheme.primary.withOpacity(0.12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? PulseColors.darkElevated : const Color(0xFF22302C),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
        actionTextColor: scheme.tertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.m)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.xl)),
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textMain),
        contentTextStyle: TextStyle(fontSize: 15.5, color: textSec, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(PulseRadius.xl)),
        ),
        showDragHandle: hc,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.full)),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain),
        backgroundColor: isDark ? PulseColors.darkSurfaceAlt : Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(
        iconColor: textSec,
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textMain),
        subtitleTextStyle: TextStyle(fontSize: 14, color: textSec),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: scheme.primary,
        unselectedLabelColor: textSec,
        indicatorColor: scheme.primary,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }
}
