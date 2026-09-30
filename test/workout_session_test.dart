import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/data/workout_session.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PHASE 3 — WP3.1 Workout Session Engine tests
///
/// Two layers:
///  A) Pure unit tests of the session manager (derived stats, guards,
///     undo symmetry, serialization).
///  B) Store-level data-consistency tests that simulate app restarts
///     through the real persistence backend.
/// ═══════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutSessionManager (pure)', () {
    late WorkoutSessionManager mgr;
    late int changes;

    setUp(() {
      changes = 0;
      mgr = WorkoutSessionManager(onChanged: () => changes++);
    });

    test('start creates an active session and fires onChanged', () {
      final s = mgr.start('Upper Body Strength');
      expect(mgr.hasActive, isTrue);
      expect(s.status, SessionStatus.active);
      expect(changes, 1);
    });

    test('starting a second workout auto-saves the first as partial', () {
      final a = mgr.start('Upper Body Strength');
      mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      mgr.start('HIIT Burn');
      expect(a.status, SessionStatus.finished);
      expect(mgr.history.length, 1);
      expect(mgr.history.first.totalSets, 1); // partial save kept
    });

    test('logSet without an active session throws StateError', () {
      expect(
          () => mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 5, weightKg: 10),
          throwsStateError);
    });

    test('volume and set counts derive from records, not constants', () {
      final s = mgr.start('Upper Body Strength');
      mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      mgr.logSet(exerciseIndex: 0, setNumber: 2, reps: 10, weightKg: 20);
      mgr.logSet(exerciseIndex: 1, setNumber: 1, reps: 8, weightKg: 12.5);
      expect(s.volumeKg, 10 * 20 + 10 * 20 + 8 * 12.5);
      expect(s.totalSets, 3);
      expect(s.exercisesCompleted, 2);
      expect(s.setsDoneFor(0), 2);
      expect(s.lastSetFor(0)?.setNumber, 2);
    });

    test('undoLastSet is symmetric with logSet', () {
      final s = mgr.start('Upper Body Strength');
      final before = s.volumeKg;
      mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      mgr.undoLastSet();
      expect(s.volumeKg, before);
      expect(s.totalSets, 0);
      expect(mgr.undoLastSet(), isNull); // undo on empty is a no-op
    });

    test('nonsense inputs are clamped, never corrupt history', () {
      final s = mgr.start('Upper Body Strength');
      mgr.logSet(exerciseIndex: -5, setNumber: 0, reps: 999, weightKg: -10);
      final r = s.sets.single;
      expect(r.exerciseIndex, 0);
      expect(r.setNumber, 1);
      expect(r.reps, 200);
      expect(r.weightKg, 0);
    });

    test('finish caps elapsed at startedAt..finishedAt and stores rating', () {
      final start = DateTime(2026, 9, 30, 18);
      final s = mgr.start('Upper Body Strength', now: start);
      mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20,
          now: start.add(const Duration(minutes: 40)));
      final done = mgr.finish(rating: 1, now: start.add(const Duration(minutes: 42)))!;
      expect(done.durationMinutes, 42);
      expect(done.rating, 1);
      expect(mgr.hasActive, isFalse);
      // estimated kcal deterministic: 42 min × 6.2 (intermediate)
      expect(done.estimatedKcal, (42 * 6.2).round());
    });

    test('finish with earlier end time than start does not go negative', () {
      final start = DateTime(2026, 9, 30, 18);
      mgr.start('Upper Body Strength', now: start);
      final done = mgr.finish(now: start.subtract(const Duration(hours: 1)))!;
      expect(done.elapsed, Duration.zero);
    });

    test('rate() updates a saved session by id', () {
      final s = mgr.start('Core Circuit');
      mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 15, weightKg: 0);
      mgr.finish();
      mgr.rate(s.id, 2);
      expect(mgr.history.first.rating, 2);
      mgr.rate('missing-id', 1); // no throw, no change
      expect(mgr.history.first.rating, 2);
    });

    test('JSON round-trip preserves sets, timestamps and ratings', () {
      final start = DateTime(2026, 9, 30, 18);
      mgr.start('Upper Body Strength', now: start);
      mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20, now: start.add(const Duration(minutes: 2)));
      mgr.logSet(exerciseIndex: 2, setNumber: 1, reps: 12, weightKg: 22.5, now: start.add(const Duration(minutes: 9)));
      mgr.finish(rating: 0, now: start.add(const Duration(minutes: 30)));
      mgr.start('Morning Mobility'); // leave an ACTIVE session too

      final json = jsonDecodeSafe(mgr.toJson());
      final restored = WorkoutSessionManager(onChanged: () {})..hydrate(json);

      expect(restored.history.length, 1);
      final h = restored.history.first;
      expect(h.templateName, 'Upper Body Strength');
      expect(h.totalSets, 2);
      expect(h.volumeKg, 10 * 20 + 12 * 22.5);
      expect(h.rating, 0);
      expect(h.durationMinutes, 30);
      expect(restored.activeSession?.templateName, 'Morning Mobility');
    });

    test('hydrate skips malformed rows instead of crashing', () {
      final mgr2 = WorkoutSessionManager(onChanged: () {});
      mgr2.hydrate({
        'active': null,
        'history': [
          {'bogus': true},
          'not-a-map',
          {'template': 'X', 'startedAt': 'garbage'},
        ],
      });
      expect(mgr2.history, isEmpty);
      expect(mgr2.activeSession, isNull);
    });

    test('volumeLabel groups thousands like §37', () {
      final s = mgr.start('Upper Body Strength');
      for (var i = 0; i < 12; i++) {
        mgr.logSet(exerciseIndex: 0, setNumber: 1, reps: 60, weightKg: 12);
      }
      expect(s.volumeKg, 12 * 60 * 12); // 8640
      expect(s.volumeLabel, '8,640 kg');
    });
  });

  group('PulseStore workout integration (restart consistency)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<PulseStore> freshStore() async {
      final repo = SharedPreferencesLocalRepository();
      await repo.init();
      final store = PulseStore();
      await store.initLocal(repo);
      return store;
    }

    test('full flow: start → sets → finish credits derived kcal once', () async {
      final store = await freshStore();
      final kcalBefore = store.activityCaloriesBurned;
      final workoutsBefore = store.workoutsCompletedToday;

      store.startWorkout('Upper Body Strength');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      store.logSet(exerciseIndex: 0, setNumber: 2, reps: 10, weightKg: 20);
      final done = store.finishWorkout(rating: 1)!;

      expect(store.sessions.hasActive, isFalse);
      expect(store.activityCaloriesBurned, greaterThan(kcalBefore));
      expect(store.workoutsCompletedToday, workoutsBefore + 1);
      expect(done.totalSets, 2);

      // Finish again must be a no-op (no double credit).
      final kcalAfter = store.activityCaloriesBurned;
      expect(store.finishWorkout(), isNull);
      expect(store.activityCaloriesBurned, kcalAfter);
    });

    test('mid-workout restart restores the ACTIVE session with its sets', () async {
      final store = await freshStore();
      store.startWorkout('Upper Body Strength');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      store.logSet(exerciseIndex: 0, setNumber: 2, reps: 12, weightKg: 20);
      await store.flushPendingSave();

      // Simulate process death + relaunch.
      final store2 = await freshStore();
      final resumed = store2.sessions.activeSession;
      expect(resumed, isNotNull);
      expect(resumed!.templateName, 'Upper Body Strength');
      expect(resumed.totalSets, 2);
      expect(resumed.volumeKg, 10 * 20 + 12 * 20);
      expect(resumed.lastSetFor(0)?.reps, 12);

      // And it can still be finished normally after restore.
      final done = store2.finishWorkout();
      expect(done?.totalSets, 2);
      expect(store2.sessions.hasActive, isFalse);
    });

    test('completed history survives restart and stays newest-first', () async {
      final store = await freshStore();
      store.startWorkout('Core Circuit');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 15, weightKg: 0);
      store.finishWorkout();
      store.startWorkout('HIIT Burn');
      store.logSet(exerciseIndex: 1, setNumber: 1, reps: 20, weightKg: 5);
      store.finishWorkout(rating: 2);
      await store.flushPendingSave();

      final store2 = await freshStore();
      expect(store2.sessions.history.length, 2);
      expect(store2.sessions.history.first.templateName, 'HIIT Burn');
      expect(store2.sessions.history.first.rating, 2);
      expect(store2.sessions.history.last.templateName, 'Core Circuit');
    });

    test('v1 snapshot without workouts block hydrates to empty history', () async {
      // Hand-crafted v1 payload (pre-WP3.1 installs upgrading to v2).
      SharedPreferences.setMockInitialValues({
        'pulse.snapshot.v1':
            '{"schemaVersion":1,"water":2.0,"steps":5000}',
      });
      final store = await freshStore();
      expect(store.waterLogged, 2.0); // old fields still load
      expect(store.sessions.history, isEmpty);
      expect(store.sessions.activeSession, isNull);
    });

    test('deleteAllLocalData wipes sessions incl. active one', () async {
      final store = await freshStore();
      store.startWorkout('Upper Body Strength');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      await store.flushPendingSave();
      await store.deleteAllLocalData();

      expect(store.sessions.hasActive, isFalse);
      expect(store.sessions.history, isEmpty);
      final store2 = await freshStore();
      expect(store2.sessions.history, isEmpty);
      expect(store2.sessions.activeSession, isNull);
    });

    test('export bundle contains the workouts block', () async {
      final store = await freshStore();
      store.startWorkout('Upper Body Strength');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      store.finishWorkout();
      final exported = store.exportUserDataJson();
      expect(exported, contains('"workouts"'));
      expect(exported, contains('Upper Body Strength'));
    });

    test('analytics events fire for start and complete only', () async {
      final store = await freshStore();
      final seen = <String>[];
      store.analyticsSink = seen.add;
      store.startWorkout('Upper Body Strength');
      store.logSet(exerciseIndex: 0, setNumber: 1, reps: 10, weightKg: 20);
      store.finishWorkout();
      expect(seen, ['workout_started', 'workout_completed']);
    });
  });
}

/// Deep-encode/decode through JSON so hydrate sees plain maps/lists,
/// exactly like data coming back from disk.
Map<String, dynamic> jsonDecodeSafe(Map<String, dynamic> encoded) =>
    (jsonDecode(jsonEncode(encoded)) as Map).cast<String, dynamic>();
