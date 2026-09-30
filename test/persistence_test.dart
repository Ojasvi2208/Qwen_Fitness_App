import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 2 TEST SUITE — local persistence data-consistency
///
/// Every test simulates an app restart by creating a *fresh* PulseStore
/// and re-attaching the same repository, then asserting state equality.
/// ═══════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferencesLocalRepository> newRepo() async {
    final r = SharedPreferencesLocalRepository();
    return r;
  }

  group('LocalRepository', () {
    test('empty on first launch', () async {
      final repo = await newRepo();
      await repo.init();
      expect(await repo.readSnapshot(), isNull);
    });

    test('write → read round-trip is lossless', () async {
      final repo = await newRepo();
      await repo.init();
      final snap = {'water': 2.1, 'diary': [{'id': 'x', 'foodId': 'f1', 'servings': 2.0, 'meal': 1}]};
      await repo.writeSnapshot(snap);
      final back = await repo.readSnapshot();
      expect(back, snap);
    });

    test('corrupt payload returns null instead of throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kSnapshotKey, '{not valid json!!');
      final repo = await newRepo();
      await repo.init();
      expect(await repo.readSnapshot(), isNull);
    });

    test('future schema version is refused (forward-compat guard)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kSnapshotKey, '{"water":3.0}');
      await prefs.setString(kMetaKey, '{"schemaVersion":999}');
      final repo = await newRepo();
      await repo.init();
      expect(await repo.readSnapshot(), isNull);
    });

    test('clearAll removes snapshot + meta + revision', () async {
      final repo = await newRepo();
      await repo.init();
      await repo.writeSnapshot({'water': 1.0});
      await repo.clearAll();
      expect(await repo.readSnapshot(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kMetaKey), isNull);
    });

    test('revision counter increments per save', () async {
      final repo = await newRepo();
      await repo.init();
      await repo.writeSnapshot({'a': 1});
      await repo.writeSnapshot({'a': 2});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('rev'), 2);
    });
  });

  group('PulseStore persistence — data consistency across restarts', () {
    test('food logging survives restart with identical totals', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());

      final beforeCount = store.diary.length;
      store.addFood(PulseData.foodById('f2'), 2, MealType.snacks); // banana ×2
      await store.flushPendingSave();
      final kcalBefore = store.foodKcal;
      final proteinBefore = store.protein;

      // Simulate cold restart.
      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());

      expect(revived.diary.length, beforeCount + 1);
      expect(revived.foodKcal, closeTo(kcalBefore, 0.001));
      expect(revived.protein, closeTo(proteinBefore, 0.001));
      expect(revived.hydratedFromDisk, isTrue);
    });

    test('removeEntry (undo swipe) persists', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      final id = store.diary.first.id;
      store.removeEntry(id);
      await store.flushPendingSave();

      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());
      expect(revived.diary.any((e) => e.id == id), isFalse);
      expect(revived.diary.length, store.diary.length);
    });

    test('water logging clamps identically after restart', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      store.addWater(0.5);
      store.addWater(99); // clamp at 10 L
      await store.flushPendingSave();

      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());
      expect(revived.waterLogged, store.waterLogged);
      expect(revived.waterLogged, 10.0);
    });

    test('same-day weight re-log replaces, not duplicates', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      final today = DateTime.now();
      store.logWeight(78.4, date: today);
      store.logWeight(78.1, date: today); // second entry same day
      await store.flushPendingSave();

      final todays = store.weights
          .where((w) => w.date.day == today.day && w.date.month == today.month)
          .toList();
      expect(todays.length, 1);
      expect(todays.single.kg, 78.1);
      expect(store.currentWeightKg, 78.1);

      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());
      expect(revived.currentWeightKg, 78.1);
      expect(revived.weightSeries.length, store.weightSeries.length);
    });

    test('goal edits persist atomically', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      store.setTargets(targetWeightKg: 74.0, calorieGoal: 2100, proteinGoal: 140);
      await store.flushPendingSave();

      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());
      expect(revived.goals.targetWeightKg, 74.0);
      expect(revived.goals.calorieGoal, 2100);
      expect(revived.goals.proteinGoal, 140);
      // Untouched goals keep defaults.
      expect(revived.goals.carbGoal, 220);
    });

    test('units + accessibility + theme settings persist', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      store.setUnitsWeight('lb');
      store.setUnitsDistance('mi');
      store.setHighContrast(true);
      store.setLargeText(true);
      store.setThemeMode(ThemeMode.dark);
      await store.flushPendingSave();

      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());
      expect(revived.unitsMass, 'lb');
      expect(revived.unitsDistance, 'mi');
      expect(revived.highContrast, isTrue);
      expect(revived.largeText, isTrue);
      expect(revived.themeMode, ThemeMode.dark);
    });

    test('premium flag persists (Phase 4 monetization seam)', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      expect(store.premium, isFalse);
      store.togglePremium();
      await store.flushPendingSave();

      final revived = PulseStore();
      await revived.attachPersistence(await newRepo());
      expect(revived.premium, isTrue);
    });

    test('deleteAllLocalData wipes memory AND disk (§60 right to erasure)', () async {
      final repo = await newRepo();
      final store = PulseStore();
      await store.attachPersistence(repo);
      store.addFood(PulseData.foodById('f9'), 1, MealType.snacks);
      store.addWater(1.0);
      await store.flushPendingSave();

      await store.deleteAllLocalData();

      // Memory is wiped in place (§60).
      expect(store.diary, isEmpty);
      expect(store.weights, isEmpty);
      expect(store.waterLogged, 0);
      expect(store.hydratedFromDisk, isFalse);
      // Disk is wiped too: clearAll removed the snapshot outright, so a
      // later launch takes the first-run path rather than reloading records.
      expect(await repo.readSnapshot(), isNull,
          reason: 'erased data must not survive on disk');
    });

    test('export bundle is valid JSON containing user records', () async {
      final store = PulseStore();
      await store.attachPersistence(await newRepo());
      final json = store.exportUserDataJson();
      expect(json, contains('"diary"'));
      expect(json, contains('"weights"'));
      expect(json, isNot(contains('Greek Yogurt'))); // stores ids, not catalog rows
    });

    test('unknown food id in snapshot is skipped without crashing', () async {
      final repo = await newRepo();
      await repo.init();
      await repo.writeSnapshot({
        'diary': [
          {'id': 'a', 'foodId': 'does-not-exist', 'servings': 1, 'meal': 0},
          {'id': 'b', 'foodId': 'f1', 'servings': 1, 'meal': 2},
        ],
      });
      final revived = PulseStore();
      await revived.attachPersistence(repo);
      expect(revived.diary.length, 1);
      expect(revived.diary.single.food.name, 'Greek Yogurt');
    });
  });

  group('AutosaveCoordinator', () {
    test('debounces rapid writes into one commit', () async {
      final repo = await newRepo();
      await repo.init();
      var writes = 0;
      final counting = _CountingRepo(repo, () => writes++);
      final auto = AutosaveCoordinator(
        repository: counting,
        buildSnapshot: () => {'n': writes},
        interval: const Duration(milliseconds: 30),
      );
      for (var i = 0; i < 50; i++) {
        auto.request();
      }
      expect(writes, 0); // nothing written synchronously
      await auto.flush();
      expect(writes, 1); // 50 mutations → 1 disk write
      auto.dispose();
    });

    test('flush completes writes requested during flush', () async {
      final repo = await newRepo();
      await repo.init();
      var writes = 0;
      late final AutosaveCoordinator auto;
      // The first write marks the store dirty again *while in flight*;
      // flush must loop and commit a second snapshot before returning.
      final slow = _SlowRepo(repo, extraDelayMs: 5, onFirstWrite: () => auto.request());
      auto = AutosaveCoordinator(
        repository: slow,
        buildSnapshot: () => {'n': writes},
      );
      auto.request();
      await auto.flush().timeout(const Duration(seconds: 5));
      expect(slow.writeCount, greaterThanOrEqualTo(2));
      expect(auto.isDirty, isFalse);
      auto.dispose();
    });
  });
}

class _CountingRepo implements LocalRepository {
  _CountingRepo(this.inner, this.onWrite);
  final LocalRepository inner;
  final void Function() onWrite;

  @override
  Future<void> init() => inner.init();
  @override
  Future<Map<String, dynamic>?> readSnapshot() => inner.readSnapshot();
  @override
  Future<void> writeSnapshot(Map<String, dynamic> s) async {
    onWrite();
    await inner.writeSnapshot(s);
  }

  @override
  Future<void> clearAll() => inner.clearAll();
}

class _SlowRepo implements LocalRepository {
  _SlowRepo(this.inner, {required this.extraDelayMs, this.onFirstWrite});
  final LocalRepository inner;
  final int extraDelayMs;
  final void Function()? onFirstWrite;
  int writeCount = 0;

  @override
  Future<void> init() => inner.init();
  @override
  Future<Map<String, dynamic>?> readSnapshot() => inner.readSnapshot();
  @override
  Future<void> writeSnapshot(Map<String, dynamic> s) async {
    writeCount++;
    if (writeCount == 1) onFirstWrite?.call();
    await inner.writeSnapshot(s);
    await Future.delayed(Duration(milliseconds: extraDelayMs));
  }

  @override
  Future<void> clearAll() => inner.clearAll();
}
