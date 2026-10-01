import 'dart:math' as math;

/// ══════════════════════════════════════════════════════════════════
/// N3 — Energy plan derived from the user's own details (§14)
///
/// Onboarding showed "Built from your answers" above figures typed into
/// the widget tree: every user saw 2,050 kcal whatever they entered, and
/// no BMR or TDEE logic existed anywhere in the project. This is that
/// missing calculation, and it is the difference between an app that
/// displays a plan and one that computes it.
///
/// Mifflin-St Jeor for resting energy, an activity factor for total
/// expenditure, then the deficit the pace options already promise the
/// user in their own subtitles (§14 step 5). Pure Dart → unit-testable
/// without a widget binding, like NutritionService beside it.
///
/// Safety is structural, not advisory. Input arrives straight from text
/// fields and a restored snapshot, so every value is clamped before it
/// reaches the arithmetic and the result is floored before it reaches
/// the user. When the floor binds, [floorNote] says so: the app must
/// never quietly show a target while the pace label promises another.
/// PULSE provides general information and not medical advice (§76).
/// ══════════════════════════════════════════════════════════════════

/// Biological sex, used only for the Mifflin-St Jeor constant (§14).
enum BiologicalSex { male, female }

/// The four options the activity page offers, in its own order (§14).
enum ActivityLevel { sedentary, light, active, veryActive }

/// The three options the pace page offers, with the rates its subtitles
/// state to the user: 0.25, 0.5 and 0.7 kg per week (§14 step 5).
enum WeightPace { slow, recommended, faster }

extension ActivityFactor on ActivityLevel {
  /// Standard Mifflin-St Jeor activity multipliers.
  double get factor => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.active => 1.55,
        ActivityLevel.veryActive => 1.725,
      };

  /// Daily step target implied by how the user describes their week.
  int get stepTarget => switch (this) {
        ActivityLevel.sedentary => 6000,
        ActivityLevel.light => 8000,
        ActivityLevel.active => 10000,
        ActivityLevel.veryActive => 12000,
      };
}

extension PaceRate on WeightPace {
  /// Kilograms per week — the figure the user was shown when choosing.
  double get kgPerWeek => switch (this) {
        WeightPace.slow => 0.25,
        WeightPace.recommended => 0.5,
        WeightPace.faster => 0.7,
      };
}

// ── Guard rails ───────────────────────────────────────────────────
// Input comes from free-text fields and from snapshots written by older
// builds, so none of it is trusted. These bounds are survivable human
// ranges, not validation messages: the form reports its own errors, and
// this exists so no combination of input can yield a harmful target.

const int kMinAgeYears = 13;
const int kMaxAgeYears = 100;
const double kMinHeightCm = 120;
const double kMaxHeightCm = 230;
const double kMinWeightKg = 30;
const double kMaxWeightKg = 300;

/// Energy per kilogram of body fat — the constant behind every pace.
const double kKcalPerKgFat = 7700;

/// Absolute floors. Eating below these is not something this app will
/// ever put in front of someone, whatever pace they picked.
const double kMinCaloriesFemale = 1200;
const double kMinCaloriesMale = 1500;

/// A surplus is its own harm, so gaining is capped as firmly as losing.
const double kMaxSurplusFactor = 1.25;

/// Protein grams per kilogram of body weight — the reason a 90 kg and a
/// 60 kg person must not see the same target (§14).
const double kProteinGramsPerKg = 1.6;

/// Fat as a share of the calorie target; carbohydrate takes the rest.
const double kFatShareOfCalories = 0.27;

/// Water litres per kilogram of body weight, plus a little for how hard
/// the day is. Keeps a 55 kg and a 95 kg person apart.
const double kWaterLitresPerKg = 0.033;

/// Water floor and ceiling. Body weight alone puts a very small person
/// under 1.5 L, which is less than anyone should be told to drink, and
/// leaves a very large one above what is sensible to target in a day.
const double kMinWaterLitres = 1.5;
const double kMaxWaterLitres = 4.5;

/// Returns [v] inside [lo, hi], treating a non-finite value as [lo].
/// Hydration never throws and neither does this: a NaN height must not
/// reach the arithmetic, let alone the stored goals.
double _clamp(double v, double lo, double hi) =>
    v.isFinite ? math.min(math.max(v, lo), hi) : lo;

/// The computed plan. Immutable, `const` constructor, `toJson`/`fromJson`
/// like the other value objects in this codebase.
class PulseEnergyPlan {
  final double bmr;
  final double tdee;
  final double dailyDeficit; // negative when gaining
  final double calorieGoal;
  final double proteinGoal;
  final double carbGoal;
  final double fatGoal;
  final double waterGoalLiters;
  final int stepGoal;

  /// True when the chosen pace would have breached a floor and the plan
  /// was raised to meet it. The user is told; see [floorNote].
  final bool isFloored;

  const PulseEnergyPlan({
    required this.bmr,
    required this.tdee,
    required this.dailyDeficit,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    required this.waterGoalLiters,
    required this.stepGoal,
    required this.isFloored,
  });

  /// Honest, gentle, no fake urgency and no medical claim (§ microcopy).
  /// Null unless the floor actually bound, so the plan page can show it
  /// only when there is something true to say.
  String? get floorNote => isFloored
      ? 'We have set this a little higher than the pace you picked. '
          'Going lower would mean eating less than your body needs each '
          'day, and progress that sticks comes from the pace you can keep.'
      : null;

  /// Derives the whole plan from what onboarding collected (§14).
  /// Every input is clamped first: this runs on raw form text.
  static PulseEnergyPlan from({
    required BiologicalSex sex,
    required int ageYears,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
    required WeightPace pace,
    required double targetWeightKg,
  }) {
    final age = _clamp(ageYears.toDouble(), kMinAgeYears.toDouble(), kMaxAgeYears.toDouble());
    final height = _clamp(heightCm, kMinHeightCm, kMaxHeightCm);
    final weight = _clamp(weightKg, kMinWeightKg, kMaxWeightKg);
    final target = _clamp(targetWeightKg, kMinWeightKg, kMaxWeightKg);

    // Mifflin-St Jeor: the constant is the only term that differs.
    final bmr = 10 * weight +
        6.25 * height -
        5 * age +
        (sex == BiologicalSex.male ? 5 : -161);
    final tdee = bmr * activity.factor;

    // The deficit the pace promised, in the direction the target implies.
    // Equal weights mean maintenance, so neither term applies.
    final losing = target < weight;
    final gaining = target > weight;
    final rate = pace.kgPerWeek * kKcalPerKgFat / 7;
    final deficit = losing ? rate : (gaining ? -rate : 0.0);

    final raw = tdee - deficit;

    // Two floors, whichever is higher. The fixed minimum protects a small
    // person; BMR protects a large one, whose resting burn alone exceeds
    // it. Neither alone is enough, which is why both are here.
    final minimum = math.max(
      sex == BiologicalSex.male ? kMinCaloriesMale : kMinCaloriesFemale,
      bmr,
    );
    final ceiling = tdee * kMaxSurplusFactor;
    final goal = _clamp(raw, minimum, math.max(minimum, ceiling));
    final floored = goal > raw + 0.5;

    // Macros follow the target that survived the floor, never the raw
    // one — otherwise they would describe a day the user is not eating.
    final protein = (weight * kProteinGramsPerKg).roundToDouble();
    final fat = (goal * kFatShareOfCalories / 9).roundToDouble();
    final carbs =
        math.max(0, (goal - protein * 4 - fat * 9) / 4).roundToDouble();

    return PulseEnergyPlan(
      bmr: bmr,
      tdee: tdee,
      dailyDeficit: deficit,
      calorieGoal: goal.roundToDouble(),
      proteinGoal: protein,
      carbGoal: carbs,
      fatGoal: fat,
      waterGoalLiters: (_clamp(weight * kWaterLitresPerKg + activity.index * 0.15,
                  kMinWaterLitres, kMaxWaterLitres) *
              10)
          .roundToDouble() /
          10,
      stepGoal: activity.stepTarget,
      isFloored: floored,
    );
  }
}
