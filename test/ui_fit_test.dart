import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/data/workout_session.dart';
import 'package:pulse_app/main.dart';
import 'package:pulse_app/theme/pulse_theme.dart';
import 'package:pulse_app/widgets/common.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 7 — UI-fit regressions for D1–D3 (§2.1, §4 Step 1).
/// Each case pins a defect found by using the app on a 360×800 device
/// that the 235-case suite passed straight over: an avatar reading the
/// removed sample identity, a FAB covering a tab, a sheet overflowing.
/// ═══════════════════════════════════════════════════════════════════

/// The reported device: Moto Edge 30, 1080×2400 at 400dpi (§2.1).
const Size kMotoSize = Size(360, 800);

Widget _host(PulseStore store, Widget child) => PulseScope(
      store: store,
      child: MaterialApp(theme: PulseTheme.light(), home: child),
    );

/// Sizes the surface to a real device so overflow is reproducible; the
/// 800×600 default is wider and shorter than any phone and hides both.
Future<void> _sizeTo(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2.5;
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D1 avatar initials', () {
    test('initials come from the name, never a default', () {
      expect(pulseInitials('Ojasvi'), 'O');
      expect(pulseInitials('Ojasvi Malik'), 'OM');
      // A third word is dropped rather than crowding the circle.
      expect(pulseInitials('Ojasvi Kumar Malik'), 'OK');
    });

    test('a nameless profile yields no letters at all', () {
      // The empty string is what a fresh install holds (§14); anything
      // else here is a fabricated identity, which is the D1 defect.
      expect(pulseInitials(''), '');
      expect(pulseInitials('   '), '');
      expect(pulseInitials('🏃'), '', reason: 'an emoji is not an initial');
    });

    testWidgets('an empty profile shows a neutral icon, not letters',
        (tester) async {
      await tester.pumpWidget(_host(
          PulseStore(), const Scaffold(body: PulseAvatar(initials: ''))));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.text('AM'), findsNothing,
          reason: 'the removed sample identity must not reappear');
    });

    testWidgets('the dashboard avatar matches the greeting', (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell()));
      await tester.pumpAndSettle();
      // The defect was an avatar reading 'AM' beside the name 'Ojasvi'.
      expect(find.text('OM'), findsOneWidget);
      expect(find.text('AM'), findsNothing);
    });
  });

  group('C1 no fabricated data', () {
    test('date formatting follows the clock, not a literal', () {
      final d = DateTime(2026, 10, 1); // a Thursday
      expect(fmtLongDate(d), 'Thursday, October 1');
      expect(fmtMediumDate(d), 'Thursday, Oct 1');
      expect(fmtShortDate(d), 'Oct 1');
    });

    test('the greeting follows the hour', () {
      expect(fmtGreeting(DateTime(2026, 10, 1, 8)), 'Good morning');
      expect(fmtGreeting(DateTime(2026, 10, 1, 14)), 'Good afternoon');
      expect(fmtGreeting(DateTime(2026, 10, 1, 21)), 'Good evening');
    });

    testWidgets('a fresh install states no figure it did not record',
        (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell()));
      await tester.pumpAndSettle();

      // Nothing has been logged, so no screen may claim a week of activity.
      expect(store.hasAnyData, isFalse, reason: 'precondition');
      for (final fiction in ['6,842 / 8,000', '1.7 / 2.6 L', '6,932', '2,140']) {
        expect(find.textContaining(fiction), findsNothing,
            reason: '$fiction was typed into the source, never recorded');
      }
      // The insight strip asserted a protein streak on an empty profile.
      expect(find.textContaining('5 of the last 7 days'), findsNothing);
    });

    testWidgets('the dashboard names today, not 29 September', (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell()));
      await tester.pumpAndSettle();
      expect(find.text(fmtLongDate(DateTime.now())), findsOneWidget);
      expect(find.text('Tuesday, September 29'), findsNothing);
    });

    testWidgets('the suggested workout reads the template it starts',
        (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell(initialTab: 2)));
      await tester.pumpAndSettle();

      // The figures must agree with the library entry rather than restate it.
      final t = WorkoutTemplates.library.first;
      expect(find.text(t.name), findsWidgets);
      expect(find.text('${t.minutes} min'), findsOneWidget);
      expect(find.text('${t.plan.length} exercises'), findsOneWidget);
      // Nothing schedules a workout, so no clock time may be promised.
      expect(find.textContaining('6:30 PM'), findsNothing);
    });
  });

  group('D2 navigation bar', () {
    testWidgets('every one of the five tabs is hit-testable', (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell()));
      await tester.pumpAndSettle();

      // Train is the middle destination and was the one the centre-docked
      // FAB covered: its icon and label were both unreachable.
      final fab = tester.getRect(find.byType(FloatingActionButton));
      for (final label in ['Today', 'Diary', 'Train', 'Progress', 'Profile']) {
        final dest = find.text(label);
        expect(dest, findsOneWidget, reason: '$label must be present');
        expect(fab.overlaps(tester.getRect(dest)), isFalse,
            reason: 'the + Log button must not cover the $label tab');
      }
    });
  });

  group('D3 quick log sheet', () {
    testWidgets('eight items fit a 360×800 screen without overflowing',
        (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // A RenderFlex overflow is what the yellow-and-black stripes are, and
      // takeException is the cheapest way to assert their absence (§2.1).
      expect(tester.takeException(), isNull,
          reason: 'the sheet overflowed by 176 px before tall: true');
      expect(find.text('Log Food'), findsOneWidget);
    });

    testWidgets('the last item is reachable by scrolling', (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(_host(store, const PulseShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 'Log Measurement' is eighth: the item that fell off the bottom. Drag
      // the sheet's own list — scrollUntilVisible cannot pick between it and
      // the Today list still mounted behind the sheet.
      final sheetList = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(ListView));
      await tester.drag(sheetList, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Log Measurement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 1.5 text scale still overflows nothing', (tester) async {
      final store = PulseStore();
      store.userName = 'Ojasvi Malik';
      store.userFirstName = 'Ojasvi';
      await _sizeTo(tester, kMotoSize);
      await tester.pumpWidget(PulseScope(
        store: store,
        child: MaterialApp(
          theme: PulseTheme.light(),
          builder: (ctx, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.5, maxScaleFactor: 1.5, child: child!),
          home: Builder(
            builder: (ctx) => Scaffold(
              floatingActionButton: FloatingActionButton(
                  onPressed: () => openQuickLog(ctx), child: const Icon(Icons.add)),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      // Accessibility stress from the §2.1 matrix: larger type is exactly
      // what turned a tight fit into a 176 px overflow in the first place.
      expect(tester.takeException(), isNull);
    });
  });
}
