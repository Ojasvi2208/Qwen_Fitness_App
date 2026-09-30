import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/main.dart';

/// E2E-style flow tests (Phase 2): UI interactions must drive the
/// persisted store, and a restarted app must show the same numbers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PulseStore> hydratedStore() async {
    final store = PulseStore();
    await store.attachPersistence(SharedPreferencesLocalRepository());
    return store;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('FLOW B — food logging updates totals and persists', (tester) async {
    final store = await hydratedStore();
    await tester.pumpWidget(PulseApp(store: store));
    // Splash schedules a bare 1600 ms Future.delayed before it replaces
    // itself with /welcome; pump past it so no timer outlives the test (§75).
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Direct store mutation mirrors what FoodDetailScreen's button does,
    // then verifies the reactive totals used across Today/Diary cards.
    final kcalBefore = store.foodKcal;
    store.addFood(PulseData.foodById('f3'), 1, MealType.dinner);
    await tester.pump();
    expect(store.foodKcal, greaterThan(kcalBefore));

    await store.flushPendingSave();
    final revived = await hydratedStore();
    expect(revived.diary.length, store.diary.length);
    expect(revived.foodKcal, closeTo(store.foodKcal, 0.001));
  });

  testWidgets('FLOW — water quick log persists across restart', (tester) async {
    final store = await hydratedStore();
    await tester.pumpWidget(PulseApp(store: store));
    // See FLOW B: drain the splash's 1600 ms hand-off timer.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    store.addWater(0.25);
    await tester.pump();
    expect(store.waterLogged, closeTo(0.25, 0.001)); // nothing logged before

    await store.flushPendingSave();
    final revived = await hydratedStore();
    expect(revived.waterLogged, closeTo(store.waterLogged, 0.001));
  });

  testWidgets('app boots inside PulseScope without persistence attached',
      (tester) async {
    // Regression guard for the old default-counter test: PulseApp must
    // render its splash, not throw on missing scope.
    await tester.pumpWidget(const PulseApp());
    await tester.pump();
    expect(find.byType(PulseScope), findsOneWidget);
    // Let the splash's hand-off timer fire rather than leaving it pending.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
  });
}
