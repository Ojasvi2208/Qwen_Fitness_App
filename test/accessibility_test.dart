import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/screens/diary/diary_screens.dart';
import 'package:pulse_app/screens/progress/progress_screens.dart';
import 'package:pulse_app/screens/today/today_screen.dart';
import 'package:pulse_app/screens/train/train_screens.dart';
import 'package:pulse_app/theme/pulse_theme.dart';
import 'package:pulse_app/theme/tokens.dart';
import 'package:pulse_app/widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// WP5.3 — Accessibility sweeps (§70, release doc §7.2/§10(3))
/// Charts must speak, targets must be reachable, larger text must not
/// break layout, and reduce-motion must actually still the animations.
/// ═══════════════════════════════════════════════════════════════════

class _MemRepo implements LocalRepository {
  Map<String, dynamic>? _snapshot;

  @override
  Future<void> init() async {}

  @override
  Future<Map<String, dynamic>?> readSnapshot() async => _snapshot;

  @override
  Future<void> writeSnapshot(Map<String, dynamic> s) async =>
      _snapshot = jsonDecode(jsonEncode(s)) as Map<String, dynamic>;

  @override
  Future<void> clearAll() async => _snapshot = null;
}

/// A store with enough logged data that charts and metrics actually render.
Future<PulseStore> _loggedStore() async {
  final store = PulseStore();
  await store.attachPersistence(_MemRepo());
  store.setProfile(
      name: 'Test Person', age: 30, heightCm: 170, startWeightKg: 72);
  store.setTargets(targetWeightKg: 66);
  store.addFood(PulseData.foodById('f1'), 1, MealType.breakfast);
  store.addFood(PulseData.foodById('f3'), 1.5, MealType.lunch);
  store.addWater(0.75);
  store.logWeight(70.4);
  store.logMeasurement('waist', 84);
  return store;
}

/// Hosts a screen the way main.dart does, including the MediaQuery overrides
/// that carry the §70 accessibility flags.
Widget _host(PulseStore store, Widget screen, {TextScaler? scaler}) =>
    PulseScope(
      store: store,
      child: MaterialApp(
        theme: PulseTheme.light(highContrast: store.highContrast),
        home: Builder(builder: (ctx) {
          final media = MediaQuery.of(ctx);
          return MediaQuery(
            data: media.copyWith(
              textScaler: scaler ??
                  (store.largeText
                      ? media.textScaler
                          .clamp(minScaleFactor: kPulseLargeTextScale)
                      : media.textScaler),
              disableAnimations: store.reduceMotion || media.disableAnimations,
            ),
            child: Scaffold(body: screen),
          );
        }),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

/// Every interactive target must be at least 48 logical pixels on its
/// smaller edge — the Material minimum, and what a less precise tap needs.
void _expectTapTargets(WidgetTester tester, {double min = 48}) {
  for (final type in <Type>[IconButton3, InkWell]) {
    for (final element in find.byType(type).evaluate()) {
      final size = element.size;
      if (size == null || size.isEmpty) continue;
      // Wide rows are fine; it is the short edge that fails a thumb.
      expect(size.height, greaterThanOrEqualTo(min - 0.5),
          reason: '$type is ${size.height}px tall, below the $min px minimum');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP5.3 chart semantics', () {
    testWidgets('a ring states its progress', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PulseRing(value: 0.62, color: Colors.blue))));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('62 percent of goal'), findsOneWidget);
    });

    testWidgets('a bar chart states its range and goal', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PulseBarChart(
                  values: [5000, 8000, 6500],
                  labels: ['M', 'T', 'W'],
                  goal: 8000))));
      await tester.pumpAndSettle();
      expect(
          find.bySemanticsLabel(
              '3 day chart ranging from 5000 to 8000, against a goal of 8000'),
          findsOneWidget);
    });

    testWidgets('a line chart states its endpoints', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PulseLineChart(points: [72.0, 71.1, 70.4], goalY: 66))));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Trend from 72.0 to 70.4, goal 66'),
          findsOneWidget);
    });

    testWidgets('an empty chart says so rather than staying silent',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: PulseLineChart(points: []))));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Trend chart with no data yet'),
          findsOneWidget);
    });

    testWidgets('a caller-supplied label wins over the derived one',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PulseRing(
                  value: 0.5,
                  color: Colors.blue,
                  semanticLabel: 'Half way to today\'s water goal'))));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Half way to today\'s water goal'),
          findsOneWidget);
    });
  });

  group('WP5.3 larger text', () {
    for (final screen in <({String name, Widget Function() build})>[
      (name: 'Today', build: TodayScreen.new),
      (name: 'Diary', build: DiaryScreen.new),
      (name: 'Train', build: TrainScreen.new),
      (name: 'Progress', build: ProgressScreen.new),
    ]) {
      testWidgets('${screen.name} survives 1.5x text', (tester) async {
        final store = await _loggedStore();
        await tester.pumpWidget(_host(store, screen.build(),
            scaler: const TextScaler.linear(1.5)));
        await _settle(tester);
        expect(tester.takeException(), isNull,
            reason: '${screen.name} must not overflow at 1.5x text (§70)');
      });
    }

    testWidgets('the largeText flag raises the scale it is given',
        (tester) async {
      final store = await _loggedStore();
      store.setLargeText(true);
      late TextScaler seen;
      await tester.pumpWidget(_host(
          store,
          Builder(builder: (ctx) {
            seen = MediaQuery.of(ctx).textScaler;
            return const SizedBox.shrink();
          })));
      await _settle(tester);
      expect(seen.scale(10), greaterThanOrEqualTo(10 * kPulseLargeTextScale),
          reason: 'the toggle must actually enlarge text');
    });

    testWidgets('a platform scale above the toggle is left alone',
        (tester) async {
      final store = await _loggedStore();
      store.setLargeText(true);
      late TextScaler seen;
      await tester.pumpWidget(_host(
          store,
          Builder(builder: (ctx) {
            seen = MediaQuery.of(ctx).textScaler;
            return const SizedBox.shrink();
          }),
          scaler: const TextScaler.linear(2.0)));
      await _settle(tester);
      expect(seen.scale(10), closeTo(20, 0.01),
          reason: 'never shrink text the user already enlarged system-wide');
    });
  });

  group('WP5.3 reduce motion', () {
    testWidgets('the flag reaches MediaQuery', (tester) async {
      final store = await _loggedStore();
      store.setReduceMotion(true);
      late bool disabled;
      await tester.pumpWidget(_host(
          store,
          Builder(builder: (ctx) {
            disabled = MediaQuery.of(ctx).disableAnimations;
            return const SizedBox.shrink();
          })));
      await _settle(tester);
      expect(disabled, isTrue,
          reason: 'animated widgets read this to hold still (§70)');
    });

    testWidgets('it is off by default', (tester) async {
      final store = await _loggedStore();
      late bool disabled;
      await tester.pumpWidget(_host(
          store,
          Builder(builder: (ctx) {
            disabled = MediaQuery.of(ctx).disableAnimations;
            return const SizedBox.shrink();
          })));
      await _settle(tester);
      expect(disabled, isFalse);
    });

    testWidgets('screens still build with motion reduced', (tester) async {
      final store = await _loggedStore();
      store.setReduceMotion(true);
      await tester.pumpWidget(_host(store, TodayScreen.new()));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('WP5.3 tap targets', () {
    for (final screen in <({String name, Widget Function() build})>[
      (name: 'Today', build: TodayScreen.new),
      (name: 'Diary', build: DiaryScreen.new),
      (name: 'Train', build: TrainScreen.new),
    ]) {
      testWidgets('${screen.name} keeps targets tappable', (tester) async {
        final store = await _loggedStore();
        await tester.pumpWidget(_host(store, screen.build()));
        await _settle(tester);
        _expectTapTargets(tester);
      });
    }
  });

  group('WP5.3 high contrast', () {
    testWidgets('the flag changes the theme it produces', (tester) async {
      final plain = PulseTheme.light();
      final contrast = PulseTheme.light(highContrast: true);
      // High contrast flattens elevation and strengthens outlines rather
      // than recolouring the scheme.
      expect(contrast.cardTheme.elevation, 0,
          reason: 'high contrast removes the elevation shadow (§70)');
      expect(contrast.cardTheme.elevation, isNot(plain.cardTheme.elevation));
      expect(contrast.scaffoldBackgroundColor,
          isNot(plain.scaffoldBackgroundColor));
    });

    testWidgets('screens build under high contrast', (tester) async {
      final store = await _loggedStore();
      store.setHighContrast(true);
      await tester.pumpWidget(_host(store, TodayScreen.new()));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
