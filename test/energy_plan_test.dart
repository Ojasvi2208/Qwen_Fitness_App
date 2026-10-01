import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/energy_plan.dart';
import 'package:pulse_app/data/pulse_store.dart';

/// ═══════════════════════════════════════════════════════════════════
/// N3 — Energy plan from the user's own details (§14).
///
/// Onboarding promised "Built from your answers" over figures typed
/// into the widget tree, and no BMR or TDEE logic existed anywhere.
/// These cases pin the arithmetic the plan page now claims, including
/// the floor that stops an aggressive pace producing an unsafe target
/// and the honest admission when that floor binds.
/// ═══════════════════════════════════════════════════════════════════

void main() {
  group('N3 the store actually receives the computed plan', () {
    test('a fresh store still holds generic defaults', () {
      // The defaults themselves are fine; the defect was that onboarding
      // never replaced them while claiming it had.
      final store = PulseStore();
      expect(store.goals.calorieGoal, 2000);
      expect(store.goals.carbGoal, 200);
      expect(store.goals.fatGoal, 65);
    });

    test('updateGoals writes all four, which setTargets could not', () {
      // setTargets has no carbGoal or fatGoal parameter at all, which is
      // why onboarding could never have written a complete plan.
      final store = PulseStore();
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 70,
      );
      store.updateGoals((g) {
        g.calorieGoal = plan.calorieGoal;
        g.proteinGoal = plan.proteinGoal;
        g.carbGoal = plan.carbGoal;
        g.fatGoal = plan.fatGoal;
      });
      expect(store.goals.calorieGoal, plan.calorieGoal);
      expect(store.goals.carbGoal, plan.carbGoal);
      expect(store.goals.fatGoal, plan.fatGoal);
      expect(store.goals.calorieGoal, isNot(2000),
          reason: 'the default must not survive a real plan');
    });
  });

  group('§14 basal metabolic rate — Mifflin-St Jeor', () {
    test('male BMR follows 10w + 6.25h − 5a + 5', () {
      // 10(78) + 6.25(178) − 5(28) + 5 = 780 + 1112.5 − 140 + 5
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.sedentary, pace: WeightPace.recommended,
        targetWeightKg: 70,
      );
      expect(plan.bmr, closeTo(1757.5, 0.01));
    });

    test('female BMR follows 10w + 6.25h − 5a − 161', () {
      // 10(62) + 6.25(165) − 5(32) − 161 = 620 + 1031.25 − 160 − 161
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.female, ageYears: 32, heightCm: 165, weightKg: 62,
        activity: ActivityLevel.sedentary, pace: WeightPace.recommended,
        targetWeightKg: 58,
      );
      expect(plan.bmr, closeTo(1330.25, 0.01));
    });
  });

  group('§14 total daily energy expenditure', () {
    test('each activity level applies its own multiplier', () {
      double tdeeFor(ActivityLevel a) => PulseEnergyPlan.from(
            sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
            activity: a, pace: WeightPace.recommended, targetWeightKg: 70,
          ).tdee;

      // The four levels the onboarding page offers, in its own order.
      expect(tdeeFor(ActivityLevel.sedentary), closeTo(1757.5 * 1.2, 0.01));
      expect(tdeeFor(ActivityLevel.light), closeTo(1757.5 * 1.375, 0.01));
      expect(tdeeFor(ActivityLevel.active), closeTo(1757.5 * 1.55, 0.01));
      expect(tdeeFor(ActivityLevel.veryActive), closeTo(1757.5 * 1.725, 0.01));
    });
  });

  group('§14 the deficit matches the pace the user was shown', () {
    // The onboarding page states these rates in its own subtitles, so the
    // arithmetic has to honour them: 7700 kcal per kg of body fat.
    test('recommended pace subtracts 0.5 kg/week', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 70,
      );
      expect(plan.dailyDeficit, closeTo(0.5 * 7700 / 7, 0.01));
      expect(plan.calorieGoal, closeTo(plan.tdee - plan.dailyDeficit, 0.5));
    });

    test('slow and faster paces subtract 0.25 and 0.7 kg/week', () {
      double deficitFor(WeightPace p) => PulseEnergyPlan.from(
            sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
            activity: ActivityLevel.active, pace: p, targetWeightKg: 70,
          ).dailyDeficit;

      expect(deficitFor(WeightPace.slow), closeTo(0.25 * 7700 / 7, 0.01));
      expect(deficitFor(WeightPace.faster), closeTo(0.7 * 7700 / 7, 0.01));
    });

    test('a target above current weight adds instead of subtracting', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 70,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 78,
      );
      // Gaining needs a surplus; the goal must exceed maintenance.
      expect(plan.calorieGoal, greaterThan(plan.tdee));
      expect(plan.isFloored, isFalse);
    });

    test('maintaining weight means no deficit at all', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 74,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 74,
      );
      expect(plan.dailyDeficit, closeTo(0, 0.01));
      expect(plan.calorieGoal, closeTo(plan.tdee, 0.5));
    });
  });

  group('§14 the floor keeps an aggressive pace safe', () {
    test('a small sedentary woman is never pushed below 1200 kcal', () {
      // Without a floor this lands near 700 kcal, which is the defect the
      // floor exists to prevent — not a target this app may ever show.
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.female, ageYears: 30, heightCm: 155, weightKg: 50,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 45,
      );
      expect(plan.calorieGoal, greaterThanOrEqualTo(1200));
      expect(plan.isFloored, isTrue,
          reason: 'the pace was capped, so the plan must admit it');
    });

    test('a man is never pushed below 1500 kcal', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 30, heightCm: 165, weightKg: 58,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 52,
      );
      expect(plan.calorieGoal, greaterThanOrEqualTo(1500));
      expect(plan.isFloored, isTrue);
    });

    test('the floor never drops below what the body burns at rest', () {
      // Eating under BMR is the thing the fixed minimum alone would miss
      // for a large person, whose BMR exceeds 1500 on its own.
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 25, heightCm: 196, weightKg: 130,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 95,
      );
      expect(plan.calorieGoal, greaterThanOrEqualTo(plan.bmr));
    });

    test('an ordinary plan is not floored and says so', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 70,
      );
      expect(plan.isFloored, isFalse);
      expect(plan.floorNote, isNull);
    });

    test('a floored plan carries copy that explains without shaming', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.female, ageYears: 30, heightCm: 155, weightKg: 50,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 45,
      );
      final note = plan.floorNote!;
      // §: honest, gentle, no fake urgency, no shame, no medical claim.
      expect(note, isNotEmpty);
      for (final banned in ['fail', 'unhealthy', 'too fat', 'must', 'danger']) {
        expect(note.toLowerCase(), isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('§14 macros follow the calorie target', () {
    test('protein, carbs and fat account for the whole target', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 70,
      );
      final fromMacros =
          plan.proteinGoal * 4 + plan.carbGoal * 4 + plan.fatGoal * 9;
      // Rounding to whole grams costs a few kcal; nothing more.
      expect(fromMacros, closeTo(plan.calorieGoal, 25));
    });

    test('protein scales with body weight, not with a fixed figure', () {
      double proteinFor(double kg) => PulseEnergyPlan.from(
            sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: kg,
            activity: ActivityLevel.active, pace: WeightPace.recommended,
            targetWeightKg: kg - 5,
          ).proteinGoal;
      expect(proteinFor(90), greaterThan(proteinFor(60)),
          reason: 'a fixed 135 g for everyone is the defect being fixed');
    });

    test('water and steps come from the body and the activity level', () {
      final small = PulseEnergyPlan.from(
        sex: BiologicalSex.female, ageYears: 30, heightCm: 160, weightKg: 55,
        activity: ActivityLevel.sedentary, pace: WeightPace.recommended,
        targetWeightKg: 52,
      );
      final large = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 30, heightCm: 190, weightKg: 95,
        activity: ActivityLevel.veryActive, pace: WeightPace.recommended,
        targetWeightKg: 90,
      );
      expect(large.waterGoalLiters, greaterThan(small.waterGoalLiters));
      expect(large.stepGoal, greaterThan(small.stepGoal));
    });
  });

  group('§14 hostile and incomplete input cannot produce a harmful plan', () {
    // A calculation fed straight from text fields is where the dangerous
    // numbers hide. Every case below is reachable from the onboarding form.

    test('absurd ages and sizes are clamped, never trusted', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 0, heightCm: 0, weightKg: 0,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 0,
      );
      // Unclamped, Mifflin-St Jeor returns 5 kcal here.
      expect(plan.calorieGoal, greaterThanOrEqualTo(1200));
      expect(plan.calorieGoal.isFinite, isTrue);
    });

    test('a wildly out-of-range age cannot inflate or deflate the plan', () {
      final old = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 500, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 74,
      );
      expect(old.calorieGoal, greaterThanOrEqualTo(1200));
      expect(old.bmr, greaterThan(0));
    });

    test('a weight typed in pounds is still clamped to something survivable', () {
      // 172 "kg" is really 78 kg in lb — wrong, but it must not produce a
      // target the user could act on dangerously either way.
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 172,
        activity: ActivityLevel.active, pace: WeightPace.faster,
        targetWeightKg: 70,
      );
      expect(plan.calorieGoal.isFinite, isTrue);
      expect(plan.calorieGoal, greaterThanOrEqualTo(plan.bmr));
    });

    test('an extreme target weight cannot drive an unsafe deficit', () {
      // The slider cannot reach this, but a restored snapshot can.
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.female, ageYears: 25, heightCm: 170, weightKg: 60,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 35,
      );
      expect(plan.calorieGoal, greaterThanOrEqualTo(1200));
      expect(plan.isFloored, isTrue);
    });

    test('a surplus is capped as firmly as a deficit', () {
      final plan = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 60,
        activity: ActivityLevel.sedentary, pace: WeightPace.faster,
        targetWeightKg: 200,
      );
      // Gaining fast is its own harm; the plan must not invite it.
      expect(plan.calorieGoal, lessThanOrEqualTo(plan.tdee * 1.25));
    });

    test('non-finite input never reaches the goals', () {
      for (final bad in [double.nan, double.infinity, -double.infinity]) {
        final plan = PulseEnergyPlan.from(
          sex: BiologicalSex.male, ageYears: 28, heightCm: bad, weightKg: bad,
          activity: ActivityLevel.active, pace: WeightPace.recommended,
          targetWeightKg: bad,
        );
        expect(plan.calorieGoal.isFinite, isTrue, reason: '$bad');
        expect(plan.proteinGoal.isFinite, isTrue, reason: '$bad');
        expect(plan.waterGoalLiters.isFinite, isTrue, reason: '$bad');
        expect(plan.calorieGoal, greaterThanOrEqualTo(1200), reason: '$bad');
      }
    });

    test('every goal it produces is a number a person could actually eat', () {
      // Sweep the whole input space the form allows and assert the result
      // is always inside human range — no combination may escape.
      for (final sex in BiologicalSex.values) {
        for (final activity in ActivityLevel.values) {
          for (final pace in WeightPace.values) {
            for (final age in [16, 40, 90]) {
              for (final h in [140.0, 178.0, 210.0]) {
                for (final w in [40.0, 78.0, 160.0]) {
                  final p = PulseEnergyPlan.from(
                    sex: sex, ageYears: age, heightCm: h, weightKg: w,
                    activity: activity, pace: pace, targetWeightKg: w - 10,
                  );
                  final where = '$sex $activity $pace age=$age h=$h w=$w';
                  expect(p.calorieGoal, inInclusiveRange(1200, 6000),
                      reason: where);
                  expect(p.proteinGoal, inInclusiveRange(20, 300),
                      reason: where);
                  expect(p.waterGoalLiters, inInclusiveRange(1.5, 6.0),
                      reason: where);
                  expect(p.stepGoal, inInclusiveRange(2000, 20000),
                      reason: where);
                }
              }
            }
          }
        }
      }
    });
  });

  group('§14 two different people never get the same plan', () {
    test('the figures move with the details entered', () {
      final a = PulseEnergyPlan.from(
        sex: BiologicalSex.male, ageYears: 28, heightCm: 178, weightKg: 78,
        activity: ActivityLevel.active, pace: WeightPace.recommended,
        targetWeightKg: 70,
      );
      final b = PulseEnergyPlan.from(
        sex: BiologicalSex.female, ageYears: 45, heightCm: 160, weightKg: 62,
        activity: ActivityLevel.sedentary, pace: WeightPace.slow,
        targetWeightKg: 58,
      );
      // The whole point of N3: entering details must change the plan.
      expect(a.calorieGoal, isNot(closeTo(b.calorieGoal, 1)));
      expect(a.proteinGoal, isNot(closeTo(b.proteinGoal, 1)));
    });
  });
}
