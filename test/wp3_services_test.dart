import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_app/data/consistency_service.dart';
import 'package:pulse_app/data/nutrition_service.dart';
import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/data/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════
/// Phase 3 — WP3.2 (nutrition + units), WP3.4 (streaks/report/goal
/// review), WP3.5 (reminders) service tests, including persistence
/// round-trips through the real store/repository stack.
/// ═══════════════════════════════════════════════════════════════════

class _FakeRepo implements LocalRepository {
  Map<String, dynamic>? stored;
  @override
  Future<void> init() async {}
  @override
  Future<Map<String, dynamic>?> readSnapshot() async => stored;
  @override
  Future<void> writeSnapshot(Map<String, dynamic> snapshot) async {
    stored = snapshot;
  }
  @override
  Future<void> clearAll() async => stored = null;
}

class _FakeScheduler implements ReminderScheduler {
  bool granted;
  final List<List<Reminder>> syncs = [];
  int cancels = 0;
  _FakeScheduler({this.granted = true});
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<void> sync(List<Reminder> active) async => syncs.add(active);
  @override
  Future<void> cancelAll() async => cancels++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP3.2 NutritionService', () {
    test('calorie equation matches §17 numbers for seeded day', () {
      final s = PulseStore();
      final n = NutritionService.forToday(s);
      expect(n.goal, 2050);
      expect(n.food, closeTo(1340, 1));
      expect(n.burned, 310);
      expect(n.remaining, closeTo(1020, 1));
      expect(n.remainingRounded, 1020);
    });

    test('fiber aggregates across diary entries', () {
      final s = PulseStore();
      final n = NutritionService.forToday(s);
      // f1(0)+f3*1.2(0)+f4(3.5)+f6(0)+f18*2(12.6)+f10(6.4) from seed diary
      expect(n.fiber, closeTo(22.5, 0.01));
    });

    test('meal subtotals sum to food total', () {
      final s = PulseStore();
      final n = NutritionService.forToday(s);
      final sum = n.mealKcal.values.reduce((a, b) => a + b);
      expect(sum, closeTo(n.food, 0.001));
    });

    test('protein hint is encouraging and gap-accurate', () {
      final s = PulseStore();
      final n = NutritionService.forToday(s);
      final hint = n.proteinHint(s.goals.proteinGoal);
      expect(hint, contains('${(135 - n.protein).round()} g'));
      expect(hint.toLowerCase(), isNot(contains('fail')));
    });

    test('pct clamps at 1 and guards divide-by-zero', () {
      expect(NutritionService.pct(200, 100), 1.0);
      expect(NutritionService.pct(50, 0), 0.0);
    });
  });

  group('WP3.2 Units (§59)', () {
    test('kg ↔ lb round trip', () {
      expect(Units.kgToLb(79.8), closeTo(175.9, 0.1));
      expect(Units.lbToKg(Units.kgToLb(79.8)), closeTo(79.8, 0.001));
    });
    test('mass display honors unit setting', () {
      expect(Units.mass(79.8, 'kg'), '79.8 kg');
      expect(Units.mass(79.8, 'lb'), '175.9 lb');
    });
    test('parseMass rejects nonsense (§75 "Enter a valid weight")', () {
      expect(Units.parseMass('abc', 'kg'), isNull);
      expect(Units.parseMass('-5', 'kg'), isNull);
      expect(Units.parseMass('0', 'kg'), isNull);
      expect(Units.parseMass('176', 'lb'), closeTo(79.83, 0.1));
    });
    test('height conversions', () {
      expect(Units.heightCmFtIn(178), """5' 10\"""");
      expect(Units.parseLength("""5'10\"""", 'ft'), closeTo(177.8, 0.5));
      expect(Units.parseLength('2000', 'cm'), isNull);
    });
    test('volume + distance', () {
      expect(Units.volume(250, 'oz'), contains('oz'));
      expect(Units.mlToOz(1000), closeTo(33.8, 0.1));
      expect(Units.distance(4.9, 'mi'), '3.04 mi');
      expect(Units.kmToMi(4.9), closeTo(3.04, 0.01));
    });
  });

  group('WP3.4 StreakEngine', () {
    final today = DateTime(2026, 9, 29);
    test('current streak counts consecutive days ending today', () {
      final done = {today, today.subtract(const Duration(days: 1)),
          today.subtract(const Duration(days: 2))};
      final st = StreakEngine.compute(
          (d) => done.contains(dayOf(d)), today: today);
      expect(st.current, 3);
      expect(st.bestRecent, 3);
    });
    test('gap today does not zero an ongoing streak', () {
      final done = {today.subtract(const Duration(days: 1)),
          today.subtract(const Duration(days: 2))};
      final st = StreakEngine.compute(
          (d) => done.contains(dayOf(d)), today: today);
      expect(st.current, 2);
    });
    test('broken streak message is non-punitive (§49)', () {
      final done = {today.subtract(const Duration(days: 5))};
      final st = StreakEngine.compute(
          (d) => done.contains(dayOf(d)), today: today, windowDays: 21);
      expect(st.current, 0);
      expect(st.broken, true);
      expect(st.message, contains('meaningful consistency'));
      expect(st.message.toLowerCase(), isNot(contains('failed')));
    });
    test('empty history invites gently', () {
      final st = StreakEngine.compute((d) => false, today: today);
      expect(st.current, 0);
      expect(st.message, contains('every entry counts'));
    });
  });

  group('WP3.4 Weekly report + goal review', () {
    test('report fields are bounded and populated', () {
      final s = PulseStore();
      final r = ConsistencyStore(s).weeklyReport();
      expect(r.avgCalories, greaterThan(1500));
      expect(r.avgCalories, lessThan(2600));
      expect(r.proteinGoalDays, inInclusiveRange(0, 7));
      expect(r.waterGoalDays, inInclusiveRange(0, 7));
      expect(r.workouts, greaterThanOrEqualTo(0));
      expect(r.biggestWin, isNotEmpty);
      expect(r.caloriesLabel, r.avgCalories.round().toString());
    });
    test('goal review never prompts without 5 real workouts', () {
      final s = PulseStore();
      expect(ConsistencyStore(s).smartGoalReview().shouldPrompt, false);
    });
    test('food streak reflects live diary state', () {
      final s = PulseStore();
      expect(ConsistencyStore(s).foodStreak.current, greaterThanOrEqualTo(1));
      s.diary.clear();
      expect(ConsistencyStore(s).foodStreak.current, 0);
    });
  });

  group('WP3.5 Reminders', () {
    test('time label formats 12-hour (§64 "10:30 AM")', () {
      final r = Reminder(id: 'r1', title: 'Drink Water', body: 'Time for a glass.', hour: 10, minute: 30);
      expect(r.timeLabel, '10:30 AM');
      r.hour = 18;
      expect(r.timeLabel, '6:30 PM');
      r.hour = 0;
      expect(r.timeLabel, '12:30 AM'); // midnight keeps its minute

    });
    test('repeat modes fire on correct weekdays', () {
      final daily = Reminder(id: 'a', title: 'x', body: 'y', hour: 8, minute: 0);
      final wd = Reminder(id: 'b', title: 'x', body: 'y', hour: 8, minute: 0, repeat: RepeatMode.weekdays);
      final custom = Reminder(id: 'c', title: 'x', body: 'y', hour: 8, minute: 0,
          repeat: RepeatMode.custom, days: {1, 3});
      expect(daily.firesOn(7), true);
      expect(wd.firesOn(6), false);
      expect(wd.firesOn(3), true);
      expect(custom.firesOn(2), false);
      expect(custom.firesOn(3), true);
    });
    test('book validates input (§75)', () {
      var changes = 0;
      final book = ReminderBook(onChanged: () => changes++);
      expect(book.upsert(Reminder(id: 'r', title: '  ', body: '', hour: 9, minute: 0)), false);
      expect(book.upsert(Reminder(id: 'r', title: 'ok', body: '', hour: 25, minute: 0)), false);
      expect(book.upsert(Reminder(id: 'r', title: 'ok', body: '', hour: 9, minute: 0,
          repeat: RepeatMode.custom, days: {})), false);
      expect(book.upsert(Reminder(id: 'r', title: 'Walk break', body: 'Stretch your legs.', hour: 15, minute: 0)), true);
      expect(changes, 1);
    });
    test('scheduler sync receives only enabled reminders; denied permission degrades gracefully', () async {
      final sched = _FakeScheduler(granted: true);
      final m = ReminderManager(onChanged: () {}, scheduler: sched);
      m.save(Reminder(id: 'r1', title: 'Drink Water', body: 'Glass time.', hour: 10, minute: 30));
      m.save(Reminder(id: 'r2', title: 'Evening walk', body: 'A short walk helps.', hour: 18, minute: 0));
      await Future.delayed(Duration.zero);
      expect(sched.syncs.last.length, 2);
      m.toggle('r2', false);
      await Future.delayed(Duration.zero);
      expect(sched.syncs.last.length, 1);
      // denial path: nothing throws, sync stops
      sched.granted = false;
      m.toggle('r1', true);
      await Future.delayed(Duration.zero);
      expect(m.permissionGranted, false);
    });
  });

  group('Phase 3 persistence round-trips', () {
    test('reminders + habit toggles survive restart (schema v4)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLocalRepository();
      final s1 = PulseStore();
      await s1.attachPersistence(repo);
      s1.reminders.book.onChanged = () {}; // silence autosave double-fire in test
      s1.reminders.save(Reminder(id: 'rx', title: 'Drink Water', body: 'Hydration check.', hour: 10, minute: 30));
      s1.toggleHabit('Mindfulness');
      s1.toggleHabit('Sleep');
      await s1.flushPendingSave();

      final s2 = PulseStore();
      await s2.attachPersistence(_MemRepo(await repo.readSnapshot()));
      expect(s2.reminders.book.all.length, 1);
      expect(s2.reminders.book.all.first.title, 'Drink Water');
      expect(s2.reminders.book.all.first.hour, 10);
      expect(s2.habitEnabled['Mindfulness'], true);
      expect(s2.habitEnabled['Sleep'], false);
    });

    test('Delete My Data erases reminders + restores habit defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = _FakeRepo();
      final s = PulseStore();
      await s.attachPersistence(repo);
      s.reminders.save(Reminder(id: 'rd', title: 'x', body: 'y', hour: 9, minute: 0));
      s.toggleHabit('Water');
      await s.flushPendingSave();
      await s.deleteAllLocalData();
      expect(s.reminders.book.all, isEmpty);
      expect(s.habitEnabled['Water'], true,
          reason: 'erasure restores the catalog default, which is on');
    }, skip: false);

    test('v3 snapshots hydrate cleanly into v4 store (additive migration)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = _FakeRepo();
      final s = PulseStore();
      await s.attachPersistence(repo);
      s.addFood(PulseData.foods[1], 1, MealType.snacks);
      await s.flushPendingSave();
      final snap = repo.stored!;
      snap.remove('reminders');
      snap.remove('habits');
      snap['schemaVersion'] = 3;
      final s2 = PulseStore();
      await s2.attachPersistence(_MemRepo(snap));
      expect(s2.diary.any((e) => e.food.id == 'f2'), true);
      expect(s2.reminders.book.all, isEmpty);
      expect(s2.habitEnabled['Water'], true); // default preserved
    });
  });
}

class _MemRepo implements LocalRepository {
  Map<String, dynamic>? data;
  _MemRepo(this.data);
  @override
  Future<void> init() async {}
  @override
  Future<Map<String, dynamic>?> readSnapshot() async => data;
  @override
  Future<void> writeSnapshot(Map<String, dynamic> snapshot) async => data = snapshot;
  @override
  Future<void> clearAll() async => data = null;
}
