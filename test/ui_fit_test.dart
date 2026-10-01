import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/pulse_store.dart';
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
