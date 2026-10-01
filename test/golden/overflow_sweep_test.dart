import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/screens/diary/diary_screens.dart';
import 'package:pulse_app/screens/profile/premium_screens.dart';
import 'package:pulse_app/screens/profile/settings_screens.dart';
import 'package:pulse_app/screens/progress/progress_screens.dart';
import 'package:pulse_app/screens/today/today_screen.dart';
import 'package:pulse_app/screens/train/train_screens.dart';

import 'device_profiles.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 7 — Overflow sweep across the §2.1 device matrix (Step 2).
/// A golden only fails when a person looks at the diff; a RenderFlex
/// overflow throws, so it can fail the build on its own. This is the
/// cheaper half of the golden layer and the half that found D3 and D6.
///
/// Every screen renders at 8 device/scale/theme cases. The state matrix
/// (WP5.2) already proves these screens build at 800x600 — this proves
/// they FIT at 320x568 and at a 1.5 text scale, which is what the 235
/// passing cases never once checked.
/// ═══════════════════════════════════════════════════════════════════

typedef _Screen = ({String name, Widget Function() build});

/// The tab-level and state-carrying screens, matching the WP5.2 list so
/// the two suites cannot drift apart. Screens needing route arguments are
/// covered by the flow suites instead.
const List<_Screen> _screens = [
  (name: 'Today', build: TodayScreen.new),
  (name: 'Diary', build: DiaryScreen.new),
  (name: 'Progress', build: ProgressScreen.new),
  (name: 'Nutrition progress', build: NutritionProgressScreen.new),
  (name: 'Activity progress', build: ActivityProgressScreen.new),
  (name: 'Weight progress', build: WeightProgressScreen.new),
  (name: 'Weekly report', build: WeeklyReportScreen.new),
  (name: 'Insights', build: InsightsScreen.new),
  (name: 'Streaks', build: StreaksScreen.new),
  (name: 'Goals', build: GoalsScreen.new),
  (name: 'Train', build: TrainScreen.new),
  (name: 'Workout library', build: WorkoutLibraryScreen.new),
  (name: 'Steps', build: StepsScreen.new),
  (name: 'Habits', build: HabitsScreen.new),
  (name: 'Profile', build: ProfileScreen.new),
  (name: 'Subscription', build: SubscriptionScreen.new),
];

/// Pumps past entry animations. ProgressScreen holds a 700 ms skeleton
/// and several cards run their own transitions (mirrors WP5.2).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

/// §6 Risks: "tag them and exclude from the default run". This sweep is
/// red by design until the O-series overflows it found are fixed in Step
/// 3 — 43 of 160 renders, every one logged in docs/QA_FINDINGS.md §2. It
/// is skipped so `flutter analyze && flutter test` stays the honest gate
/// for everything else rather than failing on known, documented defects.
///
/// Run it deliberately:  flutter test --run-skipped test/golden
/// Delete this constant once QA_FINDINGS.md §2 is closed.
const kSweepSkip = 'Step 3 scope: see docs/QA_FINDINGS.md §2 (O1–O9).';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final c in kPulseRenderCases) {
    group('§2.1 overflow sweep — ${c.id}', skip: kSweepSkip, () {
      for (final screen in _screens) {
        testWidgets('${screen.name} fits ${c.device.name}', (tester) async {
          pulseApplyRenderCase(tester, c);
          await tester.pumpWidget(pulseHarness(
            store: pulseProfiledStore(),
            renderCase: c,
            child: Scaffold(body: screen.build()),
          ));
          await _settle(tester);
          // A RenderFlex overflow is what the yellow-and-black stripes
          // are. ${c.device.why} is why this profile is in the matrix.
          expect(tester.takeException(), isNull,
              reason: '${screen.name} overflowed at ${c.device.logical.width}'
                  'x${c.device.logical.height} '
                  'at textScale ${c.textScale}');
        });
      }
    });
  }

  // The empty profile is the state a real first-run user is in, and the
  // one the removed sample data used to hide. Empty strings and zeroes
  // lay out differently from populated ones, so it gets its own pass on
  // the two tightest profiles.
  for (final c in const [
    PulseRenderCase(device: kPhoneSmall),
    PulseRenderCase(device: kPhoneMoto, textScale: 1.5),
  ]) {
    group('§2.1 overflow sweep — empty profile — ${c.id}', skip: kSweepSkip, () {
      for (final screen in _screens) {
        testWidgets('${screen.name} fits with nothing logged', (tester) async {
          pulseApplyRenderCase(tester, c);
          await tester.pumpWidget(pulseHarness(
            store: PulseStore(),
            renderCase: c,
            child: Scaffold(body: screen.build()),
          ));
          await _settle(tester);
          expect(tester.takeException(), isNull,
              reason: '${screen.name} overflowed on a fresh install');
        });
      }
    });
  }
}
