/// ══════════════════════════════════════════════════════════════════
/// WP3.2 — Nutrition Calculation + Unit Conversion services (§17, §59)
///
/// Single source of truth for the calorie visual equation
/// (food − eaten + activity burned = remaining), macro rounding and
/// goal-percentage math. Every screen that shows one of these numbers
/// must read it from here so Today / Diary / Coach can never disagree.
/// Pure Dart → fully unit-testable without a widget binding.
/// ══════════════════════════════════════════════════════════════════

import 'pulse_store.dart';

/// Immutable snapshot of today's nutrition totals. Computed by
/// [NutritionService.forToday]; widgets render fields directly.
class DayNutrition {
  final double goal; // kcal target
  final double food; // kcal eaten
  final double burned; // kcal from activity
  final double remaining; // goal − food + burned
  final double protein; // g
  final double carbs; // g
  final double fat; // g
  final double fiber; // g
  final Map<MealType, double> mealKcal;

  const DayNutrition({
    required this.goal,
    required this.food,
    required this.burned,
    required this.remaining,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.mealKcal,
  });

  /// Whole-kcal display value (§17: "1,020 remaining").
  int get remainingRounded => remaining.round();

  /// % of calorie goal consumed, clamped to 0–999 for sane UI.
  int get consumedPct => goal <= 0 ? 0 : (food / goal * 100).round().clamp(0, 999);

  /// Encouraging, non-judgmental headline copy for the Macros card
  /// (§85 microcopy rules — never shame-based).
  String proteinHint(double proteinGoal) {
    final gap = proteinGoal - protein;
    if (gap <= 0) return 'Protein goal reached. Nicely done.';
    if (gap <= 40) {
      return "You're ${gap.round()} g away from today's protein goal.";
    }
    return 'Aiming for ${proteinGoal.round()} g protein today — you\'re building steadily.';
  }
}

/// Derives all nutrition figures from a store's raw logs. Stateless —
/// call [forToday] whenever the store notifies.
class NutritionService {
  const NutritionService._();

  static DayNutrition forToday(PulseStore s) {
    var fiber = 0.0;
    final meals = <MealType, double>{
      for (final m in MealType.values) m: 0.0,
    };
    for (final e in s.diary) {
      fiber += e.food.fiber * e.servings;
      meals[e.meal] = (meals[e.meal] ?? 0) + e.kcal;
    }
    return DayNutrition(
      goal: s.goals.calorieGoal,
      food: s.foodKcal,
      burned: s.activityCaloriesBurned,
      remaining: s.goals.calorieGoal - s.foodKcal + s.activityCaloriesBurned,
      protein: s.protein,
      carbs: s.carbs,
      fat: s.fat,
      fiber: fiber,
      mealKcal: meals,
    );
  }

  /// Macro progress as a clamped 0..1 fraction for rings/bars.
  static double pct(double value, double goal) =>
      goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0);

  /// Rounded gram display ("92 / 135 g" style — whole grams).
  static String grams(double v) => '${v.round()}';
}

/// ── Unit conversion (§59) ───────────────────────────────────────────
/// Canonical storage units are metric: kg, cm, ml, km. Conversions are
/// centralized here so no widget ever multiplies by a magic constant.
class Units {
  const Units._();

  static const double kgPerLb = 0.45359237;
  static const double cmPerInch = 2.54;
  static const double ozPerMl = 1.0 / 29.5735295625; // US fluid ounce
  static const double milesPerKm = 0.621371192;

  // mass ------------------------------------------------------------------
  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;

  /// Display mass honoring the user's setting ('kg' | 'lb').
  static String mass(double kg, String unit, {int decimals = 1}) {
    if (unit == 'lb') {
      return '${kgToLb(kg).toStringAsFixed(decimals)} lb';
    }
    return '${kg.toStringAsFixed(decimals)} kg';
  }

  /// Parse a user-entered mass back to canonical kg. Returns null for
  /// invalid input so forms can show "Enter a valid weight" (§75).
  static double? parseMass(String raw, String unit) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v <= 0 || v > 500) return null;
    return unit == 'lb' ? lbToKg(v) : v;
  }

  // length ----------------------------------------------------------------
  static double cmToFtIn(double cm) => cm / cmPerInch; // inches
  static String heightCmFtIn(double cm) {
    final totalIn = (cm / cmPerInch).round();
    return "${totalIn ~/ 12}' ${totalIn % 12}\"";
  }

  static String length(double cm, String unit) =>
      unit == 'ft' ? heightCmFtIn(cm) : '${cm.toStringAsFixed(0)} cm';

  static double? parseLength(String raw, String unit) {
    if (unit != 'ft') {
      final v = double.tryParse(raw.trim());
      return (v == null || !v.isFinite || v <= 0 || v > 300) ? null : v;
    }
    // accepts 5'10", 5'10, 5 10
    final m = RegExp(r"(\d+)\s*['\s]\s*(\d+)").firstMatch(raw);
    if (m != null) {
      final inches = int.parse(m.group(1)!) * 12 + int.parse(m.group(2)!);
      if (inches <= 0 || inches > 108) return null;
      return inches * cmPerInch;
    }
    final v = double.tryParse(raw.trim());
    return (v == null || !v.isFinite || v <= 0 || v > 300) ? null : v;
  }

  // volume ----------------------------------------------------------------
  static double mlToOz(double ml) => ml * ozPerMl;
  static String volume(double ml, String unit) => unit == 'oz'
      ? '${mlToOz(ml).toStringAsFixed(1)} oz'
      : '${ml.toStringAsFixed(0)} ml';

  // distance --------------------------------------------------------------
  static double kmToMi(double km) => km * milesPerKm;
  static String distance(double km, String unit) => unit == 'mi'
      ? '${kmToMi(km).toStringAsFixed(2)} mi'
      : '${km.toStringAsFixed(2)} km';
}
