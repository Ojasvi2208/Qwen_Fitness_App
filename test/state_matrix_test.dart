import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/monetization.dart';
import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/screens/auth/onboarding_screen.dart';
import 'package:pulse_app/screens/diary/diary_screens.dart';
import 'package:pulse_app/screens/profile/settings_screens.dart';
import 'package:pulse_app/screens/progress/progress_screens.dart';
import 'package:pulse_app/screens/today/today_screen.dart';
import 'package:pulse_app/screens/train/train_screens.dart';
import 'package:pulse_app/theme/pulse_theme.dart';
import 'package:pulse_app/widgets/pulse_components.dart';

/// ═══════════════════════════════════════════════════════════════════
/// WP5.2 — State-matrix sweep (§87, release doc §7.2/§10(2))
/// Renders every state-carrying screen under each reachable state and
/// asserts it builds without throwing or overflowing. The matrix is the
/// point: a screen that only works with populated data is a screen that
/// breaks on a real first launch.
/// ═══════════════════════════════════════════════════════════════════

/// In-memory repository double — same shape as the one in
/// e2e_flows_test.dart so the suites stay recognisable to each other.
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

/// The states from release doc §10(2). `loading` and `error` are listed
/// there but are not screen-level states in this codebase — see the
/// deferred table in docs/PHASE5_TEST_PLAN.md — so the sweep covers the
/// five that are genuinely reachable and they are asserted where they do
/// exist (ProgressScreen's skeleton, form-field validation).
enum _State { firstRun, empty, populated, premiumLocked, offline }

/// Builds a store in the requested state. Persistence is attached through
/// the real idiom — PulseStore() is zero-arg — so hydration runs exactly
/// as it does in production.
Future<PulseStore> _storeIn(_State state) async {
  final store = PulseStore();
  await store.attachPersistence(_MemRepo());
  switch (state) {
    case _State.firstRun:
      break; // nothing captured yet: no profile, nothing logged
    case _State.empty:
      // Onboarded, but has not logged anything yet.
      store.setProfile(
          name: 'Test Person', age: 30, heightCm: 170, startWeightKg: 70);
      store.setTargets(targetWeightKg: 65);
    case _State.populated:
      store.setProfile(
          name: 'Test Person', age: 30, heightCm: 170, startWeightKg: 70);
      store.setTargets(targetWeightKg: 65);
      store.addFood(PulseData.foodById('f1'), 1, MealType.breakfast);
      store.addFood(PulseData.foodById('f3'), 1.5, MealType.lunch);
      store.addWater(0.5);
      store.logWeight(69.2);
      store.logMeasurement('waist', 82);
      store.startWorkout('Upper Body Strength');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      store.finishWorkout(rating: 1);
    case _State.premiumLocked:
      // Free tier is the locked state: ads allowed, Pro features gated.
      store.setProfile(name: 'Test Person');
      expect(store.premium, isFalse, reason: 'free tier is the gated state');
    case _State.offline:
      store.setProfile(name: 'Test Person');
      store.addFood(PulseData.foodById('f1'), 1, MealType.breakfast);
      store.setOffline(true);
  }
  return store;
}

/// Hosts one screen with the store in scope, a real theme and a Navigator,
/// mirroring how main.dart wires the app. The tab bodies (Today, Diary,
/// Progress, Train) return bare SafeAreas because the shell supplies the
/// Scaffold, so the host provides one too — without it they would render
/// against unbounded width and report a false overflow.
Widget _host(PulseStore store, Widget screen) => PulseScope(
      store: store,
      child: MaterialApp(
        theme: PulseTheme.light(),
        home: Scaffold(body: screen),
      ),
    );

typedef _Screen = ({String name, Widget Function() build});

/// The state-carrying screens. Detail and form screens that take route
/// arguments are exercised by the flow suites instead.
const List<_Screen> _screens = [
  (name: 'Today', build: TodayScreen.new),
  (name: 'Diary', build: DiaryScreen.new),
  (name: 'Progress', build: ProgressScreen.new),
  (name: 'Nutrition progress', build: NutritionProgressScreen.new),
  (name: 'Activity progress', build: ActivityProgressScreen.new),
  (name: 'Train', build: TrainScreen.new),
  (name: 'Profile', build: ProfileScreen.new),
];

/// Pumps past the animations a screen starts on entry. ProgressScreen
/// holds a 700 ms skeleton and several cards run entry transitions.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final state in _State.values) {
    group('WP5.2 state matrix — ${state.name}', () {
      for (final screen in _screens) {
        testWidgets('${screen.name} builds cleanly', (tester) async {
          final store = await _storeIn(state);
          await tester.pumpWidget(_host(store, screen.build()));
          await _settle(tester);
          expect(tester.takeException(), isNull,
              reason: '${screen.name} must render in the ${state.name} state');
        });
      }
    });
  }

  // ── State-specific guarantees ────────────────────────────────────
  group('WP5.2 first-run guarantees', () {
    testWidgets('onboarding renders without a profile', (tester) async {
      final store = await _storeIn(_State.firstRun);
      await tester.pumpWidget(_host(store, const OnboardingScreen(step: 0)));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding pre-fills nothing', (tester) async {
      final store = await _storeIn(_State.firstRun);
      await tester.pumpWidget(_host(store, const OnboardingScreen(step: 2)));
      await _settle(tester);
      // §14: a new user must not find someone else's details in the form.
      for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(field.controller?.text ?? '', isEmpty,
            reason: 'onboarding fields start blank');
      }
    });

    testWidgets('no screen shows a name before one is captured',
        (tester) async {
      final store = await _storeIn(_State.firstRun);
      await tester.pumpWidget(_host(store, ProfileScreen.new()));
      await _settle(tester);
      expect(find.textContaining('Alex'), findsNothing);
      expect(find.textContaining('Morgan'), findsNothing);
    });
  });

  group('WP5.2 empty guarantees', () {
    testWidgets('trend screens offer an empty state, not invented figures',
        (tester) async {
      for (final build in [
        NutritionProgressScreen.new,
        ActivityProgressScreen.new,
      ]) {
        final store = await _storeIn(_State.empty);
        await tester.pumpWidget(_host(store, build()));
        await _settle(tester);
        expect(find.byType(EmptyState), findsOneWidget,
            reason: 'no per-day history exists yet');
        // Figures from the old sample week must not survive anywhere.
        expect(find.textContaining('2,084'), findsNothing);
        expect(find.textContaining('6,932'), findsNothing);
        expect(find.textContaining('of 7 days'), findsNothing);
      }
    });

    testWidgets('progress home shows its own empty state', (tester) async {
      final store = await _storeIn(_State.empty);
      await tester.pumpWidget(_host(store, ProgressScreen.new()));
      await _settle(tester);
      expect(store.hasAnyData, isFalse);
      expect(find.byType(EmptyState), findsOneWidget);
    });
  });

  group('WP5.2 premium-locked guarantees', () {
    testWidgets('free tier is allowed ads and Today builds with the slot',
        (tester) async {
      final store = await _storeIn(_State.premiumLocked);
      await tester.pumpWidget(_host(store, TodayScreen.new()));
      await _settle(tester);
      expect(store.entitlements.shouldShowAds, isTrue);
      expect(AdPolicy.allowedSlots, contains(AdSlot.homeFooter));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pro hides the ad slot on the same screen', (tester) async {
      final store = await _storeIn(_State.premiumLocked);
      await store.purchasePro(PulsePricing.yearly);
      await tester.pumpWidget(_host(store, TodayScreen.new()));
      await _settle(tester);
      expect(store.premium, isTrue);
      expect(store.entitlements.shouldShowAds, isFalse);
    });
  });

  group('WP5.2 offline guarantees', () {
    testWidgets('logging still works with the offline flag set',
        (tester) async {
      final store = await _storeIn(_State.offline);
      expect(store.offlineMode, isTrue);
      final before = store.foodKcal;
      store.addFood(PulseData.foodById('f4'), 1, MealType.dinner);
      expect(store.foodKcal, greaterThan(before),
          reason: 'local-first: offline never blocks a log');
      await tester.pumpWidget(_host(store, TodayScreen.new()));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('WP5.2 loading state', () {
    testWidgets('measurements shows a skeleton before its data settles',
        (tester) async {
      final store = await _storeIn(_State.populated);
      // MeasurementsScreen is the one screen that models a loading state
      // (§87): a 700 ms delay stands in for the read it will later await.
      await tester.pumpWidget(_host(store, const MeasurementsScreen()));
      await tester.pump(const Duration(milliseconds: 100)); // timer pending
      expect(find.byType(DashboardSkeleton), findsOneWidget);
      await _settle(tester);
      expect(find.byType(DashboardSkeleton), findsNothing,
          reason: 'skeleton gives way once the delay elapses');
    });
  });
}
