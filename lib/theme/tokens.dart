import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PULSE DESIGN TOKENS — Board 01: Brand + Design System
/// Single source of truth. Screens must only reference tokens below.
/// Component naming convention: Category/Variant/Size
///   e.g. Button/Primary/Large, Card/NutritionSummary, Chart/WeightTrend
/// ═══════════════════════════════════════════════════════════════════

// ── Spacing scale (4-pt base) ──────────────────────────────────────
class PulseSpacing {
  const PulseSpacing._();
  static const double xs = 4;
  static const double s = 8;
  static const double sm = 12;
  static const double m = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double gigantic = 64;
}

// ── Radius scale ───────────────────────────────────────────────────
class PulseRadius {
  const PulseRadius._();
  static const double none = 0;
  static const double xs = 6;
  static const double s = 10;
  static const double m = 14; // inputs, small cards
  static const double l = 20; // standard cards
  static const double xl = 28; // hero cards / sheets
  static const double full = 999;
}

// ── Stroke widths ──────────────────────────────────────────────────
class PulseStroke {
  const PulseStroke._();
  static const double hairline = 0.5;
  static const double thin = 1;
  static const double regular = 1.5;
  static const double thick = 2;
  static const double ringTrack = 8;
}

// ── Opacity steps ──────────────────────────────────────────────────
class PulseOpacity {
  const PulseOpacity._();
  static const double subtle = 0.06;
  static const double low = 0.12;
  static const double medium = 0.24;
  static const double high = 0.45;
}

// ── Animation durations ────────────────────────────────────────────
class PulseDuration {
  const PulseDuration._();
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration ringFill = Duration(milliseconds: 700);
}

// ── Breakpoints (responsive adaptation) ────────────────────────────
class PulseBreakpoints {
  const PulseBreakpoints._();
  static const double compact = 440; // phones (< default target 390×844)
  static const double medium = 600; // large phones / small foldables
  static const double expanded = 840; // tablets → 2-column master/detail
}

// ── Brand palette (original identity: deep teal + coral energy) ────
class PulseColors {
  const PulseColors._();

  // Brand core
  static const Color primary = Color(0xFF0E7C6B); // deep teal
  static const Color primaryDark = Color(0xFF0A5D50);
  static const Color primaryLight = Color(0xFF3FA08D);
  static const Color secondary = Color(0xFF14919B); // petrol blue
  static const Color accent = Color(0xFFFF6B4A); // coral "energy"
  static const Color accentSoft = Color(0xFFFFE7E0);

  // Semantic
  static const Color success = Color(0xFF1E9E6A);
  static const Color warning = Color(0xFFE8A13C);
  static const Color error = Color(0xFFD64545);
  static const Color info = Color(0xFF3B82C4);

  // Nutrition macro colors (color + icon + text always paired — a11y rule)
  static const Color protein = Color(0xFFE4567A); // rose
  static const Color carbs = Color(0xFFE8A13C); // amber
  static const Color fat = Color(0xFF8E6BC9); // violet
  static const Color fiber = Color(0xFF4CAF6D); // leaf green

  // Fitness metric colors
  static const Color steps = Color(0xFF14919B); // petrol
  static const Color caloriesBurned = Color(0xFFFF6B4A); // coral
  static const Color exercise = Color(0xFF0E7C6B); // teal
  static const Color heart = Color(0xFFD64545); // red
  static const Color water = Color(0xFF3B82C4); // aqua blue
  static const Color sleep = Color(0xFF8E6BC9); // violet

  // Light theme surfaces
  static const Color lightBg = Color(0xFFF6F7F4); // warm paper
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFF1EC);
  static const Color lightText = Color(0xFF17211E);
  static const Color lightTextSecondary = Color(0xFF5C6863);
  static const Color lightDisabled = Color(0xFFAFB7B2);
  static const Color lightDivider = Color(0xFFE2E6E0);

  // Dark theme surfaces (designed intentionally, not inverted)
  static const Color darkBg = Color(0xFF101514);
  static const Color darkSurface = Color(0xFF1A211F);
  static const Color darkSurfaceAlt = Color(0xFF232B29);
  static const Color darkElevated = Color(0xFF2A3331);
  static const Color darkText = Color(0xFFEAF0ED);
  static const Color darkTextSecondary = Color(0xFF9AA7A2);
  static const Color darkDisabled = Color(0xFF55605C);
  static const Color darkDivider = Color(0xFF2E3835);
  static const Color darkPrimary = Color(0xFF43B8A2); // lifted for contrast
  static const Color darkAccent = Color(0xFFFF8A6E);
}

// ── Typography hierarchy ───────────────────────────────────────────
// Display XL 44 · Display 36 · H1 28 · H2 22 · H3 19 · Title 17
// Body L 16 · Body 15.5 · Body S 14 · Caption 12.5 · Label 12.5
// Button 16 · Metric L 34 · Metric M 24
class PulseTypography {
  const PulseTypography._();

  static TextTheme textTheme(Brightness b) {
    final base = (b == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme)
        .apply(fontFamily: null);
    final main =
        b == Brightness.light ? PulseColors.lightText : PulseColors.darkText;
    final muted =
        b == Brightness.light ? PulseColors.lightTextSecondary : PulseColors.darkTextSecondary;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
          fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1, color: main),
      displayMedium: base.displayMedium?.copyWith(
          fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: main),
      displaySmall: base.displaySmall?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: main),
      headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: main),
      headlineSmall: base.headlineSmall
          ?.copyWith(fontSize: 19, fontWeight: FontWeight.w600, color: main),
      titleLarge: base.titleLarge
          ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: main),
      titleMedium: base.titleMedium
          ?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600, color: main),
      titleSmall: base.titleSmall
          ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: main),
      bodyLarge:
          base.bodyLarge?.copyWith(fontSize: 16, height: 1.45, color: main),
      bodyMedium:
          base.bodyMedium?.copyWith(fontSize: 15.5, height: 1.45, color: main),
      bodySmall: base.bodySmall?.copyWith(fontSize: 14, height: 1.4, color: muted),
      labelLarge: base.labelLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w600, color: main),
      labelMedium: base.labelMedium?.copyWith(
          fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: muted),
      labelSmall: base.labelSmall?.copyWith(
          fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: muted),
    );
  }

  /// Metric/Large — dominant health numbers (calories, weight).
  static const TextStyle metricLarge = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1);
  /// Metric/Medium — secondary big numbers.
  static const TextStyle metricMedium = TextStyle(
      fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15);
  /// Metric/Small — inline stats.
  static const TextStyle metricSmall = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.2);
}
