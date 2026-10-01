import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/day_archive.dart';
import 'package:pulse_app/data/persistence/local_backend.dart';
import 'package:pulse_app/data/pulse_store.dart';

/// ═══════════════════════════════════════════════════════════════════
/// §3 — The daily archive, and the day that never turned over
///
/// Seven screens claimed a history the store had never recorded:
/// "58,420 steps", "7-day streak", "18 of the last 21 days". The store
/// held `stepsToday` and three other scalars, and nothing ever rolled
/// them into a dated record — so the figures could not have come from
/// anywhere but the widget tree.
///
/// Worse, and found while wiring this: the scalars were never reset
/// either. A user's step count accumulated across calendar days
/// forever. These cases pin both the archive and the rollover that
/// fills it.
/// ═══════════════════════════════════════════════════════════════════

void main() {
  group('DayRecord is an honest value object', () {
    test('a record round-trips through json', () {
      const record = DayRecord(
        date: '2026-09-28', steps: 6420, waterLiters: 2.1,
        kcal: 1840, protein: 118, workouts: 1, logged: true,
      );
      final back = DayRecord.fromJson(record.toJson());
      expect(back.date, '2026-09-28');
      expect(back.steps, closeTo(6420, 0.01));
      expect(back.waterLiters, closeTo(2.1, 0.01));
      expect(back.protein, closeTo(118, 0.01));
      expect(back.workouts, 1);
      expect(back.logged, isTrue, reason: 'a day with intake is a logged day');
    });

    test('hydration never throws on a malformed record', () {
      // §3: a corrupt entry must not cost the user the rest of their
      // history — the archive falls back, it does not abort.
      final back = DayRecord.fromJson(const {'date': '2026-09-28', 'steps': 'oops'});
      expect(back.steps, 0);
      expect(back.date, '2026-09-28');
    });
  });

  group('DayArchive records what the day actually held', () {
    test('a fresh archive has nothing to show', () {
      final archive = DayArchive();
      expect(archive.days, isEmpty);
      expect(archive.currentStreak, 0, reason: 'no logged days is no streak');
      expect(archive.loggedInLast(21), 0);
    });

    test('recording a day makes it readable back', () {
      final archive = DayArchive();
      archive.record(const DayRecord(
        date: '2026-09-28', steps: 6420, waterLiters: 2.1,
        kcal: 1840, protein: 118, workouts: 1, logged: true,
      ));
      expect(archive.days.length, 1);
      expect(archive.days.first.steps, closeTo(6420, 0.01));
    });

    test('recording the same date twice replaces, never duplicates', () {
      final archive = DayArchive();
      archive.record(const DayRecord(date: '2026-09-28', steps: 100, logged: true));
      archive.record(const DayRecord(date: '2026-09-28', steps: 900, logged: true));
      expect(archive.days.length, 1, reason: 'one calendar day is one record');
      expect(archive.days.first.steps, closeTo(900, 0.01));
    });

    test('days come back oldest first whatever order they arrived', () {
      final archive = DayArchive();
      archive.record(const DayRecord(date: '2026-09-29', steps: 2, logged: true));
      archive.record(const DayRecord(date: '2026-09-27', steps: 1, logged: true));
      expect(archive.days.map((d) => d.date).toList(), ['2026-09-27', '2026-09-29']);
    });

    test('the archive keeps a bounded window', () {
      // §3: this is a local-first app with no server — history must not
      // grow without limit inside the snapshot.
      final archive = DayArchive();
      final total = kDayArchiveMaxDays + 40;
      var day = DateTime(2026, 1, 1);
      for (var i = 1; i <= total; i++) {
        archive.record(DayRecord(date: pulseDayKey(day), steps: i.toDouble(), logged: true));
        day = day.add(const Duration(days: 1));
      }
      expect(archive.days.length, kDayArchiveMaxDays);
      expect(archive.days.last.steps, closeTo(total.toDouble(), 0.01),
          reason: 'the newest day survives; the oldest is dropped');
    });
  });

  group('the streak counts only consecutive logged days', () {
    test('three consecutive logged days ending today is a streak of three', () {
      final archive = DayArchive();
      final now = DateTime(2026, 9, 30);
      archive.record(const DayRecord(date: '2026-09-28', logged: true));
      archive.record(const DayRecord(date: '2026-09-29', logged: true));
      archive.record(const DayRecord(date: '2026-09-30', logged: true));
      expect(archive.currentStreak, 3);
      expect(archive.streakAsOf(now), 3);
    });

    test('a gap breaks the streak', () {
      final archive = DayArchive();
      archive.record(const DayRecord(date: '2026-09-26', logged: true));
      archive.record(const DayRecord(date: '2026-09-28', logged: true));
      archive.record(const DayRecord(date: '2026-09-29', logged: true));
      expect(archive.streakAsOf(DateTime(2026, 9, 29)), 2,
          reason: 'the 27th is missing, so the 26th cannot count');
    });

    test('an unlogged day is not a streak day even though the record exists', () {
      // A day the archive rolled over with nothing in it is a real
      // record of an empty day — it must not flatter the streak.
      final archive = DayArchive();
      archive.record(const DayRecord(date: '2026-09-29', logged: false));
      archive.record(const DayRecord(date: '2026-09-30', logged: true));
      expect(archive.streakAsOf(DateTime(2026, 9, 30)), 1);
    });

    test('a conditional streak counts only days meeting the condition', () {
      // Hydration and workout streaks ask a different question from
      // "did the user log at all" — a logged day that missed the water
      // goal breaks the water streak without breaking the logging one.
      final archive = DayArchive();
      archive.record(const DayRecord(date: '2026-09-28', waterLiters: 2.6, logged: true));
      archive.record(const DayRecord(date: '2026-09-29', waterLiters: 0.5, logged: true));
      archive.record(const DayRecord(date: '2026-09-30', waterLiters: 2.8, logged: true));
      final now = DateTime(2026, 9, 30);
      expect(archive.streakWhere((d) => d.waterLiters >= 2.5, now), 1,
          reason: 'the 29th missed the goal, so the 28th cannot count');
      expect(archive.streakAsOf(now), 3, reason: 'but all three were logged');
    });

    test('a streak that ended yesterday is not a current streak', () {
      final archive = DayArchive();
      archive.record(const DayRecord(date: '2026-09-27', logged: true));
      archive.record(const DayRecord(date: '2026-09-28', logged: true));
      expect(archive.streakAsOf(DateTime(2026, 9, 30)), 0,
          reason: 'honest: the user has not logged for two days');
    });
  });

  group('the archive answers the questions the screens were inventing', () {
    DayArchive seededWeek() {
      final archive = DayArchive();
      // A week a real user could have had: five logged days, two missed.
      archive.record(const DayRecord(date: '2026-09-21', steps: 8200, kcal: 1900, protein: 130, workouts: 1, logged: true));
      archive.record(const DayRecord(date: '2026-09-22', steps: 6100, kcal: 1700, protein: 95, logged: true));
      archive.record(const DayRecord(date: '2026-09-23', steps: 9400, kcal: 2100, protein: 140, workouts: 1, logged: true));
      archive.record(const DayRecord(date: '2026-09-24', steps: 0, logged: false));
      archive.record(const DayRecord(date: '2026-09-25', steps: 7300, kcal: 1850, protein: 125, logged: true));
      archive.record(const DayRecord(date: '2026-09-26', steps: 0, logged: false));
      archive.record(const DayRecord(date: '2026-09-27', steps: 5600, kcal: 1950, protein: 118, workouts: 1, logged: true));
      return archive;
    }

    test('total steps is the sum the weekly report claimed to know', () {
      expect(seededWeek().totalSteps(7), closeTo(36600, 0.01));
    });

    test('protein days counts days that met the goal, not days logged', () {
      // "5 / 7 protein days" was a constant. It is now a count against
      // the user's own goal.
      expect(seededWeek().proteinDaysMeeting(120, 7), 3,
          reason: '130, 140 and 125 clear 120; 95 and 118 do not');
    });

    test('workouts in the window is a real total', () {
      expect(seededWeek().totalWorkouts(7), 3);
    });

    test('loggedInLast reports the honest denominator', () {
      expect(seededWeek().loggedInLast(7), 5);
    });

    test('a day with activity is flagged for the calendar dots', () {
      // The calendars painted dots from `d % 3 == 0` arithmetic.
      final archive = seededWeek();
      expect(archive.wasActiveOn(DateTime(2026, 9, 21)), isTrue);
      expect(archive.wasActiveOn(DateTime(2026, 9, 24)), isFalse);
      expect(archive.wasActiveOn(DateTime(2026, 8, 1)), isFalse,
          reason: 'a day the archive never saw is not an active day');
    });

    test('the archive round-trips as a whole', () {
      final back = DayArchive.fromJson(seededWeek().toJson());
      expect(back.days.length, 7);
      expect(back.totalSteps(7), closeTo(36600, 0.01));
    });
  });

  group('the store rolls the day over instead of accumulating forever', () {
    test('a new calendar day archives the old one and clears the scalars', () {
      // The defect this found: nothing ever reset these, so steps
      // accumulated across days without limit.
      final store = PulseStore();
      // First boot adopts the day rather than archiving one it cannot
      // date; the rollover under test is the *second* call, a day later.
      store.rolloverIfNeeded(now: DateTime(2026, 9, 28));
      store.stepsToday = 6420;
      store.waterLogged = 2.1;
      store.workoutsCompletedToday = 1;

      store.rolloverIfNeeded(now: DateTime(2026, 9, 29));
      expect(store.stepsToday, 0, reason: 'a new day starts empty');
      expect(store.waterLogged, 0);
      expect(store.workoutsCompletedToday, 0);
      expect(store.archive.days.length, 1);
      expect(store.archive.days.first.steps, closeTo(6420, 0.01));
    });

    test('the same day does not roll over twice', () {
      final store = PulseStore();
      store.rolloverIfNeeded(now: DateTime(2026, 9, 28));
      store.stepsToday = 500;
      store.rolloverIfNeeded(now: DateTime(2026, 9, 29));
      store.stepsToday = 900;
      store.rolloverIfNeeded(now: DateTime(2026, 9, 29));
      expect(store.archive.days.length, 1, reason: 'still the same calendar day');
      expect(store.stepsToday, closeTo(900, 0.01), reason: 'and today is untouched');
    });

    test('rollover survives a restart', () async {
      final repo = _MemRepo();
      final store = PulseStore();
      await store.attachPersistence(repo);
      store.rolloverIfNeeded(now: DateTime(2026, 9, 28));
      store.stepsToday = 6420;
      store.rolloverIfNeeded(now: DateTime(2026, 9, 29));
      await store.flushPendingSave();

      final fresh = PulseStore();
      await fresh.attachPersistence(repo);
      expect(fresh.archive.days.length, 1);
      expect(fresh.archive.days.first.steps, closeTo(6420, 0.01));
    });

    test('an old snapshot with no archive hydrates to an empty one', () async {
      // Migration: every existing install has a snapshot written before
      // the archive existed. It must open, not crash.
      final repo = _MemRepo();
      final store = PulseStore();
      await store.attachPersistence(repo);
      store.rolloverIfNeeded(now: DateTime(2026, 9, 29));
      store.stepsToday = 100;
      store.logSip(0.1, now: DateTime(2026, 9, 29, 8, 0));
      await store.flushPendingSave();

      final raw = Map<String, dynamic>.from((await repo.readSnapshot())!);
      raw.remove('archive');
      await repo.writeSnapshot(raw);

      final fresh = PulseStore();
      await fresh.attachPersistence(repo);
      expect(fresh.archive.days, isEmpty);
      expect(fresh.stepsToday, closeTo(100, 0.01));
    });
  });

  group('water is recorded sip by sip', () {
    test('a fresh store has logged no sips', () {
      final store = PulseStore();
      expect(store.sips, isEmpty);
      expect(store.waterLogged, 0);
    });

    test('logging a sip records its volume and its time', () {
      final store = PulseStore();
      store.logSip(0.25, now: DateTime(2026, 9, 30, 14, 14));
      expect(store.sips.length, 1);
      expect(store.sips.first.liters, closeTo(0.25, 0.001));
      expect(store.sips.first.at.hour, 14);
      expect(store.waterLogged, closeTo(0.25, 0.001),
          reason: 'the total is derived from the sips, never set apart from them');
    });

    test('removing a sip removes its volume from the total', () {
      // The screen offered a working delete button over invented rows.
      final store = PulseStore();
      store.logSip(0.25, now: DateTime(2026, 9, 30, 9, 0));
      store.logSip(0.50, now: DateTime(2026, 9, 30, 11, 0));
      expect(store.waterLogged, closeTo(0.75, 0.001));
      store.removeSip(store.sips.first);
      expect(store.sips.length, 1);
      expect(store.waterLogged, closeTo(0.50, 0.001));
    });

    test('sips survive a restart and clear on rollover', () async {
      final repo = _MemRepo();
      final store = PulseStore();
      await store.attachPersistence(repo);
      store.rolloverIfNeeded(now: DateTime(2026, 9, 29));
      store.logSip(0.3, now: DateTime(2026, 9, 29, 8, 0));
      await store.flushPendingSave();

      final fresh = PulseStore();
      await fresh.attachPersistence(repo);
      expect(fresh.sips.length, 1);
      fresh.rolloverIfNeeded(now: DateTime(2026, 9, 30));
      expect(fresh.sips, isEmpty, reason: "yesterday's sips are not today's");
    });
  });
}

// ── Doubles ────────────────────────────────────────────────────────
/// In-memory stand-in for the snapshot repository (§5 test convention:
/// hand-written doubles, no mocking package).
class _MemRepo implements LocalRepository {
  Map<String, dynamic>? _snapshot;

  @override
  Future<void> init() async {}

  @override
  Future<Map<String, dynamic>?> readSnapshot() async => _snapshot;

  @override
  Future<void> writeSnapshot(Map<String, dynamic> snapshot) async =>
      _snapshot = snapshot;

  @override
  Future<void> clearAll() async => _snapshot = null;
}
