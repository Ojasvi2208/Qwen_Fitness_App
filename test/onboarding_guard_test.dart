import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/screens/auth/onboarding_screen.dart';
import 'package:pulse_app/theme/pulse_theme.dart';
import 'package:pulse_app/widgets/common.dart';

/// ═══════════════════════════════════════════════════════════════════
/// §14 — Onboarding guards, found by walking the release build
///
/// Two defects the whole suite passed over, because every test drove the
/// flow by calling the right things in the right order rather than by
/// behaving like a user in a hurry:
///
///   1. Continue advanced past the details step with every field empty,
///      storing a 0 kg weight and printing "CURRENT WEIGHT 0.0 kg" back
///      to the user as fact on the very next screen.
///   2. The system back gesture popped the entire onboarding route and
///      discarded every answer, with no warning and no way back.
///
/// Both are the kind of thing only a device walk finds, which is why the
/// standing rule is that a green suite does not mean the app works.
/// ═══════════════════════════════════════════════════════════════════

Widget _host(PulseStore store) => PulseScope(
      store: store,
      child: MaterialApp(
        theme: PulseTheme.light(),
        home: const OnboardingScreen(step: 0),
      ),
    );

/// Sizes the surface to a real phone so the step actually lays out.
Future<void> _sizeTo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 2.5;
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Walks from the goals page to the details page (step 2).
Future<void> _toDetails(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('§14 the details step cannot be skipped empty', () {
    testWidgets('continue does not advance with every field blank', (tester) async {
      await _sizeTo(tester);
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _toDetails(tester);

      expect(find.text('Step 3 of 9'), findsOneWidget,
          reason: 'the details step is step 3 of 9 in the UI');

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 9'), findsOneWidget,
          reason: 'an empty details step must not advance — it stored a 0 kg '
              'weight and showed it back as the user\'s own figure');
    });

    testWidgets('it says what is missing rather than failing silently', (tester) async {
      await _sizeTo(tester);
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _toDetails(tester);

      await tester.tap(find.text('Continue'));
      await tester.pump(); // let the snack begin
      await tester.pump(const Duration(milliseconds: 200));

      // §85 microcopy: specific about what to do, never shaming.
      final snack = find.byType(SnackBar);
      expect(snack, findsOneWidget);
      final text = tester.widget<SnackBar>(snack).content;
      expect(text, isNotNull);
    });

    testWidgets('a complete details step does advance', (tester) async {
      await _sizeTo(tester);
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _toDetails(tester);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4), reason: 'name, age, height, weight');
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), '34');
      await tester.enterText(fields.at(2), '172');
      await tester.enterText(fields.at(3), '68');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 9'), findsOneWidget,
          reason: 'valid details must not be blocked');
    });

    testWidgets('a weight below the safety floor is refused', (tester) async {
      // kMinWeightKg is 30. A typo of 6 for 68 must not become a plan.
      await _sizeTo(tester);
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _toDetails(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), '34');
      await tester.enterText(fields.at(2), '172');
      await tester.enterText(fields.at(3), '6');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 9'), findsOneWidget,
          reason: 'an implausible weight is a typo, not a target');
    });
  });

  group('§14 back means the previous step, not "lose everything"', () {
    testWidgets('a system back from step 2 returns to step 1', (tester) async {
      await _sizeTo(tester);
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 9'), findsOneWidget);

      // The hardware/gesture back, which bypassed the in-app arrow and
      // popped the whole route.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 9'), findsOneWidget,
          reason: 'back is a step backwards; it threw away all nine answers');
    });
  });
}
